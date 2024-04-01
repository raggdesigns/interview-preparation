Inversion of Control (IoC) is a design principle which inverts the flow of control of the program. Instead of the custom code calling reusable libraries, the framework calls the custom code. This helps in decoupling the execution of a task from its implementation, making it easier to switch between different implementations and manage dependencies.

### Types of IoC:

- **Dependency Injection**: Objects are given their dependencies at creation time by some external entity that coordinates each object in the system.
- **Event-Driven**: Custom code is executed in response to specific lifecycle events or operations within the application framework.
- **Template Methods**: Design pattern where step implementation is inverted such that the superclass method calls methods in the subclass rather than the other way around.

### Benefits:

- **Decoupling**: IoC decouples the execution of a task from its implementation.
- **Flexibility**: Makes it easier to change the behavior of the program by changing the components.
- **Testability**: Enhances testability through easier mocking of components.

### Example in PHP (Dependency Injection):

```php
interface MessageService {
    public function sendMessage($message, $recipient);
}

class EmailService implements MessageService {
    public function sendMessage($message, $recipient) {
        // Send an email
    }
}

class Notification {
    private $messageService;

    public function __construct(MessageService $messageService) {
        $this->messageService = $messageService;
    }

    public function notify($message, $recipient) {
        $this->messageService->sendMessage($message, $recipient);
    }
}

$emailService = new EmailService();
$notification = new Notification($emailService);
```

Here, `Notification` does not need to know the details of how messages are sent, demonstrating IoC through Dependency Injection.
