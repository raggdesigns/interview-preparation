# Polymorphism vs Inheritance

These terms are related, but they are not the same thing.
In interviews, a good answer is: inheritance is one way to model relationships between classes, while polymorphism is a way to use different implementations through one common type.

## Prerequisites

- You know class inheritance basics (`extends`)
- You know interfaces in PHP
- You understand method overriding

## Inheritance

Inheritance creates an “is-a” relationship.

```php
<?php

class Animal
{
    public function makeSound(): string
    {
        return 'Some generic sound';
    }
}

class Dog extends Animal
{
    public function makeSound(): string
    {
        return 'Bark';
    }
}
```

`Dog` inherits behavior from `Animal` and can override parts of it.

## Polymorphism

Polymorphism means client code works with a common type and each implementation behaves differently.
This common type can be a parent class or an interface.

```php
<?php

interface Notifier
{
    public function send(string $message): void;
}

class EmailNotifier implements Notifier
{
    public function send(string $message): void
    {
        echo 'Email: ' . $message . PHP_EOL;
    }
}

class SmsNotifier implements Notifier
{
    public function send(string $message): void
    {
        echo 'SMS: ' . $message . PHP_EOL;
    }
}

function notifyAll(array $notifiers, string $message): void
{
    foreach ($notifiers as $notifier) {
        $notifier->send($message);
    }
}
```

`notifyAll` is polymorphic: same call, different runtime behavior.

## Key Difference

- Inheritance: how classes are related.
- Polymorphism: how client code uses related or unrelated implementations through one type.

You can have polymorphism without inheritance by using interfaces.

## Practical Rule of Thumb

- Use inheritance for clear “is-a” hierarchies and shared behavior.
- Use polymorphism (often via interfaces) to keep high-level code flexible and easy to extend.

## Common Interview Follow-up

Why do teams often prefer composition + interface polymorphism over deep inheritance trees?

Short answer: it reduces tight coupling and makes changes safer.

## Conclusion

Inheritance is a design mechanism; polymorphism is a usage mechanism.
They often work together, but polymorphism is usually the bigger goal for extensible code.
