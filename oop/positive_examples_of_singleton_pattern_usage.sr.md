### Pozitivni primeri upotrebe Singleton obrasca

Singleton obrazac je dizajnerski obrazac koji ograničava instanciranje klase na jednu "jedinu" instancu. Ovo je korisno kada je tačno jedan objekat potreban za koordinaciju akcija kroz sistem. Uprkos nekim kritikama, uglavnom zbog potencijala za uvođenje globalnog stanja u aplikaciju, postoje scenariji u kojima Singleton obrazac može biti od koristi:

### 1. Upravljanje konfiguracijom

Singleton objekti mogu biti odličan način za upravljanje konfiguracijama aplikacije. Korišćenjem Singleton-a, osiguravate da se konfiguracioni podaci učitavaju samo jednom i da su globalno dostupni, održavajući konzistentnost kroz aplikaciju.

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

### 2. Logovanje

Za svrhe logovanja, korišćenje Singleton-a može osigurati da se jedna datoteka dnevnika ili instanca servisa za logovanje koristi kroz celu aplikaciju, pojednostavljujući upravljanje dnevnikom i izbegavajući probleme sa konfliktima pristupa datotekama ili duplikovanim unosima dnevnika.

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

### 3. Konekcije sa bazom podataka

Singleton objekti se mogu koristiti za upravljanje konekcijama sa bazom podataka, osiguravajući da je samo jedna konekcija aktivna u bilo kom trenutku. Ovo može biti posebno korisno za izbegavanje troška otvaranja i zatvaranja više konekcija tokom životnog ciklusa aplikacije.

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

### Ključne napomene

Iako je Singleton obrazac koristan u određenim scenarijima, važno je koristiti ga promišljeno. Prekomerna upotreba može dovesti do problema vezanih za upravljanje globalnim stanjem i teškoća u testiranju. Međutim, za upravljanje resursima kao što su konfiguracije, logovanje i konekcije sa bazom podataka, gde logički jedna instanca dovoljna, Singleton može pružiti jednostavno i efikasno rešenje.
