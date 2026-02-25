PHP 8.5 was released in November 2025. It continued to improve the language with pipe operator, better enums, and new utility features.

### Pipe Operator (`|>`)

The pipe operator passes the result of a left expression as the first argument to the function on the right:

```php
// Before PHP 8.5 — nested calls are hard to read
$result = array_sum(array_map(fn($n) => $n * 2, array_filter($numbers, fn($n) => $n > 0)));

// PHP 8.5 — reads left to right, like a pipeline
$result = $numbers
    |> array_filter(fn($n) => $n > 0)
    |> array_map(fn($n) => $n * 2)
    |> array_sum();
```

Each step takes the output of the previous step and feeds it as the first argument to the next function. This makes data transformation chains much easier to read.

```php
$output = ' Hello, World! '
    |> trim()
    |> strtolower()
    |> str_replace(' ', '-')
    |> htmlspecialchars();
// "hello,-world!"
```

### `Locale`-independent Float to String

PHP 8.5 ensures that casting a float to string always uses a dot as the decimal separator, regardless of the system locale:

```php
setlocale(LC_ALL, 'de_DE');

// Before PHP 8.5 — locale could affect output
// (string)1.5 might produce "1,5" in some contexts

// PHP 8.5 — always uses dot
echo (string)1.5; // "1.5" — always, regardless of locale
```

### `array_first()` and `array_last()`

Simple functions to get the first or last element of an array without modifying it:

```php
$items = ['apple', 'banana', 'cherry'];

$first = array_first($items); // "apple"
$last = array_last($items);   // "cherry"

// Works with associative arrays too
$config = ['host' => 'localhost', 'port' => 3306, 'db' => 'myapp'];
$first = array_first($config); // "localhost"
$last = array_last($config);   // "myapp"

// Returns null for empty arrays
$empty = array_first([]); // null
```

Before PHP 8.5, getting the first element without modifying the array required `reset()` (which moves the internal pointer) or `array_key_first()` + index access.

### `CLI` Improvements

PHP 8.5 improved the built-in CLI server and SAPI with better error reporting and colored output support.

### `#[\NoDiscard]` Attribute

Warns when a function's return value is ignored:

```php
#[\NoDiscard("The filtered array is not used")]
function filterActive(array $items): array
{
    return array_filter($items, fn($item) => $item['active']);
}

filterActive($users); // Warning! Return value is discarded
$active = filterActive($users); // OK — return value is used
```

This is useful for pure functions where ignoring the result is almost certainly a bug.

### Closures from Callables in Constant Expressions

Closure creation with `(...)` is now allowed in more places, including class constant defaults and attribute arguments.

### `Grapheme` Cluster Improvements

Better support for Unicode grapheme clusters in string functions, important for handling emoji and complex scripts correctly:

```php
// A family emoji is one "grapheme cluster" but multiple bytes/code points
$emoji = '👨‍👩‍👧‍👦';
grapheme_strlen($emoji); // 1 — correctly counts as one character
```

### Real Scenario

You are building a data processing pipeline for an e-commerce report. Before PHP 8.5:

```php
class SalesReport
{
    public function generate(array $orders): array
    {
        // Nested calls — read from inside out
        $result = array_sum(
            array_column(
                array_filter(
                    array_map(
                        fn($order) => [
                            'total' => $order['price'] * $order['quantity'],
                            'status' => $order['status'],
                        ],
                        $orders
                    ),
                    fn($item) => $item['status'] === 'completed'
                ),
                'total'
            )
        );

        return ['total_revenue' => $result];
    }
}
```

After PHP 8.5:

```php
class SalesReport
{
    #[\NoDiscard]
    public function generate(array $orders): array
    {
        $totalRevenue = $orders
            |> array_map(fn($order) => [
                'total' => $order['price'] * $order['quantity'],
                'status' => $order['status'],
            ])
            |> array_filter(fn($item) => $item['status'] === 'completed')
            |> array_column('total')
            |> array_sum();

        return ['total_revenue' => $totalRevenue];
    }
}

// Getting first and last order is also simpler
$firstOrder = array_first($orders);
$lastOrder = array_last($orders);

// And the #[NoDiscard] attribute prevents this mistake:
$report = new SalesReport();
$report->generate($orders); // Warning! Return value not used
$data = $report->generate($orders); // OK
```

The pipe operator makes the data flow clear — each step feeds into the next, reading top to bottom.

### Conclusion

PHP 8.5 introduced the pipe operator (`|>`) for readable function chaining, `array_first()` and `array_last()` utilities, the `#[\NoDiscard]` attribute to catch unused return values, locale-independent float-to-string casting, and improved Unicode grapheme support. The pipe operator is the most impactful feature, making data transformation pipelines much cleaner.
