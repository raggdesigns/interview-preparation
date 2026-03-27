# REST API: Specifikacija PUT Zahteva

PUT je jedna od najčešće pogrešno shvaćenih HTTP metoda. Programeri je često koriste kao PATCH (delimično ažuriranje), ali HTTP specifikacija definiše PUT kao **potpunu zamenu** resursa na datom URL-u. Razumevanje tačne semantike PUT-a — uključujući idempotentnost, uslovljena ažuriranja i kreiranje — česta je dubinska tema na intervjuima.

> **Scenario koji se koristi kroz ovaj dokument:** Proizvodni API gde klijenti ažuriraju informacije o proizvodu.

## Preduslovi

- [REST API: POST vs PUT vs PATCH](rest_api_post_vs_put_vs_patch.sr.md) — poređenje sve tri metode
- [Struktura HTTP Protokola](http_protocol_structure.sr.md) — format zahteva/odgovora

## PUT Semantika (RFC 7231)

HTTP specifikacija (RFC 7231, Odeljak 4.3.4) definiše PUT kao:

> "PUT metoda zahteva da stanje ciljnog resursa bude **kreirano ili zamenjeno** stanjem definisanim reprezentacijom priloženom u telu poruke zahteva."

Ključne implikacije:

1. **Potpuna zamena** — telo zahteva mora sadržati **kompletnu** reprezentaciju resursa
2. **Idempotentno** — slanje istog zahteva više puta ima isti efekat kao jednom
3. **Može kreirati** — ako resurs ne postoji na URL-u, PUT ga može kreirati
4. **Klijent zna URL** — za razliku od POST-a gde server dodeljuje ID, PUT cilja specifičan URL

## Primeri Zahteva i Odgovora

### Ažuriranje postojećeg resursa

```http
PUT /api/products/42 HTTP/1.1
Content-Type: application/json

{
  "name": "Wireless Mouse Pro",
  "price": 39.99,
  "category": "electronics",
  "stock": 200,
  "description": "Ergonomic wireless mouse with USB-C receiver"
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
  "description": "Ergonomic wireless mouse with USB-C receiver",
  "updatedAt": "2024-01-15T14:00:00Z"
}
```

### Kreiranje putem PUT-a (kada resurs ne postoji)

```http
PUT /api/products/sku-WM-PRO HTTP/1.1
Content-Type: application/json

{
  "name": "Wireless Mouse Pro",
  "price": 39.99,
  "category": "electronics",
  "stock": 100
}
```

```http
HTTP/1.1 201 Created
Location: /api/products/sku-WM-PRO

{
  "id": "sku-WM-PRO",
  "name": "Wireless Mouse Pro",
  "price": 39.99,
  "category": "electronics",
  "stock": 100,
  "createdAt": "2024-01-15T10:00:00Z"
}
```

### Uspešno ažuriranje bez tela

```http
PUT /api/products/42 HTTP/1.1
Content-Type: application/json

{"name": "Wireless Mouse Pro", "price": 39.99, "category": "electronics", "stock": 200}
```

```http
HTTP/1.1 204 No Content
```

204 znači "uspešno, ali nemam ništa da pošaljem nazad." Ovo je validan i čest odgovor za PUT.

## Status Kodovi za PUT

| Kod | Kada | Značenje |
|-----|------|---------|
| 200 OK | Resurs ažuriran | Vraća ažurirani resurs |
| 201 Created | Resurs nije postojao, kreiran | Vraća novi resurs + `Location` zaglavlje |
| 204 No Content | Resurs ažuriran | Nema tela odgovora (uobičajeno za API-je koji ne vraćaju podatke) |
| 400 Bad Request | Nevažeći unos | Greške validacije |
| 404 Not Found | Resurs ne postoji i kreiranje nije podržano | API je odlučio da ne kreira putem PUT-a |
| 409 Conflict | Sukobljeno stanje | Detektovana istovremena modifikacija (pogledajte ETag ispod) |
| 422 Unprocessable Entity | Važeći JSON ali semantički nevažeći | Kršenje poslovnog pravila |

## Uslovljena Ažuriranja sa ETag (Optimističko Zaključavanje)

Da biste sprečili probleme **izgubljenog ažuriranja** (dva klijenta prepisuju izmene jedni drugima), koristite ETag za uslovljene PUT zahteve.

