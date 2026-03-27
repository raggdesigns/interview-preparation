
# Dependency Injection Component

Dependency Injection Component je fundamentalni deo Symfony framework-a, koji pruža način za upravljanje zavisnostima klasa kroz konfiguraciju umesto hardkodovanja. Ova komponenta omogućava fleksibilniji, lakše održiv i testabilniji kod odvajanjem instanciranja objekata od njihovog korišćenja.

## Osnovni koncepti

- **Servisni kontejner**: PHP objekat koji upravlja instanciranjem servisnih objekata i njihovim zavisnostima.
- **Servisi**: PHP objekti koji obavljaju specifične zadatke. Servis je obično klasa sa svrhom, kao što je slanje e-mailova, rukovanje konekcijama sa bazom podataka itd.
- **Konfiguracija**: Definiše servise i njihove argumente u konfiguracionim fajlovima, poput YAML, XML ili PHP fajlova, što olakšava promenu ponašanja aplikacije bez izmene koda.

## Prednosti

- **Odvajanje zavisnosti**: Smanjuje zavisnost jedne klase od druge, čineći sistem modularnim i lakšim za izmenu ili zamenu komponenti.
- **Konfigurabilnost**: Omogućava lako konfigurisanje i upravljanje klasama i njihovim zavisnostima, poboljšavajući fleksibilnost.
- **Višekratna upotreba**: Promoviše korišćenje postojećih servisa širom aplikacije, smanjujući dupliciranje koda.

## Primer upotrebe

### Definisanje servisa

Uzmimo u obzir jednostavnu klasu servisa `Mailer`:

```php
namespace App\Service;

class Mailer
{
    private $transport;

    public function __construct($transport)
    {
        $this->transport = $transport;
    }

    public function send($message)
    {
        // Send the message
    }
}
```

### Konfigurisanje servisa

Ovaj servis možete definisati u konfiguracionom fajlu, kao što je `config/services.yaml` u Symfony projektu:

```yaml
services:
    App\Service\Mailer:
        arguments: ['%mailer_transport%']
```

U ovom primeru, klasa `Mailer` je definisana kao servis sa argumentom konstruktora, koji je parametar koji može biti definisan drugde u konfiguraciji aplikacije.

### Korišćenje servisa

Kada je definisan, servis se može preuzeti iz servisnog kontejnera i koristiti bilo gde u vašoj aplikaciji:

```php
$mailer = $container->get('App\Service\Mailer');
$mailer->send('Hello, dependency injection!');
```

Servisni kontejner upravlja instanciranjem servisa `Mailer`, uključujući prosleđivanje potrebnog parametra `$transport` kako je definisano u konfiguraciji.

## Zaključak

Dependency Injection Component pojednostavljuje upravljanje zavisnostima klasa u PHP aplikacijama, promovišući dizajn koji je modularniji, testabilniji i fleksibilniji. Korišćenjem ove komponente, Symfony programeri mogu da grade aplikacije koje su lakše za održavanje i proširivanje tokom vremena.
