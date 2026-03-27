JavaScript je jednonitni, dinamički tipizirani jezik koji radi u browser-u i u Node.js-u. Čak i kao backend PHP programer, susrećeš JavaScript na intervjuima — posebno zatvorenja, strelice i kako funkcije funkcionišu.

### Deklaracija funkcije vs Izraz funkcije

Postoje dva glavna načina za definisanje funkcije u JavaScript-u:

```javascript
// Deklaracija funkcije — hoistovana (može biti pozvana pre definisanja)
function greet(name) {
    return `Hello, ${name}!`;
}

// Izraz funkcije — NIJE hoistovan (mora biti definisan pre upotrebe)
const greet = function(name) {
    return `Hello, ${name}!`;
};

// Oba se pozivaju na isti način
greet("Dragan");  // "Hello, Dragan!"
```

**Hoisting** znači da JavaScript premešta deklaracije funkcija na vrh opsega pre izvršavanja koda:

```javascript
// Ovo radi — deklaracije funkcija su hoistovane
sayHello();  // "Hello!"
function sayHello() {
    console.log("Hello!");
}

// Ovo NE USPEVA — izrazi funkcija NISU hoistovani
sayHi();  // ReferenceError: Cannot access 'sayHi' before initialization
const sayHi = function() {
    console.log("Hi!");
};
```

### Strelice (Arrow Functions)

Strelice su kraća sintaksa za izraze funkcija, uvedene u ES6 (2015):

```javascript
// Regularna funkcija
const add = function(a, b) {
    return a + b;
};

// Strelica — kraće
const add = (a, b) => {
    return a + b;
};

// Strelica — još kraće (implicitno vraćanje za jedan izraz)
const add = (a, b) => a + b;

// Jedan parametar — zagrade opcionalne
const double = x => x * 2;

// Bez parametara — zagrade obavezne
const getRandom = () => Math.random();
```

### Strelice vs Regularne funkcije — Ključne razlike

Najvažnija razlika je kako `this` funkcioniše:

```javascript
// Regularna funkcija — `this` zavisi od TOGA KAKO je funkcija pozvana
const user = {
    name: "Dragan",
    greet: function() {
        console.log(`Hello, ${this.name}`);  // `this` = user objekat
    }
};
user.greet();  // "Hello, Dragan" ✓

// Strelica — `this` je nasleđen iz OKOLNOG OPSEGA
const user = {
    name: "Dragan",
    greet: () => {
        console.log(`Hello, ${this.name}`);  // `this` = spoljni opseg (window/undefined)
    }
};
user.greet();  // "Hello, undefined" ✗
```

**Pravilo:** Strelice NEMAJU sopstveni `this`. Koriste `this` iz opsega gde su **definisane**, ne gde su **pozvane**.

**Gde strelice blistaju:**

```javascript
// Callback-ovi — strelice čuvaju spoljni `this`
class UserService {
    constructor() {
        this.users = [];
    }

    fetchUsers() {
        // Strelica čuva `this` = instanca UserService-a
        fetch('/api/users')
            .then(response => response.json())
            .then(data => {
                this.users = data;  // `this` ispravno referira na UserService
            });
    }
}

// Sa regularnom funkcijom, morao bi sačuvati `this`:
fetchUsers() {
    const self = this;  // Sačuvaj referencu
    fetch('/api/users')
        .then(function(response) { return response.json(); })
        .then(function(data) {
            self.users = data;  // Mora koristiti `self`, ne `this`
        });
}
```

| Funkcionalnost | Regularna funkcija | Strelica |
|---------|-----------------|----------------|
| `this` vezivanje | Dinamičko (zavisi od pozivaoca) | Leksičko (iz okolnog opsega) |
| `arguments` objekat | Da | Ne |
| Može biti konstruktor | Da (`new Foo()`) | Ne |
| Ima `prototype` | Da | Ne |
| Hoisting | Da (deklaracije) | Ne |

### Zatvorenja (Closures)

Zatvorenje je funkcija koja **pamti promenljive** iz opsega gde je kreirana, čak i nakon što taj opseg završi izvršavanje.

```javascript
function createCounter() {
    let count = 0;  // Ova promenljiva je "zatvorena"

    return function() {
        count++;        // Unutrašnja funkcija još uvek ima pristup `count`-u
        return count;
    };
}

const counter = createCounter();
console.log(counter());  // 1
console.log(counter());  // 2
console.log(counter());  // 3

// `count` nije dostupan spolja
console.log(count);  // ReferenceError: count is not defined
```

Unutrašnja funkcija "zatvara" promenljivu `count` — čuva referencu na nju čak i nakon što `createCounter()` vrati.

### Kako zatvorenja funkcionišu

```javascript
function outer() {
    const message = "Hello";  // Promenljiva u opsegu spoljne funkcije

    function inner() {
        console.log(message);  // Pristupa promenljivoj iz spoljnog opsega
    }

    return inner;
}

const fn = outer();  // outer() završava, ali `message` NIJE sakupljen kao otpad
fn();                // "Hello" — unutrašnja funkcija još uvek ima pristup `message`-u
```

