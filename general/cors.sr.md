CORS (Cross-Origin Resource Sharing) je bezbednosni mehanizam pregledača koji kontroliše koje veb stranice mogu da upućuju zahteve vašem serveru sa drugog domena. Zasnovan je na **politici istog porekla (Same-Origin Policy)**.

> **Scenario koji se koristi kroz ceo dokument:** React frontend na `https://app.mysite.com` komunicira sa Symfony API-jem na `https://api.mysite.com`. Ovo su različita porekla (različiti subdomeni), pa je potrebna CORS konfiguracija.

### Politika istog porekla (Same-Origin Policy)

Podrazumevano, pregledači blokiraju JavaScript od upućivanja zahteva drugom poreklu. "Poreklo" je kombinacija **protokola + domena + porta**:

```text
https://example.com:443  — ovo je jedno poreklo

Isto poreklo:
  https://example.com/api/users      ✓ (isti protokol, domen, port)
  https://example.com/other-page     ✓

Različito poreklo:
  http://example.com                 ✗ (različit protokol — http vs https)
  https://api.example.com            ✗ (različit subdomen)
  https://example.com:8080           ✗ (različit port)
  https://other-site.com             ✗ (različit domen)
```

Bez CORS-a, ako je tvoj frontend na `https://app.mysite.com` a API na `https://api.mysite.com`, pregledač će blokirati sve API zahteve sa frontenda.

CORS je način na koji backend API govori pregledaču da opusti ovu politiku za frontend.

### Kako CORS funkcioniše

CORS koristi HTTP zaglavlja da govori pregledaču: "Ovom drugom poreklu je dozvoljeno da pristupi mojim resursima."

#### Jednostavni zahtevi

Za jednostavne zahteve (GET, POST sa osnovnim tipovima sadržaja), pregledač šalje zahtev direktno i proverava zaglavlja odgovora:

```text
1. Pregledač na https://app.mysite.com šalje zahtev:
   GET /api/users
   Origin: https://app.mysite.com

2. Server na https://api.mysite.com odgovara:
   HTTP/1.1 200 OK
   Access-Control-Allow-Origin: https://app.mysite.com

   [podaci]

3. Pregledač proverava zaglavlje:
   - Da li se Access-Control-Allow-Origin poklapa sa našim poreklom? → Da → dozvoli odgovor
   - Ako zaglavlje nedostaje ili se ne poklapa → blokiraj odgovor
```

#### Preflight zahtevi

Za "nesimplistične" zahteve (PUT, DELETE, prilagođena zaglavlja, JSON tip sadržaja), pregledač prvo šalje OPTIONS zahtev koji se zove **preflight**:

```text
1. Pregledač želi da pošalje:
   DELETE /api/users/123
   Origin: https://app.mysite.com
   Content-Type: application/json

2. Pregledač prvo šalje preflight:
   OPTIONS /api/users/123
   Origin: https://app.mysite.com
   Access-Control-Request-Method: DELETE
   Access-Control-Request-Headers: Content-Type

3. Server na https://api.mysite.com odgovara na preflight:
   HTTP/1.1 204 No Content
   Access-Control-Allow-Origin: https://app.mysite.com
   Access-Control-Allow-Methods: GET, POST, PUT, DELETE
   Access-Control-Allow-Headers: Content-Type, Authorization
   Access-Control-Max-Age: 3600

4. Pregledač proverava: da li je DELETE dozvoljen sa ovog porekla? → Da → šalje stvarni zahtev
   DELETE /api/users/123
   Origin: https://app.mysite.com

5. Server odgovara:
   HTTP/1.1 200 OK
   Access-Control-Allow-Origin: https://app.mysite.com
```

Server kontroliše sve ovo putem specifičnih HTTP zaglavlja.

### CORS zaglavlja objašnjena

#### Zaglavlja odgovora (šalje server)

| Zaglavlje | Svrha | Primer |
|-----------|-------|--------|
| `Access-Control-Allow-Origin` | Koje poreklo je dozvoljeno | `https://app.mysite.com` ili `*` |
| `Access-Control-Allow-Methods` | Koje HTTP metode su dozvoljene | `GET, POST, PUT, DELETE` |
| `Access-Control-Allow-Headers` | Koja zaglavlja zahteva su dozvoljena | `Content-Type, Authorization` |
| `Access-Control-Allow-Credentials` | Dozvoli kolačiće/auth zaglavlja | `true` |
| `Access-Control-Max-Age` | Keširaj preflight rezultat (sekunde) | `3600` |
| `Access-Control-Expose-Headers` | Zaglavlja koja pregledač može čitati | `X-Total-Count` |

#### Važna pravila

- `Access-Control-Allow-Origin: *` — dozvoljava sva porekla, ali se **ne može** koristiti sa kredencijalima
- Da bi se dozvolili kredencijali (kolačići), mora se navesti tačno poreklo i postaviti `Allow-Credentials: true`

