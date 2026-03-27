Imutabilni objekti su objekti čije stanje se ne može menjati nakon što su kreirani. Ovaj koncept je centralan za funkcionalano programiranje i koristan je i u objektno-orijentisanom programiranju za kreiranje jednostavnijeg, bezbednog za niti i manje koda sklonog greškama. Imutabilni objekti pomažu u upravljanju sporednim efektima, čineći ponašanje aplikacije predvidljivijim i lakšim za razumevanje.

### Ključne karakteristike imutabilnih objekata

- **Finalno stanje**: Jednom instanciran, polja ili properties imutabilnog objekta se ne mogu menjati.
- **Bezbednost niti**: Imutabilni objekti su prirodno bezbedni za niti jer se njihovo stanje ne može promeniti, eliminisuci potrebu za sinhronizacijom.
- **Jednostavnost**: Pojednostavljuju razvoj jer je njihovo stanje uvek predvidljivo.

### Prednosti

- **Lakoća upotrebe i bezbednost**: Imutabilni objekti su laki za upotrebu i razmatranje jer se njihovo stanje ne može neočekivano promeniti, smanjujući greške povezane sa promenama stanja.
- **Pogodnost za caching**: Pošto se ne mogu menjati, imutabilni objekti su bezbedni za caching, što može značajno poboljšati performanse.
- **Bezbednost hash ključa**: Odlični su kao ključevi za mapu ili elementi skupa jer se njihov hash kod ne menja.

### Primer u PHP-u

Ilustrujmo kako kreirati i koristiti imutabilne objekte u PHP-u.

**Pre primene imutabilnosti**:

Mutable klasa `User` dozvoljava promenu korisnikovog imena nakon kreiranja.

```php
class User {
    private $name;

    public function __construct($name) {
        $this->name = $name;
    }

    public function setName($name) {
        $this->name = $name;
    }

    public function getName() {
        return $this->name;
    }
}

$user = new User("John");
$user->setName("Doe"); // The user's name is mutable
```

**Nakon primene imutabilnosti**:

Imutabilna klasa `User` ne dozvoljava promenu imena nakon što je objekat kreiran.

```php
class ImmutableUser {
    private $name;

    public function __construct($name) {
        $this->name = $name;
    }

    public function getName() {
        return $this->name;
    }

    // No setter method
}

$user = new ImmutableUser("John");
// No method available to change the name after creation
```

### Zaključak

Imutabilni objekti nude značajne prednosti u pogledu jednostavnosti, bezbednosti niti i predvidljivosti, čineći ih vrednim konceptom u razvoju softvera. Primenom imutabilnosti, programeri mogu izbeći širok spektar grešaka povezanih sa nenameravanim promenama stanja, posebno u konkurentnim aplikacijama. Međutim, važno je balansirati upotrebu imutabilnosti sa zahtevima aplikacije, jer kreiranje novih objekata za svaku promenu stanja može uticati na performanse.
