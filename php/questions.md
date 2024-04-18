# PHP questions

## Language features
- [Data types in PHP. Describe Resource and Callable types](data_types_in_php.md)
- [this VS self, self VS static, parent VS self](this_vs_self_vs_parent.md)
- [Magic constants list. Does magic constant's value depend on the place where it is called?](magic_constants.md)
- [Generators usage examples. What makes a function become a generator?](generators.md)
- [yield from syntax](yield_from_syntax.md)
- [Cases of passing variable by reference by default](cases_of_passing_variable_by_reference_by_default.md)
- [Multiple inheritance in PHP](multiple_inheritance_in_php.md)
- [What is OPCache](what_is_opcache.md)
- [Closure vs anonymous function](closure_vs_anonymous_function.md)
- [What is an "autoload" in php and Composer?](what_is_autoload_in_php_and_composer.md)
- [How sessions work](how_sessions_work.md)
- [How to call object destructor](how_to_call_object_destructor.md)
- [Calling object destructor VS garbage collector](calling_object_destructor_vs_garbage_collector.md)
- [Interfaces. Inheritance of interfaces](interfaces.md)
- [Magic methods](magic_methods.md)
- [__invoke method useful examples](invoke_method_useful_examples.md)
- [Late static bindings](late_static_bindings.md)
- Persistent Database Connections
- Reflection practical usage examples
- Purpose of immutable objects existence (e.g. DateTimeImmutable)
- Popular SPL functions
- [What are the main risks of using PHP as a daemon](main_risks_of_using_php_as_daemon_and_how_to_manage_them.md) (Swoole, ReactPHP, Roadrunner etc.) and how to manage them

## Traits
- Traits - how add them. Inheriting and Instantiating traits
- How traits are included on low level
- Can you add constant to a trait? How can you use that constant?
- Can you use private or protected methods in a trait?

## PHP versions
- New features in PHP7 (main differences from PHP5)
- New features in PHP7.4
- [New features in PHP 8.0](answers/php_features/new_features_in_php80.md)
- [New features in PHP 8.1](answers/php_features/new_features_in_php81.md)
- [New features in PHP 8.2](answers/php_features/new_features_in_php82.md)
- [New features in PHP 8.3](answers/php_features/new_features_in_php83.md)

## Tools
- Composer - purpose and possibilities
- composer install vs composer update
- Main steps of 'composer install' command

------

## Tricky questions
1. Here is an array with keys 0, 1, 2, 3 and "Hello". What will be the key for the next value?
2. There are classes A, B, C with some restrictions:
    - A with a public constructor
    - B with a private constructor
    - C extends B

   Which constructor will be inherited in class C?

3. How can you call a method with the same name from parent class inside child class?
4. How to find second-largest number in an unsorted list? You can use only one iteration to find it.
5. What's the difference between empty() and is_null()?