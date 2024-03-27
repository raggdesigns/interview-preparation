# OOP questions

- OOP main definitions
- Polymorphism vs inheritance
- [Design patterns - main types](./answers/list_of_design_patterns.md#differences-between-design-patterns-types)
- [List of design patterns](./answers/list_of_design_patterns.md)
- Design patterns used in popular php frameworks
- Example of pattern usage in your personal projects
- Positive examples of Singleton pattern usage
- Describe patterns
    - Singleton
    - Factory
    - Adapter
    - Decorator
    - Proxy
    - Observer
    - Data Mapper
    - Command Bus
- SOLID principles. Usage examples
- Active Record pattern
- Active Record VS Data Mapper
- Composition VS Aggregation
- IoC (DiC)
- Composition vs Inheritance
- Invariance vs Covariance vs Contrvariance
- Why getters and setters are bad
- What is an object's behavior
- Service Locator VS Inversion of Control (Dependency Injection) Container
- Registry pattern VS Service Locator
- Dependency Injection VS Composition VS Inversion of Control

## Software design

- [DDD](../ddd/questions.md)
- Entity VS Data Transfer Object vs Value Object
- [CQRS](sqrs.md)
- Event Sourcing
- GRASP patterns. Low coupling vs high cohesion
- Demetra's law
- Anemic model
- Onion architecture
- Hexagonal architecture
- Immutable objects
- [Why service classes should be stateless](./stateless_service.md)
- KISS, DRY, YAGNI - explain abbreviations
- [DTO vs Command](./dto_vs_command.md) (ps. dto is usually serialized, but command object is not)
- [Separation of Concerns](./soc.md)
- TDD
- BDD

## Tricky questions

- Does adding a public field in an extended class violate Liskov Substitution principle? NO
- Does throwing and exception inside method of an extended class violate Liskov Substitution principle? NO if
  superclass's method documentation specifies that it can throw exceptions of a certain type under specific conditions
- How to guarantee creating valid object? (shortly: create it via constructor)