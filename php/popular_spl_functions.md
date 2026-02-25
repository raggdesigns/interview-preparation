SPL (Standard PHP Library) is a collection of built-in classes, interfaces, and functions that solve common programming problems. They are always available in PHP — no extensions or packages needed.

### Data Structures

#### SplStack — Last In, First Out (LIFO)

A stack works like a pile of plates. You add to the top and take from the top.

```php
$stack = new SplStack();
$stack->push('first');
$stack->push('second');
$stack->push('third');

echo $stack->pop(); // "third" — last added, first removed
echo $stack->pop(); // "second"
echo $stack->pop(); // "first"
```

#### SplQueue — First In, First Out (FIFO)

A queue works like a line at a store. First person in line gets served first.

```php
$queue = new SplQueue();
$queue->enqueue('Task 1');
$queue->enqueue('Task 2');
$queue->enqueue('Task 3');

echo $queue->dequeue(); // "Task 1" — first added, first removed
echo $queue->dequeue(); // "Task 2"
```

#### SplPriorityQueue — Items with Priority

Items come out in order of priority, not the order they were added.

```php
$queue = new SplPriorityQueue();
$queue->insert('Low priority task', 1);
$queue->insert('Critical bug fix', 10);
$queue->insert('Medium task', 5);

echo $queue->extract(); // "Critical bug fix" (priority 10)
echo $queue->extract(); // "Medium task" (priority 5)
echo $queue->extract(); // "Low priority task" (priority 1)
```

#### SplFixedArray — Fixed-size Array

More memory-efficient than regular arrays when you know the size in advance.

```php
$arr = new SplFixedArray(3);
$arr[0] = 'a';
$arr[1] = 'b';
$arr[2] = 'c';
// $arr[3] = 'd'; // RuntimeException — array is fixed at 3 elements

// Uses ~30-50% less memory than a regular array for large datasets
```

### Iterators

#### DirectoryIterator — Loop Through Files

```php
$dir = new DirectoryIterator('/var/log');
foreach ($dir as $file) {
    if ($file->isFile()) {
        echo $file->getFilename() . ' — ' . $file->getSize() . " bytes\n";
    }
}
```

#### RecursiveDirectoryIterator — Files in All Subfolders

```php
$dir = new RecursiveDirectoryIterator('/var/www/project/src');
$iterator = new RecursiveIteratorIterator($dir);

foreach ($iterator as $file) {
    if ($file->getExtension() === 'php') {
        echo $file->getPathname() . "\n";
    }
}
// Lists every .php file in src/ and all its subfolders
```

#### FilterIterator — Filter Results

```php
class PhpFileFilter extends FilterIterator
{
    public function accept(): bool
    {
        return $this->current()->getExtension() === 'php';
    }
}

$dir = new RecursiveDirectoryIterator('/var/www/src');
$recursive = new RecursiveIteratorIterator($dir);
$phpFiles = new PhpFileFilter($recursive);

foreach ($phpFiles as $file) {
    echo $file->getPathname() . "\n"; // Only .php files
}
```

### Functions

#### spl_autoload_register()

Registers a function to automatically load classes. This is the foundation of all autoloading in PHP.

```php
spl_autoload_register(function ($class) {
    $file = str_replace('\\', '/', $class) . '.php';
    if (file_exists($file)) {
        require $file;
    }
});
```

#### spl_object_id()

Returns a unique integer ID for an object. Useful for tracking objects.

```php
$a = new stdClass();
$b = new stdClass();
echo spl_object_id($a); // e.g., 1
echo spl_object_id($b); // e.g., 2
```

#### class_implements() and class_parents()

```php
$interfaces = class_implements(ArrayObject::class);
// ['IteratorAggregate', 'Traversable', 'ArrayAccess', 'Serializable', 'Countable']

$parents = class_parents(SplPriorityQueue::class);
// Shows parent classes
```

### Exceptions

SPL provides a set of standard exception classes:

| Exception | When to use |
|-----------|-------------|
| `InvalidArgumentException` | Wrong type/value passed to a function |
| `RuntimeException` | Error that can only be found at runtime |
| `LogicException` | Error in program logic |
| `OutOfRangeException` | Index out of valid range |
| `OverflowException` | Adding to a full container |
| `UnderflowException` | Removing from an empty container |
| `UnexpectedValueException` | Value doesn't match expected type |
| `LengthException` | Invalid length (e.g., string too long) |

```php
function divide(int $a, int $b): float
{
    if ($b === 0) {
        throw new InvalidArgumentException('Cannot divide by zero');
    }
    return $a / $b;
}
```

### Real Scenario

You are building a task queue system for background jobs:

```php
class JobQueue
{
    private SplPriorityQueue $queue;

    public function __construct()
    {
        $this->queue = new SplPriorityQueue();
    }

    public function addJob(string $jobName, int $priority): void
    {
        $this->queue->insert($jobName, $priority);
    }

    public function processAll(): void
    {
        while (!$this->queue->isEmpty()) {
            $job = $this->queue->extract();
            echo "Processing: $job\n";
        }
    }
}

$queue = new JobQueue();
$queue->addJob('Send welcome email', 3);
$queue->addJob('Process payment', 10);
$queue->addJob('Generate report', 1);
$queue->addJob('Update search index', 5);

$queue->processAll();
// Processing: Process payment (10)
// Processing: Update search index (5)
// Processing: Send welcome email (3)
// Processing: Generate report (1)
```

### Conclusion

SPL provides ready-to-use data structures (Stack, Queue, PriorityQueue, FixedArray), file iterators (DirectoryIterator, RecursiveDirectoryIterator), the autoloading system (`spl_autoload_register`), and standard exceptions. These are built into PHP and are more efficient than building your own implementations. The most commonly used in real projects are `spl_autoload_register()`, SPL exceptions, and the directory iterators.
