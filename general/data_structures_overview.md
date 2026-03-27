Data structures are ways of organizing data in memory so that operations like reading, searching, inserting, and deleting are efficient. Every backend developer should understand the most common ones — not because you build them from scratch, but because you use them every day without realizing it.

### Hash Table (Hash Map)

A hash table stores **key-value pairs**. It uses a **hash function** to convert a key into an array index, giving O(1) average-time access.

```text
Key "name" → hash("name") → index 5 → Value "Dragan"
Key "role" → hash("role") → index 2 → Value "developer"
```

**Where you use it daily:**

- PHP arrays (associative) — `['name' => 'Dragan']`
- Redis — the entire database is a hash map
- HTTP headers — `Content-Type: application/json`
- `.env` files — `DATABASE_URL=mysql://...`
- JSON objects — `{"name": "Dragan"}`

```php
// PHP array IS a hash table
$config = [
    'db_host' => 'localhost',
    'db_port' => 3306,
    'db_name' => 'myapp',
];

// O(1) — direct hash lookup
$host = $config['db_host'];

// O(1) — check if key exists
if (isset($config['db_port'])) { ... }
```

| Operation | Average | Worst |
|-----------|---------|-------|
| Read by key | O(1) | O(n) |
| Insert | O(1) | O(n) |
| Delete | O(1) | O(n) |
| Search by value | O(n) | O(n) |

**Hash collision** — when two keys produce the same hash value. Handled by chaining (linked list at each slot) or open addressing. Good hash functions minimize collisions.

### Linked List

A linked list is a sequence of **nodes** where each node contains a value and a **pointer** to the next node. Unlike arrays, elements are not stored in continuous memory.

```text
[value: "A" | next: →] → [value: "B" | next: →] → [value: "C" | next: null]
     Node 1                    Node 2                    Node 3
```

**Types:**

- **Singly linked** — each node points to the next
- **Doubly linked** — each node points to next AND previous

| Operation | Array | Linked List |
|-----------|-------|-------------|
| Access by index | O(1) | O(n) — must traverse from head |
| Insert at beginning | O(n) — shift all | O(1) — change pointer |
| Insert at end | O(1) amortized | O(1) if tail pointer exists |
| Delete from middle | O(n) — shift all | O(1) if node is known |
| Search | O(n) | O(n) |

**Where you encounter it:**

- PHP's `SplDoublyLinkedList` — for queues and stacks
- Git commit history — each commit points to its parent
- Blockchain — each block links to the previous
- Undo/Redo in text editors — doubly linked list of states

```php
// PHP SplDoublyLinkedList
$list = new SplDoublyLinkedList();
$list->push('first');
$list->push('second');
$list->push('third');

$list->rewind();
while ($list->valid()) {
    echo $list->current() . "\n";
    $list->next();
}
// Output: first, second, third
```

### Tree

A tree is a hierarchical structure where each node has a value and zero or more **child nodes**. The topmost node is called the **root**.

```text
            [CEO]                    ← Root
           /     \
      [CTO]       [CFO]             ← Children of root
      /   \           \
  [Dev1] [Dev2]    [Accountant]     ← Leaves (no children)
```

**Common types:**

- **Binary tree** — each node has at most 2 children
- **Binary Search Tree (BST)** — left child < parent < right child → O(log n) search
- **B-Tree** — used by MySQL indexes (many children per node, optimized for disk)
- **DOM tree** — HTML/XML document structure

**Where you encounter trees:**

- **MySQL indexes** — B-Tree/B+Tree for fast lookups
- **XML/HTML parsing** — DOM tree
- **File system** — directories are a tree
- **JSON parsing** — nested objects form a tree
- **Symfony routing** — route matching uses a tree

```php
// XML/HTML is a tree structure
$xml = '<catalog>
    <book>
        <title>Clean Code</title>
        <author>Robert Martin</author>
    </book>
    <book>
        <title>DDD</title>
        <author>Eric Evans</author>
    </book>
</catalog>';

$doc = new SimpleXMLElement($xml);

// Traverse the tree
foreach ($doc->book as $book) {
    echo $book->title . " by " . $book->author . "\n";
}
```

**B-Tree in MySQL:**

```text
                    [50]
                   /    \
            [20, 35]    [70, 85]
           /   |   \    /   |   \
        [10] [25] [40] [60] [75] [90]
```

When you run `SELECT * FROM users WHERE id = 25`, MySQL does not scan all rows. It walks the B-Tree: 50 → go left → 20,35 → between them → found 25. This is O(log n) instead of O(n).

### Stack (LIFO — Last In, First Out)

A stack works like a stack of plates — you can only add or remove from the **top**. The last element added is the first one removed.

```text
    Push "C" →  [C]  ← Top (last in, first out)
                [B]
                [A]  ← Bottom (first in, last out)
    
    Pop → removes "C"
```

