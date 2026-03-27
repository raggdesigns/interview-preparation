# REST API Arhitektura

REST (Representational State Transfer) je arhitekturalni stil za dizajniranje mrežnih aplikacija. Većina modernih web API-ja prati REST principe, što ga čini jednom od najčešćih tema na intervjuima.

> **Scenario koji se koristi kroz ovaj dokument:** Dizajniranje API-ja za e-commerce platformu sa proizvodima, narudžbinama i kupcima.

## Preduslovi

- [Struktura HTTP Protokola](http_protocol_structure.sr.md) — format zahteva/odgovora
- [Kako Funkcioniše Internet](how_internet_works.sr.md) — osnove mreže

## Šest REST Ograničenja

REST je definisan sa šest ograničenja. API koji ih sve prati naziva se "RESTful."

| Ograničenje | Značenje | Primer |
|------------|---------|--------|
| Client-Server | Klijent i server su nezavisni | Pretraživač ne zna za bazu podataka; API ne zna za UI |
| Stateless | Svaki zahtev sadrži sve potrebne informacije | Server ne čuva sesiju između zahteva; token se šalje svaki put |
| Cacheable | Odgovori moraju deklarisati da li su cacheable | `Cache-Control: max-age=3600` na listi proizvoda |
| Uniform Interface | Konzistentne URL i metod konvencije | `GET /products/42` uvek vraća proizvod #42 |
| Layered System | Klijent ne može znati da li razgovara sa serverom ili proxy-jem | CDN, load balancer ili API gateway mogu biti između |
| Code on Demand (opciono) | Server može slati izvršni kod | Retko se koristi; JavaScript preuzima pretraživač |

## Richardson Maturity Model

Leonard Richardson je definisao četiri nivoa REST zrelosti. Većina API-ja je na Nivou 2.

```text
Nivo 3: Hipermedia Kontrole (HATEOAS)
  ▲    GET /orders/42 vraća linkove: {"next": "/orders/42/pay"}
  │
Nivo 2: HTTP Glagoli
  │    GET /products, POST /orders, DELETE /orders/42
  │
Nivo 1: Resursi
  │    /products/42 umesto /api?action=getProduct&id=42
  │
Nivo 0: Močvara POX-a
       POST /api sa XML/JSON telom za sve
```

### Nivo 0 — Jedan endpoint, jedna metoda

```http
POST /api HTTP/1.1
Content-Type: application/json

{"action": "getProduct", "id": 42}
```

### Nivo 1 — Resursi kao URL-ovi

```http
POST /products/42 HTTP/1.1

{"action": "get"}
```

### Nivo 2 — HTTP glagoli (većina API-ja se ovde zaustavlja)

```http
GET /products/42 HTTP/1.1
DELETE /orders/99 HTTP/1.1
POST /orders HTTP/1.1
```

### Nivo 3 — HATEOAS (Hypermedia as the Engine of Application State)

```json
{
  "id": 42,
  "status": "pending",
  "_links": {
    "self": {"href": "/orders/42"},
    "pay": {"href": "/orders/42/pay", "method": "POST"},
    "cancel": {"href": "/orders/42/cancel", "method": "POST"}
  }
}
```

Klijent ne hardkoduje URL-ove — prati linkove iz odgovora, poput korisnika koji klikće na linkove na web stranici.

## Dizajn URL-a Resursa

```text
Dobro:                             Loše:
GET    /products                   GET    /getProducts
GET    /products/42                GET    /product?id=42
GET    /products/42/reviews        POST   /getProductReviews
POST   /products                   POST   /createProduct
PUT    /products/42                POST   /updateProduct
DELETE /products/42                GET    /deleteProduct?id=42

Pravila:
- Koristite imenice, ne glagole  (/products ne /getProducts)
- Koristite množinu             (/products ne /product)
- Koristite HTTP metode za akcije (DELETE ne /deleteProduct)
- Ugnezđujte za odnose          (/products/42/reviews)
- Koristite query parametre za filtere (/products?category=electronics&sort=price)
```

## Primer Symfony REST Kontrolera

```php
<?php

namespace App\Controller;

use App\Repository\ProductRepository;
use App\Service\ProductService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/products')]
final class ProductController
{
    public function __construct(
        private readonly ProductRepository $repository,
        private readonly ProductService $service,
    ) {}

    #[Route('', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        $page = $request->query->getInt('page', 1);
        $limit = $request->query->getInt('limit', 20);
        $category = $request->query->get('category');

        $paginator = $this->repository->findFiltered($category, $page, $limit);

        return new JsonResponse([
            'data' => array_map(
                fn ($product) => [
                    'id' => $product->getId(),
                    'name' => $product->getName(),
                    'price' => $product->getPrice(),
                ],
                iterator_to_array($paginator),
            ),
            'meta' => [
                'page' => $page,
                'limit' => $limit,
                'total' => $paginator->count(),
            ],
        ]);
    }

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

        return new JsonResponse([
            'id' => $product->getId(),
            'name' => $product->getName(),
            'price' => $product->getPrice(),
            'description' => $product->getDescription(),
            'category' => $product->getCategory()->getName(),
        ]);
    }

    #[Route('', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $product = $this->service->create($data);

        return new JsonResponse(
            ['id' => $product->getId(), 'name' => $product->getName()],
            Response::HTTP_CREATED,
            ['Location' => "/api/products/{$product->getId()}"],
        );
    }

    #[Route('/{id}', methods: ['DELETE'])]
    public function delete(int $id): Response
    {
        $product = $this->repository->find($id);

        if ($product === null) {
            return new JsonResponse(
                ['error' => 'Product not found'],
                Response::HTTP_NOT_FOUND,
            );
        }

        $this->service->delete($product);

        return new Response(status: Response::HTTP_NO_CONTENT);
    }
}
```

