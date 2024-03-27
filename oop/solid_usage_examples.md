The SOLID principles are a set of five design principles aimed at making software designs more understandable, flexible, and maintainable. Below, we explore each principle with common usage examples in PHP to illustrate their application.

### Single Responsibility Principle (SRP)

A class should have one, and only one, reason to change. This principle emphasizes that a class should have only one job or responsibility.

**Before SRP**:
A class that handles both user management and email notifications violates SRP.

```php
class UserManager {
    public function createUser($userData) {
        // Create user
    }

    public function sendEmail($userEmail, $message) {
        // Send an email
    }
}
```

**After Applying SRP**:
Splitting responsibilities into separate classes.

```php
class UserManager {
    public function createUser($userData) {
        // Create user
    }
}

class EmailService {
    public function sendEmail($userEmail, $message) {
        // Send an email
    }
}
```

### Open/Closed Principle (OCP)

Software entities should be open for extension, but closed for modification. This means that the behavior of a module can be extended without modifying its source code.

**Before OCP**:
Adding a new filter type requires modifying the existing `ProductFilter` class.

```php
class ProductFilter {
    public function filterByColor($products, $color) {
        // Returns filtered products by color
    }
}
```

**After Applying OCP**:
Using interfaces to allow for extensions without modifying the existing code.

```php
interface ProductFilterCriteria {
    public function isSatisfied($product);
}

class ColorFilter implements ProductFilterCriteria {
    private $color;

    public function __construct($color) {
        $this->color = $color;
    }

    public function isSatisfied($product) {
        return $product->color == $this->color;
    }
}
```

### Liskov Substitution Principle (LSP)

Objects of a superclass shall be replaceable with objects of a subclass without affecting the correctness of the program.

**Before LSP**:
Subclass `Square` cannot be used as a substitute for its superclass `Rectangle` without altering the program’s behavior.

```php
class Rectangle {
    protected $width;
    protected $height;

    // Setters and getters for width and height
}

class Square extends Rectangle {
    public function setWidth($width) {
        $this->width = $this->height = $width;
    }

    public function setHeight($height) {
        $this->width = $this->height = $height;
    }
}
```

**After Applying LSP**:
Refactoring to ensure substitutability.

```php
// Use separate classes without inheritance
class Rectangle { /* As before, without inheritance from Square */ }
class Square { /* Implementations specific to square */ }
```

### Interface Segregation Principle (ISP)

Clients should not be forced to depend upon interfaces they do not use.

**Before ISP**:
A monolithic interface requires the implementation of methods that the client doesn’t use.

```php
interface Worker {
    public function work();
    public function eat();
}
```

**After Applying ISP**:
Splitting the interface into smaller, more specific ones.

```php
interface Workable {
    public function work();
}

interface Eatable {
    public function eat();
}
```

### Dependency Inversion Principle (DIP)

High-level modules should not depend on low-level modules. Both should depend upon abstractions. Abstractions should not depend upon details. Details should depend upon abstractions.

**Before DIP**:
High-level module directly depends on a low-level module.

```php
class LightSwitch {
    private $lightBulb = new LightBulb();

    public function operate() {
        // Use light bulb
    }
}
```

**After Applying DIP**:
Both high-level and low-level modules depend on abstractions.

```php
interface LightBulbInterface {
    public function operate();
}

class LightBulb implements LightBulbInterface { /* Implementation */ }

class LightSwitch {
    private $lightBulb;

    public function __construct(LightBulbInterface $lightBulb) {
        $this->lightBulb = $lightBulb;
    }
}
```

Applying the SOLID principles helps create software that is easier to maintain, understand, and extend. Each principle plays a crucial role in achieving clean, scalable, and robust object-oriented design.
