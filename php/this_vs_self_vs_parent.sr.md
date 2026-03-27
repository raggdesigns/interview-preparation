U PHP-u, razumevanje razlika između `this`, `self`, `static` i `parent` je ključno za pravilno upravljanje nasleđivanjem klasa i pristupom properties i metodama u objektno-orijentisanom programiranju. Svaka ključna reč služi određenoj svrsi i ponaša se različito u zavisnosti od konteksta.

### this vs self

- **`$this`**: Referiše na trenutnu instancu objekta. Koristi se za pristup ne-statičkim properties, metodama i konstantama unutar metoda klase.
- **`self`**: Referiše na trenutnu klasu. Koristi se za pristup statičkim properties, konstantama i metodama. Za razliku od `$this`, `self` ne referiše na instancu klase već na samu klasu.

**Ključne razlike**:

- `$this` se koristi unutar konteksta objekta za referenciranje samog objekta, dok se `self` koristi unutar konteksta klase za referenciranje same klase, čak i u instancama.

### self vs static

- **`self`**: Cilja klasu gde je metoda ili property definisan.
- **`static`**: U kontekstu late static bindings, `static` referiše na pozivajuću klasu. Za razliku od `self`, koji uvek referiše na klasu u kojoj se koristi, `static` se može koristiti za referenciranje klase koja je inicijalno pozvana pri pokretanju.

**Ključne razlike**:

- `self` se razrešava na klasu u kojoj se koristi, što možda nije uvek klasa koja je pozvana. `static`, međutim, koristi PHP-ovu mogućnost late static bindings za referenciranje klase koja je pozvana pri pokretanju, podržavajući polimorfno ponašanje.

### parent vs self

- **`parent`**: Referiše na roditeljsku klasu trenutne klase i koristi se za pristup statičkim properties, konstantama i metodama roditeljske klase.
- **`self`**: Referiše na samu trenutnu klasu.

**Ključne razlike**:

- Koristite `parent` kada trebate pristupiti metodi ili property-ju u roditeljskoj klasi koji je možda bio prepisan u trenutnoj klasi. `self` se koristi za pristup elementima koji su sadržani unutar trenutne klase.

### Primeri

```php
class BaseClass {
    protected static $name = 'BaseClass';

    public static function intro() {
        echo "Hello from " . self::$name;
    }
}

class ChildClass extends BaseClass {
    protected static $name = 'ChildClass';

    public static function intro() {
        echo "Hello from " . static::$name; // Late static binding
    }
}

ChildClass::intro(); // Outputs 'Hello from ChildClass', thanks to static

class ParentExample {
    public static function who() {
        echo "ParentExample";
    }
}

class ChildExample extends ParentExample {
    public static function who() {
        parent::who(); // Accessing parent class method
    }
}

ChildExample::who(); // Outputs 'ParentExample'
```

U ovim primerima, `static` je ključno za late static binding, omogućavajući `ChildClass::intro()` da referencira `ChildClass` uprkos tome što je metoda nasleđena od `BaseClass`. U međuvremenu, `parent` omogućava `ChildExample::who()` da pristupi i izvrši `ParentExample::who()`.

### Zaključak

Izbor između `$this`, `self`, `static` i `parent` zavisi od toga da li trebate pristupiti properties ili metodama iz trenutne instance, trenutne klase, pozvane klase pri pokretanju ili roditeljske klase. Razumevanje ovih razlika je suštinsko za efektivno objektno-orijentisano programiranje u PHP-u.
