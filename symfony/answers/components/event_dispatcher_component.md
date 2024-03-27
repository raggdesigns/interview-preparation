
# Event Dispatcher Component

The Event Dispatcher Component provides a lightweight and flexible system for Symfony applications to subscribe to and dispatch events throughout the application. This component is essential for implementing the Observer pattern, allowing for decoupled application architecture.

## Core Concepts

- **Event**: An object that encapsulates the information related to a specific action or occurrence within the application.
- **Dispatcher**: Manages the dispatching of events and notifies registered listeners or subscribers about those events.
- **Listener**: A PHP callable that listens to a specific event and gets executed when that event is dispatched.
- **Subscriber**: Similar to a listener, but a subscriber can listen to multiple events.

## Benefits

- **Decoupling**: Helps in decoupling different parts of the application by allowing event-driven communication between components.
- **Flexibility**: Makes the application more flexible and adaptable to change by enabling dynamic event handling.
- **Reusability**: Promotes reusability of the event handling logic across different parts of the application or in different applications.

## Example Usage

### Creating an Event

First, define an event class:

```php
namespace App\Event;

use Symfony\Contracts\EventDispatcher\Event;

class OrderPlacedEvent extends Event
{
    public const NAME = 'order.placed';

    protected $orderId;

    public function __construct(int $orderId)
    {
        $this->orderId = $orderId;
    }

    public function getOrderId(): int
    {
        return $this->orderId;
    }
}
```

### Dispatching an Event

Next, dispatch the event from anywhere in your application:

```php
use App\Event\OrderPlacedEvent;
use Symfony\Component\EventDispatcher\EventDispatcher;

$dispatcher = new EventDispatcher();
$event = new OrderPlacedEvent(123);

$dispatcher->dispatch($event, OrderPlacedEvent::NAME);
```

### Listening to an Event

To listen to the `OrderPlacedEvent`, define a listener:

```php
class OrderListener
{
    public function onOrderPlaced(OrderPlacedEvent $event)
    {
        // Handle the event, e.g., send an email confirmation
    }
}

$listener = new OrderListener();
$dispatcher->addListener(OrderPlacedEvent::NAME, [$listener, 'onOrderPlaced']);
```

### Using Subscribers

Alternatively, you can use an event subscriber to listen to one or more events:

```php
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

class OrderSubscriber implements EventSubscriberInterface
{
    public static function getSubscribedEvents()
    {
        return [
            OrderPlacedEvent::NAME => 'onOrderPlaced',
        ];
    }

    public function onOrderPlaced(OrderPlacedEvent $event)
    {
        // Handle the event
    }
}

$dispatcher->addSubscriber(new OrderSubscriber());
```

## Conclusion

The Event Dispatcher Component is a powerful tool for implementing event-driven programming in Symfony applications, allowing for clean separation of concerns and enhancing the extensibility and flexibility of the application.
