# Circuit Breaker Pattern

Circuit breaker pattern štiti vaš sistem od kaskadnih grešaka kada jedna zavisnost postane spora ili nedostupna.
Umesto da čeka da svaki neuspeli zahtev istekne, brzo otkazuje na kratki period i daje zavisnosti vreme da se oporavi.

Na intervjuima, ova tema pokazuje da li razumete otpornost pri delimičnim ispadima, a ne samo arhitekturu srećnog puta.

## Zašto se greške kaskadno šire

Bez circuit breaker-a:

1. Servis A poziva Servis B direktno.
2. Servis B postaje spor (ili nedostupan).
3. Niti/radnici u Servisu A blokiraju čekajući.
4. Redovi rastu, timeout-i se povećavaju, ponovni pokušaji množavaju saobraćaj.
5. Servis A takođe postaje nestabilan, čak i ako je bio zdrav.

Na ovaj način mali problem downstream može prerasti u potpuni incident.

## Kada i zašto se ovo dešava

Uobičajeni okidači:

- Skok kašnjenja zavisnosti (zaključavanje baze podataka, GC pauza, mrežni problem)
- Delimični ispad API-ja treće strane
- Iscrpljivanje connection pool-a
- Oluja ponovnih pokušaja bez backoff-a i bez ograničenja
- Nagli porast saobraćaja kombinovan sa skupim sinhronim pozivima

Signali koje treba pratiti:

- Iznenadno povećanje grešaka timeout-a
- Visoka p95/p99 latencija ka jednoj zavisnosti
- Rast zasićenja radnika/niti
- Rast reda čekanja i eksplozija broja ponovnih pokušaja

## Kako circuit breaker funkcioniše (najjednostavnija verzija)

Za najjednostavniju implementaciju, koristite samo dva stanja:

- **Closed**: pozivi idu ka zavisnosti.
- **Open**: pozivi brzo otkazuju (ili vraćaju fallback) dok ne prođe vreme hlađenja.

Minimalne kontrole:

- Prag grešaka (primer: 3 neuspela poziva)
- Trajanje hlađenja (primer: 10 sekundi)

## Primer problema (bez circuit breaker-a)

Ovaj kod ponavlja poziv neuspele zavisnosti, ali nema disciplinu timeout-a i nema ponašanje brzog otkazivanja.
Tokom ispada, radnici su blokirani, a ponovni pokušaji povećavaju opterećenje.

```php
<?php

final class PaymentGatewayClient
{
    public function charge(int $amount): array
    {
        usleep(4_000_000);

        throw new RuntimeException('Gateway timeout');
    }
}

final class CheckoutService
{
    public function __construct(private PaymentGatewayClient $gateway)
    {
    }

    public function checkout(int $amount): array
    {
        for ($attempt = 1; $attempt <= 3; $attempt++) {
            try {
                return $this->gateway->charge($amount);
            } catch (RuntimeException $exception) {
                if ($attempt === 3) {
                    throw $exception;
                }
            }
        }

        throw new RuntimeException('Unexpected checkout failure');
    }
}
```

Zašto je ovo opasno:

- Svaki zahtev i dalje poziva nezdravu zavisnost.
- Višestruki ponovni pokušaji množavaju pritisak.
- Radnici čekaju na duge greške, smanjujući kapacitet sistema.

## Rešen primer (sa jednostavnim circuit breaker-om)

Ova verzija koristi minimalni breaker sa 2 stanja.
Kada greške dostignu prag, otvara se i odmah vraća fallback.
Nakon hlađenja, ponovo dozvoljava pozive.

