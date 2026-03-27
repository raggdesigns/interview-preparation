Late static bindings je mogućnost u PHP-u koja rešava određeni problem vezan za pozive statičkih metoda u kontekstu nasleđivanja. Pre njenog uvođenja u PHP 5.3, kada je statička metoda bila pozvana u podklasi, svaka referenca na `self` unutar te metode pokazivala bi na originalnu klasu gde je metoda definisana, a ne na podklasu. Ovo ponašanje ograničavalo je korisnost statičkih metoda u hijerarhijama nasleđivanja. Late static bindings pruža način da se referencira pozvana klasa u statičkom kontekstu.

### Problem

Razmotrimo primer koji ilustruje problem:

```php
class ParentClass {
    public static function who() {
        echo __CLASS__;
    }

    public static function test() {
        self::who();
    }
}

class ChildClass extends ParentClass {
    public static function who() {
        echo __CLASS__;
    }
}

ChildClass::test(); // Outputs: "ParentClass"
```

U ovom primeru, čak i kada je `test()` pozvan na `ChildClass`, izlaz je "ParentClass" jer `self::who()` referiše na `ParentClass` zbog statičkog bindinga od strane `self`-a.

### Rešenje sa late static bindings

Da bi se rešilo ovo ograničenje, PHP je uveo ključnu reč `static` za upotrebu umesto `self` kako bi se referencirala pozvana klasa, a ne klasa gde je metoda definisana.

**Refactored primer**:

```php
class ParentClass {
    public static function who() {
        echo __CLASS__;
    }

    public static function test() {
        static::who(); // Use 'static' instead of 'self'
    }
}

class ChildClass extends ParentClass {
    public static function who() {
        echo __CLASS__;
    }
}

ChildClass::test(); // Outputs: "ChildClass"
```

Sada `static::who()` ispravno identifikuje da je `ChildClass` bila pozvana klasa, zahvaljujući late static bindings-u.

### Ključne napomene

- **Ključna reč `static::`**: Koristi se za pristup statičkim metodama ili properties u kontekstu klase koja je pozvana.
- **Fleksibilnost u nasleđivanju**: Omogućava fleksibilnije prepisivanje metoda u hijerarhijama klasa.
- **Slučajevi upotrebe**: Posebno korisno za factory patterne, singleton patterne u podklasama i sve situacije gde podklase mogu prepisivati statičke metode.
- **Razmatranje performansi**: Imajte na umu da korišćenje late static bindings-a može imati blagi uticaj na performanse zbog dinamičke prirode određivanja pozvane klase.

### Zaključak

Late static bindings poboljšava objektno-orijentisane mogućnosti PHP-a omogućavajući da pozivi statičkih metoda budu intuitivniji i korisniji u nasleđivanju. Korišćenjem ključne reči `static::`, programeri mogu osigurati da se pozivi statičkih metoda ponašaju kako se očekuje kada su klase proširene, čineći kod ponovo upotrebljivim i lakšim za održavanje.
