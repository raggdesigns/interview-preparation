# OOP questions

- OOP main definitions
- Polymorphism vs inheritance
- [Design patterns - main types](./design_patterns/list_of_design_patterns.md#differences-between-design-patterns-types)
- [List of design patterns](./design_patterns/list_of_design_patterns.md)
- Design patterns used in popular php frameworks
- Example of pattern usage in your personal projects
- [Positive examples of Singleton pattern usage](positive_examples_of_singleton_pattern_usage.md)
- Describe patterns
    - Singleton
    - [Factory](design_patterns/factory.md)
    - [Adapter](design_patterns/adapter.md)
    - [Decorator](design_patterns/decorator.md)
    - [Proxy](design_patterns/proxy.md)
    - [Observer](design_patterns/observer.md)
    - [Data Mapper](design_patterns/data_mapper.md)
    - [Command Bus](design_patterns/command_bus.md)
- [SOLID principles. Usage examples](solid_usage_examples.md)
- Active Record pattern
- Active Record VS Data Mapper
- Composition VS Aggregation
- IoC (DiC)
- Composition vs Inheritance
- Invariance vs Covariance vs Contravariance
- [Why getters and setters are bad](why_getter_and_setters_are_bad.md)
- What is an object's behavior
- Service Locator VS Inversion of Control (Dependency Injection) Container
- Registry pattern VS Service Locator
- Dependency Injection VS Composition VS Inversion of Control

## Software design

- [DDD](../ddd/questions.md)
- Entity VS Data Transfer Object vs Value Object
- [CQRS](sqrs.md)
- Event Sourcing
- [GRASP patterns. Low coupling vs high cohesion](grasp.md)
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