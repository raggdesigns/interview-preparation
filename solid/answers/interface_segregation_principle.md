# Interface Segregation Principle (ISP)

The Interface Segregation Principle (ISP) states that no client should be forced to depend on methods it does not use. It encourages the segregation of large interfaces into smaller and more specific ones so that clients will only have to know about the methods that are of interest to them.

### Violating ISP

A violation of ISP occurs when a class is forced to implement an interface with methods that it does not use.

```php
interface WorkerInterface {
    public function work();
    public function eat();
}

class HumanWorker implements WorkerInterface {
    public function work() {
        echo "Working";
    }
    
    public function eat() {
        echo "Eating lunch";
    }
}

class RobotWorker implements WorkerInterface {
    public function work() {
        echo "Working more efficiently";
    }
    
    public function eat() {
        // Not applicable for robots
    }
}
```

In this example, `RobotWorker` is forced to implement the `eat` method, which it does not use, thus violating ISP.

### Refactored Code Applying ISP

To adhere to ISP, we should define multiple, more specific interfaces.

```php
interface WorkableInterface {
    public function work();
}

interface EatableInterface {
    public function eat();
}

class HumanWorker implements WorkableInterface, EatableInterface {
    public function work() {
        echo "Working";
    }
    
    public function eat() {
        echo "Eating lunch";
    }
}

class RobotWorker implements WorkableInterface {
    public function work() {
        echo "Working more efficiently";
    }
}
```

### Explanation

- By segregating the `WorkerInterface` into `WorkableInterface` and `EatableInterface`, we ensure that `HumanWorker` and `RobotWorker` only implement the methods that are relevant to them. This adheres to ISP by eliminating the need for a class to depend upon interfaces it does not use.

- This approach increases the cohesion within the system by making clear separations between different functionalities, leading to more maintainable and flexible code.

### Benefits of Applying ISP

- **Reduced Side-Effects**: Changes in unrelated interfaces do not affect clients.
- **Increased System Flexibility**: Makes it easier to refactor, change, and redeploy the system.
- **Easier to Understand**: Clients are not forced to implement interfaces they don't use, making the codebase cleaner and easier to understand.
