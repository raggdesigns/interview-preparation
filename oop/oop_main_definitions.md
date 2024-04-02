Object-Oriented Programming (OOP) is a programming paradigm based on the concept of "objects", which can contain data in
the form of fields (often known as attributes or properties), and code in the form of procedures (often known as
methods). OOP aims to increase the flexibility and maintainability of code through its main concepts: Encapsulation,
Abstraction, Inheritance, and Polymorphism.

### Encapsulation

Encapsulation is the bundling of data (attributes) and methods that operate on the data into a single unit, or class,
and restricting access to some of the object's components. This concept is often used to hide the internal
representation, or state, of an object from the outside.

**Example in PHP**:

```php
class BankAccount {
    private $balance = 0; // Data encapsulation
    
    public function deposit($amount) { // Encapsulated method to modify the data
        if ($amount > 0) {
            $this->balance += $amount;
        }
    }
    
    public function getBalance() { // Encapsulated method to access the data
        return $this->balance;
    }
}
```

In this example, the `$balance` attribute is encapsulated within the `BankAccount` class, exposing only the `deposit`
and `getBalance` methods to interact with it.

### Abstraction

Abstraction is the concept of hiding the complex reality while exposing only the necessary parts. It is a process of
reducing the complexity by hiding the unnecessary details from the user.

**Example in PHP** (Continuation from Encapsulation):

The `BankAccount` class itself is an abstraction. Users of the class don't need to understand the inner workings of
the `deposit` and `getBalance` methods to use its functionality; they just need to know what these methods do.

### Inheritance

Inheritance is a mechanism where a new class is derived from an existing class. The new class inherits all the
properties and behaviors of the existing class, allowing for reuse and extension of existing code without modification.

**Example in PHP** ( `Animal`, `Dog`, and `Cat`).

### Polymorphism

Polymorphism is the ability of different classes to respond to the same method or message in different ways. It allows
objects of different types to be treated as objects of a common super-type.

**Example in PHP** (Continuation from the Inheritance example with `Animal`, `Dog`, and `Cat`).

### Conclusion

The main concepts of OOP—Encapsulation, Abstraction, Inheritance, and Polymorphism—work together to help developers
create more flexible, modular, and reusable code. By leveraging these principles, OOP promotes greater simplicity in
application development and maintenance.
