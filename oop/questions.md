# OOP questions

- [OOP main definitions](oop_main_definitions.md)
- [Polymorphism vs inheritance](polymorphism_vs_inheritance.md)
- [Abstract classes vs interfaces](abstract_classes_vs_interfaces.md)
- [MVC pattern](mvc_pattern.md)
- [Design patterns - main types](./design_patterns/list_of_design_patterns.md#differences-between-design-patterns-types)
- [List of design patterns](./design_patterns/list_of_design_patterns.md)
- [Design patterns used in popular php frameworks](design_patterns_in_php_frameworks.md)
- Example of pattern usage in your personal projects
- [Positive examples of Singleton pattern usage](positive_examples_of_singleton_pattern_usage.md)
- Describe patterns
    - [Singleton](design_patterns/singleton.md)
    - [Factory](design_patterns/factory.md)
    - [Adapter](design_patterns/adapter.md)
    - [Decorator](design_patterns/decorator.md)
    - [Strategy](design_patterns/strategy.md)
    - [Proxy](design_patterns/proxy.md)
    - [Observer](design_patterns/observer.md)
    - [Data Mapper](design_patterns/data_mapper.md)
    - [Command Bus](design_patterns/command_bus.md)
- [SOLID principles](../solid/questions.md)
- [Active Record VS Data Mapper](active_record_vs_data_mapper.md)
- [Composition vs Inheritance](composition_vs_inheritance.md)
- [Why getters and setters are bad](why_getter_and_setters_are_bad.md)
- [Composition VS Aggregation](composition_vs_aggregation.md)
- [Dependency Injection VS Composition VS Inversion of Control (IoC/DiC)](di_vs_composition_vs_ioc.md)
- [Invariance vs Covariance vs Contravariance](invariance_vs_covariance_vs_contravariance.md)
- [What is an object's behavior](what_is_an_objects_behavior.md)
- [Service Locator VS Inversion of Control (Dependency Injection) Container](service_locator_vs_di_container.md)
- [Registry pattern VS Service Locator](registry_pattern_vs_service_locator.md)

## Software design

- [DDD](../ddd/questions.md)
- [Entity VS Data Transfer Object vs Value Object](entity_vs_data_transfer_object_vs_value_object.md)
- [CQRS](../architecture/cqrs.md)
- [Event Sourcing](../architecture/event_sourcing.md)
- [GRASP patterns. Low coupling vs high cohesion](grasp.md)
- [Demetra's law](lod.md)
- [Anemic model](anemic_model.md)
- [Onion architecture](../architecture/onion_architecture.md)
- [Hexagonal architecture](../architecture/hexagonal_architecture.md)
- [Immutable objects](immutable_objects.md)
- [Why service classes should be stateless](stateless_service.md)
- [KISS, DRY, YAGNI - explain abbreviations](kiss_dry_yagni.md)
- [DTO vs Command](dto_vs_command.md) (ps. dto is usually serialized, but command object is not)
- [Separation of Concerns](soc.md)
- [The Reactor pattern](../architecture/reactor_pattern.md)

## Tricky questions

- Does adding a public field in an extended class violate Liskov Substitution principle? NO
- Does throwing and exception inside method of an extended class violate Liskov Substitution principle? NO if
  superclass's method documentation specifies that it can throw exceptions of a certain type under specific conditions
- How to guarantee creating valid object? (shortly: create it via constructor)