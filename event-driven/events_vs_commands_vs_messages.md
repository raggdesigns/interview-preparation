# Events vs commands vs messages

**Interview framing:**

"The distinction between events, commands, and messages is one of those things that sounds pedantic until you get it wrong and build a system with confused semantics. A command says 'do this'; an event says 'this happened'; a message is the envelope that carries either. The confusion creates real bugs: if you publish 'CreateOrder' as an event, you imply anyone can handle it, but only one service should — that's a command. If you publish 'OrderCreated' as a command to a specific handler, you lose the broadcast benefit of events. Getting the semantics right up front shapes the topology of the whole system."

### The three concepts

#### Message — the envelope

A message is any unit of data sent between components. It's the transport-level concept. RabbitMQ handles messages; Kafka handles records (which are messages). The message is the *carrier*; what it carries is either a command or an event.

Don't design around "messages" as a concept — design around commands and events. The message is the wire format, not the semantic.

#### Command — "do this"

A command is a request for an action. It has a sender, a receiver, and an expectation that it will be handled.

- **Naming:** imperative. `CreateOrder`, `SendEmail`, `CancelSubscription`, `ReserveInventory`.
- **Directed:** one command, one handler. Not broadcast. Not "whoever feels like it".
- **Can be rejected.** The handler can refuse to execute.
- **Changes state.** The handler performs a side effect.
- **Sender expects a result** (at least success/failure, possibly a return value).

Commands are naturally processed by **work queues** (competing consumers pattern): the command goes to a queue, one worker picks it up and handles it.

```text
Producer → [CreateOrder] → work queue → single handler
```

#### Event — "this happened"

An event is a notification that something already occurred. It has a producer but no specific consumer — anyone can listen.

- **Naming:** past tense. `OrderCreated`, `PaymentCaptured`, `UserSignedUp`.
- **Broadcast:** zero, one, or many consumers. The producer doesn't know who's listening.
- **Cannot be rejected.** It's a fact. The order was created; you can't reject the event.
- **Doesn't expect a response.** The producer publishes and moves on.
- **Immutable.** Once published, the event doesn't change.

Events are naturally processed by **pub/sub** (fan-out pattern): the event goes to an exchange, every interested consumer gets a copy.

```text
Producer → [OrderCreated] → topic exchange → billing queue
                                           → inventory queue
                                           → analytics queue
```

### Why the distinction matters

The semantics determine the topology:

| | Command | Event |
|---|---|---|
| Direction | Point-to-point | Broadcast |
| Consumers | Exactly one | Zero to many |
| Coupling | Sender knows receiver (or at least that there is one) | Sender doesn't know receivers |
| Rejectable | Yes | No |
| Naming | Imperative (do X) | Past tense (X happened) |
| Response expected | Yes (at least ack) | No |
| Adding consumers | Requires sender change | No sender change |

If you model everything as commands, you can't add a new consumer without updating the sender. If you model everything as events, you lose the "one handler, guaranteed execution" semantics of tasks.

### The common confusion: command disguised as event

The most common mistake is publishing what is semantically a command as if it were an event:

```json
{"type": "CreateOrder", "user_id": 42, "items": [...]}
```

Published to a topic exchange where multiple consumers could receive it. But only one service should create the order. If two consumers both try, you get duplicate orders.

The fix: recognize this as a command and route it to a work queue with competing consumers (only one handles it), or don't use a broker at all — use a synchronous API call.

### The common confusion: event disguised as command

The reverse mistake: publishing an event to a specific queue as if it were a command:

```json
{"type": "OrderCreated", "order_id": "abc-123"}
```

Sent directly to the billing service's queue. This works — billing gets the event — but it couples the producer to the consumer. Adding analytics means updating the producer to also send to the analytics queue. You've lost the broadcast benefit that makes events valuable.

The fix: publish to an exchange, let each consumer bind its own queue.

### The pattern in practice

A typical order flow uses both:

