HTTP status kodovi su trocifeni brojevi koji govore klijentu šta se desilo sa njegovim zahtevom. Grupisani su prema prvoj cifri. Najvažnije grupe za intervjue su **3xx** (preusmerenja), **4xx** (greške klijenta) i **5xx** (greške servera).

### Razlika

- **3xx greške** znače da je resurs **premešten** ili da klijent treba da traži na drugom mestu. Server obaveštava klijenta o novoj lokaciji.
- **4xx greške** znače da je **klijent** napravio grešku. Zahtev je bio pogrešan, neovlašćen ili resurs ne postoji. Klijent treba da ispravi zahtev pre ponovnog pokušaja.
- **5xx greške** znače da je **server** imao problem. Zahtev može biti validan, ali server nije mogao da ga obradi. Klijent može pokušati ponovo kasnije.

### 3xx — Preusmerenja

| Kod | Naziv | Značenje |
|-----|-------|---------|
| 301 | Moved Permanently | Resurs je trajno premešten na novu URL adresu. Pretraživači i pretraživači ažuriraju svoje veze. |
| 302 | Found | Resurs je privremeno na drugoj URL adresi. Klijent treba da nastavi da koristi originalnu URL adresu. |
| 303 | See Other | Nakon POST-a, preusmerite na GET endpoint (npr. nakon slanja obrasca) |
| 304 | Not Modified | Resurs se nije promenio od poslednjeg zahteva — koristite cached verziju |
| 307 | Temporary Redirect | Kao 302 ali garantuje da je HTTP metoda sačuvana (POST ostaje POST) |
| 308 | Permanent Redirect | Kao 301 ali garantuje da je HTTP metoda sačuvana |

#### Česta Zabuna: 301 vs 302

- **301 Moved Permanently** — "Ova stranica je trajno premeštena. Ažurirajte obeleživače." Pretraživači prenose SEO rangiranje na novu URL adresu.
- **302 Found** — "Ova stranica je privremeno negde drugde. Nastavite da koristite staru URL adresu." Pretraživači zadržavaju staru URL adresu indeksiranu.

```text
# 301 — Stari domen trajno preusmerava na novi domen
GET http://old-site.com/about
→ 301 Moved Permanently
Location: https://new-site.com/about

# 302 — Stranica za održavanje, privremeno preusmeravanje
GET https://example.com/dashboard
→ 302 Found
Location: https://example.com/maintenance
```

```php
// Symfony — primeri preusmerenja
#[Route('/old-page')]
public function oldPage(): Response
{
    // 301 — trajno preusmeravanje
    return $this->redirectToRoute('new_page', [], 301);
}

#[Route('/login')]
public function login(): Response
{
    if ($this->getUser()) {
        // 302 — privremeno preusmeravanje (podrazumevano)
        return $this->redirectToRoute('dashboard');
    }
    // ...
}
```

### 4xx — Greške Klijenta

| Kod | Naziv | Značenje |
|-----|-------|---------|
| 400 | Bad Request | Zahtev je malformiran ili ima nevažeće podatke |
| 401 | Unauthorized | Autentikacija nedostaje ili je nevažeća (nije prijavljen) |
| 403 | Forbidden | Autentifikovan, ali nije dozvoljen pristup ovom resursu |
| 404 | Not Found | Resurs ne postoji |
| 405 | Method Not Allowed | HTTP metoda nije podržana (npr. POST na GET-only endpoint) |
| 409 | Conflict | Zahtev je u sukobu sa trenutnim stanjem (npr. duplikat unosa) |
| 422 | Unprocessable Entity | Sintaksa zahteva je ispravna, ali validacija podataka nije uspela |
| 429 | Too Many Requests | Prekoračeno ograničenje brzine — klijent šalje previše zahteva |

#### Česta Zabuna: 401 vs 403

- **401 Unauthorized** — "Ko si ti?" — nije pružena autentikacija ili je token istekao
- **403 Forbidden** — "Znam ko si, ali ne možeš ovo da uradiš" — autentifikovan, ali nema dozvolu

```text
# Nema tokena — 401
GET /api/admin/users
→ 401 Unauthorized

# Važeći token, ali korisnik nije admin — 403
GET /api/admin/users
Authorization: Bearer user-token-123
→ 403 Forbidden
```

#### Česta Zabuna: 400 vs 422

- **400 Bad Request** — sam zahtev je pokvaren (nevažeći JSON, pogrešan Content-Type)
- **422 Unprocessable Entity** — zahtev je dobro formiran, ali podaci nisu važeći (pogrešan format email-a, nedostaje obavezno polje)

