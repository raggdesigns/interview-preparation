# HTTP Streaming

Tradicionalni HTTP prati ciklus zahtev-odgovor: klijent šalje zahtev, čeka da server završi obradu i prima kompletan odgovor odjednom. HTTP streaming prekida ovaj obrazac slanjem podataka u komadima dok postaju dostupni, omogućavajući ažuriranja u realnom vremenu bez ponovljenog pollinga.

> **Scenario koji se koristi kroz ovaj dokument:** Kontrolna tabla koja prikazuje ažuriranja statusa narudžbina uživo za admin panel e-commerce platforme.

## Preduslovi

- [Struktura HTTP Protokola](http_protocol_structure.sr.md) — standardni format zahteva-odgovora
- [Kako Funkcioniše Internet](how_internet_works.sr.md) — osnove mreže

## Polling vs. Streaming

```text
Polling (svakih 2s):
  Klijent ──GET──→ Server    "Ima li ažuriranja?"  → "Ne"
  Klijent ──GET──→ Server    "Ima li ažuriranja?"  → "Ne"
  Klijent ──GET──→ Server    "Ima li ažuriranja?"  → "Da: narudžbina #42 otpremljena"
  Klijent ──GET──→ Server    "Ima li ažuriranja?"  → "Ne"
  Problem: Rasipani zahtevi, zakasnjela ažuriranja (do 2s kašnjenja)

Streaming (jedna konekcija):
  Klijent ──GET──→ Server    "Šalji mi ažuriranja"
                  Server ──→ "narudžbina #42 otpremljena"
                  Server ──→ "narudžbina #43 plaćena"
                  Server ──→ "narudžbina #44 otkazana"
  (konekcija ostaje otvorena, ažuriranja stižu odmah)
```

## Server-Sent Events (SSE)

SSE je standard za streaming sa servera ka klijentu preko HTTP-a. Server šalje događaje kao običan tekst preko dugovečne konekcije.

### Format SSE Protokola

```text
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive

event: orderUpdate
data: {"id": 42, "status": "shipped"}

event: orderUpdate
data: {"id": 43, "status": "paid"}

event: heartbeat
data: ping
```

Pravila:

- Svako polje je na sopstvenoj liniji: `event:`, `data:`, `id:`, `retry:`
- Događaji su razdvojeni praznim redom
- `Content-Type` mora biti `text/event-stream`
- `id:` omogućava klijentu da nastavi od mesta gde je stao nakon ponovnog povezivanja

### PHP SSE Implementacija (Symfony)

```php
<?php

namespace App\Controller;

use App\Repository\OrderRepository;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Symfony\Component\Routing\Attribute\Route;

final class OrderStreamController
{
    public function __construct(
        private readonly OrderRepository $orderRepository,
    ) {}

    #[Route('/api/orders/stream', methods: ['GET'])]
    public function stream(): StreamedResponse
    {
        $response = new StreamedResponse(function (): void {
            header('Content-Type: text/event-stream');
            header('Cache-Control: no-cache');
            header('X-Accel-Buffering: no'); // Disable Nginx buffering

            $lastCheck = new \DateTimeImmutable();

            while (true) {
                $updates = $this->orderRepository->findUpdatedSince($lastCheck);

                foreach ($updates as $order) {
                    echo "event: orderUpdate\n";
                    echo "data: " . json_encode([
                        'id' => $order->getId(),
                        'status' => $order->getStatus(),
                        'updatedAt' => $order->getUpdatedAt()->format('c'),
                    ]) . "\n\n";
                }

                // Heartbeat to keep connection alive
                echo ": heartbeat\n\n";

                // Flush output buffers — critical for streaming
                if (ob_get_level() > 0) {
                    ob_flush();
                }
                flush();

                $lastCheck = new \DateTimeImmutable();
                sleep(2);
            }
        });

        return $response;
    }
}
```

### JavaScript Klijent (EventSource)

