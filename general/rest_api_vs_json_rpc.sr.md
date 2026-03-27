# REST vs JSON-RPC

REST i JSON-RPC su dva različita stila za izgradnju API-ja. REST modelira sve kao resurse sa HTTP glagolima, dok JSON-RPC modelira sve kao pozive procedure. Razumevanje kada izabrati koji je važna arhitekturalna odluka.

> **Scenario koji se koristi kroz ovaj dokument:** Servis za plaćanje koji obrađuje naplate, povraćaje i upite o stanju računa.

## Preduslovi

- [REST API Arhitektura](rest_api_architecture.sr.md) — REST principi i dizajn
- [Struktura HTTP Protokola](http_protocol_structure.sr.md) — format zahteva/odgovora

## Ista Operacija, Različiti Stilovi

### REST Pristup

```http
POST /api/payments HTTP/1.1
Content-Type: application/json

{"amount": 99.99, "currency": "USD", "customer_id": 42}
```

```http
HTTP/1.1 201 Created
Location: /api/payments/pay_abc123

{"id": "pay_abc123", "amount": 99.99, "status": "completed"}
```

```http
POST /api/payments/pay_abc123/refund HTTP/1.1
Content-Type: application/json

{"amount": 99.99, "reason": "customer_request"}
```

```http
GET /api/customers/42/balance HTTP/1.1
```

### JSON-RPC Pristup

Svi zahtevi idu na **jedan endpoint**:

```http
POST /api HTTP/1.1
Content-Type: application/json

{"jsonrpc": "2.0", "method": "payment.charge", "params": {"amount": 99.99, "currency": "USD", "customer_id": 42}, "id": 1}
```

```http
HTTP/1.1 200 OK

{"jsonrpc": "2.0", "result": {"id": "pay_abc123", "amount": 99.99, "status": "completed"}, "id": 1}
```

```http
POST /api HTTP/1.1

{"jsonrpc": "2.0", "method": "payment.refund", "params": {"payment_id": "pay_abc123", "amount": 99.99, "reason": "customer_request"}, "id": 2}
```

```http
POST /api HTTP/1.1

{"jsonrpc": "2.0", "method": "customer.getBalance", "params": {"customer_id": 42}, "id": 3}
```

## JSON-RPC 2.0 Protokol

### Format Zahteva

```json
{
  "jsonrpc": "2.0",
  "method": "payment.charge",
  "params": {"amount": 99.99, "currency": "USD"},
  "id": 1
}
```

- `jsonrpc` — uvek "2.0"
- `method` — procedura koja se poziva
- `params` — argumenti (objekat ili niz)
- `id` — identifikator koji dodeljuje klijent za podudaranje zahteva sa odgovorom (izostaviti za notifikacije)

### Odgovor Uspeha

```json
{
  "jsonrpc": "2.0",
  "result": {"id": "pay_abc123", "amount": 99.99, "status": "completed"},
  "id": 1
}
```

### Odgovor Greške

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": {"field": "amount", "reason": "must be positive"}
  },
  "id": 1
}
```

Standardni kodovi grešaka:

| Kod | Značenje |
|-----|---------|
| -32700 | Greška parsiranja (nevažeći JSON) |
| -32600 | Nevažeći zahtev (nedostaju obavezna polja) |
| -32601 | Metoda nije pronađena |
| -32602 | Nevažeći parametri |
| -32603 | Interna greška |
| -32000 do -32099 | Greške definisane serverom |

### Batch Zahtevi

JSON-RPC podržava slanje **više poziva u jednom HTTP zahtevu**:

```json
[
  {"jsonrpc": "2.0", "method": "customer.getBalance", "params": {"customer_id": 42}, "id": 1},
  {"jsonrpc": "2.0", "method": "customer.getBalance", "params": {"customer_id": 43}, "id": 2},
  {"jsonrpc": "2.0", "method": "payment.list", "params": {"status": "pending"}, "id": 3}
]
```

Odgovor (redosled nije zagarantovan):

```json
[
  {"jsonrpc": "2.0", "result": {"balance": 150.00}, "id": 1},
  {"jsonrpc": "2.0", "result": {"balance": 75.50}, "id": 2},
  {"jsonrpc": "2.0", "result": [{"id": "pay_1"}, {"id": "pay_2"}], "id": 3}
]
```

Ovo smanjuje HTTP overhead — jedna TCP konekcija, jedan zahtev, više operacija.

## PHP Implementacija: REST Kontroler

```php
<?php

