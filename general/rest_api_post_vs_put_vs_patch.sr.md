# REST API: POST vs PUT vs PATCH

POST, PUT i PATCH su tri HTTP metode koje se koriste za modifikovanje resursa. Razumevanje kada koristiti svaku — posebno razliku između PUT i PATCH — česta je tema na intervjuima.

> **Scenario koji se koristi kroz ovaj dokument:** API za upravljanje proizvodima u e-commerce katalogu.

## Preduslovi

- [REST API Arhitektura](rest_api_architecture.sr.md) — principi dizajna resursa
- [Struktura HTTP Protokola](http_protocol_structure.sr.md) — format zahteva/odgovora

## Brzo Poređenje

| Aspekt | POST | PUT | PATCH |
|--------|------|-----|-------|
| Svrha | Kreiraj novi resurs | Zameni resurs u celosti | Delimično ažuriraj resurs |
| URL | Kolekcija (`/products`) | Specifičan resurs (`/products/42`) | Specifičan resurs (`/products/42`) |
| Idempotentno? | Ne | Da | Može biti, ali nije zagarantovano |
| Telo zahteva | Podaci novog resursa | Kompletna reprezentacija resursa | Samo izmenjeni elementi |
| Tipičan odgovor | 201 Created | 200 OK ili 204 No Content | 200 OK |

## POST — Kreiranje Novog Resursa

POST kreira novi resurs u kolekciji. Server dodeljuje ID.

```http
POST /api/products HTTP/1.1
Content-Type: application/json

{
  "name": "Wireless Mouse",
  "price": 29.99,
  "category": "electronics",
  "stock": 150
}
```

```http
HTTP/1.1 201 Created
Location: /api/products/42
Content-Type: application/json

{
  "id": 42,
  "name": "Wireless Mouse",
  "price": 29.99,
  "category": "electronics",
  "stock": 150,
  "createdAt": "2024-01-15T10:30:00Z"
}
```

**Ključne napomene:**

- Šalje na URL **kolekcije** (`/products`), ne na specifičan resurs
- Vraća **201 Created** sa `Location` zaglavljem koje pokazuje na novi resurs
- **Nije idempotentno** — slanje istog POST-a dva puta kreira dva proizvoda

```php
<?php

#[Route('/api/products', methods: ['POST'])]
public function create(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);

    $product = new Product();
    $product->setName($data['name']);
    $product->setPrice($data['price']);
    $product->setCategory($data['category']);
    $product->setStock($data['stock']);

    $this->entityManager->persist($product);
    $this->entityManager->flush();

    return new JsonResponse(
        $this->serializer->normalize($product),
        Response::HTTP_CREATED,
        ['Location' => "/api/products/{$product->getId()}"],
    );
}
```

## PUT — Zamena Resursa u Celosti

PUT zamenjuje **kompletan** resurs na datom URL-u. Ako izostavite polje, treba ga postaviti na null ili njegovu podrazumevanu vrednost.

```http
PUT /api/products/42 HTTP/1.1
Content-Type: application/json

{
  "name": "Wireless Mouse Pro",
  "price": 39.99,
  "category": "electronics",
  "stock": 200
}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 42,
  "name": "Wireless Mouse Pro",
  "price": 39.99,
  "category": "electronics",
  "stock": 200,
  "updatedAt": "2024-01-15T14:00:00Z"
}
```

**Šta "potpuna zamena" znači:**

```text
Trenutno stanje:
  { name: "Wireless Mouse", price: 29.99, category: "electronics", stock: 150 }

PUT sa nedostajućim poljem:
  { name: "Wireless Mouse Pro", price: 39.99, category: "electronics" }
  ← stock nedostaje

Rezultat (ispravno PUT ponašanje):
  { name: "Wireless Mouse Pro", price: 39.99, category: "electronics", stock: null }
  ← stock je resetovan, NIJE zadržan na 150
```

**Ključne napomene:**

- Šalje na URL **specifičnog resursa** (`/products/42`)
- **Idempotentno** — slanje istog PUT zahteva 10 puta ima isti rezultat kao jednom
- Mora uključiti **kompletnu** reprezentaciju resursa
- Može vratiti **200 OK** (sa telom) ili **204 No Content** (bez tela)
- Može **kreirati** resurs ako ne postoji na toj URL adresi (vraća 201)

