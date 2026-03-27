The Observer pattern is a behavioral design pattern where an object, known as the subject, maintains a list of its dependents, called observers, and notifies them automatically of any state changes, usually by calling one of their methods. It is mainly used to implement distributed event handling systems and is a foundational aspect of the Model-View-Controller (MVC) architectural pattern. The Observer pattern promotes loose coupling since the subject doesn't need to know anything about the observers, other than that they implement a certain interface.

### Short definition

The Observer pattern allow a bunch of objects to be notified by central object if something happens.

### Key Concepts of the Observer Pattern

- **Subject**: The entity being observed. It maintains a list of observers and notifies them of changes to its state.
- **Observer**: An interface or abstract class defining the operations to be used to notify this object of changes in the subject's state.
- **ConcreteObserver**: Implements the Observer interface and defines how to react to notifications from the Subject.

### Benefits

- **Loose Coupling**: The subject and observers are loosely coupled. The subject doesn't know the details of the observers, only that they implement the Observer interface.
- **Dynamic Relationships**: You can add and remove observers dynamically at runtime without modifying the subject or the other observers.
- **Broadcast Communication**: Changes to the subject's state can be broadcast to all interested observers simultaneously.

### Example in PHP

Consider a simple example where a `Product` class (Subject) notifies a list of observer classes when its price changes.

```php
interface Observer {
    public function update($subject);
}

interface Subject {
    public function attach(Observer $observer);
    public function detach(Observer $observer);
    public function notify();
}

// Concrete Subject
class Product implements Subject {
    private $observers = [];
    private $price;

    public function attach(Observer $observer) {
        $this->observers[spl_object_hash($observer)] = $observer;
    }

    public function detach(Observer $observer) {
        unset($this->observers[spl_object_hash($observer)]);
    }

    public function notify() {
        foreach ($this->observers as $observer) {
            $observer->update($this);
        }
    }

    public function setPrice($price) {
        $this->price = $price;
        $this->notify();
    }

    public function getPrice() {
        return $this->price;
    }
}

// Concrete Observer
class PriceObserver implements Observer {
    public function update($subject) {
        echo "New price: " . $subject->getPrice();
    }
}
```

### Usage

```php
$product = new Product();
$priceObserver = new PriceObserver();

$product->attach($priceObserver);
$product->setPrice(20); // Outputs: New price: 20

$product->detach($priceObserver);
$product->setPrice(30); // No output since the observer was detached
```

In this example, the `Product` class notifies its observers whenever its price is changed via `setPrice`. The `PriceObserver` reacts to these notifications by printing the new price. This demonstrates how the Observer pattern enables a subscribe-notify mechanism between objects, promoting a loose coupling between them.
