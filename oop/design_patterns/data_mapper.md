The Data Mapper pattern is an architectural design pattern that promotes the separation of the in-memory object
representation from the database's persistence layer. Rather than having an object carry both its own data and the logic
to load or save that data to a database, the Data Mapper pattern uses a separate mapper class to move data between
objects and the database while keeping them independent of each other.

### Key Concepts of the Data Mapper Pattern:

- **Domain Model**: These are the application's business objects, which should be agnostic of the database details.
- **Data Mapper**: A layer responsible for transferring data between the database and the objects (Domain Model).
  Mappers query the database and translate the data from the database rows to objects and vice versa.
- **Data Source Layer**: The layer where the database resides. This layer is interacted with by the Data Mapper rather
  than the Domain Model directly.

### Benefits:

- **Separation of Concerns**: Keeps the domain model and persistence logic decoupled, leading to cleaner, more
  maintainable code.
- **Flexibility**: Allows the domain model to evolve independently of the database schema, and vice versa.
- **Reusability**: The mapping logic can be reused across different parts of the application.

### Example in PHP:

Consider a simple scenario with a `User` domain model and a corresponding `UserMapper` to handle database operations.

```php
class User {
    private $id;
    private $username;

    public function __construct($id, $username) {
        $this->id = $id;
        $this->username = $username;
    }

    // Getter and setter methods
    public function getId() {
        return $this->id;
    }

    public function getUsername() {
        return $this->username;
    }
}

class UserMapper {
    protected $database;

    public function __construct(PDO $database) {
        $this->database = $database;
    }

    public function findById($id) {
        $stmt = $this->database->prepare("SELECT * FROM users WHERE id = ?");
        $stmt->execute([$id]);
        $row = $stmt->fetch();

        if ($row) {
            return new User($row['id'], $row['username']);
        }

        return null;
    }

    // Other data mapping methods like save, update, delete...
}
```

### Usage:

```php
// Assuming $pdo is a previously configured PDO object
$userMapper = new UserMapper($pdo);
$user = $userMapper->findById(1);

if ($user) {
    echo "User Found: " . $user->getUsername();
} else {
    echo "User not found.";
}
```

In this example, `User` is a simple domain model representing a user, and `UserMapper` contains the logic to map between
the `User` objects and the database records. The `findById` method demonstrates how to retrieve a user from the database
