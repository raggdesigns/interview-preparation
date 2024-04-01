Demeter's Law, also known as the Law of Demeter (LoD) or the Principle of Least Knowledge, is a guideline designed to
promote loose coupling in software designs. It was formulated at Northeastern University in the late 1980s, named after
the Greek goddess Demeter, as a playful nod to its origin. The principle emphasizes that a given object should assume as
little as possible about the structure or properties of anything else it interacts with, including its own
subcomponents.

### Key Points of Demeter's Law:

- **Only talk to your immediate friends**: Objects should only call methods on:
    - Themselves
    - Objects passed in as a parameter to the method
    - Any object they create or instantiate
    - Any components (objects) held in instance variables

By adhering to these restrictions, the principle aims to reduce the dependencies between components, making the system
more maintainable and adaptable to change.

### Common Usage Examples:

Applying Demeter's Law in object-oriented programming typically means avoiding "train wrecks" – chains of method calls
delving into an object's internal structure – and instead requiring that interactions happen through well-defined
interfaces.

#### Before Applying Demeter's Law:

Consider a shopping cart example where items in the cart have a discount policy, and you want to calculate the price
after discount:

```php
class ShoppingCart {
    public function calculateTotal() {
        $total = 0;
        foreach ($this->items as $item) {
            // Violates Demeter's Law
            $discount = $item->getDiscountPolicy()->getDiscountRate();
            $total += $item->getPrice() - ($item->getPrice() * $discount);
        }
        return $total;
    }
}
```

In this example, `calculateTotal` violates Demeter's Law by navigating through the `item` to its `discountPolicy` to get
the `discountRate`, indicating a high level of coupling.

#### After Applying Demeter's Law:

A better approach would be to encapsulate the discount calculation within the item or discount policy class:

```php
class Item {
    public function getDiscountedPrice() {
        $discount = $this->discountPolicy->getDiscountRate();
        return $this->price - ($this->price * $discount);
    }
}

class ShoppingCart {
    public function calculateTotal() {
        $total = 0;
        foreach ($this->items as $item) {
            // Complies with Demeter's Law
            $total += $item->getDiscountedPrice();
        }
        return $total;
    }
}
```

In the revised example, `ShoppingCart` only interacts with `Item`, and the logic to apply the discount is encapsulated
within `Item`, adhering to Demeter's Law. This reduces the coupling between `ShoppingCart` and the discount policy
implementation.

### Conclusion:

The Law of Demeter encourages shallow, rather than deep, interaction between objects, reducing dependencies and making
the overall system easier to maintain. However, like any principle, it should be applied judiciously and not treated as
an absolute rule. Excessive adherence to Demeter's Law can sometimes lead to an explosion of wrapper methods that merely
delegate to other methods, adding unnecessary complexity. The key is finding a balance that reduces coupling without
overly complicating the codebase.