```text
# Pokvaren JSON — 400
POST /api/users
Content-Type: application/json
Body: {name: Alice   ← nevažeća JSON sintaksa

# Važeći JSON, ali nevažeći podaci — 422
POST /api/users
Content-Type: application/json
Body: {"name": "", "email": "not-an-email"}
→ 422 sa greškama validacije
```

### 5xx — Greške Servera

| Kod | Naziv | Značenje |
|-----|-------|---------|
| 500 | Internal Server Error | Neobrađen izuzetak ili greška u serverskom kodu |
| 502 | Bad Gateway | Reverse proxy (Nginx) dobio je nevažeći odgovor od backend-a (PHP-FPM) |
| 503 | Service Unavailable | Server je preopterećen ili u održavanju |
| 504 | Gateway Timeout | Reverse proxy je čekao predugo na odgovor backend-a |

#### Česta Zabuna: 502 vs 504

- **502 Bad Gateway** — upstream server (PHP-FPM) je odgovorio, ali odgovor je bio nevažeći ili je proces pao
- **504 Gateway Timeout** — upstream server uopšte nije odgovorio u okviru vremenskog ograničenja

```text
Nginx → PHP-FPM

502: PHP-FPM proces pao ili vratio nešto nerazumljivo → Nginx ne može da razume odgovor
504: PHP-FPM još uvek obrađuje nakon 60 sekundi → Nginx odustaje od čekanja
```

### Kada Vraćati Koji Kod (za API programere)

```php
// 400 — Malformiran zahtev
if (!json_decode($request->getContent())) {
    return new JsonResponse(['error' => 'Invalid JSON'], 400);
}

// 401 — Nema autentikacije
if (!$request->headers->has('Authorization')) {
    return new JsonResponse(['error' => 'Authentication required'], 401);
}

// 403 — Nema dozvole
if (!$user->hasRole('ADMIN')) {
    return new JsonResponse(['error' => 'Access denied'], 403);
}

// 404 — Resurs nije pronađen
$product = $repository->find($id);
if ($product === null) {
    return new JsonResponse(['error' => 'Product not found'], 404);
}

// 409 — Sukob
$existing = $repository->findByEmail($email);
if ($existing !== null) {
    return new JsonResponse(['error' => 'Email already registered'], 409);
}

// 422 — Greška validacije
$errors = $validator->validate($dto);
if (count($errors) > 0) {
    return new JsonResponse(['errors' => $errors], 422);
}

// 429 — Ograničenje brzine
if ($rateLimiter->isExceeded($user)) {
    return new JsonResponse(['error' => 'Too many requests'], 429);
}
```

### Sve Grupe Status Kodova

Radi potpunosti, evo svih pet grupa:

| Grupa | Značenje | Primeri |
|-------|---------|---------|
| 1xx | Informativni | 100 Continue, 101 Switching Protocols |
| 2xx | Uspeh | 200 OK, 201 Created, 204 No Content |
| 3xx | Preusmerenje | 301 Moved Permanently, 302 Found, 304 Not Modified |
| 4xx | Greška Klijenta | 400, 401, 403, 404, 422 |
| 5xx | Greška Servera | 500, 502, 503, 504 |

### Realni Scenario

Korisnik pokušava da ažurira profil putem API-ja:

```text
1. Korisnik šalje zahtev bez tokena:
   PUT /api/profile  →  401 Unauthorized

2. Korisnik se prijavljuje i šalje zahtev sa tokenom, ali pogrešnim JSON-om:
   PUT /api/profile  →  400 Bad Request

3. Korisnik popravlja JSON, ali email je nevažeći:
   PUT /api/profile {"email": "bad"}  →  422 Unprocessable Entity

4. Korisnik šalje važeće podatke:
   PUT /api/profile {"email": "alice@test.com"}  →  200 OK

5. U međuvremenu, server baze podataka pada:
   PUT /api/profile {"email": "alice@test.com"}  →  500 Internal Server Error

6. Nginx detektuje da PHP-FPM ne reaguje:
   PUT /api/profile  →  502 Bad Gateway
```

Svaki status kod pomaže klijentu da razume šta je pošlo naopako i šta da uradi sledeće.

### Zaključak

4xx greške su klijentova greška — pogrešan zahtev, nedostaje autentikacija, resurs nije pronađen. 5xx greške su greška servera — greške, padovi, vremenski limiti. Najvažniji koje treba znati: 400 (loš zahtev), 401 (nije autentifikovan), 403 (nije autorizovan), 404 (nije pronađen), 422 (validacija nije uspela), 500 (greška servera), 502 (loš gateway), 503 (preopterećen), 504 (vremenski limit).
