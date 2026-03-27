Late static bindings is a feature in PHP that solves a specific problem related to static method calls in the context of inheritance. Before its introduction in PHP 5.3, when a static method was called in a subclass, any reference to `self` within that method would point to the original class where the method was defined, not the subclass. This behavior limited the usefulness of static methods in inheritance hierarchies. Late static bindings provide a way to reference the called class in a static context.

### The Problem

Let's consider an example to illustrate the problem:

```php
class ParentClass {
    public static function who() {
        echo __CLASS__;
    }

    public static function test() {
        self::who();
    }
}

class ChildClass extends ParentClass {
    public static function who() {
        echo __CLASS__;
    }
}

ChildClass::test(); // Outputs: "ParentClass"
```

In this example, even though `test()` is called on `ChildClass`, the output is "ParentClass" because `self::who()` refers to `ParentClass` due to `self`'s static binding.

### Solution with Late Static Bindings

To address this limitation, PHP introduced the `static` keyword for use in place of `self` to refer to the called class rather than the class where the method is defined.

**Refactored Example**:

```php
class ParentClass {
    public static function who() {
        echo __CLASS__;
    }

    public static function test() {
        static::who(); // Use 'static' instead of 'self'
    }
}

class ChildClass extends ParentClass {
    public static function who() {
        echo __CLASS__;
    }
}

ChildClass::test(); // Outputs: "ChildClass"
```

Now, `static::who()` correctly identifies that `ChildClass` was the called class, thanks to late static bindings.

### Key Points

- **`static::` Keyword**: Used to access static methods or properties in the context of the calling class.
- **Flexibility in Inheritance**: Allows for more flexible method overriding in class hierarchies.
- **Use Cases**: Particularly useful for factory patterns, singleton patterns in subclassing, and any situation where child classes might override static methods.
- **Performance Consideration**: Be mindful that using late static bindings can incur a slight performance cost due to the dynamic nature of determining the calling class.

### Conclusion

Late static bindings enhance the object-oriented features of PHP by allowing static method calls to be more intuitive and useful in inheritance. By using the `static::` keyword, developers can ensure that static method calls behave as expected when classes are extended, making code more reusable and maintainable.
