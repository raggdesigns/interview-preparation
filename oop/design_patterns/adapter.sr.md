Adapter obrazac je strukturalni dizajnerski obrazac koji omogućava objektima sa nekompatibilnim interfejsima da sarađuju. Funkcioniše kreiranjem mosta između dva nekompatibilna interfejsa, omogućavajući im da rade zajedno bez menjanja njihovog postojećeg koda. Ovaj obrazac je posebno koristan u sistemima gde nove komponente treba integrisati i raditi zajedno sa postojećim kodom bez ikakvih modifikacija postojećih komponenti.

### Ključni koncepti Adapter obrasca

- **Ciljni interfejs (Target Interface)**: Ovo je interfejs koji klijent očekuje ili koristi.
- **Adaptee**: Klasa koja ima nekompatibilan interfejs, koji treba prilagoditi za rad sa klijentskim kodom.
- **Adapter**: Klasa koja implementira ciljni interfejs i enkapsulira instancu Adaptee klase. Prevodi pozive sa ciljnog interfejsa u oblik koji Adaptee može razumeti.

### Prednosti

- **Kompatibilnost**: Dozvoljava inače nekompatibilnim klasama da rade zajedno.
- **Ponovna upotrebljivost**: Omogućava ponovnu upotrebu postojećeg koda, čak i ako ne odgovara traženim interfejsima.
- **Fleksibilnost**: Uvodi samo minimalni nivo indirekcije u sistem, dodajući fleksibilnost bez značajnog opterećenja.

### Primer u PHP-u

Zamislite sistem logovanja gde novi klijentski kod koristi `Logger` interfejs, ali postoji klasa `FileLogger` koja ne implementira ovaj interfejs.

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

U ovom primeru, `FileLogger` je Adaptee klasa koja ne odgovara `Logger` interfejsu koji klijent očekuje. `FileLoggerAdapter` je Adapter koji implementira `Logger` interfejs i prevodi poziv `log` metode u poziv `writeToFile` na enkapsuliranoj `FileLogger` instanci. Na ovaj način, postojeća `FileLogger` klasa može se koristiti u kontekstima gde se očekuje `Logger` interfejs, bez menjanja njenog koda.

Adapter obrazac pruža fleksibilno rešenje za probleme kompatibilnosti interfejsa, omogućavajući glatku integraciju i komunikaciju između komponenti sistema.