1. **User submits order** → synchronous API call (or command message) to the order service: `CreateOrder`.
2. **Order service validates and creates the order** → writes to DB → publishes event: `OrderCreated`.
3. **Billing service** subscribes to `OrderCreated` → processes payment → publishes event: `PaymentCaptured`.
4. **Inventory service** subscribes to `OrderCreated` → reserves stock → publishes event: `InventoryReserved`.
5. **Notification service** subscribes to `PaymentCaptured` → sends confirmation email.

Commands are synchronous or point-to-point (step 1). Events are broadcast (steps 2-5). Each service has its own queue for the events it cares about.

### Domain events vs integration events

A useful sub-distinction:

**Domain events** — events within a bounded context (inside one service). Handled synchronously or in the same transaction. `OrderLineAdded`, `DiscountApplied`, `OrderTotalRecalculated`. These are internal and shouldn't leak outside the service.

**Integration events** — events published to other services. `OrderCreated`, `PaymentCaptured`. These are the public contract. They should be stable, versioned, and contain enough data for consumers to act independently.

The mapping: domain events drive internal logic; integration events drive cross-service communication. Not every domain event becomes an integration event. Only the ones that matter externally.

In Symfony: Symfony Messenger dispatches commands and events to handlers. You can mark some messages for async transport (integration events to a broker) and keep others synchronous (domain events handled in-process).

### Message contracts

Whether command or event, the message has a schema that's a contract:

- **For commands:** the contract is between the sender and the receiver. Change by agreement.
- **For events:** the contract is between the producer and all consumers. Change requires backward compatibility or versioning.

Events are harder to evolve because you don't know all your consumers. Commands are easier because there's one handler. This asymmetry is why event schema discipline matters more.

> **Mid-level answer stops here.** A mid-level dev can describe the difference. To sound senior, speak to the architectural consequences of confusing them and the design discipline that keeps them clean ↓
>
> **Senior signal:** recognizing that the command/event distinction shapes the system's coupling structure and evolution trajectory.

### The design rules I follow

1. **Name it correctly.** Past tense = event. Imperative = command. The name should make the semantic unambiguous.
2. **Events go to exchanges; commands go to queues.** If you're putting a command on a topic exchange, something is wrong. If you're routing an event to a specific queue, you're losing the benefit.
3. **One handler per command; many handlers per event.** If multiple services should all react to the same message, it's an event. If exactly one service should handle it, it's a command.
4. **Don't expect a response from events.** If the producer needs to know the result, it's a command (or a saga coordination point, see [saga_pattern.md](saga_pattern.md)).
5. **Domain events stay internal; integration events cross service boundaries.** Don't leak internal domain events to external consumers.
6. **Commands can fail; events can't.** A handler can reject a command ("invalid input"). An event is a recorded fact — the handler processes it or dead-letters it, but doesn't "reject" it.

### Common mistakes

- **Commands broadcast to multiple consumers.** Duplicate handling, race conditions.
- **Events routed to single consumers.** Tight coupling, can't add new subscribers.
- **Present-tense naming.** `OrderCreate` — is this a command or an event? Ambiguous. `CreateOrder` (command) or `OrderCreated` (event) is clear.
- **Events that expect responses.** "I published `OrderCreated` and I need to know if billing handled it." That's a saga coordination problem, not an event problem.
- **No distinction in the codebase.** Commands and events in the same namespace with the same handling pattern. They should be separate types with different routing.
- **Publishing domain events as integration events.** Internal `OrderLineAdded` doesn't need to leave the service. Only `OrderCreated` (the aggregate-level fact) crosses the boundary.

### Closing

"So: commands are 'do this' (imperative, one handler, can fail), events are 'this happened' (past tense, broadcast, immutable), and messages are the transport that carries either. The distinction shapes the system's coupling: commands create point-to-point dependencies, events create broadcast relationships. Getting the semantics right up front — and naming accordingly — prevents a class of architectural bugs that are painful to fix later. Past tense for events, imperative for commands, exchanges for events, queues for commands."
