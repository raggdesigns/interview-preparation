Mockovanje svojstva objekta koje je kreisano interno unutar konstruktora ili metode predstavlja jedinstveni izazov u unit
testiranju. Uključuje kreiranje mocka za objekat koji nije prosleđen kao zavisnost, već je direktno instanciran
unutar objekta koji se testira. Ovaj scenario često zahteva kombinaciju refaktorisanja i korišćenja naprednih tehnika mockovanja.

### Strategije za mockovanje interno kreiranih svojstava

1. **Refaktorisanje za Dependency Injection**: Najjednostavniji način za omogućavanje mockovanja internih objekata jeste
   refaktorisanje koda da koristi dependency injection. Ovo omogućava da se zavisnost prosledi u konstruktor ili metodu
   spolja, što olakšava zamenu mockom tokom testiranja.

2. **Korišćenje Reflection za manipulaciju svojstvima**: Ako refaktorisanje nije moguće ili praktično, možete koristiti reflection
   za direktnu izmenu privatnih ili zaštićenih svojstava, što vam omogućava da injektujete mock objekte nakon instanciranja.

### Primer u PHP-u

**Pristup refaktorisanjem**:

Razmotrite klasu `ReportGenerator` koja interno kreira instancu `DataFetcher`-a. Da biste testirali `ReportGenerator`
nezavisno, možete je refaktorisati da prima instancu `DataFetcher`-a kao zavisnost.

```php
class DataFetcher {
    public function fetchData() {
        // Fetch data from a database
    }
}

class ReportGenerator {
    private $dataFetcher;

    public function __construct(DataFetcher $dataFetcher = null) {
        $this->dataFetcher = $dataFetcher ?? new DataFetcher();
    }

    public function generateReport() {
        $data = $this->dataFetcher->fetchData();
        // Generate the report
    }
}
```

Sa ovim refaktorisanjem, možete lako proslediti mockovan `DataFetcher` objekat kada testirate `ReportGenerator`.

**Korišćenje Reflection-a**:

Ako ne možete da refaktorišete klasu `ReportGenerator`, možete koristiti reflection da postavite svojstvo `dataFetcher` na mock
objekat.

```php
$reportGenerator = new ReportGenerator();
$reflector = new ReflectionObject($reportGenerator);
$property = $reflector->getProperty('dataFetcher');
$property->setAccessible(true);

$mockDataFetcher = $this->createMock(DataFetcher::class);
$mockDataFetcher->method('fetchData')->willReturn('mocked data');
$property->setValue($reportGenerator, $mockDataFetcher);

// Proceed with testing generateReport()
```

Ovaj pristup vam omogućava da injektujete mock bez menjanja originalnog dizajna klase. Međutim, treba ga koristiti
oprezno jer zaobilazi enkapsulaciju, što potencijalno vodi do krhkih testova.

### Zaključak

Mockovanje svojstava objekta kreiranih interno zahteva pažljivo razmatranje dizajna koda i strategije testiranja.
Kad god je moguće, preferujte refaktorisanje za korišćenje dependency injection-a, jer promoviše čistiji, lakše testabilni kod. Kada
refaktorisanje nije opcija, korišćenje reflection-a za manipulaciju svojstvima objekata može biti moćna, mada manje idealna,
alternativa.