```php
<?php

final class SimpleCircuitBreaker
{
    private int $failureCount = 0;
    private ?int $openedAt = null;

    public function __construct(
        private int $failureThreshold = 3,
        private int $cooldownSeconds = 10,
    ) {
    }

    public function call(callable $operation, callable $fallback): array
    {
        if ($this->isOpen()) {
            return $fallback();
        }

        try {
            $result = $operation();
            $this->failureCount = 0;

            return $result;
        } catch (Throwable) {
            $this->failureCount++;

            if ($this->failureCount >= $this->failureThreshold) {
                $this->openedAt = time();
            }

            return $fallback();
        }
    }

    private function isOpen(): bool
    {
        if ($this->openedAt === null) {
            return false;
        }

        if ((time() - $this->openedAt) >= $this->cooldownSeconds) {
            $this->openedAt = null;
            $this->failureCount = 0;

            return false;
        }

        return true;
    }
}

final class PaymentGatewayClient
{
    public function charge(int $amount): array
    {
        throw new RuntimeException('Gateway timeout');
    }
}

final class CheckoutService
{
    public function __construct(
        private PaymentGatewayClient $gateway,
        private SimpleCircuitBreaker $circuitBreaker,
    ) {
    }

    public function checkout(int $amount): array
    {
        return $this->circuitBreaker->call(
            operation: fn (): array => $this->gateway->charge($amount),
            fallback: fn (): array => [
                'status' => 'deferred',
                'reason' => 'payment_gateway_unavailable',
            ],
        );
    }
}
```

Šta je poboljšano:

- Otvoreno stanje sprečava ponavljanje skupih grešaka.
- Hlađenje daje zavisnosti vreme da se oporavi.
- Fallback drži vaš endpoint responzivnim.

## Šta treba razmotriti u produkciji

1. **Timeout-i pre ponovnih pokušaja**
   - Postavite kratke, eksplicitne timeout-e po pozivu.
   - Ne oslanjajte se samo na podrazumevane vrednosti timeout-a klijenta.

2. **Strategija ponovnih pokušaja**
   - Koristite ograničene ponovne pokušaje sa eksponencijalnim backoff-om i jitter-om.
   - Nikada slepo ne ponavljajte ne-idempotentne operacije.

3. **Dizajn fallback-a**
   - Odlučite o poslovno bezbednom fallback-u: keširani podaci, odložena obrada, delimičan odgovor, ili eksplicitno otkazivanje.
   - Neka ponašanje fallback-a bude predvidivo za klijente.

4. **Podešavanje praga**
   - Počnite konzervativno i podešavajte na osnovu stvarnih podataka o latenciji/greškama.
   - Previše osetljivo se otvara prečesto; previše tolerantno odlaže zaštitu.

5. **Observability**
   - Pratite promene stanja circuit breaker-a, trajanje otvorenog stanja, blokirane pozive, stopu fallback-a.
   - Alertujte na duge periode otvorenog stanja i ponavljano otvaranje/zatvaranje.

6. **Komplementarni paterni**
   - Kombinujte sa bulkhead izolacijom za zaštitu zajednički korišćenih resursa.
   - Koristite rate limiting za smanjenje pritiska naleta saobraćaja tokom incidenata.

## Napomene za intervju

- Circuit breaker nije zamena za ponovne pokušaje; kontroliše kada ponovni pokušaji treba da prestanu da pogađaju nezdravu zavisnost.
- Za minimalni dizajn, jasno objasnite prag + hlađenje + fallback.
- Pomenite kompromise: privremeno degradirano iskustvo je često bolje od potpunog ispada.

## Uobičajena pitanja na intervjuima

1. Koja je razlika između retry i circuit breaker paterna?
2. Zašto koristimo hlađenje pre nego što ponovo dozvolimo pozive?
3. Kako birate vrednosti praga grešaka i timeout-a za resetovanje?
4. Koji metriksi ukazuju da je konfiguracija vašeg circuit breaker-a pogrešna?
5. Kada treba vratiti fallback naspram trenutnog otkazivanja zahteva?

## Pogledajte i

- [Microservices communication patterns](../microservices/answers/microservices_communication_patterns.sr.md)
- [Best practices for microservices development](../microservices/answers/best_practices_for_microservices_development.sr.md)
- [Kako suziti probleme na PHP strani aplikacije](how_to_narrow_problems_on_php_side_of_an_application.sr.md)
- [Optimizacija sporog GET endpointa](optimizing_slow_get_endpoint.sr.md)
