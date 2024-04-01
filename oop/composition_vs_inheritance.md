Composition and inheritance are both fundamental object-oriented design techniques used to establish a relationship
between classes, but they serve different purposes and have different implications for the flexibility and
maintainability of code.

### Inheritance

Inheritance is a mechanism for defining a new class based on an existing class, inheriting its properties and behaviors
while allowing for overrides and extensions. It establishes a "is-a" relationship between the base (parent) class and
the derived (child) class.

**Pros**:

- **Code Reuse**: Allows for the reuse of code of the base class, reducing redundancy.
- **Simplicity**: Easy to implement, as languages support inheritance natively.

**Cons**:

- **Tight Coupling**: The child class is tightly coupled to the parent class, making changes to the parent class
  potentially hazardous.
- **Inflexibility**: Overuse of inheritance can lead to a rigid hierarchy that is difficult to change.
- **Opacity**: The behavior of the derived class can be obscured by the inherited behavior.

### Composition

Composition involves building complex objects from simpler ones, establishing a "has-a" relationship between the
composite class and its components.

**Pros**:

- **Flexibility**: More flexible than inheritance, allowing for dynamic changes to the system at runtime.
- **Loose Coupling**: Components can be easily replaced with other compatible objects, reducing dependencies.
- **Clarity**: The system is often easier to understand since behavior is explicitly delegated to components.

**Cons**:

- **More Boilerplate**: Might require more code to delegate tasks to components.
- **Complexity in Design**: Might require more thoughtful design to identify components and their interactions.

### Example in PHP

Consider a system with `Bird` classes where not all birds can fly.

**Inheritance Example**:
Using inheritance, a `FlyingBird` class might extend a `Bird` class to add flying behavior. However, this becomes
problematic if you need a `Penguin` class, as penguins are birds that cannot fly.

```php
class Bird {
    public function eat() {
        // Implementation
    }
}

class FlyingBird extends Bird {
    public function fly() {
        // Implementation
    }
}

class Penguin extends Bird {
    // Penguins can't fly, but this class inherits from Bird
}
```

**Composition Example**:
Using composition, flying behavior can be encapsulated in a separate class and included in birds that can fly.

```php
class Bird {
    public function eat() {
        // Implementation
    }
}

class FlyBehavior {
    public function fly() {
        // Implementation
    }
}

class FlyingBird {
    private $flyBehavior;
    
    public function __construct() {
        $this->flyBehavior = new FlyBehavior();
    }
    
    public function fly() {
        $this->flyBehavior->fly();
    }
}

class Penguin {
    // No need to include FlyBehavior
}
```

In this example, composition allows for more precise control over which birds can fly without inheriting unnecessary or
incorrect behavior.

### Conclusion

While inheritance can be useful for establishing a clear hierarchy and promoting code reuse, it can also lead to
inflexible and tightly coupled designs. Composition, by contrast, offers greater flexibility and maintainability by
favoring loosely coupled, clearly defined relationships between objects.
