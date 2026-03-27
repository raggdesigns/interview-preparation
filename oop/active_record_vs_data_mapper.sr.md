Kada je reč o ORM (object-relational mapping) obrascima u razvoju softvera, Active Record i Data Mapper su dva istaknuta pristupa za premošćivanje jaza između objektno-orijentisanih programskih jezika i relacionih baza podataka. Svaki obrazac ima sopstveni skup principa i slučajeva upotrebe, uticajući na to kako se projektuju i implementiraju slojevi za pristup podacima.

### Active Record

Obrazac Active Record sugeriše da objekat nosi i svoje podatke i svoje ponašanje. To znači da, pored čuvanja podataka koje predstavlja red u bazi podataka, objekat takođe zna kako da se sačuva, ažurira, obriše i preuzme iz baze podataka.

**Karakteristike**:

- **Jednostavnost**: Lako razumljivo i implementabilno, što ga čini pogodnim za aplikacije sa jednostavnom poslovnom logikom i modelima podataka.
- **Direktno mapiranje**: Svaka klasa odgovara tabeli u bazi podataka, a instance klase predstavljaju redove u tabeli.
- **Tijesna povezanost**: Poslovni objekti su tijesno povezani sa šemom baze podataka.

**Primer u PHP-u**:

```php
class User extends ActiveRecord {
    public $id;
    public $name;
    // Methods for save, update, delete...
}

$user = new User();
$user->name = "John Doe";
$user->save();
```

### Data Mapper

Obrazac Data Mapper uključuje poseban maper koji prenosi podatke između objekata i baze podataka dok ih održava međusobno nezavisnim. Ovo omogućava složeniju domensku logiku i labaviju vezu između domenskog i sloja mapiranja podataka.

**Karakteristike**:

- **Fleksibilnost**: Omogućava složene domenske modele koji se ne podudaraju direktno sa šemom baze podataka.
- **Labava veza**: Domenski model je odvojen od operacija baze podataka, poboljšavajući testabilnost i održivost.
- **Sloj apstrakcije**: Dodaje sloj između domenskog modela i baze podataka, koji može upravljati transakcijama i domenskom logikom odvojeno.

**Primer u PHP-u**:

```php
class User {
    public $id;
    public $name;
}

class UserMapper {
    protected $database;

    public function __construct($database) {
        $this->database = $database;
    }

    public function save(User $user) {
        // Save the User object to the database
    }
}

$user = new User();
$user->name = "John Doe";
$userMapper = new UserMapper($database);
$userMapper->save($user);
```

### Active Record vs Data Mapper: Ključne Razlike

- **Povezanost**: Active Record tijesno vezuje objekat za bazu podataka, dok Data Mapper promoviše labavu vezu, odvajajući domenski model od operacija baze podataka.
- **Odgovornost**: U Active Record-u, objekti su odgovorni za sopstvenu perzistenciju, dok Data Mapper prebacuje tu odgovornost na posebnu klasu mapera.
- **Složenost i fleksibilnost**: Active Record je generalno jednostavniji i direktniji, što ga čini dobrim izborom za jednostavnije aplikacije. Data Mapper, mada složeniji za implementaciju, nudi veću fleksibilnost, čineći ga pogodnim za složene domenske modele i poslovnu logiku.

### Zaključak

Izbor između Active Record i Data Mapper zavisi od specifičnih zahteva projekta, kao što su složenost domenske logike, potreba za labavom vezom i poznatost tima sa obrascem. Za jednostavne CRUD aplikacije, Active Record može biti pogodniji, dok za složene sisteme sa bogatim domenskim modelima, Data Mapper može pružiti bolju održivost i fleksibilnost.
