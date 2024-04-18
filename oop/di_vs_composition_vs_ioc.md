Dependency Injection, Composition, and Inversion of Control are fundamental concepts in software design, each serving to reduce coupling and increase the modularity of code. While they are related and often used together, they address different aspects of software construction.

### Dependency Injection (DI)

Dependency Injection is a design pattern in which an object receives other objects it depends on, known as its dependencies, from an external source rather than creating them itself. DI is a form of Inversion of Control (IoC) focused on dependency management.

**Benefits**:
- **Loose Coupling**: Dependencies are provided externally, making classes less dependent on specific implementations.
- **Enhanced Testability**: Dependencies can be easily mocked or stubbed out in tests.

**Example in PHP**:

+++php
class UserRepository {
    // Dependency injection via constructor
    public function __construct(DatabaseConnection $dbConnection) {
        $this->dbConnection = $dbConnection;
    }
}
+++

### Composition

Composition is a design principle where objects are composed of other objects to achieve more complex functionality. It is based on the "has-a" relationship, meaning an object has one or more objects as part of its state.

**Benefits**:
- **Flexibility**: New behavior can be added by composing objects in new ways.
- **Avoids Inheritance Hierarchies**: Reduces the need for deep inheritance hierarchies, simplifying code relationships.

**Example in PHP**:

+++php
class Engine { }
class Car {
    private $engine;
    // Composition: Car "has-a" Engine
    public function __construct(Engine $engine) {
        $this->engine = $engine;
    }
}
+++

### Inversion of Control (IoC)

IoC is a broad principle where the control flow of a program is inverted compared to traditional procedural programming. Rather than the application code controlling the flow and decision-making, the framework or runtime environment takes on those responsibilities. DI is a form of IoC focused on dependency management.

**Benefits**:
- **Decoupling**: IoC containers manage the instantiation and lifecycle of objects, reducing coupling between components.
- **Centralized Configuration**: Dependencies and their configurations can be managed from a central location.

**Example in PHP**:

// Demonstrated in the DI example, where an IoC container would manage the instantiation of `UserRepository` and its `DatabaseConnection` dependency.

### Comparison

- **Scope**: DI is a technique under the IoC umbrella focused on how objects get their dependencies. Composition is about structuring objects and their relationships. IoC is a broader principle that can be applied in various ways, including DI, to achieve loose coupling.
- **Usage**: DI is typically implemented using frameworks or containers that manage dependencies. Composition is a design choice made when structuring classes and their relationships. IoC is a design goal that influences architecture and framework choices.

### Conclusion

Understanding the distinctions and relationships between Dependency Injection, Composition, and Inversion of Control is crucial for designing flexible, loosely coupled software. While DI and IoC focus on managing dependencies to achieve decoupling, Composition addresses how objects are structured and interact, offering an alternative to inheritance for building complex functionalities.
