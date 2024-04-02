Polymorphism and Inheritance are two fundamental concepts in object-oriented programming (OOP) that work together to
allow programmers to create flexible and reusable code. Understanding the distinction between these concepts is crucial
for effective OOP design.

### Inheritance

Inheritance allows a class to inherit properties and methods from another class, known as the parent class. This
mechanism provides a way to create a new class based on an existing class, extending or modifying its behavior.

**Example in PHP**:

```php
class Animal {
    public function makeSound() {
        echo "Some generic sound\\n";
    }
}

class Dog extends Animal {
    public function makeSound() {
        echo "Bark\\n";
    }
}

class Cat extends Animal {
    public function makeSound() {
        echo "Meow\\n";
    }
}
```

In this example, `Dog` and `Cat` inherit from `Animal`. Each subclass overrides the `makeSound` method to produce a
specific sound, demonstrating how inheritance is used to extend the functionality of the base class.

### Polymorphism

Polymorphism allows objects of different classes to be treated as objects of a common superclass. It is the ability of
different objects to respond, each in their own way, to the same message (or method call).

**Example in PHP** (Continuing from the Inheritance example):

```php
function letAnimalMakeSound(Animal $animal) {
    $animal->makeSound();
}

$dog = new Dog();
$cat = new Cat();

letAnimalMakeSound($dog); // Outputs: Bark
letAnimalMakeSound($cat); // Outputs: Meow
```

Despite `letAnimalMakeSound` expecting an `Animal` type, it can accept any subclass of `Animal` due to polymorphism.
Each class responds to `makeSound` in its own way, fulfilling the polymorphic behavior.

### Polymorphism vs Inheritance

- **Inheritance** is about creating a "is-a" relationship between a base class and derived classes, enabling code reuse
  and extension of base class functionality.
- **Polymorphism** allows objects of different classes to be treated interchangeably, with each object responding to the
  same method call in a class-specific way.

While inheritance establishes a relationship between classes for code reuse, polymorphism leverages this relationship to
enable different behaviors to be executed through a common interface, enhancing the flexibility of the code.

### Conclusion

Both inheritance and polymorphism are pillars of OOP that enable developers to write more modular, maintainable, and
reusable code. Inheritance provides a mechanism for class extension and reuse, while polymorphism offers a way to
interact with different objects through a uniform interface, promoting flexibility and reducing complexity in code
structure.
