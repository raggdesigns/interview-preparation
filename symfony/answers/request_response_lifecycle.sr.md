# Životni ciklus zahteva i odgovora u Symfony-u

Životni ciklus zahteva i odgovora u Symfony-u je sistematski proces koji obrađuje HTTP zahtev i generiše odgovor. Ovaj ciklus je ključan u razvoju web aplikacija korišćenjem Symfony-a. U nastavku je sažeto objašnjenje ovog ciklusa:

## 1. **Ulazna tačka**

- Web server prosleđuje dolazni zahtev ulaznoj tački Symfony aplikacije (`public/index.php`).
- Učitavaju se promenljive okruženja i omogućava se debug mod ako je postavljen.

## 2. **Inicijalizacija Kernel-a**

- Kreira se instanca Kernel-a sa tipom okruženja aplikacije i zastavicom debug moda.
- Iz PHP superglobalnih promenljivih se instancira `Request` objekat.

## 3. **Obrada zahteva**

- Kernel obrađuje instancu `Request` kroz nekoliko koraka:
  - **Resetovanje servisa**: Servisi kojima je dozvoljeno resetovanje se resetuju ako stek zahteva nije prazan.
  - **Inicijalizacija Bundle-ova**: Bundle-ovi navedeni u `config/bundles.php` se inicijalizuju.
  - **Inicijalizacija kontejnera**: Servisni kontejner se inicijalizuje, konfiguriše i kompajlira. Ovo uključuje podešavanje internih postavki, mapa metoda, ID-jeva servisa i osluškivača dogadjaja.

## 4. **Rutiranje i izvršavanje kontrolera**

- `Request` objekat se obogaćuje informacijama o rutiranju, uključujući kontroler koji treba da se izvrši.
- Poziva se odgovarajuća metoda kontrolera radi obrade zahteva.

## 5. **Generisanje odgovora**

- Kontroler vraća `Response` objekat koji se potom dorađuje kroz različite kernel dogadjaje poput `kernel.view` i `kernel.response`.

## 6. **Slanje odgovora**

- HTTP odgovor se šalje nazad klijentu.

## 7. **Terminacija**

- Dispečuje se dogadjaj `kernel.terminate`, omogućavajući sve aktivnosti nakon slanja odgovora.

## Primer koda

U nastavku su pojednostavljeni isečci koda iz ključnih faza životnog ciklusa:

```php
// Entry Point: public/index.php
use App\Kernel;
use Symfony\Component\HttpFoundation\Request;

require dirname(__DIR__).'/vendor/autoload.php';

$kernel = new Kernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);
$request = Request::createFromGlobals();
$response = $kernel->handle($request);
$response->send();
$kernel->terminate($request, $response);
```

```php
// Kernel Handling: symfony/http-kernel/Kernel.php
public function handle(Request $request)
{
$this->boot();
return $this->getHttpKernel()->handle($request);
}
```

## Poboljšanja

- **Poboljšana jasnoća**: Koraci su opisani u jasnom, logičnom redosledu, što olakšava razumevanje toka od zahteva do odgovora.
- **Pojednostavljena objašnjenja**: Tehnički žargon je sveden na minimum kako bi objašnjenje bilo dostupno čitaocima različitih nivoa poznavanja Symfony-a.
- **Praktičan primer**: Uključivanje pojednostavljenih isečaka koda pruža praktičan uvid u to kako je životni ciklus implementiran u Symfony aplikacijama.

Ovo revidovano objašnjenje ima za cilj da demistifikuje životni ciklus zahteva i odgovora u Symfony-u, čineći ga pristupačnijim za programere.