```javascript
const source = new EventSource('/api/orders/stream');

source.addEventListener('orderUpdate', (event) => {
    const order = JSON.parse(event.data);
    console.log(`Order #${order.id}: ${order.status}`);
    updateDashboard(order);
});

source.onerror = () => {
    console.log('Connection lost, reconnecting...');
    // EventSource automatically reconnects
};
```

**Ključna prednost:** `EventSource` automatski obrađuje ponovno povezivanje. Ako konekcija padne, pretraživač se ponovo povezuje i šalje poslednji primljeni `id` putem `Last-Event-ID` zaglavlja.

## Chunked Transfer Encoding

Chunked enkodovanje šalje telo odgovora u komadima, omogućavajući serveru da počne sa slanjem pre nego što zna ukupnu veličinu. Ovo je korisno za izvoz velikih podataka.

### HTTP Format

```text
HTTP/1.1 200 OK
Transfer-Encoding: chunked

1a\r\n
This is the first chunk.\r\n
1c\r\n
This is the second chunk.\r\n
0\r\n
\r\n
```

Svaki komad počinje svojom veličinom u heksadecimalnom obliku, a zatim podacima. Komad nulte dužine signalizira kraj.

### PHP CSV Eksport sa Chunked Streamingom

```php
<?php

namespace App\Controller;

use App\Repository\OrderRepository;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Symfony\Component\Routing\Attribute\Route;

final class ExportController
{
    public function __construct(
        private readonly OrderRepository $orderRepository,
    ) {}

