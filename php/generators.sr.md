U PHP-u, generatori pružaju lak način za implementaciju jednostavnih iteratora. Omogućavaju iteraciju kroz skup podataka bez potrebe za kreiranjem niza u memoriji, što ih čini posebno korisnim za rad sa velikim skupovima podataka ili tokovima podataka. Funkcija postaje generator kada koristi ključnu reč `yield` za prosleđivanje podataka pozivaocu. Ovaj mehanizam pauzira izvršavanje funkcije i čuva njeno stanje, kako bi se moglo nastaviti od mesta gde je stalo.

### Prednosti korišćenja generatora

- **Efikasnost memorije**: Generatori omogućavaju iteraciju kroz velike skupove podataka ili tokove učitavanjem samo malog dela podataka u memoriju u bilo kom trenutku.
- **Jednostavnost**: Pisanje generator funkcije je često jednostavnije od implementacije objekta koji implementira Iterator interfejs.
- **Fleksibilnost**: Generatori se mogu koristiti za produkciju sekvenci podataka u hodu, bez potrebe za generisanjem čitave sekvence pre početka iteracije.

### Primeri korišćenja generatora

#### Generisanje opsega brojeva

Umesto korišćenja `range()`, koji generiše niz, možete koristiti generator za produkciju brojeva u hodu.

```php
function xrange($start, $end, $step = 1) {
    for ($i = $start; $i <= $end; $i += $step) {
        yield $i;
    }
}

foreach (xrange(1, 10) as $number) {
    echo $number . PHP_EOL;
}
```

Ovaj primer iterira od 1 do 10, ispisujući svaki broj, ali bez prethodnog kreiranja niza svih brojeva.

#### Čitanje redova iz datoteke

Generator može efikasno čitati redove iz datoteke bez učitavanja čitave datoteke u memoriju.

```php
function getLines($fileName) {
    $file = fopen($fileName, 'r');
    if (!$file) throw new Exception('Could not open the file!');

    while (($line = fgets($file)) !== false) {
        yield $line;
    }

    fclose($file);
}

foreach (getLines('somefile.txt') as $line) {
    echo $line;
}
```

Ova funkcija otvara datoteku, yield-uje redove jedan po jedan i zatvara datoteku kada završi, koristeći minimalnu memoriju čak i za velike datoteke.

#### Beskonačne sekvence

Generatori su idealni za produkciju beskonačnih sekvenci koje bi bilo nemoguće predstaviti nizom.

```php
function fibonacci() {
    $a = 0;
    $b = 1;

    yield $a;
    yield $b;

    while (true) {
        $next = $a + $b;
        yield $next;
        $a = $b;
        $b = $next;
    }
}

foreach (fibonacci() as $value) {
    if ($value > 100) break;
    echo $value . PHP_EOL;
}
```

Ovaj generator proizvodi Fibonacci sekvencu, prekidajući petlju kada vrednost pređe 100.

### Zaključak

Funkcija postaje generator u PHP-u korišćenjem ključne reči `yield`. Generatori pružaju moćan, memorijski efikasan način za iteraciju kroz skupove podataka ili generisanje sekvenci podataka bez potrebe za međunizom ili implementacijom složenih iterator objekata. Posebno su korisni za rad sa velikim skupovima podataka, beskonačnim sekvencama ili tokovima podataka.
