Event Sourcing is an architectural pattern in which changes to the state of an application are stored as a sequence of
events. Instead of storing just the current state of the data in a domain, event sourcing also saves the series of
actions carried out on that data. The events are stored in an append-only log and can be used to reconstruct past
states, audit changes, and drive application state forward.

### Key Concepts of Event Sourcing

- **Events**: Immutable records that capture a fact or action in the system, such as 'UserRegistered' or 'OrderPlaced'.
  Each event represents a state change.
- **Event Store**: The storage mechanism for the events. It acts as the source of truth for the application state.
- **Aggregates**: Entities or domain objects that get their state by applying events in sequence.
- **Projections**: Read models created from events that are optimized for queries.
- **Event Handlers**: Logic that reacts to events, either by updating state, triggering side effects, or producing new
  events.

### Benefits

- **Auditability**: Since all changes are stored as events, it provides a complete history of the state changes.
- **Flexibility**: New features can be added by introducing new events and handlers without modifying existing code.
- **Scalability**: Events are append-only, and projections can be rebuilt, allowing for distributed systems that scale
  well.

### Example in PHP

Consider an order management system where order actions are recorded as events.

```php
interface Event {
    public function getType();
    public function getPayload();
}

class OrderPlaced implements Event {
    protected $orderId;
    protected $orderDetails;

    public function __construct($orderId, $orderDetails) {
        $this->orderId = $orderId;
        $this->orderDetails = $orderDetails;
    }

    public function getType() {
        return 'OrderPlaced';
    }

    public function getPayload() {
        return ['orderId' => $this->orderId, 'orderDetails' => $this->orderDetails];
    }
}

class EventStore {
    protected $events = [];

    public function store(Event $event) {
        $this->events[] = $event;
    }

    public function getEvents() {
        return $this->events;
    }
}
```

### Usage

```php
$eventStore = new EventStore();
$orderDetails = ['product' => 'Book', 'quantity' => 1];
$orderPlacedEvent = new OrderPlaced(1, $orderDetails);

$eventStore->store($orderPlacedEvent);

foreach ($eventStore->getEvents() as $event) {
    // Process event
    echo $event->getType() . ' with payload: ' . json_encode($event->getPayload()) . "\\n";
}
```

In this example, `OrderPlaced` is an event representing the action of placing an order. The `EventStore` acts as the
repository for these events. By storing each action as an event, the system can reconstruct the order's state at any
point, ensure the order's actions are auditable, and react to events as needed.

### Conclusion

Event Sourcing provides a robust architecture for managing state changes in a system, offering advantages in terms of
auditability, flexibility, and scalability. However, it introduces complexity and requires careful consideration of
event storage, replay, and versioning strategies.
