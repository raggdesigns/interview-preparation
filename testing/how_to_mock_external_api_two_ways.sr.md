Mockovanje poziva eksternih API-ja je od suštinskog značaja u unit testiranju kako bi se osiguralo da su testovi brzi, pouzdani i nezavisni
od eksternih servisa. Postoji nekoliko pristupa za postizanje ovoga, ali dve uobičajene metode su korišćenje mock objekata unutar
vašeg okvira za testiranje i korišćenje biblioteka za HTTP mockovanje.

### 1. Korišćenje mock objekata

Ovaj pristup uključuje kreiranje mock objekta koji simulira ponašanje klase odgovorne za pravljenje
poziva eksternom API-ju. Možete konfigurisati mock da vraća unapred definisane odgovore.

**Primer u PHP-u sa PHPUnit-om**:

Pretpostavite da imate klasu `WeatherService` koja dohvata podatke o vremenu sa eksternog API-ja. Možete mockirati ovaj servis u
vašim testovima.

```php
class WeatherService {
    public function getWeather($location) {
        // Makes an external API call
    }
}

class WeatherServiceTest extends PHPUnit\Framework\TestCase {
    public function testGetWeatherReturnsExpectedData() {
        $weatherServiceMock = $this->createMock(WeatherService::class);
        $weatherServiceMock->method('getWeather')->willReturn('Sunny');

        $this->assertEquals('Sunny', $weatherServiceMock->getWeather('Anywhere'));
    }
}
```

Ovaj test osigurava da vaša aplikacija može ispravno da obradi odgovor 'Sunny' bez stvarnog pozivanja eksternog
API-ja.

### 2. Biblioteke za HTTP mockovanje

Biblioteke za HTTP mockovanje vam omogućavaju da presretnete HTTP zahteve i vratite unapred definisane odgovore. Ovo je korisno za kompleksnije
scenarije gde trebate simulirati različite odgovore eksternog API-ja.

**Primer u PHP-u sa Guzzle-om i njegovim Mock Handler-om**:

Ako vaša aplikacija koristi Guzzle za HTTP zahteve, možete koristiti Guzzle-ove ugrađene mogućnosti mockovanja.

```php
use GuzzleHttp\Client;
use GuzzleHttp\Handler\MockHandler;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Psr7\Response;

class WeatherClientTest extends PHPUnit\Framework\TestCase {
    public function testGetWeather() {
        $mock = new MockHandler([
            new Response(200, [], '{"weather": "Sunny"}'),
            // You can add more responses to simulate different scenarios
        ]);

        $handlerStack = HandlerStack::create($mock);
        $client = new Client(['handler' => $handlerStack]);

        $response = $client->request('GET', 'http://example.com/weather');
        $data = json_decode($response->getBody()->getContents(), true);

        $this->assertEquals('Sunny', $data['weather']);
    }
}
```

Ovaj pristup je moćan jer direktno testira HTTP request sloj, pružajući integrisanije iskustvo testiranja
bez oslanjanja na eksterni servis.

### Zaključak

Mockovanje eksternih API-ja je kritičan aspekt unit testiranja aplikacija koje se oslanjaju na servise trećih strana. Bez obzira da li
birate da koristite mock objekte radi jednostavnosti ili biblioteke za HTTP mockovanje za sveobuhvatnije testiranje, obe metode vam omogućavaju
da kreirate predvidive, izolovane testove koji poboljšavaju pouzdanost i održivost vaše aplikacije.
