Onion Architecture is a software architecture pattern that aims to maintain the core of an application (domain model and
business logic) independent of infrastructure and technical details. It emphasizes the separation of concerns by
layering the application such that external dependencies (like databases and frameworks) do not influence the core code.

### Core Concepts of Onion Architecture

- **Core Domain**: At the center of the architecture, containing the domain model and business rules.
- **Application Layer**: Surrounds the domain layer, containing application logic and defines how domain objects are
  used. It orchestrates the flow of data to and from the domain and might also implement the interfaces defined in the
  domain layer.
- **Domain Services**: Encapsulate business logic that doesn't naturally fit within a domain object, and are placed
  within the core or application layers depending on their dependencies.
- **Infrastructure Layer**: The outermost layer, containing code that communicates with external systems (databases,
  third-party services, UI). This layer implements interfaces defined in the application layer.

### Principles

- **Dependency Inversion**: Inner layers define interfaces that outer layers implement, inverting traditional dependency
  management.
- **Separation of Concerns**: Different aspects of the application are physically separated into different layers.
- **Core Independence**: The application core remains independent of frameworks and databases, facilitating easier
  testing and maintenance.

### Benefits

- **Flexibility**: By decoupling the application core from infrastructure concerns, it becomes easier to change or
  replace external components without affecting the core logic.
- **Maintainability**: A well-organized codebase, where concerns are separated cleanly, is easier to understand and
  maintain.
- **Testability**: The domain model and business logic can be tested without the need for external dependencies like a
  database.

### Example in PHP

Imagine an application with a simple use-case: retrieving user information and sending a notification.

**Domain Layer** (Core):

```php
interface UserRepository {
    public function findUserById($id);
}

class User {
    private $id;
    private $name;
    // Getter methods
}
```

**Application Layer**:

```php
class UserService {
    private $userRepository;
    private $notificationService;

    public function __construct(UserRepository $userRepository, NotificationService $notificationService) {
        $this->userRepository = $userRepository;
        $this->notificationService = $notificationService;
    }

    public function notifyUser($userId, $message) {
        $user = $this->userRepository->findUserById($userId);
        $this->notificationService->send($user, $message);
    }
}
```

**Infrastructure Layer**:

```php
class SqlUserRepository implements UserRepository {
    // Implementation using a database
}

class EmailNotificationService implements NotificationService {
    // Implementation sending emails
}
```

In this example, the `UserService` in the application layer coordinates between the domain and infrastructure, fetching
a user and sending a notification without being tightly coupled to the database or the specifics of the notification
delivery method.

### Conclusion

Onion Architecture offers a comprehensive approach to building applications with maintainability, flexibility, and
portability in mind. By keeping the domain model and business logic at the center of your design, shielded from external
changes and technologies, you can create a robust and scalable application.
