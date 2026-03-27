# Optimizovanje sporog GET endpoint-a

Ako GET endpoint istekne na velikoj tabeli, prvi cilj je ukloniti najveće usko grlo bez promene ugovora odgovora.
Na intervjuima, ova tema proverava da li možeš debagovati u ispravnom redosledu: izmeri, pronađi usko grlo, primeni ciljane popravke i proveri uticaj.

## Preduslovi

- Možeš čitati SQL i izvršavati `EXPLAIN`
- Poznaješ osnove kašnjenja zahteva (p95, prag timeout-a)
- Razumeš indekse i poništavanje cache-a na osnovnom nivou

## Brzi tok trijage

1. Potvrdi gde se troši vreme: baza podataka, sloj aplikacije ili mreža.
2. Uhvati jedan realni spori upit iz logova ili APM-a.
3. Izvrši `EXPLAIN` i proveri skenirane redove, korišćenje indeksa i strategiju sortiranja.
4. Primeni jednu promenu odjednom i ponovo izmeri p95 kašnjenje.

## Najčešće popravke (po redosledu)

### 1) Popravke upita i indeksa

- Dodaj ili prilagodi kompozitne indekse za obrasce `WHERE + ORDER BY`.
- Izbegavaj selektovanje kolona koje ne vraćaš.
- Zameni paginaciju zasnovanu na offsetu sa cursor/keyset paginacijom za duboke stranice.

### 2) Caching na nivou odgovora

- Cache-iraj stabilne odgovore sa ključevima zasnovanim na parametrima filtera.
- Koristi kratki TTL plus eksplicitno poništavanje pri pisanju.

### 3) Arhitektura pristupa podacima

- Premesti saobraćaj koji intenzivno čita na read replike.
- Unapred izračunaj skupe agregacije u pozadinskom zadatku kada real-time nije potreban.

## Praktičan primer

Problem:

- Endpoint: `GET /orders?user_id=42&status=paid&page=120`
- p95 kašnjenje: 8.2s
- DB plan pokazuje puno skeniranje i filesort na tabeli sa 40M redova.

Pre:

```sql
SELECT *
FROM orders
WHERE user_id = 42 AND status = 'paid'
ORDER BY created_at DESC
LIMIT 50 OFFSET 5950;
```

Posle:

```sql
CREATE INDEX idx_orders_user_status_created_at
ON orders (user_id, status, created_at DESC);

SELECT id, total_amount, created_at, status
FROM orders
WHERE user_id = 42
  AND status = 'paid'
  AND created_at < '2026-02-01 10:12:00'
ORDER BY created_at DESC
LIMIT 50;
```

Rezultat (primer metrika):

- pregledani redovi: 2.3M -> 1.2K
- p95 kašnjenje: 8.2s -> 220ms
- stopa timeout-a: 14% -> <1%

## Napomene za intervju

- Počni sa merenjem, ne pretpostavkama.
- Objasni zašto je svaka optimizacija odabrana za ovaj obrazac upita.
- Pomeni kompromise: zastarelost cache-a, kašnjenje replike, overhead pisanja indeksa.

## Zaključak

Za spore GET endpoint-e, put sa najvećom vrednošću je: identifikuj spori upit, popravi obrazac pristupa i indeksiranje, zatim dodaj caching i skaliranje čitanja samo kada je potrebno.
Ovo čuva odgovor nepromenjenim dok pravi performanse predvidivim.
