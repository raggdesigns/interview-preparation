# OOP pitanja

- [OOP osnovne definicije](oop_main_definitions.sr.md)
- [Polimorfizam vs nasleđivanje](polymorphism_vs_inheritance.sr.md)
- [Apstraktne klase vs interfejsi](abstract_classes_vs_interfaces.sr.md)
- [MVC obrazac](mvc_pattern.sr.md)
- [Projektni obrasci - glavni tipovi](./design_patterns/list_of_design_patterns.sr.md#differences-between-design-patterns-types)
- [Lista projektnih obrazaca](./design_patterns/list_of_design_patterns.sr.md)
- [Projektni obrasci u popularnim PHP frejmvorcima](design_patterns_in_php_frameworks.sr.md)
- Primer korišćenja obrazaca u ličnim projektima
- [Pozitivni primeri korišćenja Singleton obrasca](positive_examples_of_singleton_pattern_usage.sr.md)
- Opišite obrasce
  - [Singleton](design_patterns/singleton.sr.md)
  - [Factory](design_patterns/factory.sr.md)
  - [Adapter](design_patterns/adapter.sr.md)
  - [Decorator](design_patterns/decorator.sr.md)
  - [Strategy](design_patterns/strategy.sr.md)
  - [Proxy](design_patterns/proxy.sr.md)
  - [Observer](design_patterns/observer.sr.md)
  - [Data Mapper](design_patterns/data_mapper.sr.md)
  - [Command Bus](design_patterns/command_bus.sr.md)
- [SOLID principi](../solid/questions.sr.md)
- [Active Record VS Data Mapper](active_record_vs_data_mapper.sr.md)
- [Kompozicija vs nasleđivanje](composition_vs_inheritance.sr.md)
- [Zašto su getteri i setteri loši](why_getter_and_setters_are_bad.sr.md)
- [Kompozicija VS Agregacija](composition_vs_aggregation.sr.md)
- [Dependency Injection VS Kompozicija VS Inversion of Control (IoC/DiC)](di_vs_composition_vs_ioc.sr.md)
- [Invarijansa vs Kovarijansa vs Kontravarijansa](invariance_vs_covariance_vs_contravariance.sr.md)
- [Šta je ponašanje objekta](what_is_an_objects_behavior.sr.md)
- [Service Locator VS Inversion of Control (Dependency Injection) Container](service_locator_vs_di_container.sr.md)
- [Registry obrazac VS Service Locator](registry_pattern_vs_service_locator.sr.md)

## Dizajn softvera

- [DDD](../ddd/questions.sr.md)
- [Entity VS Data Transfer Object vs Value Object](entity_vs_data_transfer_object_vs_value_object.sr.md)
- [CQRS](../architecture/cqrs.sr.md)
- [Event Sourcing](../architecture/event_sourcing.sr.md)
- [GRASP obrasci. Niska sprežnost vs visoka kohezija](grasp.sr.md)
- [Demetrin zakon](lod.sr.md)
- [Anemični model](anemic_model.sr.md)
- [Onion arhitektura](../architecture/onion_architecture.sr.md)
- [Hexagonalna arhitektura](../architecture/hexagonal_architecture.sr.md)
- [Nepromenljivi objekti](immutable_objects.sr.md)
- [Zašto servisne klase treba da budu bez stanja](stateless_service.sr.md)
- [KISS, DRY, YAGNI - objasnite skraćenice](kiss_dry_yagni.sr.md)
- [Refaktorisanje legacy koda: tehnike, obrasci, pristup](refactoring_legacy_code.sr.md)
- [DTO vs Command](dto_vs_command.sr.md) (napomena: dto se obično serijalizuje, ali command objekat ne)
- [Separation of Concerns](soc.sr.md)
- [Reactor obrazac](../architecture/reactor_pattern.sr.md)

## Teška pitanja

- Da li dodavanje javnog polja u proširenu klasu krši Liskov Substitution princip? NE
- Da li bacanje izuzetka unutar metode proširene klase krši Liskov Substitution princip? NE, ako dokumentacija metode superklase specificira da može bacati izuzetke određenog tipa pod određenim uslovima
- Kako garantovati kreiranje validnog objekta? (ukratko: kreirati ga kroz konstruktor)
