# OOP Osnovne definicije

Objektno-orijentisano programiranje (OOP) je način modeliranja koda oko domenskih koncepata (objekata) umesto samo oko funkcija.
Na intervjuima, ova tema se često koristi da se proveri da li možete dizajnirati održiv kod, ne samo pisati sintaksu.
Četiri osnovne ideje su enkapsulacija, apstrakcija, nasleđivanje i polimorfizam.

## Preduslovi

- Osnovna PHP sintaksa klase (`class`, `public`, `private`)
- Razlika između stanja objekta (svojstava) i ponašanja (metoda)
- Osnovno razumevanje interfejsa ili roditeljskih klasa

## Enkapsulacija

Enkapsulacija znači da objekat kontroliše kako se njegovo unutrašnje stanje čita i menja.
Izlažete bezbedne operacije i skrivate direktne promene stanja.

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

Zašto je ovo važno: kod van klase ne može dovesti objekat u nevalidno stanje.

## Apstrakcija

Apstrakcija znači izlaganje onoga što objekat radi, dok se skriva kako to radi.
Korisnici koriste mali, jasan API i ne zavise od unutrašnjih koraka.

U primeru `BankAccount` iznad, pozivatelji ne trebaju znati kako su implementirane validacija ili ažuriranja stanja; koriste samo `deposit`, `withdraw` i `balance`.

## Nasleđivanje

Nasleđivanje dozvoljava dečjoj klasi da ponovo koristi ponašanje roditeljske klase i proširi ga.
Koristite ga samo kada postoji prava veza "is-a" (jeste).

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

## Polimorfizam

Polimorfizam znači da kod može raditi sa roditeljskim tipom i još uvek izvršavati ponašanje specifično za dete.

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

`printAnimalSounds` tretira sve objekte kao `Animal`, ali svako dete vraća svoj sopstveni zvuk.

## Uobičajeni uglovi intervjua

- Kada nasleđivanje postaje problem?
- Kako enkapsulacija i validacija smanjuju greške?
- Zašto je polimorfizam koristan za proširivost?
- Kada bi kompozicija trebalo biti preferirana nad nasleđivanjem?

## Zaključak

Enkapsulacija štiti stanje, apstrakcija smanjuje kognitivno opterećenje, nasleđivanje omogućava ponovnu upotrebu, a polimorfizam omogućava proširivanje.
Zajedno pomažu u izgradnji koda koji je lakši za menjanje i sigurniji za razvoj.
