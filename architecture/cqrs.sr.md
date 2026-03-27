# Šta je CQRS

Command Query Responsibility Segregation (CQRS) je dizajn pattern koji razdvaja modifikaciju podataka (komanda) od čitanja podataka (upit), koristeći odvojena sučelja za svaku operaciju. Ovaj pristup je razrada principa Command Query Separation (CQS) i za cilj ima da obezbedi da metode budu odgovorne ili za promenu stanja objekta, bez vraćanja podataka, ili za upitivanje stanja objekta, bez promene tog stanja.

## Ključni koncepti

- **Komande**: Operacije koje menjaju stanje sistema, ali ne vraćaju podatke. Komande predstavljaju nameru da se promeni stanje domene aplikacije.

- **Upiti**: Operacije koje vraćaju podatke bez promene stanja sistema. Upiti obično uključuju čitanje podataka iz skladišta.

- **Razdvajanje modela**: CQRS često podrazumeva korišćenje odvojenih modela za čitanje i pisanje. Model za pisanje obrađuje komande, a model za čitanje obrađuje upite.

- **Event Sourcing**: Iako nije obavezan, CQRS se često koristi zajedno sa event sourcing-om, gde se promene stanja aplikacije čuvaju kao niz događaja.

## Prednosti CQRS

- **Pojednostavljivanje složenih aplikacija**: Razdvajanjem komandi i upita, programerima je lakše da razumeju i rade sa različitim aspektima operacija nad podacima aplikacije.

- **Skalabilnost**: Odvojeni modeli za čitanje i pisanje omogućavaju da se svaki od njih skalira nezavisno, prema potrebama sistema.

- **Optimizacija**: Različiti mehanizmi za skladištenje i preuzimanje podataka mogu biti optimizovani za komande ili upite, čime se poboljšavaju performanse i efikasnost.

- **Poboljšana bezbednost**: Precizna kontrola nad operacijama čitanja i pisanja može unaprediti bezbednosne mere, omogućavajući preciznije dozvole i kontrolu pristupa.

## Izazovi

- **Povećana složenost**: Uvođenje CQRS-a može povećati složenost sistema, zahtevajući pažljiv dizajn i razmatranje za efikasnu implementaciju.

- **Konzistentnost**: Održavanje konzistentnosti između modela za čitanje i pisanje, posebno u sistemima gde je potrebna trenutna konzistentnost, može biti izazovno.

- **Razvojni trošak**: Može postojati veći razvojni trošak pri održavanju odvojenih modela i infrastrukture koja ih podržava.

- **Kriva učenja**: Programeri koji su novi u CQRS-u i srodnim patternima poput event sourcing-a mogu naići na krivu učenja.

### Kršenje CQRS-a

Najpre razmotrimo klasu koja kombinuje operacije komande (pisanje) i upita (čitanje), što krši CQRS princip:

```php
class UserAccount {
    private $users = [];

    // This method combines command (adding a user) and query (returning user details) operations, violating CQRS
    public function createUser($userName) {
        $userId = uniqid();
        $this->users[$userId] = $userName;

        // Command operation above, query operation below
        return $this->getUser($userId);
    }

    // Query operation: Retrieves user details
    public function getUser($userId) {
        return isset($this->users[$userId]) ? $this->users[$userId] : null;
    }
}
```

U ovom primeru, metoda `createUser` obavlja i operaciju komande (dodavanje korisnika u niz `users`) i operaciju upita (vraćanje detalja novododatog korisnika), mešajući odgovornosti komandi i upita u jednoj metodi.

### Ispravna primena CQRS-a

Da bismo se pridržavali CQRS-a, razdvajamo odgovornosti komande i upita u različite metode ili čak različite klase. Evo kako biste mogli refaktorisati gornji primer da ispravno primeni CQRS:

```php
// Command class responsible for user creation (write operations)
class UserCommandService {
    private $users = [];

    public function createUser($userName) {
        $userId = uniqid();
        $this->users[$userId] = $userName;
        // Command operation only: modifies state but does not return data
    }

    // Method to access the users array for synchronization purposes
    public function getUsers() {
        return $this->users;
    }
}

// Query class responsible for fetching user details (read operations)
class UserQueryService {
    private $users = [];

    public function __construct($users) {
        $this->users = $users;
    }

    public function getUser($userId) {
        // Query operation only: returns data but does not modify state
        return isset($this->users[$userId]) ? $this->users[$userId] : null;
    }
}
```

U refaktorisanom primeru:

- Klasa `UserCommandService` rukuje operacijom komande za kreiranje korisnika. Odgovorna je za operacije pisanja i ne vraća nikakve podatke, pridržavajući se dela komande u CQRS-u.
- Klasa `UserQueryService` rukuje operacijom upita. Inicijalizuje se podacima o korisnicima (potencijalno prosleđenim iz `UserCommandService`), i obavlja samo operacije čitanja, pridržavajući se dela upita u CQRS-u.
- Ovo razdvajanje obezbeđuje da su odgovornosti komandi i upita jasno podeljene, prateći CQRS princip. Sistem postaje lakši za održavanje, a svaki deo može biti nezavisno optimizovan za svoju specifičnu ulogu.

Primenom CQRS-a na ovaj način, unapređujete razdvajanje nadležnosti, skalabilnost i fleksibilnost vaše aplikacije, omogućavajući efikasnije rukovanje različitim operacijama.
