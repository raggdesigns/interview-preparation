# Closure vs Anonymous Function

In PHP interviews, these terms are often used together.
Simple explanation: an anonymous function is a function without a name; a closure is that function plus captured outer variables.

## Prerequisites

- You know PHP function syntax
- You know variable scope basics
- You have seen callbacks like `array_map`

## Anonymous Function

Anonymous function = function literal with no name.

```php
<?php

$toUpper = function (string $value): string {
    return strtoupper($value);
};

echo $toUpper('php'); // PHP
```

## Closure (Captured Scope)

A closure captures variables from outer scope using `use`.

```php
<?php

$taxRate = 0.20;

$priceWithTax = function (float $price) use ($taxRate): float {
    return $price * (1 + $taxRate);
};

echo $priceWithTax(100); // 120
```

The function keeps access to `$taxRate` from when it was created.

## Capture by Value vs by Reference

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

Interview tip: mention `use (&$var)` carefully, because shared mutable state can cause bugs.

## Typical Use Cases

- Short callbacks: sorting, mapping, filtering
- Framework middleware and event handlers
- Factory functions that return behavior with preconfigured context

## Common Interview Question

Are they different types in PHP?

Practical answer: both are represented as `Closure` objects at runtime; “closure” usually emphasizes captured scope.

## Conclusion

Anonymous function describes form (no name).
Closure describes behavior (captures outer scope).
In day-to-day PHP, people often say “closure” for both, but the capture aspect is the key distinction.