### Problem Izgubljenog Ažuriranja

```text
Vremenski okvir bez ETag-ova:

1. Klijent A: GET /products/42        → {name: "Mouse", price: 29.99, stock: 150}
2. Klijent B: GET /products/42        → {name: "Mouse", price: 29.99, stock: 150}
3. Klijent A: PUT /products/42        → {name: "Mouse Pro", price: 39.99, stock: 150}
   ✓ Uspešno — cena ažurirana
4. Klijent B: PUT /products/42        → {name: "Mouse", price: 29.99, stock: 200}
   ✓ Uspešno — ali promena cene Klijenta A je IZGUBLJENA!
```

### Rešenje: ETag + If-Match

```text
1. Klijent A: GET /products/42
   Odgovor: ETag: "v3"
            {name: "Mouse", price: 29.99, stock: 150}

2. Klijent B: GET /products/42
   Odgovor: ETag: "v3"
            {name: "Mouse", price: 29.99, stock: 150}

3. Klijent A: PUT /products/42
             If-Match: "v3"
             {name: "Mouse Pro", price: 39.99, stock: 150}
   Odgovor: 200 OK, ETag: "v4"
            ✓ Uspešno — verzija odgovara

4. Klijent B: PUT /products/42
             If-Match: "v3"        ← zastarelo! Trenutna verzija je "v4"
             {name: "Mouse", price: 29.99, stock: 200}
   Odgovor: 409 Conflict
            "Resurs je izmenjen od poslednjeg preuzimanja"
            ✗ Klijent B mora ponovo preuzeti i pokušati
```

### PHP Implementacija sa Verzionisanjem

```php
<?php

namespace App\Controller;

use App\Entity\Product;
use App\Repository\ProductRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/products')]
final class ProductController
{
    public function __construct(
        private readonly ProductRepository $repository,
        private readonly EntityManagerInterface $em,
    ) {}

    #[Route('/{id}', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $product = $this->repository->find($id);

        if ($product === null) {
            return new JsonResponse(
                ['error' => 'Product not found'],
                Response::HTTP_NOT_FOUND,
            );
        }

        $response = new JsonResponse($this->serialize($product));
        $response->setEtag((string) $product->getVersion());

        return $response;
    }

    #[Route('/{id}', methods: ['PUT'])]
    public function replace(int $id, Request $request): JsonResponse|Response
    {
        $product = $this->repository->find($id);

        if ($product === null) {
            return new JsonResponse(
                ['error' => 'Product not found'],
                Response::HTTP_NOT_FOUND,
            );
        }

        // Check ETag for conditional update (optimistic locking)
        $ifMatch = $request->headers->get('If-Match');
        if ($ifMatch !== null && $ifMatch !== (string) $product->getVersion()) {
            return new JsonResponse(
                ['error' => 'Resource was modified since you last fetched it'],
                Response::HTTP_CONFLICT,
            );
        }

        $data = json_decode($request->getContent(), true);

        // PUT = full replacement — all fields required
        $product->setName($data['name']);
        $product->setPrice($data['price']);
        $product->setCategory($data['category']);
        $product->setStock($data['stock']);
        $product->setDescription($data['description'] ?? null);

        $this->em->flush(); // Version auto-increments via Doctrine @Version

        $response = new JsonResponse($this->serialize($product));
        $response->setEtag((string) $product->getVersion());

        return $response;
    }

    private function serialize(Product $product): array
    {
        return [
            'id' => $product->getId(),
            'name' => $product->getName(),
            'price' => $product->getPrice(),
            'category' => $product->getCategory(),
            'stock' => $product->getStock(),
            'description' => $product->getDescription(),
        ];
    }
}
```

Kolona `@Version` u entitetu Product automatski se inkrementira pri svakom ažuriranju, čineći je prirodnim ETag-om.

## Potpuna Zamena vs. Delimično Ažuriranje

