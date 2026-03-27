GRASP (General Responsibility Assignment Software Patterns) je skup principa koji ima za cilj poboljšanje objektno-orijentisanog dizajna pružanjem smernica za dodeljivanje odgovornosti klasama. Među ovim principima, "Nisko Spajanje" i "Visoka Kohezija" su temeljni koncepti koji pomažu u kreiranju održivijih, fleksibilnijih i razumljivijih dizajna.

### Nisko Spajanje (Low Coupling)

Spajanje se odnosi na stepen direktnog znanja koje jedna klasa ima o drugoj. Nisko spajanje je dizajnerski cilj koji teži smanjenju zavisnosti između klasa, čineći ih manje međusobno povezanim. Ovo pojednostavljuje izmene i razumevanje sistema, jer promene u jednom delu sistema imaju minimalan uticaj na druge delove.

**Prednosti niskog spajanja**:

- **Lakoća izmena**: Promene u jednoj klasi imaju manji uticaj na druge klase.
- **Ponovna upotrebljivost**: Klase se mogu lakše ponovo koristiti u različitim kontekstima ako ne zavise previše od drugih specifičnih klasa.
- **Testabilnost**: Klase sa manje zavisnosti je lakše testirati izolovano.

### Visoka Kohezija (High Cohesion)

Kohezija se odnosi na to koliko su usko povezane i fokusirane odgovornosti jedne klase (ili modula). Visoka kohezija znači da je klasa fokusirana na ono što treba da radi, sadrži samo odgovornosti koje su usko povezane sa svrhom klase. Ovo klasu čini razumljivijom i lakšom za upravljanje.

**Prednosti visoke kohezije**:

- **Razumljivost**: Klase sa jasno definisanim fokusom su lakše za razumevanje jer su njihove operacije usko povezane.
- **Održivost**: Lakše je održavati i menjati klase kada su njihove odgovornosti jasno definisane i koncentrisane na jednu svrhu.
- **Smanjena složenost**: Visoka kohezija obično rezultira jednostavnijim klasama sa manje metoda i atributa, smanjujući ukupnu složenost.

### Primer u PHP-u

Da bismo ilustrovali nisko spajanje i visoku koheziju, razmotrimo jednostavan sistem upravljanja korisnicima:

#### Pre (Visoko Spajanje i Niska Kohezija)

```php
class UserManager {
    public function createUser($userData) {
        // Create user logic
    }

    public function sendEmail($userEmail, $content) {
        // Email sending logic
    }

    // Additional unrelated methods...
}
```

U ovom primeru, `UserManager` se bavi kreiranjem korisnika i slanjem e-pošte, što pokazuje nisku koheziju (mešovite odgovornosti) i potencijalno visoko spajanje ako proces slanja e-pošte zavisi od specifičnosti sistema upravljanja korisnicima.

#### Posle (Nisko Spajanje i Visoka Kohezija)

```php
class UserManager {
    public function createUser($userData) {
        // Create user logic
    }
}

class EmailService {
    public function sendEmail($recipientEmail, $content) {
        // Email sending logic
    }
}
```

Sada je `UserManager` fokusiran isključivo na upravljanje korisnicima (visoka kohezija), a `EmailService` se bavi slanjem e-pošte. Ovaj dizajn smanjuje spajanje između upravljanja korisnicima i funkcionalnosti e-pošte, jer su sada razdvojeni u različite klase. Promene u servisu za e-poštu neće uticati na upravljač korisnicima i obrnuto.

### Zaključak

U objektno-orijentisanom dizajnu, težnja ka niskom spajanju i visokoj koheziji pomaže u kreiranju sistema koji su lakši za razumevanje, održavanje i proširivanje. Ovi principi usmeravaju strukturiranje klasa i njihovih odnosa, što dovodi do robustnijeg i fleksibilnijeg dizajna.
