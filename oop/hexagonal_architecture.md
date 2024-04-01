Hexagonal Architecture, also known as Ports and Adapters Architecture, is a design pattern that aims to drive an
application's design from the inside out, focusing on the application's core logic and minimizing the coupling between
the application and external agents such as databases, web services, or user interfaces. The primary goal is to allow
the application's core functionality to be unaffected by changes in external services or client requirements.

### Core Concepts of Hexagonal Architecture:

- **Ports**: Interfaces that define how external agents can communicate with the application. Ports can be categorized
  into primary (driven by the application) and secondary (driving the application) ports.
- **Adapters**: Implementations that connect external agents (databases, web services, UI, etc.) to the application
  through ports. Adapters translate external calls into calls to the application's ports.
- **Application Core**: Contains the business logic and models of the application. It is surrounded by ports and
  adapters, hence the "hexagonal" metaphor, implying that the core can easily be connected to different external
  components without modification.

### Benefits:

- **Decoupling**: The application core is decoupled from external concerns, making it easier to modify or replace
  external components (databases, UI frameworks, etc.) without affecting the core business logic.
- **Testability**: The core application can be tested independently of external services and clients by using test
  adapters.
- **Flexibility**: New functionalities can be added as external components without changing the application core,
  promoting extensibility and scalability.

### Example in PHP

Let's illustrate the Hexagonal Architecture with a simple application that creates user accounts and notifies the user
via email.

**Application Core**:

```php
interface UserRepository {
    public function addUser($user);
}

interface NotificationService {
    public function notify($user, $message);
}

class CreateUserUseCase {
    private $userRepository;
    private $notificationService;

    public function __construct(UserRepository $userRepository, NotificationService $notificationService) {
        $this->userRepository = $userRepository;
        $this->notificationService = $notificationService;
    }

    public function createUser($userData) {
        // Logic to create user
        $this->userRepository->addUser($userData);
        $this->notificationService->notify($userData, 'Account created successfully');
    }
}
```

**Adapters** (Secondary ports implementation):

```php
class SqlUserRepository implements UserRepository {
    // Implementation using SQL database
}

class EmailNotificationService implements NotificationService {
    // Implementation using email service
}
```

**Primary Port** (Use Case initiated by an external agent, e.g., Web Controller):

```php
// Assuming a web framework
class UserController {
    private $createUserUseCase;

    public function __construct(CreateUserUseCase $createUserUseCase) {
        $this->createUserUseCase = $createUserUseCase;
    }

    public function createUser($request) {
        // Extract user data from request
        $this->createUserUseCase->createUser($userData);
    }
}
```

In this example, the `CreateUserUseCase` class in the application core defines the primary business logic.
The `SqlUserRepository` and `EmailNotificationService` classes act as adapters for the secondary ports, allowing
external services to be plugged into the application core. The `UserController` serves as an entry point to the
application, translating web requests into actions performed by the use case.

### Conclusion

Hexagonal Architecture offers a powerful way to organize application code, emphasizing separation of concerns,
testability, and flexibility. By isolating the application core from external technologies and delivery mechanisms, it
facilitates long-term maintainability and adaptability of the system.