| Operation | Time |
|-----------|------|
| Push (add to top) | O(1) |
| Pop (remove from top) | O(1) |
| Peek (look at top) | O(1) |

**Where you encounter stacks:**

- **Function call stack** — when function A calls function B, A is pushed on the stack. When B returns, A is popped and continues
- **Undo operations** — each action is pushed on the stack, undo pops the last one
- **Expression parsing** — compilers use stacks to evaluate `(3 + 4) * (2 - 1)`
- **Browser back button** — history is a stack

```php
// Stack in PHP using SplStack
$stack = new SplStack();
$stack->push('action1: create user');
$stack->push('action2: update email');
$stack->push('action3: change role');

// Undo last action
$lastAction = $stack->pop();  // "action3: change role"
echo "Undoing: $lastAction\n";

// PHP function call stack — you see it in exceptions
// Exception trace:
//   #0 App\Service\UserService->register()
//   #1 App\Controller\UserController->create()
//   #2 Symfony\Component\HttpKernel->handle()
```

### Queue (FIFO — First In, First Out)

A queue works like a line at a shop — the first person in line is the first one served. Elements are added at the **back** and removed from the **front**.

```text
    Enqueue "C" →  [A] [B] [C]
                    ↑           ↑
                  Front        Back
    
    Dequeue → removes "A" (first in, first out)
```

| Operation | Time |
|-----------|------|
| Enqueue (add to back) | O(1) |
| Dequeue (remove from front) | O(1) |
| Peek (look at front) | O(1) |

**Where you encounter queues — this is critical for backend developers:**

- **RabbitMQ** — message broker that processes jobs in order
- **Redis lists** — `LPUSH` + `RPOP` creates a queue
- **Symfony Messenger** — dispatches messages to a queue for async processing
- **Background job processing** — email sending, PDF generation, image resizing

```php
// PHP SplQueue
$queue = new SplQueue();
$queue->enqueue('job1: send welcome email');
$queue->enqueue('job2: generate invoice');
$queue->enqueue('job3: resize avatar');

// Process jobs in order (FIFO)
while (!$queue->isEmpty()) {
    $job = $queue->dequeue();
    echo "Processing: $job\n";
}
// Output: job1, job2, job3 — in the order they were added
```

### Queue in Real Backend Systems

Queues are fundamental to backend systems. When your web application needs to do something slow (send email, generate PDF, call external API), you put a message on a queue and a **worker** processes it later.

```php
// Symfony Messenger — fire and forget
class OrderController extends AbstractController
{
    #[Route('/orders', methods: ['POST'])]
    public function create(Request $request, MessageBusInterface $bus): JsonResponse
    {
        $order = $this->orderService->create($request->toArray());
        
        // Put message on queue — returns immediately
        $bus->dispatch(new SendOrderConfirmationEmail($order->getId()));
        $bus->dispatch(new GenerateInvoicePdf($order->getId()));
        $bus->dispatch(new NotifyWarehouse($order->getId()));
        
        return $this->json(['orderId' => $order->getId()], 201);
        // User gets response in 50ms instead of waiting for email+PDF+API
    }
}
```

```bash
# Redis queue — RabbitMQ alternative
# Producer (your PHP app):
LPUSH order_queue '{"orderId": 123, "action": "send_email"}'
LPUSH order_queue '{"orderId": 124, "action": "generate_pdf"}'

# Consumer (worker process):
RPOP order_queue  # Gets the first message added (FIFO)
```

### Comparison Table

| Structure | Access | Search | Insert | Delete | Use case |
|-----------|--------|--------|--------|--------|----------|
| Hash Table | O(1) by key | O(n) by value | O(1) | O(1) | Config, cache, lookup tables |
| Linked List | O(n) | O(n) | O(1) at ends | O(1) if found | Insertion-heavy workloads |
| Binary Search Tree | O(log n) | O(log n) | O(log n) | O(log n) | Database indexes, sorted data |
| Stack | O(1) top only | O(n) | O(1) | O(1) | Undo, call stack, parsing |
| Queue | O(1) front only | O(n) | O(1) | O(1) | Job processing, message brokers |

### Conclusion

As a backend developer, you work with these data structures every day — PHP arrays are hash tables, MySQL indexes are B-Trees, RabbitMQ and Symfony Messenger use queues, and the function call stack is a stack. Understanding their time complexity helps you choose the right tool: use hash maps for fast key-based lookups, queues for async job processing, and be aware that `in_array()` is O(n) while `isset()` is O(1). In interviews, focus on when to use each structure and their real-world applications rather than memorizing implementation details.

> See also: [PHP arrays internals](../php/php_arrays_internals.md), [Redis basics](../caching/redis_basics.md), [How internet works](how_internet_works.md)
