The Adapter pattern is a structural design pattern that allows objects with incompatible interfaces to collaborate. It
works by creating a bridge between two incompatible interfaces, enabling them to work together without altering their
existing code. This pattern is especially useful in systems where new components need to be integrated and work together
with existing code without any modifications to the existing components.

### Key Concepts of the Adapter Pattern

- **Target Interface**: This is the interface that the client expects or uses.
- **Adaptee**: The class that has the incompatible interface, which needs to be adapted to work with the client code.
- **Adapter**: The class that implements the Target interface and encapsulates an instance of the Adaptee class. It
  translates calls from the Target interface into a form that the Adaptee can understand.

### Benefits

- **Compatibility**: Allows otherwise incompatible classes to work together.
- **Reusability**: Enables the reuse of existing code, even if it does not match the required interfaces.
- **Flexibility**: Introduces only a minimal level of indirection to the system, adding flexibility without significant
  overhead.

### Example in PHP

Imagine a logging system where the new client code uses a Logger interface, but there's an existing class `FileLogger`
that doesn't implement this interface.

```php
// Target Interface
interface Logger {
    public function log($message);
}

// Adaptee
class FileLogger {
    public function writeToFile($message) {
        echo "Logging to a file: $message\\n";
    }
}

// Adapter
class FileLoggerAdapter implements Logger {
    protected $fileLogger;

    public function __construct(FileLogger $fileLogger) {
        $this->fileLogger = $fileLogger;
    }

    public function log($message) {
        $this->fileLogger->writeToFile($message);
    }
}

// Client code
$fileLogger = new FileLogger();
$logger = new FileLoggerAdapter($fileLogger);
$logger->log("Hello, world!");
```

In this example, `FileLogger` is the Adaptee class that doesn't fit the `Logger` interface expected by the
client. `FileLoggerAdapter` is the Adapter that implements the `Logger` interface and translates its `log` method call
into a `writeToFile` call on the encapsulated `FileLogger` instance. This way, the existing `FileLogger` class can be
used in contexts where a `Logger` interface is expected, without changing its code.

The Adapter pattern provides a flexible solution to interface compatibility issues, enabling smooth integration and
communication between components of a system.
