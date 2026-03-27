JavaScript je jednonitni — može raditi samo jednu stvar odjednom. Ali obrađuje asinhrone operacije (mrežne zahteve, tajmere, čitanje fajlova) kroz **event loop** i neblokirajući I/O. Promise-i, async/await i fetch su moderni alati za rad sa asinhronim kodom.

### Problem — Zašto async?

```javascript
// Bez async-a, ovo bi zamrznulo browser/Node.js:
const response = httpGetSync("https://api.example.com/users");  // Blokira 2 sekunde
console.log(response);  // Ništa se ne dešava dok zahtev nije završen
renderPage();            // Korisnik čeka 2 sekunde sa zamrznutom stranicom

// Sa async-om, program nastavlja dok čeka:
fetch("https://api.example.com/users")    // Pokreće zahtev, odmah vraća
    .then(response => response.json())     // Izvršava se kada odgovor stigne
    .then(data => console.log(data));      // Izvršava se kada je JSON parsiran
renderPage();  // Izvršava se odmah — stranica nije zamrznuta
```

### Callback-ovi — Stari način

Pre Promise-a, asinhroni kod je koristio callback-ove:

```javascript
// Obrazac callback-a
function getUser(id, callback) {
    setTimeout(function() {
        callback(null, { id: id, name: "Dragan" });
    }, 1000);
}

getUser(42, function(error, user) {
    if (error) {
        console.error(error);
        return;
    }
    console.log(user.name);
});
```

**Callback pakao** — ugnježdeni callback-ovi postaju nečitljivi:

```javascript
getUser(42, function(err, user) {
    getOrders(user.id, function(err, orders) {
        getOrderDetails(orders[0].id, function(err, details) {
            getShippingInfo(details.shippingId, function(err, shipping) {
                console.log(shipping.status);  // 4 nivoa duboko!
            });
        });
    });
});
```

Promise-i i async/await rešavaju ovaj problem.

### Promise-i

Promise predstavlja vrednost koja će biti dostupna **u budućnosti**. Ima tri stanja:

- **Pending** — početno stanje, operacija u toku
- **Fulfilled** (razrešeno) — operacija uspešno završena
- **Rejected** — operacija neuspela

```javascript
// Kreiranje Promise-a
const promise = new Promise(function(resolve, reject) {
    // Asinhrona operacija
    setTimeout(function() {
        const success = true;
        if (success) {
            resolve({ id: 42, name: "Dragan" });  // Fulfilled
        } else {
            reject(new Error("User not found"));    // Rejected
        }
    }, 1000);
});

// Korišćenje Promise-a
promise
    .then(function(user) {
        console.log(user.name);  // "Dragan" — izvršava se pri uspehu
    })
    .catch(function(error) {
        console.error(error.message);  // Izvršava se pri neuspehu
    })
    .finally(function() {
        console.log("Done");  // Izvršava se uvek (uspeh ili neuspeh)
    });
```

### Lančanje Promise-a

Svaki `.then()` vraća novi Promise, tako da ih možeš ulančati:

```javascript
// Ravni lanac umesto ugnježdenih callback-ova
getUser(42)
    .then(user => getOrders(user.id))
    .then(orders => getOrderDetails(orders[0].id))
    .then(details => getShippingInfo(details.shippingId))
    .then(shipping => console.log(shipping.status))
    .catch(error => console.error("Something failed:", error.message));
```

Uporedi ovo sa primerom callback pakla gore — mnogo čišće.

### Promise.all, Promise.race, Promise.allSettled

