### Data Transfer Object (DTO)

DTO je objekat koji prenosi podatke između procesa, s ciljem smanjenja broja poziva metoda, posebno u mrežnom okruženju. Često se koristi za prenos podataka sa servera ka klijentu radi prikaza, ali ne i za poslovnu logiku ili interakciju sa bazom podataka. DTO objekti se često serijalizuju u formate poput JSON ili XML radi lakšeg prenosa.

**Karakteristike**:
- Koristi se za enkapsulaciju podataka radi prenosa.
- Pojednostavljuje strukturu podataka, često ravnajući složene podatke.
- Imutabilan: jednom kreiran, ne treba da se menja.
- Nema ponašanja (metoda) koje menjaju stanje.

**Primer**: Vraćanje informacija o korisniku u veb aplikaciji.

```php
class UserDTO {
    public $id;
    public $name;
    public $email;

    public function __construct($id, $name, $email) {
        $this->id = $id;
        $this->name = $name;
        $this->email = $email;
    }
}

// Usage example
function getUserData($userId) {
    // Assume $user is fetched from database
    $user = new UserDTO(1, "John Doe", "john@example.com");
    return json_encode($user); // Serialized DTO
}
```

### Command objekat

Command objekat enkapsulira sve informacije potrebne za izvođenje akcije ili pokretanje događaja u nekom trenutku. To uključuje naziv metode, objekat koji je vlasnik metode i vrednosti parametara metode. Command objekti su deo Command obrasca, koji odvaja objekat koji poziva operaciju od onog koji zna kako da je izvrši.

**Karakteristike**:
- Enkapsulira zahtev kao objekat.
- Sadrži sve informacije potrebne za akciju: naziv metode, parametre.
- Može biti proširen da uključuje funkcionalnost poništavanja (undo).
- Obično se ne serijalizuje za prenos podataka, već se koristi za enkapsulaciju ponašanja.

**Primer**: Implementacija jednostavne undo funkcionalnosti u aplikaciji.

```php
interface Command {
    public function execute();
    public function undo();
}

class AddUserCommand implements Command {
    private $userId;
    private $userName;

    public function __construct($userId, $userName) {
        $this->userId = $userId;
        $this->userName = $userName;
    }

    public function execute() {
        // Logic to add a user
        echo "User {$this->userName} added.";
    }

    public function undo() {
        // Logic to remove a user
        echo "User {$this->userName} removed.";
    }
}

// Usage example
$command = new AddUserCommand(1, "John Doe");
$command->execute(); // Executes the command
$command->undo(); // Undoes the command
```

### Ključne razlike

- **Svrha**: DTO objekti su dizajnirani za prenos podataka bez poslovne logike, često serijalizovani za transport. Command objekti enkapsuliraju akcije i njihove parametre, sadržeći poslovnu logiku koja treba da se izvrši.
- **Serijalizacija**: DTO objekti se obično serijalizuju za prenos podataka (npr. u JSON ili XML), što ih čini idealnim za REST API-je ili drugu klijent-server komunikaciju. Command objekti se obično ne serijalizuju; oni su više o ponašanju nego o prenosu podataka.
- **Stanje i ponašanje**: DTO objekti su stati-puni ali bez ponašanja. Prenose podatke ali ne definišu akcije. Command objekti su i stati-puni i bogati ponašanjem, definišući akcije koje treba izvesti.
- **Kontekst upotrebe**: DTO objekti se koriste kada treba preneti podatke između delova sistema ili između sistema. Command objekti se koriste za predstavljanje operacija ili transakcija, odvajajući zahtev za akciju od njenog izvođenja.

Razumevanje ovih razlika je ključno za primenu pravog obrasca u odgovarajućem kontekstu unutar PHP aplikacija ili bilo kojih drugih projekata razvoja objektno-orijentisanog softvera.
