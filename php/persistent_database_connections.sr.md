Perzistentna veza sa bazom podataka je veza koja ostaje otvorena nakon završetka PHP skripte. Sledeća skripta kojoj je potrebna veza sa istom bazom podataka može ponovo koristiti ovu postojeću vezu umesto kreiranja nove.

### Kako rade normalne veze

U tipičnom PHP zahtevu:

1. PHP skripta počinje
2. Otvara novu vezu sa bazom podataka
3. Izvršava upite
4. Zatvara vezu
5. Skripta se završava

Ovo znači da **svaki zahtev** kreira i uništava vezu. Kreiranje veze je skupo — uključuje mrežnu komunikaciju, autentikaciju i alokaciju memorije.

### Kako rade perzistentne veze

Sa perzistentnim vezama:

1. Prvi zahtev: PHP otvara vezu i označava je kao perzistentnu
2. Skripta se završava, ali veza **ostaje otvorena**
3. Sledeći zahtev: PHP pronalazi postojeću vezu i ponovo je koristi
4. Nema potrebe za kreiranje nove veze — štedi vreme

### Kako koristiti perzistentne veze

#### Sa PDO

Dodajte opciju `ATTR_PERSISTENT`:

```php
// Normal connection (closes after script)
$pdo = new PDO('mysql:host=localhost;dbname=myapp', 'user', 'password');

// Persistent connection (stays open for reuse)
$pdo = new PDO('mysql:host=localhost;dbname=myapp', 'user', 'password', [
    PDO::ATTR_PERSISTENT => true
]);
```

#### Sa MySQLi

Koristite prefiks `p:` pre naziva hosta:

```php
// Normal connection
$conn = new mysqli('localhost', 'user', 'password', 'myapp');

// Persistent connection
$conn = new mysqli('p:localhost', 'user', 'password', 'myapp');
```

### Prednosti

- **Brže vreme odziva**: Preskakanje kreiranja veze štedi 10-50ms po zahtevu.
- **Manji teret na serveru baze podataka**: Manje operacija povezivanja/prekidanja veze.
- **Bolje performanse pod opterećenjem**: Kada mnogo korisnika šalje zahteve u isto vreme.

### Problemi i rizici

- **Ograničenje broja veza**: Svaka perzistentna veza ostaje otvorena. Ako imate 100 PHP worker-a, možete imati 100 otvorenih veza — čak i ako su većina neaktivne. Ovo može iscrpeti ograničenje broja veza baze podataka.
- **Prljavo stanje (Dirty State)**: Prethodna skripta je možda promenila stanje veze (npr. pokrenula nekomitovanu transakciju, postavila drugi charset ili kreirala privremene tabele). Sledeća skripta nasleđuje ovo stanje.
- **Korišćenje memorije**: Otvorene veze koriste memoriju i na PHP i na strani baze podataka.
- **Nije korisno za kratkotrajne procese**: Funkcioniše samo sa dugotrajnim PHP procesima kao što je PHP-FPM, ne sa CGI.

### Kako rukovati prljavim stanjem

Uvek resetujte stanje veze na početku skripte:

```php
$pdo = new PDO('mysql:host=localhost;dbname=myapp', 'user', 'password', [
    PDO::ATTR_PERSISTENT => true
]);

// Reset any leftover state from previous scripts
$pdo->exec('SET NAMES utf8mb4');
$pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, 1);
```

### Realni scenario

Imate REST API koji opslužuje 1000 zahteva u sekundi. Svaki zahtev pravi jedan upit i traje ukupno 50ms. Bez perzistentnih veza, 20ms od toga se troši samo na otvaranje veze. Sa perzistentnim vezama, to pada na gotovo 0ms — ubrzanje od 40%.

Međutim, vaš MySQL server dozvoljava samo 150 veza. Ako pokrenete 200 PHP-FPM worker-a sa perzistentnim vezama, premašićete ograničenje i dobiti greške "Too many connections". Morate balansirati broj PHP worker-a sa ograničenjem veza baze podataka.

### Kada koristiti perzistentne veze

| Koristite | Nemojte koristiti |
|-----------|-------------------|
| Aplikacije sa visokim prometom | Web sajtovi sa malim prometom |
| PHP-FPM sa connection pooling-om | CGI mod |
| Jednostavni obrasci upita | Složene transakcije po zahtevu |
| Kada je vreme kreiranja veze usko grlo | Kada ne možete kontrolisati max veze |

### Zaključak

Perzistentne veze mogu poboljšati performanse ponovnim korišćenjem veza sa bazom podataka između zahteva. Međutim, dolaze sa rizicima kao što su problemi sa ograničenjem broja veza i prljavo stanje. Koristite ih kada je vreme kreiranja veze stvarno usko grlo i obavezno resetujte stanje veze na početku svakog zahteva.
