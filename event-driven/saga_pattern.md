# The saga pattern

**Interview framing:**

"A saga is a sequence of local transactions across multiple services, coordinated so that if any step fails, previous steps are compensated — rolled back through domain-specific undo operations. It's the distributed-systems answer to 'I can't use a single database transaction because the data lives in different services'. The two flavors are choreography (services react to each other's events) and orchestration (a central coordinator drives the flow). The senior insight is that sagas are not a substitute for transactions — they're a fundamentally different model with different guarantees, and the compensation logic is where all the complexity lives."

### The problem sagas solve

In a monolith, a business operation like "place an order" runs in a single database transaction:

```sql
BEGIN;
INSERT INTO orders (...);
UPDATE inventory SET stock = stock - 1 WHERE sku = 'ABC';
INSERT INTO payments (...);
COMMIT;
```

All three steps succeed or fail atomically. In microservices, the order, inventory, and payment data live in different databases owned by different services. There's no shared transaction.

Options:

1. **Distributed transaction (2PC).** Coordinated commit across databases. Slow, operationally complex, not supported by most message brokers, and a known availability bottleneck.
2. **Saga.** Each service commits locally; events coordinate the steps; failures trigger compensating actions.

Sagas are the pragmatic choice for most microservice architectures.

### How a saga works

A saga breaks a business operation into a series of **steps**. Each step is a local transaction within one service. After each step succeeds, the next step is triggered (via events or commands). If a step fails, **compensating transactions** undo the effects of previous steps.

**The order saga:**

```text
Step 1: Order service → create order (status: PENDING)
Step 2: Payment service → reserve funds
Step 3: Inventory service → reserve stock
Step 4: Order service → confirm order (status: CONFIRMED)
```

**If step 3 fails (out of stock):**

```text
Compensation 2: Payment service → release reserved funds
Compensation 1: Order service → cancel order (status: CANCELLED)
```

Each compensation undoes the *business effect* of a prior step, not the database transaction. "Release reserved funds" is not `ROLLBACK` — it's a new operation that reverses the business meaning.

### Choreography — services react to events

In choreography, there's no central coordinator. Each service publishes events after its local transaction, and other services subscribe and react.

```text
Order Service: create order → publish OrderCreated
    ↓
Payment Service: subscribes to OrderCreated → reserve funds → publish PaymentReserved
    ↓
Inventory Service: subscribes to PaymentReserved → reserve stock → publish StockReserved
    ↓
Order Service: subscribes to StockReserved → confirm order → publish OrderConfirmed
```

**If Inventory fails:**

```text
Inventory Service: publish StockReservationFailed
    ↓
Payment Service: subscribes → release funds → publish PaymentReleased
    ↓
Order Service: subscribes → cancel order → publish OrderCancelled
```

**Pros:**

- No single point of failure. No coordinator to go down.
- Each service is autonomous — it reacts to events without being told what to do.
- Simple for short sagas (2-3 steps).

**Cons:**

- **Hard to understand.** The flow is implicit — you have to read every service's event subscriptions to reconstruct the saga. There's no single place that describes the whole workflow.
- **Hard to debug.** When something goes wrong, you trace events across services. No central log of "what step are we on?"
- **Cyclic dependencies.** Services can develop event loops where A reacts to B reacts to A.
- **Compensation chains are complex.** Every service needs to know which events to listen to for rollback, and the ordering of compensations is implicit.

**Use choreography when:** the saga is short (2-3 steps), the flow is stable and rarely changes, and each service genuinely owns its piece of the logic.

### Orchestration — a coordinator drives the flow

In orchestration, a central **saga orchestrator** (a dedicated service or a workflow engine) drives the steps. It sends commands to each service and receives replies.

```text
Saga Orchestrator:
  1. Send CreateOrder command to Order Service → receive OrderCreated
  2. Send ReservePayment command to Payment Service → receive PaymentReserved
  3. Send ReserveStock command to Inventory Service → receive StockReserved
  4. Send ConfirmOrder command to Order Service → receive OrderConfirmed
```

**If step 3 fails:**

```text
Saga Orchestrator:
  3. Receive StockReservationFailed
  Compensate 2: Send ReleasePayment to Payment Service
  Compensate 1: Send CancelOrder to Order Service
```

**Pros:**

- **The flow is explicit.** One place describes the entire saga: the orchestrator. You can read it, debug it, version it.
- **Compensation logic is centralized.** The orchestrator knows exactly which steps have been completed and which need compensating.
- **Easy to add steps.** Adding a new step means updating one orchestrator, not modifying event subscriptions across multiple services.
- **Better error handling.** The orchestrator can retry individual steps, apply timeouts, and make complex decisions.

**Cons:**

- **Single point of failure.** The orchestrator must be reliable and available. If it goes down, sagas stall.
- **Coupling to the orchestrator.** Services receive commands from the orchestrator, creating a dependency.
- **Risk of becoming a God service.** If the orchestrator accumulates too much business logic, it becomes a monolith in disguise.

**Use orchestration when:** the saga has many steps, the flow is complex with conditional branches, compensation logic is non-trivial, or you need clear visibility into the saga state.

### Choreography vs orchestration — the decision

```text
Is the saga 2-3 simple, linear steps?
├── Yes → choreography is fine.
└── No → Is the flow complex, conditional, or frequently changing?
         ├── Yes → orchestration.
         └── It's moderate (4-5 steps, mostly linear) → either works; 
             prefer orchestration for debuggability.
```