```javascript
// Promise.all — čeka da se SVE promise završe
// Brzo ne uspeva: ako bilo koji promise bude odbijen, cela stvar je odbijena
const [users, orders, products] = await Promise.all([
    fetch("/api/users").then(r => r.json()),
    fetch("/api/orders").then(r => r.json()),
    fetch("/api/products").then(r => r.json()),
]);
// Sva tri zahteva se izvršavaju PARALELNO, ne jedan za drugim

// Promise.race — vraća PRVI promise koji se završi (uspeh ili neuspeh)
const fastest = await Promise.race([
    fetch("https://api1.example.com/data"),
    fetch("https://api2.example.com/data"),
]);

// Promise.allSettled — čeka SVE, čak i ako neki ne uspeju
const results = await Promise.allSettled([
    fetch("/api/users"),
    fetch("/api/broken-endpoint"),  // Ovo može ne uspeti
    fetch("/api/products"),
]);
// results = [
//   { status: "fulfilled", value: Response },
//   { status: "rejected", reason: Error },
//   { status: "fulfilled", value: Response },
// ]
```

### Async/Await

`async/await` je sintaksni šećer nad Promise-ima. Čini asinhroni kod da izgleda kao sinhroni kod:

```javascript
// Sa Promise-ima
function loadUser(id) {
    return fetch(`/api/users/${id}`)
        .then(response => response.json())
        .then(user => {
            console.log(user.name);
            return user;
        })
        .catch(error => {
            console.error("Failed:", error);
        });
}

// Sa async/await — ista logika, lakše za čitanje
async function loadUser(id) {
    try {
        const response = await fetch(`/api/users/${id}`);
        const user = await response.json();
        console.log(user.name);
        return user;
    } catch (error) {
        console.error("Failed:", error);
    }
}
```

**Pravila:**
- `await` se može koristiti samo unutar `async` funkcije
- `await` pauzira izvršavanje funkcije dok se Promise ne razreši
- `async` funkcije uvek vraćaju Promise

```javascript
// Sekvencijalno — jedno za drugim (sporo)
async function loadData() {
    const users = await fetch("/api/users").then(r => r.json());      // Čeka 500ms
    const orders = await fetch("/api/orders").then(r => r.json());    // Čeka 500ms
    const products = await fetch("/api/products").then(r => r.json()); // Čeka 500ms
    // Ukupno: ~1500ms
}

// Paralelno — sve odjednom (brzo)
async function loadData() {
    const [users, orders, products] = await Promise.all([
        fetch("/api/users").then(r => r.json()),
        fetch("/api/orders").then(r => r.json()),
        fetch("/api/products").then(r => r.json()),
    ]);
    // Ukupno: ~500ms (najduži pojedinačni zahtev)
}
```

### Fetch API

`fetch()` je moderan način za pravljenje HTTP zahteva u JavaScript-u. Vraća Promise.

```javascript
// GET zahtev
const response = await fetch("https://api.example.com/users");
const users = await response.json();

// POST zahtev
const response = await fetch("https://api.example.com/users", {
    method: "POST",
    headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer eyJhbGciOi...",
    },
    body: JSON.stringify({
        name: "Dragan",
        email: "dragan@example.com",
    }),
});

if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
}

const newUser = await response.json();
console.log(newUser.id);  // 42
```

**Važno:** `fetch()` NE odbija HTTP greške (404, 500). Odbija samo pri mrežnim neuspesima. Moraš proveriti `response.ok`:

```javascript
// LOŠE — ovo NE hvata greške 404 ili 500
fetch("/api/users/999")
    .then(response => response.json())  // Izvršava se čak i na 404!
    .catch(error => console.error(error));  // Hvata samo mrežne neuspehe

// DOBRO — proveri response.ok
async function getUser(id) {
    const response = await fetch(`/api/users/${id}`);

    if (!response.ok) {
        if (response.status === 404) {
            throw new Error("User not found");
        }
        throw new Error(`Server error: ${response.status}`);
    }

    return response.json();
}
```

### Fetch vs Axios vs XMLHttpRequest

