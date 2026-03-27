Mockovanje statičkih metoda u unit testovima može biti izazovno zbog njihovog globalnog stanja i nedostatka konteksta objekta. Međutim,
moderni okviri za testiranje i alati pružaju mehanizme za prevazilaženje ovih izazova, omogućavajući efikasnu izolaciju
i testiranje klasa koje se oslanjaju na pozive statičkih metoda.

### Razumevanje izazova

Statičke metode pripadaju samoj klasi, a ne bilo kojoj instanci klase. Ovo ih čini inherentno teškim za
direktno mockovanje jer tradicionalni mocking okviri se oslanjaju na polimorfizam i zamenu objekata za injektovanje mock
ponašanja.

### Rešenja za mockovanje statičkih metoda

1. **Refactoring za korišćenje Dependency Injection-a**: Jedan pristup za povećanje testabilnosti statičkih metoda jeste refactoring
   koda za korišćenje dependency injection-a, zamenom poziva statičkih metoda pozivima metoda na interfejsu ili nadklasi,
   koje se onda mogu mockirati.

2. **Korišćenje okvira za testiranje koji podržavaju mockovanje statičkih metoda**: Neki okviri za testiranje pružaju alate za direktno mockovanje statičkih
   metoda, mada sa određenim ograničenjima ili specifičnim zahtevima.

### Primer u PHP-u korišćenjem PHPUnit-a

Od PHPUnit-a 9, direktna podrška za mockovanje statičkih metoda je ograničena i generalno se ne preporučuje. Međutim, možete zaobići
ovo ograničenje refactoring-om ili korišćenjem biblioteka trećih strana poput Mockery-ja koje podržavaju mockovanje statičkih metoda.

**Pristup refactoring-om**:

Umesto direktnog pozivanja statičke metode unutar klase, možete apstrahovati funkcionalnost iza interfejsa i
koristiti dependency injection da obezbedite bilo pravu implementaciju ili mock objekat tokom testiranja.

```php
interface DependencyInterface {
    public function someMethod();
}

class StaticDependencyWrapper implements DependencyInterface {
    public function someMethod() {
        return SomeClass::someStaticMethod();
    }
}

class ConsumerClass {
    private $dependency;

    public function __construct(DependencyInterface $dependency) {
        $this->dependency = $dependency;
    }

    public function useDependency() {
        return $this->dependency->someMethod();
    }
}

// In your tests
$mock = $this->createMock(DependencyInterface::class);
$mock->method('someMethod')->willReturn('mocked result');

$consumer = new ConsumerClass($mock);
// Proceed with tests
```

**Korišćenje Mockery-ja za direktno mockovanje statičkih metoda**:

Ako refactoring nije izvodljiv i potrebno je direktno mockirati statičku metodu, možete koristiti Mockery, PHP mocking
okvir koji podržava ovu funkcionalnost.

```php
use Mockery;

Mockery::mock('alias:SomeClass')
       ->shouldReceive('someStaticMethod')
       ->andReturn('mocked result');

// Proceed with tests that involve SomeClass::someStaticMethod
```

U ovom primeru, Mockery je instruisan da mockira statičku metodu `someStaticMethod` klase `SomeClass`, zamenjujući njeno
ponašanje unapred definisanom povratnom vrednošću.

### Zaključak

Mockovanje statičkih metoda zahteva pažljivo razmatranje zbog potencijalnog globalnog stanja i izazova postizanja
izolacije u testovima. Kad god je moguće, uradite refactoring prema korišćenju dependency injection-a radi poboljšanja testabilnosti.
Kada je direktno mockovanje statičkih metoda neophodno, razmotrite korišćenje specijalizovanih alata poput Mockery-ja, razumevajući
implikacije i ograničenja takvog pristupa.