```text
Trenutni resurs:
  {
    "name": "Wireless Mouse",
    "price": 29.99,
    "category": "electronics",
    "stock": 150,
    "description": "Basic wireless mouse"
  }

PUT zahtev (bez "description"):
  {
    "name": "Wireless Mouse Pro",
    "price": 39.99,
    "category": "electronics",
    "stock": 200
  }

Ispravni PUT rezultat — description postavljen na null:
  {
    "name": "Wireless Mouse Pro",
    "price": 39.99,
    "category": "electronics",
    "stock": 200,
    "description": null        ← OBRISAN, nije zadržan
  }

Šta većina API-ja zapravo radi (neispravno, ali uobičajeno):
  {
    "name": "Wireless Mouse Pro",
    "price": 39.99,
    "category": "electronics",
    "stock": 200,
    "description": "Basic wireless mouse"  ← ZADRŽAN — ovo je PATCH ponašanje
  }
```

Mnogi API-ji implementiraju PUT kao delimično ažuriranje, što tehnički krši specifikaciju. Ako želite delimična ažuriranja, koristite PATCH.

## Idempotentnost u Praksi

PUT je idempotentno jer ponavljanje istog zahteva proizvodi isto stanje resursa:

```text
PUT /products/42  {"name": "Mouse Pro", "price": 39.99}

1. zahtev: proizvod ažuriran na {name: "Mouse Pro", price: 39.99}
2. zahtev: proizvod ažuriran na {name: "Mouse Pro", price: 39.99}  ← isto stanje
3. zahtev: proizvod ažuriran na {name: "Mouse Pro", price: 39.99}  ← isto stanje

Bezbedno za ponavljanje nakon mrežnog neuspeha — nema sporednih efekata od duplikata.
```

**Napomena:** Idempotentnost se odnosi na **stanje resursa**, a ne na sporedne efekte. Timestamp `updatedAt` može se promeniti i unos u audit logu može biti kreiran, ali sam resurs je u istom stanju.

## Česta Pitanja na Intervjuima

### P: Može li PUT da kreira resurs?

**O:** Da. Prema RFC 7231, ako resurs na ciljnom URL-u ne postoji, PUT ga može kreirati i vratiti **201 Created**. Ključna razlika od POST-a: sa PUT-om, **klijent** specificira URL (npr. `PUT /products/sku-WM-PRO`), dok sa POST-om, **server** dodeljuje identifikator (npr. `POST /products` → server kreira `/products/42`). U praksi, mnogi API-ji podržavaju kreiranje samo putem POST-a i vraćaju 404 za PUT na nepostojeće resurse.

### P: Šta je ETag i kako se odnosi na PUT?

**O:** **ETag** (Entity Tag) je identifikator verzije koji server vraća u `ETag` zaglavlju odgovora. Pri ažuriranju putem PUT-a, klijent šalje ETag u `If-Match` zaglavlju. Server ga poredi sa trenutnom verzijom — ako se podudaraju, ažuriranje se nastavlja; ako ne, server vraća **409 Conflict**, što znači da je neko drugi u međuvremenu modifikovao resurs. Ovo se zove **optimističko zaključavanje** — sprečava problem izgubljenog ažuriranja bez zaključavanja na nivou baze podataka.

### P: Zašto PUT treba biti idempotentno?

**O:** Jer mrežni zahtevi mogu tiho da padnu. Ako klijent pošalje PUT zahtev i konekcija istekne, ne zna da li je server obradio zahtev. Idempotentnost garantuje da **ponavljanje istog PUT-a daje isti rezultat**, tako da klijent može bezbedno ponovo poslati bez prouzrokovanja nedoslednosti. Ovo je za razliku od POST-a, gde ponavljanje može kreirati duplikate resurse.

## Zaključak

PUT zamenjuje kompletan resurs na specifičnom URL-u i idempotentno je po specifikaciji. Može kreirati resurse (201) ili ih ažurirati (200/204). Uslovljena ažuriranja sa `ETag` + `If-Match` sprečavaju problem izgubljenog ažuriranja putem optimističkog zaključavanja. Najčešća greška je tretiranje PUT-a kao delimičnog ažuriranja (to je PATCH) — ispravne PUT implementacije postavljaju nedostajuća polja na null umesto da zadržavaju njihove prethodne vrednosti.

## Vidi Takođe

- [REST API: POST vs PUT vs PATCH](rest_api_post_vs_put_vs_patch.sr.md) — poređenje sve tri metode
- [REST API Arhitektura](rest_api_architecture.sr.md) — principi dizajna API-ja
- [Optimističko i Pesimističko Zaključavanje](../highload/optimistic_pessimistic_lock.sr.md) — strategije kontrole konkurentnosti
