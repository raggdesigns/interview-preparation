# Kako suziti probleme na PHP strani aplikacije

Kada korisnici prijavljuju da je "aplikacija spora", uzrok može biti PHP kod, baza podataka, mreža ili eksterni API-ji.
Cilj je dokazati gde se troši vreme pre nego što se kod promeni.
Na intervjuima, ova tema proverava redosled debagovanja i sposobnost izbegavanja slepih optimizacija.

## Preduslovi

- Možeš čitati logove aplikacije i logove web servera
- Razumeš metrike kašnjenja zahteva (avg, p95, p99)
- Poznaješ osnovno ponašanje PHP-FPM-a i ograničenja memorije

## Brzi dijagnostički tok

1. Potvrdi simptom: stopa grešaka, stopa timeout-a ili skok kašnjenja.
2. Reprodukuj sa jednim endpointom i jednim realnim payload-om.
3. Poveži logove zahteva sa PHP logovima za isti request ID.
4. Podeli vreme po sloju: PHP kod, vreme DB upita, vreme eksternog API poziva.
5. Popravi prvo najveće usko grlo i ponovo izmeri.

## Šta prvo proveriti

### 1) Signali grešaka i timeout-a

- PHP fatalne greške, upozorenja, događaji prekoračenja memorije
- Unosi u PHP-FPM slowlog
- Nginx/Apache greške timeout-a upstream-a

### 2) Raspodela vremena u aplikaciji

- Ukupno vreme zahteva
- Vreme baze podataka nasuprot vremenu van baze
- Vreme eksternog HTTP poziva

Ako dominira vreme van baze podataka, fokusiraj se na PHP putanju izvršavanja.

### 3) Profilisanje vruće putanje

Koristi profajlere (na primer Blackfire ili Xdebug režim profilisanja) da pronađeš:

- Ponavljajuće skupe petlje
- Kod koji intenzivno koristi serijalizaciju
- N+1 pozive servisa unutar petlji

## Praktičan primer

Problem:

- `GET /api/products` p95 povećan sa 180ms na 1.9s.
- Dashboard baze podataka pokazuje stabilan upit.

Istraga:

1. Dodaj request ID u logove.
2. Uporedi vremena po zahtevu.
3. Utvrdi da se 1.5s troši u petlji koja poziva eksterni pricing API po proizvodu.

Pre (anti-obrazac):

```php
foreach ($products as $product) {
    $product->price = $pricingClient->fetchPrice($product->id);
}
```

Posle:

```php
$ids = array_map(fn ($product) => $product->id, $products);
$priceMap = $pricingClient->fetchPricesBulk($ids);

foreach ($products as $product) {
    $product->price = $priceMap[$product->id] ?? null;
}
```

Rezultat (primer): p95 sa 1.9s na 320ms.

## Korisni alati

- Strukturisani logovi sa request ID-em
- APM trejsovi (New Relic, Datadog, itd.)
- PHP profajler (uzorkovanje ili trejsovanje)
- Statička analiza za rizične putanje koda (PHPStan/Psalm)

## Napomene za intervju

- Reci kako izolaš slojeve pre popravke.
- Pomeni jedan konkretan metrik pre i posle.
- Objasni zašto je odabrana popravka ciljala najveće usko grlo.

## Zaključak

Sužavanje PHP problema uglavnom se svodi na disciplinovanu izolaciju.
Prvo izmeri, identifikuj dominantni trošak, primeni jednu fokusiranu popravku i proveri istim metrikom.
