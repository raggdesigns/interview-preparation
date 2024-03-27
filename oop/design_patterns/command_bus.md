The Command Bus pattern is a design pattern used in software architecture to decouple the sender of a command from its
executor. It acts as a middleware that takes a command object, which represents an action or change to the system, and
routes it to the appropriate handler. The handler then executes the intended action. This pattern is especially useful
in complex applications with a large number of operations or in scenarios where operations need to be executed in a
specific way, such as asynchronously or on a different thread.

### Key Concepts of the Command Bus Pattern:

- **Command**: A plain object that represents an instruction to perform a specific action. It contains all the necessary
  information for the action to be executed.
- **Command Bus**: The mechanism that receives commands and delegates them to the correct handler. It acts as a single
  entry point for executing commands.
- **Command Handler**: A service that performs the operation encapsulated by the command. Each type of command has its
  own handler.

### Benefits:

- **Decoupling**: The sender of a command is decoupled from the receiver that executes the command, enhancing modularity
  and maintainability.
- **Flexibility**: New commands and handlers can be easily added without changing the existing command bus or other
  handlers.
- **Ease of Testing**: Components can be tested independently. Commands and handlers can be easily mocked or stubbed in
  tests.
- **Organization**: Centralizes the execution of commands, making the system's operations easier to understand and
  manage.

### Example in PHP:

Let's consider a simple example where a command bus is used to execute a user registration command.

```php
// Command
class RegisterUserCommand {
    public $username;
    public $email;

    public function __construct($username, $email) {
        $this->username = $username;
        $this->email = $email;
    }
}

// Command Handler
class RegisterUserHandler {
    public function handle(RegisterUserCommand $command) {
        // Logic to register the user
        echo "Registering user: " . $command->username;
    }
}

// Command Bus
class CommandBus {
    protected $handlers = [];

    public function registerHandler($commandType, $handler) {
        $this->handlers[$commandType] = $handler;
    }

    public function handle($command) {
        $commandType = get_class($command);
        if (!isset($this->handlers[$commandType])) {
            throw new Exception("No handler registered for command: " . $commandType);
        }
        $handler = $this->handlers[$commandType];
        $handler->handle($command);
    }
}
```

### Usage:

```php
$commandBus = new CommandBus();
$handler = new RegisterUserHandler();

// Registering the handler with the command type it should handle
$commandBus->registerHandler(RegisterUserCommand::class, $handler);

// Creating a new command
$command = new RegisterUserCommand("JohnDoe", "john@example.com");

// Handling the command
$commandBus->handle($command);
// Outputs: Registering user: JohnDoe
```

In this example, `CommandBus` serves as the central point through which commands are sent and handled.
The `RegisterUserCommand` is a command object that contains data related to user registration. The `RegisterUserHandler`
is responsible for handling this command. By using the command bus, we effectively decouple the code that issues the
command from the code that executes it, following the Command Bus pattern.
