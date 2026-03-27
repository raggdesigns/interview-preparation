
# Lazy Loading za klase

Lazy loading je dizajn obrazac koji ima za cilj odlaganje kreiranja objekta, izračunavanja vrednosti ili nekog drugog skupog procesa do prvog puta kada je potreban. Ovaj obrazac može značajno poboljšati performanse i efikasnost resursa u softverskim aplikacijama.

## Kako funkcioniše Lazy Loading

U kontekstu objektno-orijentisanog programiranja, lazy loading obično uključuje kreiranje proxy objekta koji deluje kao zamena za pravi objekat. Proxy objekat odlaže kreiranje skupog objekta sve dok njegova funkcionalnost zaista nije potrebna. Ovaj pristup može smanjiti vreme pokretanja i korišćenje memorije, posebno ako se objekat nikada ne koristi.

## Prednosti Lazy Loadinga

- **Poboljšane performanse**: Odlaganjem inicijalizacije objekta, aplikacije mogu brže startovati, što je posebno korisno u scenarijima gde se mnogi objekti ne koriste odmah ili čak nikad tokom određenog pokretanja.
- **Smanjeno korišćenje memorije**: Memorijski resursi se koriste efikasnije pošto se objekti kreiraju tek kada su potrebni.
- **Bolje upravljanje resursima**: Resursi poput konekcija na bazu podataka ili hendlova fajlova koji su asocirani sa objektom ne alociraju se sve dok to nije neophodno.

## Slučajevi upotrebe

- **Pokretanje aplikacije**: Ubrzajte vreme učitavanja aplikacije odlaganjem inicijalizacije teških servisa ili komponenti dok nisu potrebni.
- **Alociranje resursa na zahtev**: Korisno u scenarijima gde su resursi ograničeni i želite ih alocirati samo kada je potrebno.
- **Interakcije sa bazom podataka**: Odložite učitavanje podataka iz baze podataka dok zaista nisu potrebni, minimizirajući nepotrebno preuzimanje podataka i korišćenje memorije.

## Primer: Implementacija Lazy Loadinga u PHP-u

Jednostavan način za implementaciju lazy loadinga u PHP-u je kroz korišćenje closure i magične metode `__get()`.

```php
class LazyLoader
{
    private $properties = [];

    public function __set($name, $value)
    {
        $this->properties[$name] = $value;
    }

    public function __get($name)
    {
        if (isset($this->properties[$name]) && is_callable($this->properties[$name])) {
            $this->properties[$name] = $this->properties[$name]();
        }

        return $this->properties[$name] ?? null;
    }
}

// Usage
$lazyLoader = new LazyLoader();
$lazyLoader->expensiveObject = function() {
    return new ExpensiveObject();
};

// The ExpensiveObject is created only when it's first accessed.
$expensiveObject = $lazyLoader->expensiveObject;
```

## Zaključak

Lazy loading je moćan obrazac koji može pomoći u poboljšanju performansi i efikasnosti vaše aplikacije odlaganjem inicijalizacije objekata dok zaista nisu potrebni. Implementacija lazy loadinga zahteva pažljivo razmatranje kada i kako se objekti koriste kako bi se osiguralo efikasno upravljanje resursima.