```text
# Dozvoli sva porekla (bez kredencijala)
Access-Control-Allow-Origin: *

# Dozvoli specifično poreklo sa kredencijalima
Access-Control-Allow-Origin: https://app.mysite.com
Access-Control-Allow-Credentials: true
```

Evo kako se ova zaglavlja konfigurišu u praksi.

### Konfiguracija CORS-a u Nginx-u

```nginx
server {
    listen 443 ssl;
    server_name api.mysite.com;

    location /api/ {
        # Handle preflight
        if ($request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin "https://app.mysite.com";
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization";
            add_header Access-Control-Max-Age 3600;
            return 204;
        }

        # Regular requests
        add_header Access-Control-Allow-Origin "https://app.mysite.com";
        add_header Access-Control-Allow-Credentials "true";

        fastcgi_pass unix:/var/run/php-fpm.sock;
        # ...
    }
}
```

### Konfiguracija CORS-a u Symfony-u

Korišćenje `nelmio/cors-bundle`:

```bash
composer require nelmio/cors-bundle
```

```yaml
# config/packages/nelmio_cors.yaml
nelmio_cors:
    defaults:
        origin_regex: true
        allow_origin: ['%env(CORS_ALLOW_ORIGIN)%']
        allow_methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
        allow_headers: ['Content-Type', 'Authorization']
        expose_headers: ['Link', 'X-Total-Count']
        max_age: 3600
    paths:
        '^/api/':
            allow_origin: ['https://app.mysite.com']
            allow_credentials: true
```

```env
# .env
CORS_ALLOW_ORIGIN='^https?://(localhost|app\.mysite\.com)(:[0-9]+)?$'
```

### Konfiguracija CORS-a u PHP-u (ručno)

```php
// Simple CORS middleware
function handleCors(Request $request): ?Response
{
    $allowedOrigins = ['https://app.mysite.com'];
    $origin = $request->headers->get('Origin');

    if ($origin === null || !in_array($origin, $allowedOrigins)) {
        return null; // No CORS headers needed
    }

    // Handle preflight
    if ($request->getMethod() === 'OPTIONS') {
        $response = new Response('', 204);
        $response->headers->set('Access-Control-Allow-Origin', $origin);
        $response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
        $response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        $response->headers->set('Access-Control-Max-Age', '3600');
        return $response;
    }

    return null; // Continue to controller, add headers in response listener
}
```

### Uobičajene CORS greške

#### 1. Wildcard sa kredencijalima

```text
# Ovo NE funkcioniše — pregledač to odbija
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true

# Mora se koristiti specifično poreklo
Access-Control-Allow-Origin: https://app.mysite.com
Access-Control-Allow-Credentials: true
```

#### 2. Nedostaje OPTIONS handler

```text
# Ako server vraća 405 za OPTIONS zahteve, preflight ne uspeva
# Proveri da li tvoj veb server ili framework obrađuje OPTIONS
```

#### 3. Nedostaju zaglavlja u stvarnom odgovoru

```text
# CORS zaglavlja moraju biti prisutna I u preflightu I u stvarnom odgovoru
# Ne samo u OPTIONS odgovoru
```

Dok CORS štiti od neovlašćenog čitanja odgovora sa drugog porekla, **ne** štiti od svih pretnji sa drugog porekla — posebno CSRF-a.

### CORS vs CSRF

#### Šta je CSRF?

CSRF (Cross-Site Request Forgery) je napad u kome zlonamerna veb stranica navodi pregledač korisnika da pošalje neželjeni zahtev serveru na kome je korisnik već autentikovan. Napadač ne može da pročita odgovor — to mu ni nije potrebno. Cilj je **izvršiti akciju koja menja stanje** (prenos novca, promena email-a, brisanje podataka) koristeći korisnikovu sesiju.

#### Kako se vrši CSRF napad

Koristeći naš scenario — korisnik je prijavljen na `https://app.mysite.com`, i pregledač čuva sesijski kolačić za `https://api.mysite.com`:

```text
1. Korisnik se prijavi na https://app.mysite.com
   → Pregledač čuva sesijski kolačić za https://api.mysite.com

2. Korisnik poseti https://evil.com (phishing link, reklama, itd.)
   → evil.com sadrži skriveni automatski podneseni formular:

   <form action="https://api.mysite.com/api/transfer" method="POST">
     <input type="hidden" name="to" value="attacker_account">
     <input type="hidden" name="amount" value="5000">
   </form>
   <script>document.forms[0].submit();</script>

3. Pregledač šalje POST na https://api.mysite.com
   → Sesijski kolačić se AUTOMATSKI prilaže od strane pregledača
   → Server vidi validnu sesiju i izvršava prenos

4. Napadač NE MOŽE da pročita odgovor (CORS to blokira)
   → Ali šteta je već napravljena — novac je prenet
```

