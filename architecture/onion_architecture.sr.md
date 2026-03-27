Onion arhitektura je pattern softverske arhitekture koji za cilj ima da jezgro aplikacije (domenski model i poslovna logika) drži nezavisnim od infrastrukture i tehničkih detalja. Naglašava razdvajanje nadležnosti slojevitim pristupom aplikaciji tako da spoljne zavisnosti (poput baza podataka i framework-a) ne utiču na osnovni kod.

### Osnovni koncepti Onion arhitekture:

- **Osnovna domena**: U centru arhitekture, sadrži domenski model i poslovna pravila.
- **Aplikacioni sloj**: Okružuje domenski sloj, sadrži aplikacionu logiku i definiše kako se domenski objekti koriste. Koordinira tok podataka do i od domene i može takođe implementirati interfejse definisane u domenskom sloju.
- **Domenski servisi**: Enkapsuliraju poslovnu logiku koja se prirodno ne uklapa u domenski objekat, i smešteni su u osnovne ili aplikacione slojeve u zavisnosti od njihovih zavisnosti.
- **Infrastrukturni sloj**: Najspoljniji sloj, sadrži kod koji komunicira sa spoljnim sistemima (bazama podataka, servisima trećih strana, UI). Ovaj sloj implementira interfejse definisane u aplikacionom sloju.

### Principi:

- **Inverzija zavisnosti**: Unutrašnji slojevi definišu interfejse koje spoljni slojevi implementiraju, invertirajući tradicionalno upravljanje zavisnostima.
- **Razdvajanje nadležnosti**: Različiti aspekti aplikacije su fizički odvojeni u različite slojeve.
- **Nezavisnost jezgra**: Jezgro aplikacije ostaje nezavisno od framework-a i baza podataka, olakšavajući testiranje i održavanje.

### Prednosti:

- **Fleksibilnost**: Odvajanjem jezgra aplikacije od infrastrukturnih briga, postaje lakše menjati ili zamenjivati spoljne komponente bez uticaja na osnovnu logiku.
- **Održivost**: Dobro organizovana baza koda, gde su nadležnosti čisto odvojene, lakša je za razumevanje i održavanje.
- **Testabilnost**: Domenski model i poslovna logika mogu biti testirani bez potrebe za spoljnim zavisnostima poput baze podataka.

### Primer u PHP-u

Zamislite aplikaciju sa jednostavnim use case-om: preuzimanje informacija o korisniku i slanje obaveštenja.

**Domenski sloj** (Jezgro):

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

**Aplikacioni sloj**:

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

**Infrastrukturni sloj**:

```php
class SqlUserRepository implements UserRepository {
    // Implementation using a database
}

class EmailNotificationService implements NotificationService {
    // Implementation sending emails
}
```

U ovom primeru, `UserService` u aplikacionom sloju koordinira između domene i infrastrukture, preuzimajući korisnika i šaljući obaveštenje bez čvrstog sprezanja sa bazom podataka ili specifičnostima metode isporuke obaveštenja.

### Zaključak

Onion arhitektura nudi sveobuhvatan pristup izgradnji aplikacija sa fokusom na održivost, fleksibilnost i prenosivost. Čuvanjem domenskog modela i poslovne logike u centru vašeg dizajna, zaštićenih od spoljnih promena i tehnologija, možete kreirati robusnu i skalabilnu aplikaciju.
