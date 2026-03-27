# Interface Segregation Principle (ISP)

Interface Segregation Principle (ISP) navodi da nijedan klijent ne treba biti primoran da zavisi od metoda koje ne koristi. Podstiče razdvajanje velikih interfejsa na manje i specifičnije, tako da klijenti trebaju da znaju samo o metodama koje su im relevantne.

### Kršenje ISP

Kršenje ISP javlja se kada je klasa primorana da implementira interfejs sa metodama koje ne koristi.

```php
interface WorkerInterface {
    public function work();
    public function eat();
}

class HumanWorker implements WorkerInterface {
    public function work() {
        echo "Working";
    }

    public function eat() {
        echo "Eating lunch";
    }
}

class RobotWorker implements WorkerInterface {
    public function work() {
        echo "Working more efficiently";
    }

    public function eat() {
        // Not applicable for robots
    }
}
```

U ovom primeru, `RobotWorker` je primoran da implementira metodu `eat`, koju ne koristi, čime se krši ISP.

### Refactored kod koji primenjuje ISP

Da bi se poštovao ISP, trebalo bi da definišemo više, specifičnijih interfejsa.

```php
interface WorkableInterface {
    public function work();
}

interface EatableInterface {
    public function eat();
}

class HumanWorker implements WorkableInterface, EatableInterface {
    public function work() {
        echo "Working";
    }

    public function eat() {
        echo "Eating lunch";
    }
}

class RobotWorker implements WorkableInterface {
    public function work() {
        echo "Working more efficiently";
    }
}
```

### Objašnjenje

- Razdvajanjem `WorkerInterface` na `WorkableInterface` i `EatableInterface`, osiguravamo da `HumanWorker` i `RobotWorker` implementiraju samo metode koje su im relevantne. Ovo je u skladu sa ISP eliminisanjem potrebe da klasa zavisi od interfejsa koje ne koristi.

- Ovaj pristup povećava koheziju unutar sistema pravljenjem jasnih razdvajanja između različitih funkcionalnosti, što dovodi do lakšeg za održavanje i fleksibilnijeg koda.

### Prednosti primene ISP

- **Smanjeni neželjeni efekti**: Promene u nepovezanim interfejsima ne utiču na klijente.
- **Povećana fleksibilnost sistema**: Olakšava refactoring, promenu i ponovnu implementaciju sistema.
- **Lakše za razumevanje**: Klijenti nisu primorani da implementiraju interfejse koje ne koriste, čineći bazu koda čistijom i lakšom za razumevanje.
