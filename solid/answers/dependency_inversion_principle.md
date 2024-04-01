# Dependency Inversion Principle (DIP)

The Dependency Inversion Principle (DIP) advocates for modules to be independent of the concrete implementations of
their dependencies. Instead, both high-level modules and low-level modules should depend on abstractions (e.g.,
interfaces). This principle consists of two key parts:

1. High-level modules should not depend on low-level modules. Both should depend on abstractions.
2. Abstractions should not depend on details. Details should depend on abstractions.

When subclass changes the parent class will not need to change. Its inverse of control.The high level class takes
control of dependency by using
defined injection with interface.

## Workflow Mindset

- Classes should depend on interfaces instead of concrete classes.
- Those interfaces should be design by the class that uses them not by the classes that will implement them.

### Violating DIP

A common violation of DIP occurs when a high-level module directly depends on a low-level module.

```php
class LightBulb {
    public function turnOn() {
        echo "LightBulb: turned on\\n";
    }
    
    public function turnOff() {
        echo "LightBulb: turned off\\n";
    }
}

class ElectricPowerSwitch {
    public $lightBulb;
    public $on;
    
    public function __construct(LightBulb $lightBulb) {
        $this->lightBulb = $lightBulb;
        $this->on = false;
    }
    
    public function press() {
        if ($this->on) {
            $this->lightBulb->turnOff();
            $this->on = false;
        } else {
            $this->lightBulb->turnOn();
            $this->on = true;
        }
    }
}
```

In this example, `ElectricPowerSwitch` is directly dependent on the concrete `LightBulb` class, violating DIP.

### Refactored Code Applying DIP

To adhere to DIP, we should rely on abstractions rather than concrete classes.

# Dependency Inversion Principle (DIP) Code Examples with Detailed Comments

### Refactored Code Applying DIP with Comments

```php
// Abstraction (Interface) - Demonstrates "Abstractions should not depend on details."
interface SwitchableDeviceInterface {
  public function turnOn();
  public function turnOff();
}

// Low-level module (Detail) - Demonstrates "Details should depend on abstractions."
class LightBulb implements SwitchableDeviceInterface {
  // Implementation of turnOn and turnOff methods adheres to the interface
  // This is an example of "Details should depend on abstractions."
  public function turnOn() {
    echo "LightBulb: turned on\\n";
  }

  public function turnOff() {
    echo "LightBulb: turned off\\n";
  }
}

// High-level module - Demonstrates "High-level modules should not depend on low-level modules. Both should depend on abstractions."
class ElectricPowerSwitch {
  // Dependency on abstraction, not on concrete class
  // This adherence to "Both should depend on abstractions" allows for the decoupling of high-level modules from low-level modules.
  public $device; // Adheres to "Both should depend on abstractions."
  public $on;

  // Constructor injection of the dependency on an abstraction (SwitchableDeviceInterface)
  // This is a practical application of "High-level modules should not depend on low-level modules. Both should depend on abstractions."
  public function __construct(SwitchableDeviceInterface $device) {
      $this->device = $device;
      $this->on = false;
  }

  // Method that operates on the abstraction rather than a concrete implementation
  // Further adherence to "High-level modules should not depend on low-level modules."
  public function press() {
      if ($this->on) {
          $this->device->turnOff();
          $this->on = false;
      } else {
          $this->device->turnOn();
          $this->on = true;
      }
  }
}
```

In these refactored examples:

- The `SwitchableDeviceInterface` interface is the abstraction that both the high-level module (`ElectricPowerSwitch`)
  and the low-level module (`LightBulb`) depend on. This design adheres to DIP by decoupling the modules from each other
  and relying on abstractions instead of concrete implementations.

- `ElectricPowerSwitch` does not depend directly on the `LightBulb` class (a specific implementation), but on
  the `SwitchableDeviceInterface`. This setup demonstrates the principle that "High-level modules should not depend on
  low-level modules. Both should depend on abstractions."

- The `LightBulb` class, being a low-level module, depends on the `SwitchableDeviceInterface` abstraction,
  illustrating "Details should depend on abstractions."

### Explanation

- By using the `SwitchableDeviceInterface` abstraction, `ElectricPowerSwitch` can now work with any device that
  implements this interface, not just a light bulb. This makes the code more flexible and decouples the high-level
  module from the low-level module.

- This approach aligns with DIP by ensuring that both high-level and low-level modules depend on abstractions rather
  than concrete implementations.

### Benefits of Applying DIP

- **Enhanced Flexibility**: The system becomes more flexible and adaptable to change.
- **Ease of Testing**: Dependency inversion facilitates more straightforward unit testing by mocking dependencies.
- **Reduced Coupling**: Reduces the coupling between different parts of the code, making it easier to maintain and
  extend.
