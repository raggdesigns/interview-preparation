Proxy obrazac je strukturalni dizajnerski obrazac koji pruža objekat koji deluje kao zamena ili placeholder za drugi objekat radi kontrole pristupa njemu. Ovaj posrednik može služiti različitim svrhama, kao što su rukovanje skupim kreiranjem objekata, kontrola pristupa osetljivim objektima, ili dodavanje dodatnih ponašanja (kao što su logovanje ili bezbednosne provere) kada se objekat pristupa. Proxy obrazac je posebno koristan kada želite dodati sloj apstrakcije nad stvarnim rukovanjem interakcijama objekata.

### Ključni koncepti Proxy obrasca

- **Interfejs subjekta (Subject Interface)**: Definiše zajednički interfejs za RealSubject i Proxy, dozvoljavajući Proxy-ju da se koristi svuda gde se očekuje RealSubject.
- **RealSubject**: Stvarni objekat koji Proxy predstavlja i kontroliše pristup njemu.
- **Proxy**: Održava referencu na RealSubject, kontroliše pristup njemu i može biti odgovoran za njegovo kreiranje i brisanje. Proxy često izvodi dodatne zadatke kada prosleđuje zahteve RealSubject-u, kao što su lena inicijalizacija, logovanje ili kontrola pristupa.

### Tipovi Proxy-ja

- **Virtuelni Proxy (Virtual Proxy)**: Odlaže kreiranje i inicijalizaciju skupih objekata dok nisu potrebni.
- **Zaštitni Proxy (Protective Proxy)**: Kontroliše pristup osetljivim objektima implementacijom kontrole pristupa.
- **Udaljeni Proxy (Remote Proxy)**: Predstavlja objekat u drugom adresnom prostoru (npr. mrežni server), rukujući komunikacijom potrebnom za slanje zahteva objektu.
- **Pametni Proxy (Smart Proxy)**: Dodaje dodatna ponašanja (npr. brojanje referenci ili logovanje) kada se objekat pristupa.

### Primer u PHP-u

Razmotrimo jednostavan primer gde koristimo Proxy za kontrolu pristupa osetljivom `BankAccount` objektu.

```php
interface BankAccount {
    public function deposit($amount);
    public function getBalance();
}

// RealSubject
class RealBankAccount implements BankAccount {
    private $balance = 0;

    public function deposit($amount) {
        $this->balance += $amount;
    }

    public function getBalance() {
        return $this->balance;
    }
}

// Proxy
class BankAccountProxy implements BankAccount {
    private $realBankAccount;
    private $userRole;

    public function __construct($userRole) {
        $this->userRole = $userRole;
        $this->realBankAccount = new RealBankAccount();
    }

    public function deposit($amount) {
        $this->realBankAccount->deposit($amount);
    }

    public function getBalance() {
        if ($this->userRole === 'authorized') {
            return $this->realBankAccount->getBalance();
        } else {
            return "Access denied. User role not authorized to view balance.";
        }
    }
}
```

### Upotreba

```php
$bankAccount = new BankAccountProxy('unauthorized');
$bankAccount->deposit(100);
echo $bankAccount->getBalance(); // Outputs: Access denied. User role not authorized to view balance.

$authorizedBankAccount = new BankAccountProxy('authorized');
$authorizedBankAccount->deposit(100);
echo $authorizedBankAccount->getBalance(); // Outputs the balance
```

U ovom primeru, `BankAccountProxy` kontroliše pristup stanju `RealBankAccount`-a na osnovu korisničke uloge. Ovo demonstrira kako Proxy obrazac može dodati sloj bezbednosti i kontrole nad pristupom objektima, bez menjanja koda originalnog objekta.
