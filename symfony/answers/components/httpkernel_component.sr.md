
# Symfony HttpKernel Component

Symfony HttpKernel Component je u srcu Symfony framework-a, rukovanjem HTTP zahtevima i generisanjem odgovora. Reč je o ključnoj komponenti koja pokreće Symfony Full-Stack Framework, ali može da se koristi i samostalno u drugim PHP aplikacijama za kreiranje robusnog i fleksibilnog HTTP framework-a.

## Osnovni koncepti

- **Kernel**: Centralni deo HttpKernel komponente, odgovoran za konvertovanje `Request` objekata u `Response` objekte.
- **Request**: Objekat koji enkapsulira HTTP zahtev koji je uputio klijent.
- **Response**: Objekat koji predstavlja HTTP odgovor koji vraća server.
- **Controller**: PHP funkcija ili metoda koja prima zahtev i vraća odgovor.
- **Dogadjaj**: HttpKernel komponenta je u velikoj meri vodjenja dogadjajima, omogućavajući programerima da se zakače na proces obrade zahteva.

## Kako funkcioniše

HttpKernel prati jednostavan, ali moćan radni tok:

1. **Zahtev**: HTTP zahtev se hvata i konvertuje u `Symfony\Component\HttpFoundation\Request` objekat.
2. **Kernel Handle**: Objekat zahteva se prosleđuje kernel-ovoj metodi `handle`.
3. **Dispečovanje dogadjaja**: Različiti dogadjaji (kao što su `kernel.request`, `kernel.controller` itd.) se dispečuju tokom procesa, omogućavajući prilagođeno rukovanje i izmene.
4. **Razrešavanje kontrolera**: Odredjuje se kontroler odgovoran za rukovanje zahtevom.
5. **Odgovor**: Kontroler obrađuje zahtev i vraća `Symfony\Component\HttpFoundation\Response` objekat.
6. **Slanje odgovora**: Objekat odgovora se šalje nazad klijentu.

## Prednosti

- **Fleksibilnost**: Odvajanjem rukovanja zahtevima u komponente i korišćenjem dogadjaja, HttpKernel omogućava visoku prilagodljivost.
- **Višekratna upotreba**: Komponenta se može koristiti van Symfony Full-Stack projekata, u Silex aplikacijama ili u bilo kom PHP projektu koji zahteva HTTP rukovanje.
- **Testabilnost**: Korišćenje objekata zahteva i odgovora olakšava testiranje aplikacija simuliranjem HTTP zahteva i inspekcijom odgovora.

## Primer upotrebe

Evo osnovnog primera kreiranja kernel-a i rukovanja zahtevom:

```php
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\HttpKernelInterface;

class MyKernel implements HttpKernelInterface
{
    public function handle(Request $request, $type = self::MASTER_REQUEST, $catch = true)
    {
        // Your logic to return a Response
        return new Response('Hello World!');
    }
}

$request = Request::createFromGlobals();
$kernel = new MyKernel();

$response = $kernel->handle($request);
$response->send();
```

U ovom primeru, implementiran je kernel koji uvek vraća odgovor sa porukom "Hello World!". U realnom scenariju, kernel bi sadržao složeniju logiku za određivanje odgovarajućeg kontrolera koji će obraditi zahtev na osnovu rutiranja, parametara zahteva i drugih faktora.

## Zaključak

Symfony HttpKernel Component pruža strukturiranu osnovu za rukovanje HTTP zahtevima i odgovorima. Podupire Symfony Full-Stack Framework, ali je dovoljno fleksibilan da se koristi u bilo kom PHP projektu koji zahteva sofisticirano HTTP rukovanje.
