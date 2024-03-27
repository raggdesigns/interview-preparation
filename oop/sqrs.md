# What is CQRS

Command Query Responsibility Segregation (CQRS) is a design pattern that separates the modification of data (command) from the reading of data (query), using separate interfaces for each operation. This approach is an elaboration on the principle of Command Query Separation (CQS) and aims to ensure that methods are either responsible for changing the state of an object, without returning any data, or for querying the state of an object, without changing it.

## Key Concepts

- **Commands**: Operations that alter the state of a system but do not return data. Commands represent the intention to change the state of an application's domain.

- **Queries**: Operations that return data without changing the state of the system. Queries typically involve reading data from a datastore.

- **Separation of Models**: CQRS often involves using separate models for reads and writes. The write model handles commands, and the read model handles queries.

- **Event Sourcing**: While not required, CQRS is frequently used together with event sourcing, where changes to the application state are stored as a sequence of events.

## Benefits of CQRS

- **Simplified Complex Applications**: By separating commands and queries, developers can more easily understand and work with the distinct aspects of an application's data operations.

- **Scalability**: Separate read and write models allow for each to be scaled independently based on the system's needs.

- **Optimization**: Different storage and retrieval mechanisms can be optimized for either commands or queries, improving performance and efficiency.

- **Improved Security**: Fine-grained control over read and write operations can enhance security measures, allowing for more precise permissions and access controls.

## Challenges

- **Increased Complexity**: Introducing CQRS can increase the complexity of the system, requiring careful design and consideration to implement effectively.

- **Consistency**: Maintaining consistency between the read and write models, especially in systems where immediate consistency is required, can be challenging.

- **Development Overhead**: There may be a greater development overhead in maintaining separate models and the infrastructure to support them.

- **Learning Curve**: Developers new to CQRS and associated patterns like event sourcing may face a learning curve.

### Violating CQRS

Initially, let's consider a class that combines both command (write) and query (read) operations, which violates the CQRS principle:

```php
class UserAccount {
    private $users = [];

    // This method combines command (adding a user) and query (returning user details) operations, violating CQRS
    public function createUser($userName) {
        $userId = uniqid();
        $this->users[$userId] = $userName;

        // Command operation above, query operation below
        return $this->getUser($userId);
    }

    // Query operation: Retrieves user details
    public function getUser($userId) {
        return isset($this->users[$userId]) ? $this->users[$userId] : null;
    }
}
```

In this example, the `createUser` method performs both a command operation (adding a user to the `users` array) and a query operation (returning the newly added user's details), mixing command and query responsibilities in a single method.

### Correctly Applying CQRS

To adhere to CQRS, we separate the command and query responsibilities into different methods or even different classes. Here's how you could refactor the above example to apply CQRS correctly:

```php
// Command class responsible for user creation (write operations)
class UserCommandService {
    private $users = [];

    public function createUser($userName) {
        $userId = uniqid();
        $this->users[$userId] = $userName;
        // Command operation only: modifies state but does not return data
    }
    
    // Method to access the users array for synchronization purposes
    public function getUsers() {
        return $this->users;
    }
}

// Query class responsible for fetching user details (read operations)
class UserQueryService {
    private $users = [];

    public function __construct($users) {
        $this->users = $users;
    }

    public function getUser($userId) {
        // Query operation only: returns data but does not modify state
        return isset($this->users[$userId]) ? $this->users[$userId] : null;
    }
}
```

In the refactored example:

- The `UserCommandService` class handles the command operation of creating a user. It is responsible for write operations and does not return any data, adhering to the command part of CQRS.
- The `UserQueryService` class handles the query operation. It is initialized with the user data (potentially passed from `UserCommandService`), and it only performs read operations, adhering to the query part of CQRS.
- This separation ensures that command and query responsibilities are clearly divided, following the CQRS principle. The system becomes more maintainable, and each part can be optimized independently for its specific role.

By applying CQRS in this way, you enhance the separation of concerns, scalability, and flexibility of your application, allowing for more efficient handling of different operations.
