# Alati za analizu problema na strani baze podataka aplikacije

Problemi sa bazom podataka lakše se rešavaju kada se prati fiksni tok rada umesto skakanja direktno na nasumično podešavanje.
Na intervjuima, jak odgovor je da objasniš koji alat koristiš u svakom koraku i zašto.

## Preduslovi

- Možeš izvršiti `EXPLAIN` / `EXPLAIN ANALYZE`
- Poznaješ osnovne indekse i planove upita
- Možeš čitati metrike CPU-a, memorije, IOPS-a i konekcija

## Dijagnostički tok rada

1. Detekcija: identifikuj simptom (spori upiti, čekanje na zaključavanje, visok CPU, kašnjenje replikacije).
2. Lokalizacija: pronađi glavne uzročnike po otisku prsta upita i vremenskom prozoru.
3. Inspekcija: analiziraj planove, borbu za zaključavanje i zasićenost resursa.
4. Popravka: primeni promenu indeksa/upita/sheme/konfiguracije.
5. Verifikacija: uporedi metrike pre i posle.

## Kategorije alata i namena

### 1) Alati na nivou upita

- Slow query log + alati za digest (na primer `pt-query-digest`)
- `EXPLAIN` / `EXPLAIN ANALYZE`
- Dashboardi statistike performansi / iskaza

Koristi ih prvo kada je kašnjenje specifično za upit.

### 2) Metrike engine-a baze podataka

- Dashboardi engine-a (stopa pogotka bafera/cache-a, aktivne konekcije, čekanje na zaključavanje)
- Metrike hosta (CPU, pritisak memorije, kašnjenje diska)

Koristi ih kada se mnogi upiti usporavaju odjednom.

### 3) Analiza zaključavanja i konkurentnosti

- Prikazi čekanja na zaključavanje / logovi deadlock-a
- Inspekcija transakcija i blokirajućih sesija

Koristi ih kada se timeout-ovi dešavaju čak i za normalno brze upite.

### 4) End-to-end observabilnost

- APM trejs koji povezuje zahtev aplikacije sa SQL span-ovima
- Centralizovani logovi sa request ID-em

Koristi ovo da dokažeš da li je DB uzrok ili samo deo većeg uskog grla zahteva.

## Praktičan primer

Simptom:

- p95 endpoint-a za naplatu raste sa 250ms na 2.4s.

Put istrage:

1. APM trejs pokazuje 1.9s unutar SQL sloja.
2. Digest sporog log-a ukazuje na jedan otisak upita koji doprinosi 62% vremena DB.
3. `EXPLAIN` pokazuje puno skeniranje na `orders` sa filtrom po `customer_id` + `created_at`.
4. Dodaj kompozitni indeks i ponovo proveri plan.

Rezultat (primer):

- p95 kašnjenja upita: 1.7s -> 90ms
- p95 endpoint-a: 2.4s -> 410ms

## Napomene za intervju

- Pomeni specifične metrike pre i posle.
- Objasni da podešavanje prati izmerena uska grla.
- Pomeni kompromise (trošak pisanja indeksa, rast skladišta, overhead održavanja).

## Zaključak

Najbolji pristup rešavanju problema sa bazom podataka je vođen alatima i ureden: detektuj, lokalizuj, inspektuj, popravi, verifikuj.
Ovo izbegava nagađanje i vodi ka bržim, bezbednijim poboljšanjima performansi.
