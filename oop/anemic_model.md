The Anemic Domain Model is a term coined by Martin Fowler to describe a software design anti-pattern where the domain
model is focused solely on data without encapsulating any domain logic. In this pattern, the business logic is typically
implemented in separate classes, such as services, which manipulate the state of the domain objects. This approach
contrasts with a rich domain model, where logic and data are combined to model real-world business entities more
closely.

### Key Characteristics of the Anemic Domain Model

- **Data-Only Entities**: Entities in the model primarily contain data fields without any business logic.
- **Service-Layer Business Logic**: Business logic is implemented outside the domain model, often in service classes or
  transaction scripts.
- **Separation of State and Behavior**: There is a clear separation between the state of the application (stored in the
  domain entities) and the behavior (implemented in services or controllers).

### Example in PHP

Consider an e-commerce application with a simple `Order` entity. In an anemic domain model, the `Order` class might look
like this:

```php
class Order {
    public $id;
    public $orderLines = [];
    public $status;

    // Getter and setter methods for the properties
}

class OrderService {
    public function calculateTotal(Order $order) {
        $total = 0;
        foreach ($order->orderLines as $line) {
            $total += $line['quantity'] * $line['price'];
        }
        return $total;
    }

    public function addOrderLine(Order $order, $line) {
        $order->orderLines[] = $line;
    }

    // Other methods manipulating Order
}
```

In this example, the `Order` class is purely a data container without any business logic. The `OrderService` class
contains all the operations that can be performed on an `Order`, such as calculating the total or adding an order line.

### Criticisms of the Anemic Domain Model

- **Violation of Object-Oriented Design Principles**: The separation of state and behavior goes against the basic
  principles of object-oriented design, where objects are supposed to encapsulate both data and behavior.
- **Increased Complexity**: The logic being external to the model can lead to bloated service classes and make it harder
  to maintain and understand the codebase.
- **Difficulties in Enforcing Business Rules**: With logic spread across services, it can become challenging to ensure
  that all business rules are consistently applied.

### Conclusion

While the Anemic Domain Model may seem simpler and more straightforward at first, especially for developers coming from
a procedural programming background, it often results in a design that is harder to maintain and evolve. A rich domain
model, where entities encapsulate both data and behavior, can lead to a more intuitive and maintainable design,
especially in complex applications with extensive business logic.
