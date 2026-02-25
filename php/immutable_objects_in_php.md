An immutable object is an object whose state cannot be changed after it is created. Once you set its values, they stay the same forever. If you need different values, you create a new object instead of modifying the existing one.

### Mutable vs Immutable

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

### Why Immutable Objects Exist

#### 1. Prevent Accidental Changes

The biggest reason is to avoid bugs caused by unexpected modifications:

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

With `DateTimeImmutable`, this bug cannot happen:

```php
$event = new Event('Conference', new DateTimeImmutable('2024-06-01'));
$date = $event->getStartDate();
$date->modify('+30 days'); // Returns a NEW object, Event is not affected

echo $event->getStartDate()->format('Y-m-d'); // "2024-06-01" — safe!
```

#### 2. Safe to Share Between Objects

When an object is immutable, you can pass it around without worrying that some other code will change it.

#### 3. Easier to Reason About

If you know an object never changes, you can trust its value everywhere in your code. No need to check "did something modify it?"

#### 4. Thread Safety

In concurrent applications, immutable objects are safe to use from multiple threads without locks.

### How to Create Immutable Objects in PHP

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

Key rules for making immutable objects:

- Use `readonly` properties (PHP 8.1+) or only private properties with no setters
- Never modify internal state — return a **new instance** instead
- Deep-copy any mutable objects passed to the constructor

### PHP's Built-in Immutable Classes

- `DateTimeImmutable` — immutable version of `DateTime`
- `DateInterval` — already effectively immutable
- Value objects in frameworks (e.g., Symfony's `Request` headers)

### Real Scenario

You are building a shopping cart. The price of a product should never accidentally change after it's set:

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

### Conclusion

Immutable objects exist to prevent bugs caused by accidental state changes. Once created, they cannot be modified — any "change" produces a new object. PHP's `DateTimeImmutable` is the most common example. Use `readonly` properties (PHP 8.1+) and return new instances from modification methods to create your own immutable objects.
