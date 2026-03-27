# Closure vs anonimna funkcija

Na PHP intervjuima, ovi pojmovi se često koriste zajedno.
Jednostavno objašnjenje: anonimna funkcija je funkcija bez imena; closure je ta funkcija plus uhvaćene spoljne promenljive.

## Preduslovi

- Poznajete PHP sintaksu funkcija
- Poznajete osnove opsega promenljivih
- Videli ste callback-ove kao što je `array_map`

## Anonimna funkcija

Anonimna funkcija = function literal bez imena.

```php
<?php

$toUpper = function (string $value): string {
    return strtoupper($value);
};

echo $toUpper('php'); // PHP
```

## Closure (uhvaćeni opseg)

Closure hvata promenljive iz spoljnog opsega koristeći `use`.

```php
<?php

$taxRate = 0.20;

$priceWithTax = function (float $price) use ($taxRate): float {
    return $price * (1 + $taxRate);
};

echo $priceWithTax(100); // 120
```

Funkcija zadržava pristup `$taxRate` iz trenutka kada je kreirana.

## Hvatanje po vrednosti vs po referenci

```php
<?php

$counter = 0;

$byValue = function () use ($counter): int {
    return ++$counter;
};

$byReference = function () use (&$counter): int {
    return ++$counter;
};

echo $byValue();     // 1 (internal copy)
echo $byValue();     // 1 (still internal copy)
echo $byReference(); // 1 (updates outer variable)
echo $byReference(); // 2
```

Savet za intervju: pomenite `use (&$var)` pažljivo, jer deljeno promenljivo stanje može uzrokovati greške.

## Tipični slučajevi upotrebe

- Kratki callback-ovi: sortiranje, mapiranje, filtriranje
- Middleware i event handler-i u frameworkima
- Factory funkcije koje vraćaju ponašanje sa unapred konfigurisanim kontekstom

## Uobičajeno pitanje na intervjuu

Da li su to različiti tipovi u PHP-u?

Praktičan odgovor: oba su predstavljena kao `Closure` objekti pri izvršavanju; "closure" obično naglašava uhvaćeni opseg.

## Zaključak

Anonimna funkcija opisuje formu (nema ime).
Closure opisuje ponašanje (hvata spoljni opseg).
U svakodnevnom PHP-u, ljudi često kažu "closure" za oba, ali aspekt hvatanja je ključna razlika.
