Test-Driven Development (TDD) je pristup razvoju softvera gde se testovi pišu pre samog koda. Zagovara kreiranje
automatizovanih testova koji definišu željena poboljšanja ili nove funkcije pre nego što se sama funkcionalnost
implementira. Proces karakteriše kratki i ponavljajući razvojni ciklus koji ima za cilj povećanje kvaliteta i
razumljivosti koda.

### Osnovni proces TDD-a

1. **Napišite test**: Počnite pisanjem testa za sledeći deo funkcionalnosti koji želite da dodate.
2. **Pokrenite testove**: Pokrenite test suite. Novi test bi trebalo da ne prolazi jer funkcionalnost koju testira
   još nije implementirana.
3. **Napišite kod**: Implementirajte funkcionalnost potrebnu da bi test prošao.
4. **Ponovo pokrenite testove**: Ponovo pokrenite testove. Ako novi test prolazi, pređite na sledeću funkcionalnost.
   Ako ne, ispravite kod dok test ne prodje.
5. **Uradite refactoring**: Očistite novi kod, osiguravajući da se dobro uklapa u postojeći dizajn i da se pridržava
   standarda kodiranja. Proverite da testovi i dalje prolaze nakon refactoring-a.

Ovaj ciklus se ponavlja za svaki novi deo funkcionalnosti.

### Prednosti

- **Rano otkrivanje grešaka**: Pisanje testova pre pomaže u ranom identifikovanju problema u razvojnom ciklusu.
- **Poboljšanje dizajna**: TDD podstiče jednostavnije, jasnije i modularnije dizajne zahtevajući od programera da
  unapred razmišljaju o interfejsima i interakcijama.
- **Pouzdanost pri promenama**: Sveobuhvatan test suite omogućava programerima da menjaju kodnu bazu sa
  pouzdanjem, znajući da će testovi uhvatiti regresije.
- **Dokumentacija**: Testovi služe kao dokumentacija koja pruža uvid u to šta kod treba da radi.

### Primer u PHP-u

Zamislite da razvijamo funkciju za sabiranje dva broja. Prateći TDD, počinjemo pisanjem testa.

```php
class CalculatorTest extends PHPUnit_Framework_TestCase {
    public function testAdd() {
        $calculator = new Calculator();
        $this->assertEquals(4, $calculator->add(2, 2));
    }
}
```

Pokretanje ovog testa će ne uspeti jer `Calculator` i njegova metoda `add` još ne postoje.

Sada pišemo minimalni kod neophodan za prolaz testa:

```php
class Calculator {
    public function add($a, $b) {
        return $a + $b;
    }
}
```

Nakon implementacije funkcije `add`, ponovnim pokretanjem testa trebalo bi da prodje. Sledeći korak bi bio
refactoring ako je potreban, a zatim prelaz na sledeći deo funkcionalnosti ili poboljšanje.

### Zaključak

TDD je moćna metodologija koja, kada se ispravno primenjuje, može dovesti do pouzdanijeg, lakšeg za održavanje i
razumljivijeg koda. Zahteva disciplinu i vežbu za savladavanje, ali su prednosti u smislu kvaliteta koda i
produktivnosti programera vredan ulog.