namespace App\Controller;

use App\Service\PaymentService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/payments')]
final class PaymentController
{
    public function __construct(
        private readonly PaymentService $paymentService,
    ) {}

    #[Route('', methods: ['POST'])]
    public function charge(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $payment = $this->paymentService->charge(
            $data['amount'],
            $data['currency'],
            $data['customer_id'],
        );

        return new JsonResponse(
            ['id' => $payment->getId(), 'status' => $payment->getStatus()],
            Response::HTTP_CREATED,
            ['Location' => "/api/payments/{$payment->getId()}"],
        );
    }

    #[Route('/{id}', methods: ['GET'])]
    public function show(string $id): JsonResponse
    {
        $payment = $this->paymentService->find($id);

        return new JsonResponse([
            'id' => $payment->getId(),
            'amount' => $payment->getAmount(),
            'status' => $payment->getStatus(),
        ]);
    }

    #[Route('/{id}/refund', methods: ['POST'])]
    public function refund(string $id, Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $refund = $this->paymentService->refund($id, $data['amount']);

        return new JsonResponse(
            ['id' => $refund->getId(), 'status' => 'refunded'],
            Response::HTTP_CREATED,
        );
    }
}
```

## PHP Implementacija: JSON-RPC Handler

```php
<?php

namespace App\JsonRpc;

use App\Service\CustomerService;
use App\Service\PaymentService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;

final class JsonRpcHandler
{
    private array $methods;

    public function __construct(
        private readonly PaymentService $paymentService,
        private readonly CustomerService $customerService,
    ) {
        $this->methods = [
            'payment.charge' => $this->handleCharge(...),
            'payment.refund' => $this->handleRefund(...),
            'customer.getBalance' => $this->handleGetBalance(...),
        ];
    }

    #[Route('/api', methods: ['POST'])]
    public function handle(Request $request): JsonResponse
    {
        $body = json_decode($request->getContent(), true);

        if ($body === null) {
            return $this->errorResponse(null, -32700, 'Parse error');
        }

        // Batch request
        if (array_is_list($body)) {
            $responses = array_map(fn (array $req) => $this->dispatch($req), $body);
            return new JsonResponse(array_filter($responses));
        }

        return new JsonResponse($this->dispatch($body));
    }

    private function dispatch(array $request): ?array
    {
        $id = $request['id'] ?? null;
        $method = $request['method'] ?? '';
        $params = $request['params'] ?? [];

        if (!isset($this->methods[$method])) {
            return $this->error($id, -32601, "Method not found: {$method}");
        }

        try {
            $result = ($this->methods[$method])($params);

            // Notification (no id) — no response
            if ($id === null) {
                return null;
            }

            return ['jsonrpc' => '2.0', 'result' => $result, 'id' => $id];
        } catch (\InvalidArgumentException $e) {
            return $this->error($id, -32602, $e->getMessage());
        } catch (\Throwable $e) {
            return $this->error($id, -32603, 'Internal error');
        }
    }

    private function error(?int $id, int $code, string $message): array
    {
        return [
            'jsonrpc' => '2.0',
            'error' => ['code' => $code, 'message' => $message],
            'id' => $id,
        ];
    }

    private function errorResponse(?int $id, int $code, string $message): JsonResponse
    {
        return new JsonResponse($this->error($id, $code, $message));
    }

    private function handleCharge(array $params): array
    {
        $payment = $this->paymentService->charge(
            $params['amount'],
            $params['currency'],
            $params['customer_id'],
        );

        return ['id' => $payment->getId(), 'status' => $payment->getStatus()];
    }

    private function handleRefund(array $params): array
    {
        $refund = $this->paymentService->refund(
            $params['payment_id'],
            $params['amount'],
        );

        return ['id' => $refund->getId(), 'status' => 'refunded'];
    }

