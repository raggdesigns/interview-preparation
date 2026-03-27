Mockovanje property-ja objekta koji je kreiran interno unutar konstruktora ili metode predstavlja jedinstveni izazov u unit
testiranju. Uključuje kreiranje mocka za objekat koji nije prosleđen kao zavisnost, već je direktno instanciran
unutar objekta koji se testira. Ovaj scenario često zahteva kombinaciju refactoring-a i korišćenja naprednih tehnika mockovanja.

### Strategije za mockovanje interno kreiranih properties

1. **Refactoring za Dependency Injection**: Najjednostavniji način za omogućavanje mockovanja internih objekata jeste
   refactoring koda da koristi dependency injection. Ovo omogućava da se zavisnost prosledi u konstruktor ili metodu
   spolja, što olakšava zamenu mockom tokom testiranja.

2. **Korišćenje Reflection za manipulaciju properties**: Ako refactoring nije moguć ili praktičan, možete koristiti reflection
   za direktnu izmenu privatnih ili zaštićenih properties, što vam omogućava da injektujete mock objekte nakon instanciranja.

### Primer u PHP-u

**Pristup refactoring-om**:

Razmotrite klasu `ReportGenerator` koja interno kreira instancu `DataFetcher`-a. Da biste testirali `ReportGenerator`
nezavisno, možete je refactoring-ovati da prima instancu `DataFetcher`-a kao zavisnost.

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

Sa ovim refactoring-om, možete lako proslediti mockovan `DataFetcher` objekat kada testirate `ReportGenerator`.

**Korišćenje Reflection-a**:

Ako ne možete da uradite refactoring klase `ReportGenerator`, možete koristiti reflection da postavite property `dataFetcher` na mock
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

Mockovanje properties objekta kreiranih interno zahteva pažljivo razmatranje dizajna koda i strategije testiranja.
Kad god je moguće, preferujte refactoring za korišćenje dependency injection-a, jer promoviše čistiji, lakše testabilni kod. Kada
refactoring nije opcija, korišćenje reflection-a za manipulaciju properties objekata može biti moćna, mada manje idealna,
alternativa.