    #[Route('/api/orders/export.csv', methods: ['GET'])]
    public function exportCsv(): StreamedResponse
    {
        return new StreamedResponse(function (): void {
            $handle = fopen('php://output', 'w');
            fputcsv($handle, ['ID', 'Customer', 'Total', 'Status', 'Date']);

            // Stream 100,000 rows without loading all into memory
            $batchSize = 1000;
            $offset = 0;

            while (true) {
                $orders = $this->orderRepository->findBatch($offset, $batchSize);

                if (empty($orders)) {
                    break;
                }

                foreach ($orders as $order) {
                    fputcsv($handle, [
                        $order->getId(),
                        $order->getCustomerName(),
                        $order->getTotal(),
                        $order->getStatus(),
                        $order->getCreatedAt()->format('Y-m-d'),
                    ]);
                }

                flush();
                $offset += $batchSize;
            }

            fclose($handle);
        }, 200, [
            'Content-Type' => 'text/csv',
            'Content-Disposition' => 'attachment; filename="orders.csv"',
        ]);
    }
}
```

Ovo prenosi redove klijentu dok se upituju — konstantna upotreba memorije bez obzira na veličinu skupa podataka.

## Tabela Poređenja

| Aspekt | SSE | WebSocket | Long Polling |
|--------|-----|-----------|-------------|
| Smer | Samo Server → Klijent | Bidirekciono | Server → Klijent |
| Protokol | HTTP | WebSocket (nadogradnja sa HTTP-a) | HTTP |
| Ponovno povezivanje | Automatsko (ugrađeno) | Ručno | Ručno |
| Format podataka | Samo tekst | Tekst i binarno | Bilo šta |
| Podrška pretraživača | Svi moderni pretraživači | Svi moderni pretraživači | Svi pretraživači |
| Kroz proxy-e | Radi (to je HTTP) | Može zahtevati konfiguraciju | Radi |
| Najpogodnije za | Uživo feedovi, obaveštenja | Chat, gaming, saradnja u realnom vremenu | Stari pretraživači |

**Kada izabrati šta:**

- **SSE** — Server gura ažuriranja klijentu (kontrolne table, obaveštenja, uživo feedovi). Jednostavno, nije potreban specijalni server.
- **WebSocket** — Klijent i server oba šalju poruke (chat, višeigračke igre, kolaborativno uređivanje).
- **Long Polling** — Rezervna opcija kada SSE/WebSocket nisu dostupni. Klijent šalje zahtev, server ga drži dok podaci nisu spremni.

## Razmatranja za Produkciju

### Nginx Konfiguracija za SSE

```nginx
location /api/orders/stream {
    proxy_pass http://php-fpm-backend;

    # Disable buffering — critical for streaming
    proxy_buffering off;
    proxy_cache off;

    # Disable Nginx timeout for long-lived connections
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;

    # SSE-specific headers
    add_header Cache-Control no-cache;
    add_header X-Accel-Buffering no;
}
```

### Iscrpljivanje PHP-FPM Radnika

Svaka SSE konekcija drži PHP-FPM radnika za celo trajanje konekcije. Sa 50 FPM radnika i 50 SSE konekcija, nema radnika za regularne zahteve.

```text
Rešenja:
1. Koristite namenski FPM pool za streaming endpointe (odvojena granica radnika)
2. Koristite ReactPHP/Swoole za SSE (jedan proces obrađuje hiljade konekcija)
3. Prepustite namenski servis (Mercure, Centrifugo)
4. Postavite maksimalno vreme konekcije i pustite EventSource da se ponovo poveže
```

## Česta Pitanja na Intervjuima

### P: Koja je razlika između SSE i WebSocket-a?

**O:** **SSE** je jednosmerno (samo server ka klijentu), koristi standardni HTTP, automatski se ponovo povezuje i podržava samo tekstualne podatke. **WebSocket** je bidirekciono, koristi sopstveni protokol (nadogradnja sa HTTP-a), zahteva ručno upravljanje ponovnim povezivanjem i podržava binarne podatke. Izaberite SSE za scenarije gde server gura ažuriranja (obaveštenja, uživo feedovi) i WebSocket kada klijent takođe treba da šalje poruke (chat, gaming).

### P: Kako se upravlja streamingom bez iscrpljivanja PHP-FPM radnika?

**O:** Svaka SSE konekcija zauzima jedan FPM radnik tokom celog životnog veka konekcije. Rešenja: (1) koristite **namenski FPM pool** sa odvojenim `pm.max_children` za streaming endpointe, (2) koristite **async runtime** kao što su ReactPHP ili Swoole koji mogu da obrađuju hiljade konekcija u jednom procesu, ili (3) prepustite **namenskom streaming servisu** poput Mercure-a koji se integriše sa Symfony-jem.

### P: Kada biste izabrali chunked enkodovanje umesto SSE?

**O:** Chunked enkodovanje je za **velika jednokratna ažuriranja** gde želite da počnete sa slanjem podataka pre nego što je kompletan odgovor spreman (CSV eksport, generisanje velikih izveštaja). SSE je za **trajna ažuriranja u realnom vremenu** gde konekcija ostaje otvorena na neodređeno vreme. Chunked enkodovanje završava kada su podaci kompletni; SSE drži konekciju otvorenom dok se klijent ne odspoji.

## Zaključak

HTTP streaming eliminiše overhead ponavljanog pollinga održavanjem konekcije otvorenom za isporuku podataka u realnom vremenu. SSE je najjednostavnija opcija za ažuriranja sa servera ka klijentu (ugrađeno ponovno povezivanje, standardni HTTP), dok WebSocket omogućava bidirekcionalnu komunikaciju. U PHP-u, Symfony-jev `StreamedResponse` obrađuje i SSE i chunked preuzimanja, ali produkcijska razmještanja moraju uzeti u obzir ograničenja FPM radnika putem namenskih pool-ova, async runtime-ova ili namenskih streaming servisa.

## Vidi Takođe

- [Struktura HTTP Protokola](http_protocol_structure.sr.md) — standardni format zahteva/odgovora
- [Konkurentnost vs. Paralelizam](concurrency_vs_parallelism.sr.md) — koncepti asinhrone obrade
- [REST API Arhitektura](rest_api_architecture.sr.md) — standardni obrasci dizajna API-ja