Ključni obrasci:

- `GET /api/products` — vraća stranicu liste sa metapodacima
- `GET /api/products/42` — vraća jedan resurs ili 404
- `POST /api/products` — vraća 201 sa `Location` zaglavljem
- `DELETE /api/products/42` — vraća 204 No Content

## Strategije Verzionisanja API-ja

| Strategija | Primer | Prednosti | Nedostaci |
|-----------|--------|----------|----------|
| URL putanja | `/api/v1/products` | Jednostavna, eksplicitna | URL se menja između verzija |
| Query param | `/api/products?version=1` | Lako podrazumevati | Lako zaboraviti |
| Zaglavlje | `Accept: application/vnd.shop.v1+json` | URL ostaje čist | Teže testirati u pretraživaču |
| Content negotiation | `Accept: application/json; version=1` | Baziran na standardima | Složeno za implementaciju |

Verzionisanje URL putanjom je najčešće u praksi jer je jednostavno i eksplicitno.

## Format Odgovora sa Greškom

Konzistentan format greške čini API-je lakšim za konzumiranje:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "price",
        "message": "Price must be a positive number"
      },
      {
        "field": "name",
        "message": "Name is required"
      }
    ]
  }
}
```

Standardni HTTP status kodovi:

```text
200 OK              → Uspešan GET, PUT, PATCH
201 Created         → Uspešan POST (resurs kreiran)
204 No Content      → Uspešan DELETE
400 Bad Request     → Nevažeći unos (greške validacije)
401 Unauthorized    → Nedostaje ili nevažeća autentikacija
403 Forbidden       → Autentifikovan ali ne autorizovan
404 Not Found       → Resurs ne postoji
409 Conflict        → Sukob stanja resursa (duplikat emaila)
422 Unprocessable   → Semantički nevažeći (važeći JSON, loše vrednosti)
429 Too Many Reqs   → Prekoračeno ograničenje brzine
500 Internal Error  → Greška servera
```

## Česta Pitanja na Intervjuima

### P: Šta čini API RESTful?

**O:** API je RESTful kada prati šest REST ograničenja: **razdvajanje klijent-server**, **bezdržavnost** (nema serverske sesije), **cacheable** (odgovori ukazuju da li mogu biti cached), **uniformni interfejs** (konzistentna URL struktura sa HTTP glagolima), **slojeviti sistem** (proxy-ji/CDN-ovi mogu biti između klijenta i servera) i opciono **kod na zahtev**. U praksi, većina API-ja dostiže Nivo 2 Richardson Maturity Model-a — koriste resurse kao URL-ove i HTTP glagole za akcije — ali preskaču Nivo 3 (HATEOAS).

### P: Kako dizajnirate URL-ove za ugnezđene resurse?

**O:** Ugnezđavajte resurse za izražavanje **odnosa vlasništva**: `GET /products/42/reviews` vraća recenzije koje pripadaju proizvodu 42. Ali izbegavajte duboko ugnezđavanje na više od dva nivoa — umesto `/users/1/orders/42/items/7`, koristite `/order-items/7` sa query filterima. URL treba da odražava hijerarhiju resursa samo kada dete ne može da postoji bez roditelja.

### P: Šta je HATEOAS i zašto se retko koristi?

**O:** HATEOAS (Hypermedia as the Engine of Application State) znači da odgovori uključuju linkove ka povezanim akcijama i resursima, tako da klijent ne hardkoduje URL-ove. Na primer, odgovor narudžbine uključuje `_links: { pay: "/orders/42/pay" }`. Retko se koristi jer većina API-ja služi mobilnim/SPA klijentima koji ionako imaju hardkodovane URL obrasce, i overhead generisanja i parsiranja hipermedia linkova dodaje složenost bez jasne koristi za ove klijente.

## Zaključak

Dizajn REST API-ja se usredsređuje na resurse (imenice u URL-ovima), HTTP glagole (akcije) i status kodove (ishodi). Dobro dizajnirani API koristi konzistentne URL obrasce, odgovarajuće HTTP metode, paginaciju za liste, smislene odgovore sa greškama i verzionisanje od samog početka. Većina produkcijskih API-ja cilja Nivo 2 Richardson Maturity Model-a — koristeći resurse i HTTP glagole — što pruža dobru ravnotežu strukture i jednostavnosti.

## Vidi Takođe

- [Struktura HTTP Protokola](http_protocol_structure.sr.md) — anatomija zahteva/odgovora
- [REST API: POST vs PUT vs PATCH](rest_api_post_vs_put_vs_patch.sr.md) — semantika HTTP metoda
- [REST API: Specifikacija PUT Zahteva](rest_api_put_request_specification.sr.md) — dubinska analiza PUT-a
- [REST vs JSON-RPC](rest_api_vs_json_rpc.sr.md) — alternativni stilovi API-ja
