
# Kako se rute parsiraju i mapiraju na akcije kontrolera u Symfony-u

U Symfony-u, komponenta za rutiranje je odgovorna za mapiranje HTTP zahteva na akcije kontrolera. Ovaj proces uključuje parsiranje konfiguracije ruta i njihovo podudaranje sa URL-om dolaznog zahteva. U nastavku je pregled kako ovaj proces funkcioniše, korak po korak.

## Korak 1: Definisanje ruta

Rute se mogu definisati u YAML, XML, PHP formatu ili putem anotacija u komentarima kontrolera. Svaka ruta mora da ima jedinstveno ime i da navede putanju, zajedno sa akcijom kontrolera na koji se mapira.

### Primer korišćenjem anotacija:

```php
// src/Controller/BookController.php
namespace App\Controller;

use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class BookController
{
    /**
     * @Route("/books/{id}", name="book_show")
     */
    public function show($id): Response
    {
        // ...
    }
}
```

U ovom primeru, anotacija `@Route` definiše rutu pod nazivom `book_show` koja mapira putanju `/books/{id}` na metodu `show` klase `BookController`.

## Korak 2: Podudaranje ruta

Kada se podnese zahtev, komponenta za rutiranje u Symfony-u parsira URL zahteva i pokušava da ga poklopi sa definisanim rutama. Definicije ruta se proveravaju po redosledu kojim su definisane, i koristi se prvo podudaranje.

Putanja može da sadrži pokazatelje mesta (npr. `{id}`) koji se konvertuju u promenljive i prosleđuju akciji kontrolera.

## Korak 3: Prosleđivanje kontroleru

Kada se ruta poklopi, Symfony prosleđuje zahtev odgovarajućoj akciji kontrolera. Kontroler zatim obrađuje zahtev i vraća odgovor.

## Iza scene: Komponenta za rutiranje

Komponenta za rutiranje se sastoji od nekoliko ključnih klasa i interfejsa:

- **RouteCollection**: Čuva sve definicije ruta.
- **UrlMatcher**: Odgovoran za podudaranje ruta sa URL-ovima zahteva.
- **Router**: Glavni interfejs sistema za rutiranje, koji kombinuje RouteCollection i UrlMatcher.

## Napredne funkcionalnosti rutiranja

Symfony-jev router podržava nekoliko naprednih funkcionalnosti, uključujući:

- **Parametri ruta**: Dinamički segmenti u putanji rute koji se prosleđuju kontroleru.
- **Zahtevi**: Ograničenja za parametre ruta, poput regex obrazaca.
- **Ograničenja HTTP metoda**: Ograničavanje ruta na specifične HTTP metode (GET, POST, itd.).
- **Imenovane rute**: Korišćenje naziva ruta za programsko generisanje URL-ova.

## Zaključak

Rutiranje u Symfony-u je moćan i fleksibilan sistem koji omogućava programerima da čisto i efikasno mapiraju HTTP zahteve na akcije kontrolera. Definisanjem ruta i korišćenjem Symfony-jeve komponente za rutiranje, aplikacije mogu da obrađuju širok spektar obrazaca zahteva i ponašanja.
