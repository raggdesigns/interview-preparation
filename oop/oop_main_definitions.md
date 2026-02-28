# OOP Main Definitions

Object-Oriented Programming (OOP) is a way to model code around domain concepts (objects) instead of only around functions.
In interviews, this topic is often used to check whether you can design maintainable code, not just write syntax.
The four core ideas are encapsulation, abstraction, inheritance, and polymorphism.

## Prerequisites

- Basic PHP class syntax (`class`, `public`, `private`)
- Difference between object state (properties) and behavior (methods)
- Basic understanding of interfaces or parent classes

## Encapsulation

Encapsulation means the object controls how its internal state is read and changed.
You expose safe operations and hide direct state changes.

```php
<?php

class BankAccount
{
    private int $balance = 0;

    public function deposit(int $amount): void
    {
        if ($amount <= 0) {
            throw new InvalidArgumentException('Amount must be positive');
        }

        $this->balance += $amount;
    }

    public function withdraw(int $amount): void
    {
        if ($amount <= 0 || $amount > $this->balance) {
            throw new InvalidArgumentException('Invalid withdrawal amount');
        }

        $this->balance -= $amount;
    }

    public function balance(): int
    {
        return $this->balance;
    }
}
```

Why this matters: code outside the class cannot put the object into an invalid state.

## Abstraction

Abstraction means exposing what the object does, while hiding how it does it.
Consumers use a small, clear API and do not depend on internal steps.

In the `BankAccount` example above, callers do not need to know how validation or state updates are implemented; they only use `deposit`, `withdraw`, and `balance`.

## Inheritance

Inheritance allows a child class to reuse behavior from a parent class and extend it.
Use it only when there is a true “is-a” relationship.

```php
<?php

abstract class Animal
{
    public function __construct(protected string $name)
    {
    }

    abstract public function sound(): string;

    public function describe(): string
    {
        return $this->name . ' says ' . $this->sound();
    }
}

class Dog extends Animal
{
    public function sound(): string
    {
        return 'woof';
    }
}

class Cat extends Animal
{
    public function sound(): string
    {
        return 'meow';
    }
}
```

## Polymorphism

Polymorphism means code can work with a parent type and still run child-specific behavior.

```php
<?php

function printAnimalSounds(array $animals): void
{
    foreach ($animals as $animal) {
        echo $animal->describe() . PHP_EOL;
    }
}

printAnimalSounds([
    new Dog('Rex'),
    new Cat('Milo'),
]);
```

`printAnimalSounds` treats all objects as `Animal`, but each child returns its own sound.

## Common Interview Angles

- When does inheritance become a problem?
- How do encapsulation and validation reduce bugs?
- Why is polymorphism useful for extensibility?
- When should composition be preferred over inheritance?

## Conclusion

Encapsulation protects state, abstraction reduces cognitive load, inheritance enables reuse, and polymorphism enables extension.
Together they help you build code that is easier to change and safer to evolve.
