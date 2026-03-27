Data Mapper obrazac je arhitekturalni dizajnerski obrazac koji promoviše razdvajanje reprezentacije objekta u memoriji od sloja perzistencije baze podataka. Umesto da objekat nosi i sopstvene podatke i logiku za učitavanje ili čuvanje tih podataka u bazu podataka, Data Mapper obrazac koristi zasebnu klasu mapera za premeštanje podataka između objekata i baze podataka, držeći ih nezavisnim jedne od drugog.

### Ključni koncepti Data Mapper obrasca:

- **Domenski model (Domain Model)**: Ovo su poslovni objekti aplikacije, koji trebaju biti agnostični prema detaljima baze podataka.
- **Data Mapper**: Sloj odgovoran za prenos podataka između baze podataka i objekata (Domenskog modela). Maperi upituju bazu podataka i prevode podatke iz redova baze podataka u objekte i obrnuto.
- **Sloj izvora podataka (Data Source Layer)**: Sloj gde se nalazi baza podataka. Sa ovim slojem interaguje Data Mapper, a ne Domenski model direktno.

### Prednosti:

- **Separacija odgovornosti**: Drži domenski model i logiku perzistencije razdvojenom, što dovodi do čistijeg, lakšeg za održavanje koda.
- **Fleksibilnost**: Dozvoljava domenskom modelu da se razvija nezavisno od šeme baze podataka i obrnuto.
- **Ponovna upotrebljivost**: Logika mapiranja se može ponovo koristiti u različitim delovima aplikacije.

### Primer u PHP-u:

Razmotrimo jednostavan scenario sa `User` domenskim modelom i odgovarajućim `UserMapper`-om za rukovanje operacijama baze podataka.

```php
class User {
    private $id;
    private $username;

    public function __construct($id, $username) {
        $this->id = $id;
        $this->username = $username;
    }

    // Getter and setter methods
    public function getId() {
        return $this->id;
    }

    public function getUsername() {
        return $this->username;
    }
}

class UserMapper {
    protected $database;

    public function __construct(PDO $database) {
        $this->database = $database;
    }

    public function findById($id) {
        $stmt = $this->database->prepare("SELECT * FROM users WHERE id = ?");
        $stmt->execute([$id]);
        $row = $stmt->fetch();

        if ($row) {
            return new User($row['id'], $row['username']);
        }

        return null;
    }

    // Other data mapping methods like save, update, delete...
}
```

### Upotreba:

```php
// Assuming $pdo is a previously configured PDO object
$userMapper = new UserMapper($pdo);
$user = $userMapper->findById(1);

if ($user) {
    echo "User Found: " . $user->getUsername();
} else {
    echo "User not found.";
}
```

U ovom primeru, `User` je jednostavan domenski model koji predstavlja korisnika, a `UserMapper` sadrži logiku za mapiranje između `User` objekata i zapisa u bazi podataka. Metoda `findById` demonstrira kako dohvatiti korisnika iz baze podataka.
