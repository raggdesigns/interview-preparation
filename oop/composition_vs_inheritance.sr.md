Kompozicija i nasleđivanje su obe fundamentalne tehnike objektno-orijentisanog dizajna koje se koriste za uspostavljanje odnosa između klasa, ali služe različitim svrhama i imaju različite implikacije za fleksibilnost i održivost koda.

### Nasleđivanje

Nasleđivanje je mehanizam za definisanje nove klase na osnovu postojeće klase, nasleđivanjem njenih svojstava i ponašanja uz mogućnost prepisivanja i proširenja. Uspostavlja relaciju "je" između bazne (roditeljske) klase i izvedene (podklase).

**Prednosti**:

- **Ponovna upotreba koda**: Omogućava ponovnu upotrebu koda bazne klase, smanjujući redundancu.
- **Jednostavnost**: Lako za implementaciju, jer jezici podržavaju nasleđivanje nativno.

**Nedostaci**:

- **Tijesna veza**: Podklasa je tijesno povezana sa roditeljskom klasom, što može biti opasno pri promenama roditeljske klase.
- **Nefleksibilnost**: Preterana upotreba nasleđivanja može dovesti do rigidne hijerarhije koja je teška za promenu.
- **Neprozirnost**: Ponašanje izvedene klase može biti zamagljeno nasleđenim ponašanjem.

### Kompozicija

Kompozicija uključuje izgradnju složenih objekata od jednostavnijih, uspostavljajući relaciju "ima" između kompozitne klase i njenih komponenti.

**Prednosti**:

- **Fleksibilnost**: Fleksibilnija od nasleđivanja, omogućavajući dinamičke promene sistema tokom izvršavanja.
- **Labava veza**: Komponente se mogu lako zameniti drugim kompatibilnim objektima, smanjujući zavisnosti.
- **Jasnoća**: Sistem je često lakši za razumevanje jer je ponašanje eksplicitno delegirano komponentama.

**Nedostaci**:

- **Više boilerplate koda**: Može zahtevati više koda za delegiranje zadataka komponentama.
- **Složenost dizajna**: Može zahtevati promišljeniji dizajn za identifikovanje komponenti i njihovih interakcija.

### Primer u PHP-u

Razmotrimo sistem sa klasama `Bird` gde ne mogu sve ptice leteti.

**Primer sa nasleđivanjem**:
Koristeći nasleđivanje, klasa `FlyingBird` može proširiti klasu `Bird` da doda ponašanje letenja. Međutim, ovo postaje problematično ako trebate klasu `Penguin`, jer pingvini su ptice koje ne mogu leteti.

```php
class Bird {
    public function eat() {
        // Implementation
    }
}

class FlyingBird extends Bird {
    public function fly() {
        // Implementation
    }
}

class Penguin extends Bird {
    // Penguins can't fly, but this class inherits from Bird
}
```

**Primer sa kompozicijom**:
Koristeći kompoziciju, ponašanje letenja može biti enkapsulisano u posebnoj klasi i uključeno u ptice koje mogu leteti.

```php
class Bird {
    public function eat() {
        // Implementation
    }
}

class FlyBehavior {
    public function fly() {
        // Implementation
    }
}

class FlyingBird {
    private $flyBehavior;

    public function __construct() {
        $this->flyBehavior = new FlyBehavior();
    }

    public function fly() {
        $this->flyBehavior->fly();
    }
}

class Penguin {
    // No need to include FlyBehavior
}
```

U ovom primeru, kompozicija omogućava precizniju kontrolu nad tim koje ptice mogu leteti bez nasleđivanja nepotrebnog ili netačnog ponašanja.

### Zaključak

Dok nasleđivanje može biti korisno za uspostavljanje jasne hijerarhije i promovisanje ponovne upotrebe koda, može takođe dovesti do nefleksibilnih i tijesno vezanih dizajna. Kompozicija, nasuprot tome, nudi veću fleksibilnost i održivost favorizovanjem labavo vezanih, jasno definisanih odnosa između objekata.
