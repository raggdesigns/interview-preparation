### Positive Examples of Singleton Pattern Usage

The Singleton pattern is a design pattern that restricts the instantiation of a class to one "single" instance. This is
useful when exactly one object is needed to coordinate actions across the system. Despite some criticism, mainly due to
its potential to introduce global state in an application, there are scenarios where the Singleton pattern can be
beneficial:

### 1. Configuration Management

Singletons can be an excellent way to manage application configurations. By using a Singleton, you ensure that
configuration data is loaded only once and is accessible globally, maintaining consistency across the application.

```php
class Config {
    private static $instance = null;
    private $settings = [];

    private function __construct() {
        // Load configuration settings from a file or environment
        $this->settings = ['db_host' => 'localhost', 'db_name' => 'test'];
    }

    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new Config();
        }
        return self::$instance;
    }

    public function getSetting($key) {
        return $this->settings[$key] ?? null;
    }
}

// Usage
$config = Config::getInstance();
$dbHost = $config->getSetting('db_host');
```

### 2. Logging

For logging purposes, using a Singleton can ensure that a single log file or logging service instance is used throughout
the application, simplifying log management and avoiding issues with file access conflicts or duplicated log entries.

```php
class Logger {
    private static $instance = null;
    private $logfile;

    private function __construct() {
        $this->logfile = fopen('app.log', 'a');
    }

    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new Logger();
        }
        return self::$instance;
    }

    public function log($message) {
        fwrite($this->logfile, $message . PHP_EOL);
    }

    public function __destruct() {
        fclose($this->logfile);
    }
}

// Usage
$logger = Logger::getInstance();
$logger->log("Application started");
```

### 3. Database Connections

Singletons can be used to manage database connections, ensuring that only one connection is active at any given time.
This can be particularly useful to avoid the overhead of opening and closing multiple connections during the lifecycle
of an application.

```php
class Database {
    private static $instance = null;
    private $connection;

    private function __construct() {
        $this->connection = new PDO('mysql:host=localhost;dbname=test', 'user', 'password');
    }

    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new Database();
        }
        return self::$instance;
    }

    public function getConnection() {
        return $this->connection;
    }
}

// Usage
$db = Database::getInstance();
$connection = $db->getConnection();
```

### Key Takeaways

While the Singleton pattern is useful in certain scenarios, it's important to use it judiciously. Overuse can lead to
issues related to global state management and testing difficulties. However, for managing resources like configurations,
logging, and database connections, where a single instance logically suffices, Singletons can provide a straightforward
and effective solution.