Many teams start with choreography because it feels simpler, then migrate to orchestration when the saga grows beyond 3-4 steps and the implicit flow becomes impossible to reason about.

### Compensation — the hard part

Compensating transactions are the core complexity of sagas. They're not rollbacks — they're new operations that semantically undo a previous step.

Design considerations:

- **Not every operation has a clean compensation.** "Send an email" can't be unsent. "Charge a credit card" can be refunded, but the user sees both the charge and the refund.
- **Compensations can fail.** The compensation itself might not succeed (network failure, service down). You need retry logic on compensations, and a dead-letter strategy for compensations that can't complete.
- **Compensations must be idempotent.** Running the same compensation twice should be safe.
- **Order matters.** Compensations should run in reverse order of the original steps. Don't release payment before you've cancelled the order.
- **Some compensations are "no-ops" if the step used a reservation model.** "Reserve funds" is compensated by "release reservation", not "refund the charge". The reservation model is deliberately designed to make compensation cheap.

### The reservation pattern — designing for compensation

Instead of making irreversible changes immediately, make them in two phases:

1. **Reserve** — a tentative hold that can be released cheaply. "Reserve $50 from the customer's payment method" (no actual charge). "Reserve 3 units of inventory" (not yet committed).
2. **Confirm or release** — after the saga succeeds, confirm the reservation. After it fails, release it.

This pattern makes compensation trivial: releasing a reservation is a lightweight operation that doesn't affect the user. Contrast with "charge the credit card" → "refund the credit card" → user sees both on their statement and calls support.

Design business operations to be reservable when possible. It dramatically simplifies sagas.

### Saga state management

The orchestrator (or in choreography, each service) needs to track the saga's current state: which steps have been completed, what the saga's overall status is, and what data has been accumulated.

Storage options:

- **Database table.** A `sagas` table with `saga_id`, `status`, `current_step`, `data`. Simple, durable, queryable.
- **Event log.** The saga's state is derived from the events it's produced. Event-sourced sagas are powerful but add complexity.
- **Workflow engine.** Temporal, Camunda, AWS Step Functions — dedicated tools for saga orchestration with built-in state management, retries, and timeouts.

For PHP, a database table with a saga entity managed by Doctrine is the simplest starting point. Workflow engines are worth it when saga complexity justifies the tooling investment.

### Timeouts and stuck sagas

A saga can get stuck if a step never completes — the service is down, the message is lost, the handler is broken.

Mitigation:

- **Timeouts per step.** If a step doesn't complete within N minutes, the orchestrator triggers compensation.
- **Idempotent retries.** Retry the command before giving up.
- **Dead-letter monitoring.** Failed saga steps that can't complete go to a DLQ and trigger alerts.
- **Manual intervention.** Some stuck sagas need human attention. The saga state should be inspectable and resumable.

### Sagas and idempotency

Because messages can be delivered more than once, every saga step and every compensation must be idempotent:

- Same command delivered twice → same effect as once.
- Same compensation run twice → same effect as once.

This is non-negotiable. Without it, retries and redeliveries produce wrong states.

See [../message-brokers/idempotent_consumers.md](../message-brokers/idempotent_consumers.md) for implementation patterns.

> **Mid-level answer stops here.** A mid-level dev can describe choreography and orchestration. To sound senior, speak to compensation design, the reservation pattern, and the operational concerns of running sagas in production ↓
>
> **Senior signal:** treating compensation as the primary design challenge of sagas and designing operations to be compensatable from the start.

### The design principles I follow

1. **Design for compensation first.** Before implementing a saga step, ask "how do I undo this?". If the answer is "I can't", redesign the step (use reservations, split the operation, or accept the risk explicitly).
2. **Prefer orchestration for anything beyond 3 steps.** Debuggability matters more than decoupling at scale.
3. **Use the reservation pattern wherever possible.** Reserve → confirm/release is always cheaper than do → undo.
4. **Every step and compensation is idempotent.** Non-negotiable.
5. **Timeouts on every step.** No step should block the saga indefinitely.
6. **The saga state is observable.** You should be able to query "what sagas are stuck, what step are they on, how long have they been there?"
7. **Saga logs are audit trails.** The sequence of events and compensations is a natural audit log for the business operation.

### Common mistakes

- **No compensation logic.** "We'll handle failures manually." You won't.
- **Irreversible steps without the reservation pattern.** Charging a credit card as step 2 of a 5-step saga means you might need to refund it — which the customer will notice.
- **Choreography with 7 steps.** Nobody can follow the flow. Use orchestration.
- **Non-idempotent steps.** Redelivery produces duplicate charges, duplicate reservations, duplicate notifications.
- **No timeouts.** A stuck saga blocks the business operation indefinitely.
- **Compensations that can fail without retry.** A failed compensation leaves the system in a partially-rolled-back state.
- **Orchestrator as a God service.** The orchestrator coordinates; it doesn't contain business logic. Business logic stays in the services.

### Closing

"So a saga is a sequence of local transactions coordinated by events (choreography) or by a central orchestrator (orchestration), with compensating transactions to undo previous steps when a later step fails. Choreography works for short, simple flows; orchestration works for complex ones. The real design challenge is compensation — every step must be undoable, ideally through the reservation pattern. Every step and compensation must be idempotent. Timeouts prevent stuck sagas. And the saga state should be observable and inspectable. Sagas are not transactions — they're a different model with weaker guarantees and more design work — but they're the pragmatic answer to distributed business operations across services."