    private function handleGetBalance(array $params): array
    {
        $balance = $this->customerService->getBalance($params['customer_id']);

        return ['balance' => $balance];
    }
}
```

## Detaljno Poređenje

| Aspekt | REST | JSON-RPC |
|--------|------|----------|
| Paradigma | Orijentisan na resurse (imenice) | Orijentisan na akcije (glagoli) |
| Endpoint-i | Mnogi (`/payments`, `/customers/42/balance`) | Jedan (`/api`) |
| HTTP metode | GET, POST, PUT, PATCH, DELETE | Samo POST |
| Status kodovi | Puna HTTP semantika (201, 404, 409...) | Uvek 200 (greške u telu odgovora) |
| Keširanje | Ugrađeno putem HTTP keširanja zaglavlja | Nije kešibilno (sve POST) |
| Otkrivanje | URL-ovi su samodokumentujući | Nazivi metoda zahtevaju dokumentaciju |
| Batch obrada | Nije nativna (potrebna prilagođena implementacija) | Ugrađena (niz zahteva) |
| Format greške | HTTP status + telo odgovora | Strukturirani objekat greške sa kodovima |
| Alati | Swagger/OpenAPI, Postman, pretraživači | JSON-RPC specifični alati |
| Slučaj upotrebe | Javni API-ji, aplikacije orijentisane na CRUD | Interni API-ji, složene operacije |

## Kada Izabrati Koji

```text
Izaberite REST kada:
  ✓ Gradite API koji je javno dostupan (klijenti očekuju REST)
  ✓ Operacije orijentisane na CRUD prirodno se mapiraju na resurse
  ✓ Važno je HTTP keširanje (CDN, keš pretraživača)
  ✓ Želite GET endpoint-e koji se mogu testirati u pretraživaču
  ✓ Bitna je otkrivost API-ja (URL-ovi su samodokumentujući)

Izaberite JSON-RPC kada:
  ✓ Interna komunikacija servis-ka-servisu
  ✓ Složene operacije koje se ne mapiraju na CRUD (npr. "prenos novca između računa")
  ✓ Batch zahtevi su važni (smanjite HTTP overhead)
  ✓ Želite jednostavniji protokol (jedan endpoint, uvek POST)
  ✓ Akcije su prirodnije od resursa (glagoli nad imenicama)
```

**Napomena:** Za visokoperformantnu internu komunikaciju, **gRPC** (Protocol Buffers over HTTP/2) se sve više preferira nad i REST-om i JSON-RPC-om zbog binarnog enkodiranja, streaminga i generisanja koda.

## Česta Pitanja na Intervjuima

### P: Kada biste koristili JSON-RPC umesto REST-a?

**O:** JSON-RPC je bolji za **internu komunikaciju servis-ka-servisu** gde operacije ne mapiraju čisto na CRUD (npr. "prenos sredstava između računa," "preračunavanje cena," "spajanje korisničkih naloga"). Takođe je bolji kada su potrebni **batch zahtevi** — slanje više poziva u jednom HTTP zahtevu. REST je bolji za javne API-je gde su keširabilnost, otkrivost i standardna HTTP semantika važni.

### P: Kako se keširanje razlikuje između REST-a i JSON-RPC-a?

**O:** REST prirodno koristi HTTP keširanje — `GET /products/42` može biti keširan od strane CDN-ova, pretraživača i reverse proxy-ja koristeći standardna `Cache-Control` i `ETag` zaglavlja. JSON-RPC šalje sve kao POST na jedan endpoint, koji HTTP keš neće keširati podrazumevano. Za keširanje JSON-RPC odgovora, potrebno je keširanje na nivou aplikacije (npr. Redis), što zahteva više posla.

### P: Koje su prednosti batch zahteva JSON-RPC-a?

**O:** Batch zahtevi šalju više poziva procedura u **jednom HTTP zahtevu**, smanjujući overhead konekcije (DNS, TCP, TLS). Ovo je posebno dragoceno za mobilne klijente sa konekcijama visoke latencije. REST nema standardni mehanizam za batch obradu — trebalo bi prilagođeni endpoint ili koristiti GraphQL za upite nad više resursa.

## Zaključak

REST modelira API-je oko resursa i HTTP semantike, čineći ga idealnim za javne CRUD API-je sa ugrađenim keširanjem i otkrivošću. JSON-RPC modelira API-je oko poziva procedura sa jednostavnijim protokolom (jedan endpoint, strukturirane greške, podrška za batch), čineći ga boljim za interne servise sa složenim operacijama. Većina aplikacija koristi REST za javni API i razmatra JSON-RPC ili gRPC za internu komunikaciju servisa gde je mapiranje na CRUD nezgodno.

## Vidi Takođe

- [REST API Arhitektura](rest_api_architecture.sr.md) — REST principi i dizajn
- [REST API: POST vs PUT vs PATCH](rest_api_post_vs_put_vs_patch.sr.md) — semantika HTTP metoda
- [SOA Arhitektura](soa_architecture.sr.md) — obrasci servisno orijentisane arhitekture