```php
<?php

#[Route('/api/products/{id}', methods: ['PUT'])]
public function replace(int $id, Request $request): JsonResponse
{
    $product = $this->repository->find($id);

    if ($product === null) {
        return new JsonResponse(
            ['error' => 'Product not found'],
            Response::HTTP_NOT_FOUND,
        );
    }

    $data = json_decode($request->getContent(), true);

    // PUT zamenjuje SVA polja — nedostajuća polja postaju null
    $product->setName($data['name'] ?? null);
    $product->setPrice($data['price'] ?? null);
    $product->setCategory($data['category'] ?? null);
    $product->setStock($data['stock'] ?? null);

    $this->entityManager->flush();

    return new JsonResponse($this->serializer->normalize($product));
}
```

## PATCH — Delimično Ažuriranje Resursa

PATCH ažurira **samo navedena polja**, ostavljajući sve ostalo nepromenjenim.

```http
PATCH /api/products/42 HTTP/1.1
Content-Type: application/json

{
  "price": 34.99
}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 42,
  "name": "Wireless Mouse Pro",
  "price": 34.99,
  "category": "electronics",
  "stock": 200,
  "updatedAt": "2024-01-15T15:00:00Z"
}
```

Samo se `price` promenio — sva ostala polja zadržala su svoje postojeće vrednosti.

**Ključne napomene:**

- Sadrži **samo polja za ažuriranje** (ne kompletan resurs)
- Nije zagarantovano da je idempotentno (npr. `PATCH {"stock": "+10"}` — inkrementiranje)
- Jednostavnije za klijente — nije potrebno prvo preuzimati kompletan resurs

```php
<?php

#[Route('/api/products/{id}', methods: ['PATCH'])]
public function update(int $id, Request $request): JsonResponse
{
    $product = $this->repository->find($id);

    if ($product === null) {
        return new JsonResponse(
            ['error' => 'Product not found'],
            Response::HTTP_NOT_FOUND,
        );
    }

    $data = json_decode($request->getContent(), true);

    // PATCH ažurira SAMO pružena polja
    if (array_key_exists('name', $data)) {
        $product->setName($data['name']);
    }
    if (array_key_exists('price', $data)) {
        $product->setPrice($data['price']);
    }
    if (array_key_exists('category', $data)) {
        $product->setCategory($data['category']);
    }
    if (array_key_exists('stock', $data)) {
        $product->setStock($data['stock']);
    }

    $this->entityManager->flush();

    return new JsonResponse($this->serializer->normalize($product));
}
```

## JSON Patch (RFC 6902)

Za složena delimična ažuriranja, JSON Patch definiše standardni format za opisivanje promena kao operacija:

```http
PATCH /api/products/42 HTTP/1.1
Content-Type: application/json-patch+json

[
  {"op": "replace", "path": "/price", "value": 34.99},
  {"op": "add", "path": "/tags/-", "value": "on-sale"},
  {"op": "remove", "path": "/discount"}
]
```

Operacije: `add`, `remove`, `replace`, `move`, `copy`, `test`.

Operacija `test` je korisna za uslovljena ažuriranja:

```json
[
  {"op": "test", "path": "/price", "value": 39.99},
  {"op": "replace", "path": "/price", "value": 34.99}
]
```

Ovo menja cenu samo ako je trenutno 39.99 — oblik optimističnog zaključavanja.

## Idempotentnost Objašnjena

Zahtev je **idempotentno** ako njegovo jednokratno izvršavanje ima isti efekat kao višekratno izvršavanje.

```text
POST /products {name: "Mouse"}
  → 1. poziv: kreira proizvod #42     (1 proizvod postoji)
  → 2. poziv: kreira proizvod #43     (2 proizvoda postoje)
  → NIJE idempotentno

PUT /products/42 {name: "Mouse Pro", price: 39.99}
  → 1. poziv: ažurira proizvod #42    (proizvod = Mouse Pro, 39.99)
  → 2. poziv: ažurira proizvod #42    (proizvod = Mouse Pro, 39.99 — isto stanje)
  → Idempotentno

DELETE /products/42
  → 1. poziv: briše proizvod #42      (proizvod nestao)
  → 2. poziv: proizvod već nestao     (još uvek nestao — isto stanje)
  → Idempotentno
```

