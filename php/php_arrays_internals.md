PHP arrays look simple on the surface, but internally they are implemented as a **hash table** (also called hash map). This is very different from arrays in languages like C or Java, which are just continuous blocks of memory indexed by numbers.

### What Is a Hash Table

A hash table is a data structure that maps **keys** to **values** using a **hash function**. The hash function converts a key (like a string `"name"` or an integer `5`) into a number that tells PHP where to store the value in memory.

```php
$user = ['name' => 'Dragan', 'role' => 'developer'];
// Internally:
// hash("name") → position 3 in memory → stores "Dragan"
// hash("role") → position 7 in memory → stores "developer"
```

This gives PHP arrays **O(1) average time** for reading, writing, and checking if a key exists — the same speed regardless of whether the array has 10 or 10 million elements.

### PHP Array Internal Structure

Since PHP 7, arrays use a structure called `HashTable` in C. Each array consists of:

1. **Hash table** — an array of "buckets" where data is stored
2. **Bucket** — holds the key, the value, and a hash of the key
3. **Packed vs hash mode** — PHP optimizes for integer-indexed arrays

```text
PHP Array (HashTable)
├── nTableSize: 8         (allocated bucket slots, always power of 2)
├── nNumOfElements: 3     (actual elements stored)
├── nNumUsed: 3           (slots used including deleted ones)
├── arData: [             (array of Buckets)
│   Bucket { key: "name", val: "Dragan", h: 0x7a34f... }
│   Bucket { key: "role", val: "developer", h: 0x3c91a... }
│   Bucket { key: "age",  val: 30, h: 0x8b72c... }
│   (5 empty slots)
│ ]
```

### Packed Arrays vs Hash Arrays

PHP optimizes for the common case of sequential integer keys (0, 1, 2, ...):

```php
// Packed array — optimized, no hash computation needed
$colors = ['red', 'green', 'blue'];
// Keys are 0, 1, 2 — PHP stores them in order and accesses by offset directly

// Hash array — uses hash function for key lookup
$user = ['name' => 'Dragan', 'email' => 'dragan@example.com'];
// String keys require hash computation
```

Packed arrays use less memory and are faster because PHP can skip the hashing step and access elements directly by their integer offset.

**When does a packed array become a hash array?**

```php
$arr = [0 => 'a', 1 => 'b', 2 => 'c'];  // Packed — sequential integers from 0

$arr = [0 => 'a', 5 => 'b', 1 => 'c'];   // Hash — non-sequential keys
$arr = ['x' => 'a'];                       // Hash — string key
unset($arr[1]);                             // Hash — gap in sequence after unset
```

### Hash Collisions

Two different keys can produce the same hash value. This is called a **collision**. PHP handles collisions using **linked lists** — when two keys hash to the same bucket position, they are chained together.

```text
Bucket slot 3: "name" → "Dragan" → (next) "city" → "Belgrade"
                        Both "name" and "city" hashed to slot 3
```

In practice, collisions are rare. PHP resizes the hash table when it gets too full (load factor), which keeps collisions low.

### Memory Usage

PHP arrays use significantly more memory than simple C arrays because each element stores:

- The value (zval — 16 bytes)
- The key (string key + hash, or integer key)
- Pointers for ordering and collision chains
- Bucket overhead

```php
// This array of 1 million integers uses ~36 MB in PHP
$arr = range(1, 1_000_000);
echo memory_get_usage(true);  // ~36 MB

// In C, the same data would use ~4 MB (1M × 4 bytes per int)
```

**Tip:** For large datasets with only integer values, use `SplFixedArray` — it uses a real C-style array and saves 2-3x memory:

```php
$fixed = new SplFixedArray(1_000_000);
for ($i = 0; $i < 1_000_000; $i++) {
    $fixed[$i] = $i;
}
echo memory_get_usage(true);  // ~16 MB (vs ~36 MB for regular array)
```

