# Dependency Inversion Principle (DIP)

Dependency Inversion Principle (DIP) zagovara da moduli budu nezavisni od konkretnih implementacija svojih zavisnosti. Umesto toga, i moduli visokog nivoa i moduli niskog nivoa trebaju zavisiti od apstrakcija (npr. interfejsa). Ovaj princip se sastoji od dva ključna dela:

1. Moduli visokog nivoa ne trebaju zavisiti od modula niskog nivoa. Oba trebaju zavisiti od apstrakcija.
2. Apstrakcije ne trebaju zavisiti od detalja. Detalji trebaju zavisiti od apstrakcija.

Kada podklasa promeni, roditeljska klasa neće morati da se menja. To je inverzija kontrole. Klasa visokog nivoa preuzima kontrolu nad zavisnostima korišćenjem definisane injekcije sa interfejsom.

## Način razmišljanja

- Klase trebaju zavisiti od interfejsa umesto od konkretnih klasa.
- Te interfejse treba da dizajnira klasa koja ih koristi, a ne klase koje će ih implementirati.

### Kršenje DIP

Uobičajeno kršenje DIP javlja se kada modul visokog nivoa direktno zavisi od modula niskog nivoa.

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

U ovom primeru, `ElectricPowerSwitch` direktno zavisi od konkretne klase `LightBulb`, čime se krši DIP.

### Refactored kod koji primenjuje DIP

Da bi se poštovao DIP, trebali bismo se oslanjati na apstrakcije umesto na konkretne klase.

# Dependency Inversion Principle (DIP) — primeri koda sa detaljnim komentarima

### Refactored kod koji primenjuje DIP sa komentarima

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

U ovim refactored primerima:

- Interfejs `SwitchableDeviceInterface` je apstrakcija od koje zavise i modul visokog nivoa (`ElectricPowerSwitch`)
  i modul niskog nivoa (`LightBulb`). Ovaj dizajn je u skladu sa DIP razdvajanjem modula jednih od drugih
  i oslanjanjem na apstrakcije umesto na konkretne implementacije.

- `ElectricPowerSwitch` ne zavisi direktno od klase `LightBulb` (specifične implementacije), već od
  `SwitchableDeviceInterface`. Ovo demonstrira princip da "Moduli visokog nivoa ne trebaju zavisiti od
  modula niskog nivoa. Oba trebaju zavisiti od apstrakcija."

- Klasa `LightBulb`, kao modul niskog nivoa, zavisi od apstrakcije `SwitchableDeviceInterface`,
  ilustrujući "Detalji trebaju zavisiti od apstrakcija."

### Objašnjenje

- Korišćenjem apstrakcije `SwitchableDeviceInterface`, `ElectricPowerSwitch` sada može raditi sa bilo kojim uređajem koji
  implementira ovaj interfejs, ne samo sa sijalicom. Ovo čini kod fleksibilnijim i razdvaja modul visokog nivoa od modula niskog nivoa.

- Ovaj pristup je u skladu sa DIP osiguravanjem da i moduli visokog i niskog nivoa zavise od apstrakcija, a ne
  od konkretnih implementacija.

### Prednosti primene DIP

- **Poboljšana fleksibilnost**: Sistem postaje fleksibilniji i prilagodljiviji promenama.
- **Lakoća testiranja**: Inverzija zavisnosti olakšava jedinično testiranje putem zamene zavisnosti lažnim objektima (mocking).
- **Smanjeno sprezanje**: Smanjuje sprezanje između različitih delova koda, čineći ga lakšim za održavanje i proširivanje.
