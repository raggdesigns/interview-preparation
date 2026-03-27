U objektno-orijentisanom dizajnu i softverskoj arhitekturi, Entity, Data Transfer Object (DTO) i Value Object su termini koji opisuju različite načine strukturiranja podataka i ponašanja u aplikacijama. Svaki ima posebnu svrhu i koristi se u različitim kontekstima.

### Entity

Entity objekti su objekti koji imaju poseban identitet koji traje kroz vreme i različita stanja. Entity je definisan više svojim identitetom nego atributima. Atributi mogu da se menjaju tokom vremena, ali entity ostaje isti.

**Karakteristike**:

- **Identitet**: Entity objekti imaju jedinstveni identifikator.
- **Mutabilnost**: Njihovo stanje ili atributi mogu da se menjaju tokom vremena, ali njihov identitet se ne menja.
- **Životni ciklus**: Obično imaju životni ciklus kojim se upravlja kroz CRUD operacije (Create, Read, Update, Delete).

**Primer u PHP-u**:

```php
class User {
    private $id; // Unique identifier
    private $name; // Mutable attribute

    public function __construct($id, $name) {
        $this->id = $id;
        $this->name = $name;
    }

    // Getter and setter methods
}
```

### Data Transfer Object (DTO)

DTO objekti su jednostavni objekti koji se koriste za prenos podataka između podsistema softverske aplikacije. DTO objekti ne sadrže nikakvu poslovnu logiku. Koriste se za smanjenje broja poziva metoda, posebno u mrežnom okruženju.

**Karakteristike**:

- **Jednostavnost**: Samo atributi podataka, bez poslovne logike.
- **Kontejner podataka**: Koristi se za transport podataka između slojeva ili servisa.
- **Imutabilnost** (opciono): Često dizajnirani kao imutabilni radi povećanja bezbednosti niti u konkurentnim operacijama.

**Primer u PHP-u**:

```php
class UserDTO {
    public $id;
    public $name;

    public function __construct($id, $name) {
        $this->id = $id;
        $this->name = $name;
    }
}
```

### Value Object

Value Object objekti su objekti koji opisuju neku karakteristiku ili atribut, ali nisu definisani jedinstvenim identitetom. Koriste se za opisivanje aspekata domene bez potrebe za jedinstvenošću.

**Karakteristike**:

- **Imutabilnost**: Jednom kreirani, ne treba da se menjaju.
- **Jednakost**: Određena jednakošću njihovih atributa, a ne identitetom.
- **Ponašanje bez sporednih efekata**: Mogu sadržati metode koje operišu na atributima ali ne menjaju stanje objekta.

**Primer u PHP-u**:

```php
class EmailAddress {
    private $email;

    public function __construct($email) {
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException("Invalid email address");
        }
        $this->email = $email;
    }

    public function getEmail() {
        return $this->email;
    }

    // Value objects are equal if their attributes are equal
    public function equals(EmailAddress $other) {
        return $this->email === $other->getEmail();
    }
}
```

### Entity vs DTO vs Value Object: Ključne razlike

- **Identitet vs. Atributi**: Entity objekti su definisani jedinstvenim identifikatorom, dok su Value Object objekti definisani svojim atributima. DTO objekti su kontejneri podataka i obično nemaju identitet niti ponašanje.
- **Imutabilnost**: Value Object objekti su imutabilni, dok se Entity objekti mogu menjati tokom vremena. DTO objekti mogu biti jedno ili drugo, ali su često imutabilni radi pojednostavljivanja prenosa podataka.
- **Kontekst upotrebe**: Entity objekti predstavljaju poslovne objekte sa identitetom. Value Object objekti opisuju karakteristike tih objekata. DTO objekti pojednostavljuju prenos podataka između delova sistema ili kroz mreže.

### Vidi takođe

- [Entities i Value Objects u DDD kontekstu](../ddd/answers/entities_and_value_objects.sr.md)
- [DTO vs Command](dto_vs_command.sr.md)

### Zaključak

Razumevanje razlika između Entity, DTO i Value Object je ključno za dizajniranje jasnih, održivih softverskih arhitektura. Izbor pravog obrasca zavisi od specifičnih zahteva aplikacije, kao što su potreba za identitetom, važnost enkapsulacije podataka i priroda operacija prenosa podataka.