### Time Complexity

| Operation | Average | Worst case |
|-----------|---------|------------|
| Read by key `$arr['name']` | O(1) | O(n) — all keys collide (extremely rare) |
| Write `$arr['name'] = 'x'` | O(1) | O(n) — resize + copy |
| Check key `isset($arr['name'])` | O(1) | O(n) |
| Delete `unset($arr['name'])` | O(1) | O(n) |
| Search value `in_array($val, $arr)` | O(n) | O(n) — must check every element |
| Count `count($arr)` | O(1) | O(1) — stored in nNumOfElements |

**Important:** `in_array()` is O(n) because it searches values, not keys. If you need fast value lookups, flip the array:

```php
// Slow — O(n) per lookup
$allowed = ['admin', 'editor', 'moderator'];
if (in_array($role, $allowed)) { ... }  // Scans all 3 elements

// Fast — O(1) per lookup
$allowed = ['admin' => true, 'editor' => true, 'moderator' => true];
if (isset($allowed[$role])) { ... }  // Direct hash lookup
```

### PHP Array Is Ordered

Unlike hash maps in many languages (e.g., Java's `HashMap`), PHP arrays maintain **insertion order**. This is because each bucket stores a pointer to the next element in insertion order.

```php
$arr = ['c' => 3, 'a' => 1, 'b' => 2];
foreach ($arr as $key => $value) {
    echo "$key: $value\n";
}
// Output: c: 3, a: 1, b: 2  ← insertion order, NOT sorted by key
```

This is why PHP can use the same array type as a list, dictionary, stack, queue, and ordered map.

### PHP Array as Multiple Data Structures

```php
// As a list (indexed)
$list = ['apple', 'banana', 'cherry'];

// As a dictionary (key-value)
$config = ['host' => 'localhost', 'port' => 3306];

// As a stack (LIFO)
$stack = [];
array_push($stack, 'task1');
array_push($stack, 'task2');
$last = array_pop($stack);  // 'task2'

// As a queue (FIFO)
$queue = [];
$queue[] = 'job1';
$queue[] = 'job2';
$first = array_shift($queue);  // 'job1' — but O(n) because it reindexes!

// For real queue performance, use SplQueue
$queue = new SplQueue();
$queue->enqueue('job1');
$queue->enqueue('job2');
$first = $queue->dequeue();  // 'job1' — O(1)
```

### Real Scenario

You are building a caching layer that stores user data in memory during a request:

```php
// Bad approach — searching by value is O(n) per lookup
$activeUserIds = [101, 205, 312, 450, 891, /* ... 10,000 more */];

foreach ($orders as $order) {
    // in_array scans up to 10,000 elements for EACH order
    if (in_array($order->getUserId(), $activeUserIds)) {
        $this->processOrder($order);
    }
}

// Good approach — flip to hash lookup, O(1) per check
$activeUsers = array_flip($activeUserIds);
// Result: [101 => 0, 205 => 1, 312 => 2, ...]

foreach ($orders as $order) {
    if (isset($activeUsers[$order->getUserId()])) {  // O(1)
        $this->processOrder($order);
    }
}
```

With 10,000 active users and 50,000 orders:

- `in_array`: up to 10,000 × 50,000 = 500 million comparisons
- `isset`: 50,000 hash lookups = practically instant

### Conclusion

PHP arrays are implemented as hash tables (ordered hash maps). They support O(1) average-time read/write by key, maintain insertion order, and can act as lists, dictionaries, stacks, and queues. They use more memory than C-style arrays because each element carries metadata. Use `isset()` instead of `in_array()` for fast lookups, `SplFixedArray` for large integer-indexed datasets, and `SplQueue` for real queue operations. Understanding the internal structure helps you write performant PHP code and avoid hidden O(n) operations.

> See also: [Popular SPL functions](popular_spl_functions.md), [Data types in PHP](data_types_in_php.md)
