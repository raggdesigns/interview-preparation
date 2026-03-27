# PHP pitanja

## Karakteristike jezika
- [Tipovi podataka u PHP-u. Opišite Resource i Callable tipove](data_types_in_php.sr.md)
- [this VS self, self VS static, parent VS self](this_vs_self_vs_parent.sr.md)
- [Lista magičnih konstanti. Da li vrednost magične konstante zavisi od mesta gde se poziva?](magic_constants.sr.md)
- [Primeri korišćenja generatora. Šta čini funkciju generatorom?](generators.sr.md)
- [yield from sintaksa](yield_from_syntax.sr.md)
- [Slučajevi prosleđivanja promenljive po referenci podrazumevano](cases_of_passing_variable_by_reference_by_default.sr.md)
- [Višestruko nasleđivanje u PHP-u](multiple_inheritance_in_php.sr.md)
- [Šta je OPCache](what_is_opcache.sr.md)
- [Closure vs anonimna funkcija](closure_vs_anonymous_function.sr.md)
- [Šta je "autoload" u PHP-u i Composer-u?](what_is_autoload_in_php_and_composer.sr.md)
- [Kako rade sesije](how_sessions_work.sr.md)
- [Pozivanje destruktora objekta VS garbage collector](calling_object_destructor_vs_garbage_collector.sr.md)
- [Interfejsi. Nasleđivanje interfejsa](interfaces.sr.md)
- [Magične metode](magic_methods.sr.md)
- [Korisni primeri __invoke metode](invoke_method_useful_examples.sr.md)
- [Late static bindings](late_static_bindings.sr.md)
- [Trajne veze sa bazom podataka](persistent_database_connections.sr.md)
- [Praktični primeri korišćenja Reflection-a](reflection_practical_usage_examples.sr.md)
- [Svrha postojanja nepromenljivih objekata (npr. DateTimeImmutable)](immutable_objects_in_php.sr.md)
- [Popularne SPL funkcije](popular_spl_functions.sr.md)
- [Interna struktura PHP nizova (implementacija heš tabele)](php_arrays_internals.sr.md)
- [Koji su glavni rizici korišćenja PHP-a kao demona](main_risks_of_using_php_as_daemon_and_how_to_manage_them.sr.md) (Swoole, ReactPHP, Roadrunner itd.) i kako njima upravljati

## Traits
- [Traits - kako ih dodati. Nasleđivanje i instanciranje traits-a](traits.sr.md)
- [Kako su traits uključeni na niskom nivou](traits.sr.md)
- [Da li možete dodati konstantu u trait? Kako možete koristiti tu konstantu?](traits.sr.md)
- [Da li možete koristiti privatne ili zaštićene metode u trait-u?](traits.sr.md)

## PHP verzije
- [Nove funkcionalnosti u PHP7 (glavne razlike od PHP5)](new_features_in_php7.sr.md)
- [Nove funkcionalnosti u PHP7.4](new_features_in_php74.sr.md)
- [Nove funkcionalnosti u PHP 8.0](new_features_in_php80.sr.md)
- [Nove funkcionalnosti u PHP 8.1](new_features_in_php81.sr.md)
- [Nove funkcionalnosti u PHP 8.2](new_features_in_php82.sr.md)
- [Nove funkcionalnosti u PHP 8.3](new_features_in_php83.sr.md)
- [Nove funkcionalnosti u PHP 8.4](new_features_in_php84.sr.md)
- [Nove funkcionalnosti u PHP 8.5](new_features_in_php85.sr.md)

## Alati
- [Composer - svrha i mogućnosti](composer.sr.md)
- [composer install vs composer update](composer.sr.md)
- [Glavni koraci komande 'composer install'](composer.sr.md)

------

## [Teška pitanja](tricky_questions.sr.md)
1. [Postoji niz sa ključevima 0, 1, 2, 3 i "Hello". Koji će biti ključ za sledeću vrednost?](tricky_questions.sr.md)
2. [Postoje klase A, B, C sa određenim ograničenjima: A sa javnim konstruktorom, B sa privatnim konstruktorom, C proširuje B — koji konstruktor će biti nasleđen u klasi C?](tricky_questions.sr.md)
3. [Kako možete pozvati metodu sa istim imenom iz roditeljske klase unutar podklase?](tricky_questions.sr.md)
4. [Kako pronaći drugi najveći broj u nesortiranoj listi? Možete koristiti samo jednu iteraciju da ga pronađete.](tricky_questions.sr.md)
5. [Koja je razlika između empty() i is_null()?](tricky_questions.sr.md)