JavaScript čuva promenljivu `message` živom jer `inner()` ima referencu na nju. Ovo je zatvorenje — kombinacija funkcije i njenog okolnog stanja.

### Praktični primeri zatvorenja

**1. Privatne promenljive (enkapsulacija)**

```javascript
function createUser(name) {
    let loginCount = 0;  // Privatno — ne može se pristupiti spolja

    return {
        getName: () => name,
        login: () => {
            loginCount++;
            console.log(`${name} logged in. Total: ${loginCount}`);
        },
        getLoginCount: () => loginCount,
    };
}

const user = createUser("Dragan");
user.login();           // "Dragan logged in. Total: 1"
user.login();           // "Dragan logged in. Total: 2"
user.getLoginCount();   // 2
// user.loginCount      // undefined — privatno!
```

**2. Fabrike funkcija**

```javascript
function createMultiplier(factor) {
    return (number) => number * factor;
}

const double = createMultiplier(2);
const triple = createMultiplier(3);

double(5);  // 10
triple(5);  // 15
```

**3. Event handler-i sa stanjem**

```javascript
function createClickHandler(buttonName) {
    let clickCount = 0;

    return function() {
        clickCount++;
        console.log(`${buttonName} clicked ${clickCount} times`);
    };
}

const handleSave = createClickHandler("Save");
const handleDelete = createClickHandler("Delete");

// Svaki handler ima sopstveni nezavisni `clickCount`
handleSave();    // "Save clicked 1 times"
handleSave();    // "Save clicked 2 times"
handleDelete();  // "Delete clicked 1 times"
```

### Uobičajena zamka zatvorenja — Promenljiva petlje

```javascript
// PROBLEM — sve funkcije dele isti `i`
for (var i = 0; i < 3; i++) {
    setTimeout(function() {
        console.log(i);
    }, 1000);
}
// Izlaz: 3, 3, 3  (ne 0, 1, 2!)
// Jer je `var` opseg funkcije, sva zatvorenja dele isti `i`
// Do trenutka kada setTimeout radi, petlja je završena i i = 3

// REŠENJE 1 — koristi `let` (opseg bloka, kreira novu promenljivu za svaku iteraciju)
for (let i = 0; i < 3; i++) {
    setTimeout(function() {
        console.log(i);
    }, 1000);
}
// Izlaz: 0, 1, 2  ✓

// REŠENJE 2 — IIFE (Immediately Invoked Function Expression)
for (var i = 0; i < 3; i++) {
    (function(j) {
        setTimeout(function() {
            console.log(j);
        }, 1000);
    })(i);
}
// Izlaz: 0, 1, 2  ✓
```

### Zatvorenja u poređenju sa PHP-om

PHP takođe ima zatvorenja, ali sa ključnom razlikom — moraš eksplicitno deklarisati koje promenljive hvatat koristeći `use`:

```php
// PHP — eksplicitno hvatanje sa `use`
function createCounter(): Closure {
    $count = 0;
    return function() use (&$count) {  // Mora koristiti ključnu reč `use`
        $count++;
        return $count;
    };
}

$counter = createCounter();
echo $counter();  // 1
echo $counter();  // 2
```

```javascript
// JavaScript — automatsko hvatanje, nema posebne sintakse
function createCounter() {
    let count = 0;
    return function() {  // Automatski hvata `count`
        count++;
        return count;
    };
}
```

### Lanac opsega

JavaScript ima tri nivoa opsega:

```javascript
const global = "I'm global";  // Globalni opseg

function outer() {
    const outerVar = "I'm outer";  // Opseg funkcije

    function inner() {
        const innerVar = "I'm inner";  // Opseg funkcije

        // inner može pristupiti svim trima:
        console.log(innerVar);   // ✓ sopstveni opseg
        console.log(outerVar);   // ✓ zatvorenje — opseg roditelja
        console.log(global);     // ✓ globalni opseg
    }

    // outer može pristupiti dvama:
    console.log(outerVar);   // ✓ sopstveni opseg
    console.log(global);     // ✓ globalni opseg
    console.log(innerVar);   // ✗ ReferenceError — unutrašnji opseg nije dostupan
}
```

### Zaključak

JavaScript funkcije mogu biti deklarisane (hoistovane) ili izražene (nisu hoistovane). Strelice pružaju kraću sintaksu i nasleđuju `this` iz okolnog opsega — čineći ih idealnim za callback-ove. Zatvorenja dozvoljavaju funkcijama da pamte promenljive iz opsega kreiranja, omogućavajući privatno stanje, fabrike funkcija i event handler-e sa stanjem. Ključna razlika od PHP zatvorenja je da JavaScript hvata promenljive automatski dok PHP zahteva ključnu reč `use`. Razumevanje ovih koncepata je neophodno za rad sa modernim JavaScript-om i za tehničke intervjue.

> Vidi takođe: [Asinhroni JavaScript — Promise-i, async/await, fetch](async_javascript.sr.md), [PHP zatvorenja](../php/closure_vs_anonymous_function.sr.md)
