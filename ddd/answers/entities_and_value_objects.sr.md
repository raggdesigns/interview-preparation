Entiteti i Value Objects su dva fundamentalna koncepta u Domain-Driven Design-u (DDD) koji pomažu u efektivnijem modelovanju domene. Razumevanje ovih koncepata omogućava precizno predstavljanje nijansi domene unutar softvera.

### Entiteti

Entiteti su objekti koji su definisani ne atributima, već nitom kontinuiteta i identiteta. To znači da je entitet jedinstven unutar sistema, čak i ako se njegovi atributi menjaju tokom vremena. Identitet entiteta je konstantan od trenutka kreiranja do prestanka postojanja unutar sistema.

#### Primer entiteta:

```
class User {
    private $userId;
    private $name;
    private $email;

    public function __construct($userId, $name, $email) {
        $this->userId = $userId;
        $this->name = $name;
        $this->email = $email;
    }
    // Getteri i seteri...
}
```
Razmotri `User` na platformi društvenih mreža. Korisnik može promeniti ime, email ili profilnu sliku, ali ostaje isti korisnik. Ovo je predstavljeno jedinstvenim identifikatorom (kao što je ID korisnika) koji se ne menja, čak i kada se drugi atributi menjaju.

### Value Objects

Value Objects, s druge strane, su definisani atributima. Ako promeniš bilo koji atribut Value Object-a, on u suštini postaje novi objekat. Value Objects nemaju jedinstveni identifikator koji ih prati tokom životnog ciklusa, i često se koriste za opisivanje aspekata entiteta.

#### Primer Value Object-a:

```
class Address {
    private $street;
    private $city;
    private $postalCode;

    public function __construct($street, $city, $postalCode) {
        $this->street = $street;
        $this->city = $city;
        $this->postalCode = $postalCode;
    }
    // Getteri...
}
```
`Address` koji se koristi u sistemu za dostavu može biti Value Object. Definisan je atributima (ulica, grad, poštanski broj), a promena bilo kojeg od ovih atributa rezultira drugom adresom.

### Pogrešna interpretacija i njeni efekti

Uobičajena pogrešna interpretacija u DDD-u je tretiranje objekta koji bi trebao biti Entitet kao Value Object. Ova greška može manifestovati značajne probleme kako se sistem razvija.

#### Primer pogrešne odluke:

Zamislite sistem onlajn knjižare gde je svaka knjiga inicijalno modelovana kao Value Object, pod pogrešnom pretpostavkom da je sve što identifikuje knjigu kombinacija naslova, autora i ISBN-a. Ova odluka dovodi do komplikacija kada sistem treba da prati pojedinačne primerke knjiga za potrebe upravljanja inventarom ili rukuje prodajom i povratom, jer Value Objects nemaju jedinstveni identifikator.

### Korektivna akcija:
```
class Book {
    private $bookId;
    private $title;
    private $author;
    private $ISBN;

    public function __construct($bookId, $title, $author, $ISBN) {
        $this->bookId = $bookId;
        $this->title = $title;
        $this->author = $author;
        $this->ISBN = $ISBN;
    }
    // Getteri...
}
```
Za rešavanje ovih problema, razvojni tim treba da refaktoriše model, tretirajući `Book` kao Entitet umesto Value Object-a. Ovo uključuje dodeljivanje jedinstvenog identifikatora svakoj instanci `Book-a`, omogućavajući sistemu da razlikuje različite primerke istog naslova.


### Zaključak

Razlika između Entiteta i Value Objects nije samo akademska; ima praktične implikacije za dizajn i funkcionalnost sistema. Pravilno primenjeni, ovi koncepti mogu kreirati model domene koji je robustan, fleksibilan i usklađen sa poslovnim realnostima, olakšavajući buduća poboljšanja i prilagođavanja novim zahtevima.

### Vidi takođe

- [Entitet vs DTO vs Value Object (OOP perspektiva)](../../oop/entity_vs_data_transfer_object_vs_value_object.sr.md)
