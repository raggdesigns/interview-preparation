Imutabilni objekat je objekat čije stanje ne može biti promenjeno nakon što je kreiran. Jednom kada postavite njegove vrednosti, one ostaju iste zauvek. Ako vam trebaju drugačije vrednosti, kreirate novi objekat umesto da modifikujete postojeći.

### Mutabilni vs imutabilni

```php
// MUTABLE — you can change the object after creating it
$date = new DateTime('2024-01-15');
$date->modify('+1 day'); // Changes the SAME object to Jan 16
echo $date->format('Y-m-d'); // "2024-01-16" — original is gone!

// IMMUTABLE — modifying returns a NEW object, original stays the same
$date = new DateTimeImmutable('2024-01-15');
$nextDay = $date->modify('+1 day'); // Returns a NEW object
echo $date->format('Y-m-d');    // "2024-01-15" — original unchanged
echo $nextDay->format('Y-m-d'); // "2024-01-16" — this is a new object
```

### Zašto postoje imutabilni objekti

#### 1. Sprečavanje slučajnih promena

Najveći razlog je izbegavanje grešaka uzrokovanih neočekivanim modifikacijama:

```php
class Event
{
    public function __construct(
        private string $name,
        private DateTime $startDate
    ) {}

    public function getStartDate(): DateTime
    {
        return $this->startDate;
    }
}

$event = new Event('Conference', new DateTime('2024-06-01'));

// Someone gets the date and modifies it
$date = $event->getStartDate();
$date->modify('+30 days'); // This changes the date INSIDE the Event object!

echo $event->getStartDate()->format('Y-m-d'); // "2024-07-01" — BUG!
```

Sa `DateTimeImmutable`, ova greška ne može da se dogodi:

```php
$event = new Event('Conference', new DateTimeImmutable('2024-06-01'));
$date = $event->getStartDate();
$date->modify('+30 days'); // Returns a NEW object, Event is not affected

echo $event->getStartDate()->format('Y-m-d'); // "2024-06-01" — safe!
```

#### 2. Bezbedno deljenje između objekata

Kada je objekat imutabilan, možete ga prosleđivati bez brige da će ga neki drugi kod promeniti.

#### 3. Lakše razumevanje

Ako znate da se objekat nikada ne menja, možete verovati njegovoj vrednosti svuda u kodu. Nema potrebe da proveravate "da li ga je nešto modifikovalo?"

#### 4. Bezbednost niti

U konkurentnim aplikacijama, imutabilni objekti su bezbedni za korišćenje iz više niti bez zaključavanja.

### Kako kreirati imutabilne objekte u PHP-u

```php
class Money
{
    public function __construct(
        private readonly float $amount,
        private readonly string $currency
    ) {}

    public function getAmount(): float
    {
        return $this->amount;
    }

    public function getCurrency(): string
    {
        return $this->currency;
    }

    // Instead of changing this object, return a NEW one
    public function add(Money $other): self
    {
        if ($this->currency !== $other->currency) {
            throw new InvalidArgumentException('Cannot add different currencies');
        }

        return new self($this->amount + $other->amount, $this->currency);
    }

    public function multiply(float $factor): self
    {
        return new self($this->amount * $factor, $this->currency);
    }
}

$price = new Money(100, 'EUR');
$tax = new Money(21, 'EUR');

$total = $price->add($tax);       // NEW object: 121 EUR
$doubled = $total->multiply(2);   // NEW object: 242 EUR

// $price is still 100 EUR — never changed
```

Ključna pravila za kreiranje imutabilnih objekata:

- Koristite `readonly` properties (PHP 8.1+) ili samo privatne properties bez setter-a
- Nikada ne modifikujte interno stanje — umesto toga vraćajte **novu instancu**
- Duboko kopirajte sve mutabilne objekte prosleđene konstruktoru

### Ugrađene imutabilne klase u PHP-u

- `DateTimeImmutable` — imutabilna verzija `DateTime`
- `DateInterval` — već efektivno imutabilan
- Value objekti u frameworkima (npr. Symfony-jevi `Request` headeri)

### Realni scenario

Gradite korpu za kupovinu. Cena proizvoda ne bi trebalo nikada slučajno da se promeni nakon što je postavljena:

```php
class Product
{
    public function __construct(
        private readonly string $name,
        private readonly Money $price
    ) {}

    public function getPrice(): Money
    {
        return $this->price; // Safe to return — Money is immutable
    }

    public function withDiscount(float $percent): self
    {
        $discount = $this->price->multiply($percent / 100);
        $newPrice = new Money(
            $this->price->getAmount() - $discount->getAmount(),
            $this->price->getCurrency()
        );

        return new self($this->name, $newPrice); // New product, original unchanged
    }
}

$laptop = new Product('Laptop', new Money(999, 'EUR'));
$discounted = $laptop->withDiscount(10); // New Product at 899.10 EUR
// $laptop is still 999 EUR
```

### Zaključak

Imutabilni objekti postoje kako bi sprečili greške uzrokovane slučajnim promenama stanja. Jednom kreirani, ne mogu biti modifikovani — svaka "promena" proizvodi novi objekat. PHP-ov `DateTimeImmutable` je najčešći primer. Koristite `readonly` properties (PHP 8.1+) i vraćajte nove instance iz metoda za modifikaciju kako biste kreirali sopstvene imutabilne objekte.
