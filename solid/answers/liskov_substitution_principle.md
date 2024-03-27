# Liskov Substitution Principle (LSP)

The Liskov Substitution Principle (LSP) is a concept in object-oriented programming that states objects of a superclass should be replaceable with objects of a subclass without affecting the correctness of the program. Essentially, subclasses should extend the base classes without changing their behavior.

### Violating LSP

A common violation of LSP occurs when a subclass overrides a method of its superclass in a way that does not support the original behavior.

```php
class Bird {
    public function fly() {
        echo "Fly high in the sky";
    }
}

class Ostrich extends Bird {
    public function fly() {
        throw new Exception("I can't fly");
    }
}

function letTheBirdFly(Bird $bird) {
    $bird->fly();
}

letTheBirdFly(new Bird()); // Works fine
letTheBirdFly(new Ostrich()); // Throws an exception
```

In this example, `Ostrich` is a subclass of `Bird`. However, not all birds can fly, making the `fly` method inappropriate for `Ostrich`, thus violating LSP.

### Refactored Code Applying LSP

To adhere to LSP, we should redesign the class hierarchy to ensure that subclasses can be used in place of a base class.

```php
interface Bird {
    public function eat();
}

interface FlyingBird extends Bird {
    public function fly();
}

class Sparrow implements FlyingBird {
    public function eat() {
        echo "Eat";
    }
    
    public function fly() {
        echo "Fly high in the sky";
    }
}

class Ostrich implements Bird {
    public function eat() {
        echo "Eat";
    }
}

function letTheBirdFly(FlyingBird $bird) {
    $bird->fly();
}

letTheBirdFly(new Sparrow()); // Works fine
// letTheBirdFly(new Ostrich()); // This will now result in a compile-time error
```

### Explanation

- By separating the interfaces for `Bird` and `FlyingBird`, we ensure that only birds that can fly implement the `fly` method. This adheres to LSP by not forcing the `Ostrich` class to implement behavior (flying) it cannot fulfill.

- This approach makes our class hierarchy more flexible and accurate, allowing birds to extend or implement behavior that makes sense for them, ensuring substitutability without altering the correctness of the program.

### Benefits of Applying LSP

- **Enhanced Model Accuracy**: Better represents real-world scenarios.
- **Increased Robustness**: System is less prone to errors as objects are used more predictably.
- **Improved Code Reusability**: Clearer contracts lead to components that are easier to reuse.