**Zašto je važno:** Mrežni neuspesi. Ako PUT zahtev istekne, klijent može bezbedno ponoviti — rezultat je isti. Ako POST zahtev istekne, klijent ne zna da li je resurs kreiran, što risira duplikate.

## Česte Greške

| Greška | Zašto je pogrešno | Ispravni pristup |
|--------|-----------------|-----------------|
| Korišćenje POST za ažuriranja | POST nije idempotentno — ponovni pokušaji mogu kreirati duplikate | Koristite PUT ili PATCH |
| Korišćenje PUT sa delimičnim podacima | PUT znači potpunu zamenu — nedostajuća polja postaju null | Koristite PATCH za delimična ažuriranja |
| Korišćenje PATCH za kreiranje resursa | PATCH je za modifikovanje postojećih resursa | Koristite POST ili PUT za kreiranje |
| Ignorisanje idempotentnosti u PUT | PUT mora biti idempotentno po specifikaciji | Osigurajte da isti PUT zahtev uvek daje isti rezultat |
| Korišćenje GET za brisanje | GET mora biti bezopasan (bez sporednih efekata) | Koristite DELETE metodu |

## Česta Pitanja na Intervjuima

### P: Koja je razlika između PUT i PATCH?

**O:** **PUT** zamenjuje kompletan resurs — morate poslati sva polja, a svako nedostajuće polje se postavlja na null ili podrazumevanu vrednost. Idempotentno je. **PATCH** ažurira samo pružena polja, ostavljajući ostala nepromenjenim. Na primer, za promenu samo cene: PUT zahteva slanje `{name, price, category, stock}`, dok PATCH treba samo `{price}`. Koristite PUT kada klijent ima kompletan resurs; koristite PATCH za ciljana ažuriranja.

### P: Da li je PATCH idempotentno?

**O:** PATCH **može biti** idempotentno, ali nije **zagarantovano**. Jednostavno ažuriranje polja poput `{price: 34.99}` je idempotentno (isti rezultat svaki put). Ali operacija poput `{stock: "+10"}` ili JSON Patch `{"op": "add", "path": "/tags/-", "value": "sale"}` (dodavanje u niz) nije — svaki poziv dodaje još jednu stavku. HTTP specifikacija ne zahteva da PATCH bude idempotentno, za razliku od PUT.

### P: Zašto idempotentnost ima značaja u dizajnu API-ja?

**O:** Mrežni zahtevi mogu da padnu ili isteknu. Ako je server obradio zahtev, ali je odgovor izgubljen, klijent treba znati da li je bezbedno **pokušati ponovo**. Idempotentne metode (PUT, DELETE) mogu se bezbedno ponavljati — rezultat je isti. Ne-idempotentne metode (POST) mogu kreirati duplikate. Zbog toga API-ji za plaćanje često koriste **idempotency ključeve**: klijent šalje jedinstveni ključ sa POST zahtevima, a server osigurava da se operacija desi samo jednom po ključu.

## Zaključak

Koristite POST za kreiranje resursa (server dodeljuje ID), PUT za zamenu resursa u celosti (potpuna reprezentacija, idempotentno) i PATCH za ažuriranje specifičnih polja (delimičan payload). Najčešća greška je korišćenje PUT sa delimičnim podacima — to je posao PATCH-a. Idempotentnost je ono što PUT čini bezbednim za ponavljanje i POST rizičnim bez dodatnih zaštitnih mera poput idempotency ključeva.

## Vidi Takođe

- [REST API Arhitektura](rest_api_architecture.sr.md) — principi dizajna API-ja
- [REST API: Specifikacija PUT Zahteva](rest_api_put_request_specification.sr.md) — dubinska analiza PUT semantike
- [HTTP 4xx vs 5xx Greške](http_4xx_vs_5xx_errors.sr.md) — status kodovi odgovora
