PHP je dinamičan, labavo tipiziran jezik koji podržava razne tipove podataka. Razumevanje ovih tipova je ključno za efikasno PHP programiranje. Među nekoliko tipova podataka, PHP uključuje neke manje uobičajene tipove kao što su `resource` i `callable`, koji su neophodni za određene operacije.

### Resource

Tip `resource` je specijalna promenljiva koja se koristi za čuvanje referenci na spoljne resurse. Resursi se kreiraju i koriste od strane specifičnih funkcija i ne mogu se direktno kreirati od strane programera. Primeri spoljnih resursa uključuju file handle-ove, konekcije na bazu podataka i identifikatore slikovnog platna kreirane funkcijama kao što su `fopen()`, `mysqli_connect()` ili `imagecreate()`.

**Karakteristike**:

- **Neskalabilnost**: Resursi nisu skalabilni podaci. Većinu resursa ne možete serijalizovati (konvertovati u format koji se može čuvati).
- **Oslobađanje pri završetku skripte**: PHP automatski oslobađa sve resurse na kraju izvršavanja skripte, ali je dobra praksa ručno osloboditi resurse kada više nisu potrebni, koristeći funkcije kao što je `fclose()` za file handle-ove ili `mysqli_close()` za konekcije na bazu podataka.

**Primer**:

```php
$file = fopen("example.txt", "r");
if ($file) {
    while (($line = fgets($file)) !== false) {
        echo $line;
    }
    fclose($file); // Manually closing the file resource
}
```

### Callable

`callable` je tip podataka koji predstavlja bilo šta što se može "pozvati" kao funkcija u PHP-u. To uključuje jednostavne funkcije, metode objekata, statičke metode klasa, pa čak i closure-ove (anonimne funkcije).

**Karakteristike**:

- **Svestranost**: Tip `callable` je veoma svestran, omogućavajući PHP programerima da pišu visoko fleksibilan i dinamičan kod.
- **Korišćenje u funkcijama višeg reda**: Funkcije kao što su `array_map()`, `array_filter()` i `usort()` prihvataju tipove `callable` kao argumente za primenu callback funkcije na elemente niza.

**Primer**:

- Jednostavna funkcija:

```php
function myFunction($value) {
    return $value * 2;
}
$result = array_map('myFunction', [1, 2, 3]); // Passing the name of the function as a string
```

- Anonimna funkcija (Closure):

```php
$result = array_map(function($value) { return $value * 2; }, [1, 2, 3]);
```

- Metoda objekta:

```php
class MyClass {
    public function myMethod($value) {
        return $value * 2;
    }
}
$obj = new MyClass();
$result = array_map([$obj, 'myMethod'], [1, 2, 3]); // Passing an array with an object and method name
```

### Zaključak

Tipovi `resource` i `callable` u PHP-u služe specijalizovanim svrhama. `Resource` tipovi efikasno upravljaju spoljnim resursima, osiguravajući da PHP skripte mogu da komuniciraju sa spoljnim okruženjem, poput datoteka i baza podataka, bez direktnog rukovanja složenim detaljima implementacije. `Callable` tipovi, s druge strane, nude fleksibilnost u načinu na koji se funkcije definišu i koriste, omogućavajući PHP skriptama da koriste funkcije kao objekte prvog reda — prosleđujući ih kao argumente, vraćajući ih iz funkcija ili čuvajući ih u promenljivim.