Ključni uvid: **zahtev je poslat i izvršen** od strane servera. CORS je samo blokirao napadaču **čitanje odgovora** — što mu ni nije trebalo.

#### Odakle dolazi napad

| Korak | Gde | Šta se dešava |
|-------|-----|---------------|
| Priprema | `https://evil.com` | Napadač hostuje stranicu sa skrivenim formularom ili image tagom |
| Okidač | Pregledač korisnika | Pregledač šalje zahtev sa automatski priloženim kolačićima |
| Meta | `https://api.mysite.com` | Server prima legitiman zahtev i izvršava ga |

#### Poređenje: CORS vs CSRF

| | CORS | CSRF |
|-|------|------|
| Šta | Mehanizam pregledača koji blokira **čitanje** odgovora sa drugog porekla | Napad koji eksploatiše **slanje** zahteva drugom poreklu |
| Smer | Kontroliše ko može **čitati** API odgovor | Eksploatiše pregledač koji **šalje** zahteve sa kolačićima |
| Štiti od | Neovlašćenog JavaScript čitanja podataka sa tvog API-ja | *(CSRF je napad, ne zaštita)* |
| NE štiti od | Zahteva koji menjaju stanje (POST, DELETE) — zahtev i dalje stiže do servera | N/A |
| Mehanizam zaštite | Server šalje `Access-Control-Allow-Origin` zaglavlja | CSRF tokeni, SameSite kolačići ili Bearer token autentikacija |

#### Zašto CORS sam nije dovoljan

CORS samo govori pregledaču: *"Ovo poreklo može čitati moje odgovore."* Ali čak i bez CORS dozvole, pregledač **i dalje šalje** zahtev (za jednostavne zahteve kao što su slanja formulara). Server ga obradi, i sporedni efekat se dogodi.

Da bi se API potpuno zaštitio od CSRF-a, potrebno je jedno od:

1. **CSRF tokeni** — server generiše jedinstven token po sesiji/formularu koji `https://evil.com` ne može znati niti replicirati
2. **SameSite kolačići** — postavi `SameSite=Strict` ili `SameSite=Lax` da pregledač ne šalje kolačiće na zahteve sa drugog porekla
3. **Bearer token autentikacija** — koristi `Authorization: Bearer <token>` umesto kolačića. Pošto se ovo zaglavlje **ne šalje automatski** od strane pregledača, stranica `https://evil.com` ne može pokrenuti autentifikovane zahteve

> API-ji koji koriste JWT tokene u `Authorization` zaglavlju (umesto kolačića) **nisu ranjivi na CSRF** — stranica napadača nema način da priloži token uz zahtev.

Za potpuni pregled metoda prevencije CSRF-a, pogledaj [Šta je CSRF](csrf.sr.md).

### Stvarni scenario

Imaš React frontend na `https://app.mysite.com` i Symfony API na `https://api.mysite.com`. Bez CORS konfiguracije:

```text
Frontend (React):
fetch('https://api.mysite.com/api/users')
→ Pregledač blokira: "No 'Access-Control-Allow-Origin' header present"
```

Dodaješ CORS zaglavlja u API:

```yaml
# nelmio_cors.yaml
nelmio_cors:
    paths:
        '^/api/':
            allow_origin: ['https://app.mysite.com']
            allow_methods: ['GET', 'POST', 'PUT', 'DELETE']
            allow_headers: ['Content-Type', 'Authorization']
            allow_credentials: true
            max_age: 3600
```

Sada pregledač dozvoljava frontendu da upućuje API pozive. Preflight se cache-ira na 1 sat (`max_age: 3600`), tako da su naredni zahtevi brži.

### Zaključak

CORS je bezbednosna funkcija pregledača koja kontroliše HTTP zahteve između frontenda i backend API-ja sa različitih porekla. Server koristi `Access-Control-Allow-*` zaglavlja da govori pregledaču koja porekla, metode i zaglavlja su dozvoljena. Nesimplistični zahtevi prvo pokraju preflight OPTIONS zahtev.

Međutim, CORS kontroliše samo ko može **čitati** odgovore — **ne sprečava** napade koji menjaju stanje (CSRF), jer se zahtev i dalje šalje i izvršava. Odgovarajuće bezbednosno podešavanje za razdvajanje frontenda i backenda zahteva i CORS konfiguraciju (da dozvoli legitimna čitanja sa drugog porekla) **i** CSRF zaštitu (tokene, SameSite kolačiće ili Bearer token autentikaciju) da bi se sprečile neovlašćene akcije.

> Vidi takođe: [Šta je CSRF](csrf.sr.md), [OWASP Top 10](owasp_top_10.sr.md), [Napadi na veb aplikacije](web_application_attacks.sr.md)
