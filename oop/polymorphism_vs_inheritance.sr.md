# Polimorfizam vs Nasleđivanje

Ovi termini su povezani, ali nisu ista stvar.
Na intervjuima, dobar odgovor je: nasleđivanje je jedan način modeliranja odnosa između klasa, dok je polimorfizam način korišćenja različitih implementacija kroz jedan zajednički tip.

## Preduslovi

- Znate osnove nasleđivanja klasa (`extends`)
- Znate interfejse u PHP-u
- Razumete prekoračivanje metoda

## Nasleđivanje

Nasleđivanje kreira vezu "is-a" (jeste).

```php
<?php

class Animal
{
    public function makeSound(): string
    {
        return 'Some generic sound';
    }
}

class Dog extends Animal
{
    public function makeSound(): string
    {
        return 'Bark';
    }
}
```

`Dog` nasleđuje ponašanje od `Animal` i može prekoračiti delove toga.

## Polimorfizam

Polimorfizam znači da klijentski kod radi sa zajedničkim tipom i svaka implementacija se ponaša različito.
Ovaj zajednički tip može biti roditeljska klasa ili interfejs.

```php
<?php

interface Notifier
{
    public function send(string $message): void;
}

class EmailNotifier implements Notifier
{
    public function send(string $message): void
    {
        echo 'Email: ' . $message . PHP_EOL;
    }
}

class SmsNotifier implements Notifier
{
    public function send(string $message): void
    {
        echo 'SMS: ' . $message . PHP_EOL;
    }
}

function notifyAll(array $notifiers, string $message): void
{
    foreach ($notifiers as $notifier) {
        $notifier->send($message);
    }
}
```

`notifyAll` je polimorfan: isti poziv, različito ponašanje u vreme izvršavanja.

## Ključna razlika

- Nasleđivanje: kako su klase povezane.
- Polimorfizam: kako klijentski kod koristi povezane ili nepovezane implementacije kroz jedan tip.

Možete imati polimorfizam bez nasleđivanja koristeći interfejse.

## Praktično pravilo

- Koristite nasleđivanje za jasne hijerarhije "is-a" i zajedničko ponašanje.
- Koristite polimorfizam (često putem interfejsa) da visoko-nivo kod bude fleksibilan i lak za proširivanje.

## Uobičajeno pitanje na intervjuu

Zašto timovi često preferiraju kompoziciju + polimorfizam interfejsa nad dubokim stablima nasleđivanja?

Kratki odgovor: smanjuje tesno spajanje i čini promene sigurnijim.

## Zaključak

Nasleđivanje je mehanizam dizajna; polimorfizam je mehanizam upotrebe.
Često rade zajedno, ali polimorfizam je obično veći cilj za proširiv kod.
