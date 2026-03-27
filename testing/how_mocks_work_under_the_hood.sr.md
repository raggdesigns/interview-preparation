Mock objekti se koriste u unit testiranju za simuliranje ponašanja pravih objekata. Posebno su korisni kada
pravi objekti nisu praktični za uključivanje u unit test, bilo zato što su spori, teški za podešavanje, ili je potrebno
aktivirati određene uslove za testiranje. Razumevanje kako mockovi rade ispod haube pruža uvid u njihovu ulogu u
automatizovanom testiranju i kako doprinose efikasnijim, izolovanim testovima.

### Osnovni koncept mockova

Mock objekat zamenjuje pravi objekat unutar test okruženja, oponašajući ponašanje pravog objekta. Ispod haube, mock objekat tipično:

- Implementira isti interfejs ili nasleđuje klasu koju mockuje.
- Sadrži unapred definisane odgovore na pozive metoda.
- Prati interakcije (npr. pozive metoda, argumente) radi kasnijeg verifikovanja.

### Kako se mockovi implementiraju

1. **Implementacija interfejsa ili nasleđivanje klase**: Mockovi mogu dinamički implementirati interfejs objekta
   koji mockuju ili nasleđivati njegovu klasu. Ovo se često postiže korišćenjem tehnika dinamičkog proksi-ja ili generisanja klasa
   u toku izvršavanja.

2. **Presretanje metoda (Method Interception)**: Kada se pozove metoda na mock objektu, poziv se presreće. Mock objekat tada
   pruža unapred definisan odgovor bez izvršavanja koda prave metode.

3. **Definisanje ponašanja**: Programeri definišu ponašanje mocka pre nego što se koristi, specifikujući šta treba da se vrati
   ili baci kada se pozovu određene metode.

4. **Praćenje interakcija**: Mockovi čuvaju zapis o svojim interakcijama, koji se može proveriti u testovima kako bi se
   verifikovalo da je objekat koji se testira komunicirao sa mockom na očekivani način.

### Primer u PHP-u sa PHPUnit-om

PHPUnit, popularni okvir za testiranje za PHP, pruža mocking framework koji programerima omogućava kreiranje i
konfigurisanje mock objekata dinamički.

```php
use PHPUnit\Framework\TestCase;

class SomeClassTest extends TestCase {
    public function testFunctionThatUsesAnObject() {
        // Create a mock for the SomeDependency class.
        $mock = $this->createMock(SomeDependency::class);

        // Configure the mock.
        $mock->method('doSomething')
             ->willReturn('specificValue');

        // Use the mock in test.
        $someClass = new SomeClass($mock);
        $result = $someClass->functionThatUsesDoSomething();

        // Assert that the result is as expected
        $this->assertSame('specificValue', $result);
    }
}
```

U ovom primeru, `SomeDependency::class` je mockovan tako da kada se pozove njegova metoda `doSomething`, vraća
`'specificValue'`. Ovo omogućava testu da se fokusira na ponašanje `SomeClass`-a bez oslanjanja na pravu
implementaciju `SomeDependency`-ja.

### Ispod haube

PHPUnit koristi metodu `createMock` za generisanje mock objekta u hodu. Ovaj objekat je proksi koji implementira sve
javne metode klase `SomeDependency`. Kada se pozove metoda `doSomething` na mock objektu, ona proverava svoju
internu mapu za taj poziv metode i vraća unapred definisanu vrednost bez izvršavanja bilo kakvog originalnog koda metode.

### Zaključak

Mockovi su moćni alati u arsenalu unit testiranja, koji omogućavaju izolovano testiranje simuliranjem kompleksnih objekata i
njihovih interakcija. Razumevanjem kako mockovi rade ispod haube, programeri mogu bolje da ih iskoriste za pisanje testova
koji su fokusirani, brzi i laki za održavanje.
