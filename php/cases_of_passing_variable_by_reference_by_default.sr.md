U PHP-u, promenljive se po defaultu prosleđuju po vrednosti, što znači da se pravi kopija promenljive u opsegu funkcije, i promene promenljive unutar funkcije ne utiču na originalnu promenljivu van funkcije. Međutim, PHP takođe podržava prosleđivanje promenljivih po referenci, što funkcijama omogućava da menjaju originalnu promenljivu. Po defaultu, PHP prosleđuje promenljive po vrednosti, ali postoje specifični slučajevi u kojima se promenljive prosleđuju po referenci:

### 1. Dodela po referenci

Možete eksplicitno napraviti referencu na promenljivu koristeći operator reference (`&`) u dodeli.

```php
$a = 10;
$b = &$a; // $b is a reference to $a.
$b = 20;
echo $a; // Outputs: 20
```

### 2. Argumenti funkcije po referenci

Argumenti funkcije mogu se prosleđivati po referenci dodavanjem ampersanda (`&`) ispred parametra. To znači da će sve promene parametra unutar funkcije biti odražene na originalnoj promenljivoj.

```php
function increment(&$value) {
    $value++;
}

$count = 1;
increment($count);
echo $count; // Outputs: 2
```

### 3. Vraćanje referenci

Funkcija može da vrati referencu na promenljivu koristeći operator `&` i u deklaraciji funkcije i pri njenom pozivanju.

```php
function &getValue() {
    static $value = 100;
    return $value;
}

$newVal = &getValue();
$newVal = 200;
echo getValue(); // Outputs: 200
```

### 4. Foreach petlja

Kada iterirate kroz nizove koristeći `foreach` petlju, možete iterirati po referenci kako biste menjali originalne elemente niza.

```php
$arr = [1, 2, 3];
foreach ($arr as &$value) {
    $value = $value * 2;
}
unset($value); // Break the reference with the last element
print_r($arr); // Outputs: Array ( [0] => 2 [1] => 4 [2] => 6 )
```

### 5. Podrazumevano prosleđivanje po referenci u određenim ugrađenim PHP funkcijama

Neke ugrađene PHP funkcije i metode koriste reference po defaultu. Uobičajen primer je upotreba `preg_match` gde se poklapanja prosleđuju po referenci kako bi ih funkcija popunila.

```php
$str = "PHP is great";
preg_match('/is/', $str, $matches);
print_r($matches); // $matches is filled by reference.
```

### Zaključak

Mada PHP prosleđuje promenljive po vrednosti po defaultu, prosleđivanje po referenci se eksplicitno vrši koristeći operator `&`. Ovo je korisno u situacijama kada želite da omogućite funkciji da direktno menja svoje argumente ili da izbegnete kopiranje velikih količina podataka radi performansi. Važno je koristiti reference oprezno, jer mogu dovesti do koda koji je teže razumeti i održavati.
