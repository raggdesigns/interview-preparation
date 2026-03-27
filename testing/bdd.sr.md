Behavior-Driven Development (BDD) je proširenje Test-Driven Development (TDD) pristupa koje se fokusira na ponašanje
aplikacije iz perspektive njenih stejkholdera. Naglašava saradnju između programera, QA inženjera i
nетehničkih ili poslovnih učesnika u softverskom projektu. BDD podstiče timove da koriste razgovor i konkretne
primere kako bi formalizovali zajedničko razumevanje očekivanog ponašanja aplikacije.

### Osnovni koncepti BDD-a:

- **Sveprisutni jezik (Ubiquitous Language)**: Korišćenje zajedničkog jezika koji svi stejkholderi razumeju za opisivanje ponašanja
  aplikacije, često obuhvaćenog kroz korisničke priče.
- **Izvršive specifikacije (Executable Specifications)**: Pisanje specifikacija na način koji omogućava njihovo izvršavanje kao testova, tipično koristeći
  domenski specifične jezike (DSL) poput Gherkin-a.
- **Razvoj spolja prema unutra (Outside-In Development)**: Započinjanje razvoja od spoljnih slojeva (UI, spoljni interfejsi) i rad prema unutra
  ka domenskoj logici, vođeno specifikacijama ponašanja.

### Prednosti:

- **Poboljšana komunikacija**: Podstiče bolju komunikaciju između tehničkih i nетehničkih članova tima
  fokusiranjem na ponašanje umesto na tehničke detalje.
- **Jasnije zahteve**: Pomaže da se osigura da razvojni tim razume šta je potrebno iz poslovne
  perspektive.
- **Regresiono testiranje**: Pruža skup regresionih testova koji mogu proveriti postojeće ponašanje aplikacije dok se dodaju nove
  funkcionalnosti.

### Primer u PHP-u sa Behat-om

Behat je popularni BDD alat za PHP koji vam omogućava da pišete opise ponašanja softvera čitljive čoveku i pretvarate
ih u PHP test kod. Evo jednostavnog primera:

**Feature fajl** (`addition.feature`):

```gherkin
Feature: Addition
  In order to avoid silly mistakes
  As a math idiot
  I want to be told the sum of two numbers

  Scenario: Add two numbers
    Given I have entered 2 into the calculator
    And I have entered 3 into the calculator
    When I press add
    Then the result should be 5 on the screen
```

**Behat test** (`FeatureContext.php`):

```php
use Behat\Behat\Context\Context;
use Calculator;

class FeatureContext implements Context {
    private $calculator;
    private $result;

    /** @Given I have entered :number into the calculator */
    public function iHaveEnteredIntoTheCalculator($number) {
        $this->calculator = new Calculator();
        $this->calculator->pressNumber($number);
    }

    /** @When I press add */
    public function iPressAdd() {
        $this->result = $this->calculator->pressAdd();
    }

    /** @Then the result should be :result on the screen */
    public function theResultShouldBeOnTheScreen($result) {
        if ($this->result != $result) {
            throw new Exception("Actual result is not equal to expected");
        }
    }
}
```

U ovom primeru, feature fajl opisuje ponašanje operacije sabiranja u aplikaciji kalkulatora iz
perspektive korisnika. Odgovarajući Behat test implementira korake definisane u feature fajlu, obezbeđujući da se
aplikacija ponaša kako se očekuje.

### Zaključak

BDD je kolaborativni pristup koji proširuje principe TDD-a fokusiranjem na eksterno ponašanje
aplikacije, čineći je pristupačnijom za nетehničke stejkholdere. Podsticanjem jasne komunikacije i zajedničkog
razumevanja, BDD pomaže timovima da grade softver koji je usko usklađen sa poslovnim zahtevima i očekivanjima.
