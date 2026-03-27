Command Bus obrazac je dizajnerski obrazac koji se koristi u softverskoj arhitekturi za odvajanje pošiljaoca komande od njenog izvršavaoca. Deluje kao međusoftver koji uzima objekat komande, koji predstavlja akciju ili promenu sistema, i usmerava je odgovarajućem upravljaču. Upravljač zatim izvršava nameravanu akciju. Ovaj obrazac je posebno koristan u složenim aplikacijama sa velikim brojem operacija ili u scenarijima gde operacije treba izvršiti na poseban način, kao što je asinhrono ili na drugoj niti.

### Ključni koncepti Command Bus obrasca

- **Komanda (Command)**: Objekat koji predstavlja instrukciju za izvođenje specifične akcije. Sadrži sve neophodne informacije za izvođenje akcije.
- **Command Bus**: Mehanizam koji prima komande i delegira ih ispravnom upravljaču. Deluje kao jedinstven ulaz za izvršavanje komandi.
- **Upravljač komandom (Command Handler)**: Servis koji izvodi operaciju enkapsuliranu komandom. Svaki tip komande ima sopstveni upravljač.

### Prednosti

- **Odvajanje**: Pošiljalac komande je odvojen od primaoca koji izvršava komandu, poboljšavajući modularnost i održivost.
- **Fleksibilnost**: Nove komande i upravljači se mogu lako dodati bez menjanja postojećeg Command Bus-a ili ostalih upravljača.
- **Lakoća testiranja**: Komponente se mogu testirati nezavisno. Komande i upravljači se mogu lako zamenjivati ili imitirati u testovima.
- **Organizacija**: Centralizuje izvršavanje komandi, čineći operacije sistema lakšim za razumevanje i upravljanje.

### Primer u PHP-u

Razmotrimo jednostavan primer gde se Command Bus koristi za izvršavanje komande registracije korisnika.

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

### Upotreba

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

U ovom primeru, `CommandBus` služi kao centralna tačka kroz koju se komande šalju i obrađuju. `RegisterUserCommand` je objekat komande koji sadrži podatke vezane za registraciju korisnika. `RegisterUserHandler` je odgovoran za obradu ove komande. Korišćenjem Command Bus-a, efikasno odvajamo kod koji izdaje komandu od koda koji je izvršava, prateći Command Bus obrazac.