| Funkcionalnost | fetch | Axios | XMLHttpRequest |
|---------|-------|-------|---------------|
| Ugrađeno | Da (moderni browser-i + Node 18+) | Ne (biblioteka) | Da (staro) |
| Vraća | Promise | Promise | Koristi callback-ove |
| Rukovanje greškama | Mora proveriti `response.ok` | Odbija na 4xx/5xx | Ručno |
| Otkazivanje zahteva | AbortController | CancelToken | abort() |
| Parsiranje JSON-a | Ručno (`.json()`) | Automatski | Ručno |
| Interceptori | Ne | Da | Ne |

### Event loop

Razumevanje zašto async funkcioniše zahteva poznavanje event loop-a:

```
┌───────────────────────────┐
│        Call Stack          │  ← Izvršava sinhroni kod
│  (jedna stvar odjednom)   │
└───────────┬───────────────┘
            │
            ▼
┌───────────────────────────┐
│       Web APIs /          │  ← Obrađuje asinhrone operacije
│     Node.js APIs          │     (setTimeout, fetch, I/O)
└───────────┬───────────────┘
            │
            ▼
┌───────────────────────────┐
│     Callback Queue        │  ← Callback-ovi u redu čekanja
│  (Task Queue + Microtask) │     koji čekaju da se izvršavaju
└───────────┬───────────────┘
            │
            ▼
┌───────────────────────────┐
│       Event Loop          │  ← Premešta callback-ove iz reda
│   "Da li je call stack    │     u call stack kada je prazan
│        prazan?"           │
└───────────────────────────┘
```

```javascript
console.log("1");                         // Sinhrono — izvršava se odmah

setTimeout(() => console.log("2"), 0);    // Asinhrono — ide u red zadataka

Promise.resolve().then(() => console.log("3"));  // Asinhrono — ide u red mikrozadataka

console.log("4");                         // Sinhrono — izvršava se odmah

// Izlaz: 1, 4, 3, 2
// Zašto? Mikrozadaci (Promise-i) se izvršavaju pre regularnih zadataka (setTimeout)
```

### Obrasci rukovanja greškama

```javascript
// Obrazac 1: try/catch sa async/await
async function processOrder(orderId) {
    try {
        const order = await getOrder(orderId);
        const payment = await processPayment(order);
        const shipment = await createShipment(order);
        return { order, payment, shipment };
    } catch (error) {
        // Hvata greške od bilo kojeg od tri await poziva
        console.error("Order processing failed:", error.message);
        throw error;  // Ponovo baci ako treba da se caller pozabavi time
    }
}

// Obrazac 2: individualno rukovanje greškama
async function loadDashboard() {
    const [usersResult, ordersResult] = await Promise.allSettled([
        fetch("/api/users").then(r => r.json()),
        fetch("/api/orders").then(r => r.json()),
    ]);

    const users = usersResult.status === "fulfilled" ? usersResult.value : [];
    const orders = ordersResult.status === "fulfilled" ? ordersResult.value : [];

    return { users, orders };
    // Dashboard se učitava čak i ako jedan API poziv ne uspe
}
```

### Zaključak

JavaScript obrađuje asinhrone operacije kroz Promise-e i event loop. Promise-i predstavljaju buduće vrednosti sa tri stanja (pending, fulfilled, rejected). Async/await je sintaksni šećer koji čini Promise lance čitljivim. `fetch()` je ugrađeni HTTP klijent koji vraća Promise-e — zapamti da proveriš `response.ok` za HTTP greške. Koristi `Promise.all()` za paralelno pokretanje nezavisnih zahteva. Event loop obrađuje mikrozadatke (Promise-e) pre makrozadataka (setTimeout). Ovi koncepti se često pojavljuju na intervjuima čak i za backend programere jer moderne aplikacije intenzivno interaguju sa JavaScript frontend-ima.

> Vidi takođe: [Funkcije, strelice i zatvorenja](js_fundamentals.sr.md), [REST API arhitektura](../general/rest_api_architecture.md), [HTTP streaming](../general/http_streaming.md)
