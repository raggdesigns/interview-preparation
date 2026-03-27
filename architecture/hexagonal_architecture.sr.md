Heksagonalna arhitektura, poznata i kao Ports and Adapters arhitektura, je dizajn pattern koji za cilj ima da dizajn aplikacije vodi iznutra prema spolja, fokusirajući se na osnovnu logiku aplikacije i minimizujući sprezanje između aplikacije i spoljnih agenata kao što su baze podataka, web servisi ili korisnička sučelja. Primarni cilj je da osnovna funkcionalnost aplikacije ostane nepromenjena bez obzira na izmene u spoljnim servisima ili zahtevima klijenata.

### Osnovni koncepti Heksagonalne arhitekture:

- **Ports**: Interfejsi koji definišu kako spoljni agenti mogu komunicirati sa aplikacijom. Ports se mogu kategorisati u primarne (pokretane od strane aplikacije) i sekundarne (koji pokreću aplikaciju) portove.
- **Adapters**: Implementacije koje povezuju spoljne agente (baze podataka, web servise, UI, itd.) sa aplikacijom putem portova. Adapters prevode spoljne pozive u pozive portova aplikacije.
- **Jezgro aplikacije**: Sadrži poslovnu logiku i modele aplikacije. Okruženo je portovima i adapterima, otuda i metafora "heksagonalne" arhitekture, što implicira da se jezgro može lako povezati sa različitim spoljnim komponentama bez modifikacije.

### Prednosti:

- **Razdvajanje**: Jezgro aplikacije je odvojeno od spoljnih briga, što olakšava modifikaciju ili zamenu spoljnih komponenti (baza podataka, UI framework-a, itd.) bez uticaja na osnovnu poslovnu logiku.
- **Testabilnost**: Osnovna aplikacija može biti testirana nezavisno od spoljnih servisa i klijenata korišćenjem test adaptera.
- **Fleksibilnost**: Nove funkcionalnosti mogu biti dodate kao spoljne komponente bez promene jezgra aplikacije, promovisanjem proširivosti i skalabilnosti.

### Primer u PHP-u

Ilustrujmo Heksagonalnu arhitekturu jednostavnom aplikacijom koja kreira korisničke naloge i obaveštava korisnika putem emaila.

**Jezgro aplikacije**:

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

**Adapters** (implementacija sekundarnih portova):

```php
class SqlUserRepository implements UserRepository {
    // Implementation using SQL database
}

class EmailNotificationService implements NotificationService {
    // Implementation using email service
}
```

**Primarni port** (Use Case pokrenut od strane spoljnog agenta, npr. Web Controller-a):

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

U ovom primeru, klasa `CreateUserUseCase` u jezgru aplikacije definiše primarnu poslovnu logiku. Klase `SqlUserRepository` i `EmailNotificationService` deluju kao adapteri za sekundarne portove, omogućavajući spoljnim servisima da budu priključeni na jezgro aplikacije. `UserController` služi kao ulazna tačka u aplikaciju, prevodeći web zahteve u akcije koje izvršava use case.

### Zaključak

Heksagonalna arhitektura nudi moćan način organizacije koda aplikacije, naglašavajući razdvajanje nadležnosti, testabilnost i fleksibilnost. Izolacijom jezgra aplikacije od spoljnih tehnologija i mehanizama isporuke, olakšava dugoročnu održivost i prilagodljivost sistema.
