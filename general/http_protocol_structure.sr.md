HTTP (HyperText Transfer Protocol) je protokol baziran na tekstu koji se koristi za komunikaciju između klijenta (obično pretraživača) i servera. Svaka HTTP interakcija sastoji se od zahteva koji šalje klijent i odgovora koji vraća server.

### Struktura HTTP Zahteva

HTTP zahtev ima četiri dela:

```text
[METODA] [URL] [HTTP VERZIJA]
[ZAGLAVLJA]
[PRAZAN RED]
[TELO (opciono)]
```

#### Realni primer

```text
POST /api/users HTTP/1.1
Host: example.com
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUz...
Content-Length: 45

{"name": "Alice", "email": "alice@test.com"}
```

#### 1. Linija Zahteva

Prva linija sadrži tri dela:

- **Metoda** — koja akcija se izvodi: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`, `HEAD`
- **URL** (putanja) — resurs: `/api/users`, `/products/123`
- **HTTP verzija** — obično `HTTP/1.1` ili `HTTP/2`

#### 2. Zaglavlja

Zaglavlja pružaju dodatne informacije o zahtevu. Svako zaglavlje je par ključ-vrednost:

| Zaglavlje | Svrha | Primer |
|-----------|-------|--------|
| `Host` | Ciljni server | `example.com` |
| `Content-Type` | Format tela | `application/json` |
| `Authorization` | Kredencijali za autentikaciju | `Bearer token123` |
| `Accept` | Koji format klijent očekuje u odgovoru | `application/json` |
| `Content-Length` | Veličina tela u bajtovima | `45` |
| `Cookie` | Podaci sesije/kolačića | `session_id=abc123` |
| `User-Agent` | Identifikacija klijenta | `Mozilla/5.0...` |

#### 3. Prazan Red

Prazan red odvaja zaglavlja od tela. Govori serveru "zaglavlja su gotova, telo počinje sledeće."

#### 4. Telo (opciono)

Telo sadrži podatke poslate serveru. GET i DELETE zahtevi obično nemaju telo. POST, PUT i PATCH obično imaju telo.

### Struktura HTTP Odgovora

HTTP odgovor takođe ima četiri dela:

```text
[HTTP VERZIJA] [STATUS KOD] [STATUS TEKST]
[ZAGLAVLJA]
[PRAZAN RED]
[TELO]
```

#### Realni primer

```text
HTTP/1.1 201 Created
Content-Type: application/json
Location: /api/users/42
X-Request-Id: abc-123

{"id": 42, "name": "Alice", "email": "alice@test.com"}
```

#### 1. Linija Statusa

- **HTTP verzija** — `HTTP/1.1`
- **Status kod** — broj koji govori rezultat: `200`, `404`, `500`
- **Status tekst** — opis čitljiv za ljude: `OK`, `Not Found`, `Internal Server Error`

#### 2. Zaglavlja Odgovora

| Zaglavlje | Svrha | Primer |
|-----------|-------|--------|
| `Content-Type` | Format tela odgovora | `application/json` |
| `Content-Length` | Veličina tela | `62` |
| `Location` | URL novokreiranog resursa | `/api/users/42` |
| `Set-Cookie` | Slanje kolačića klijentu | `session_id=abc; HttpOnly` |
| `Cache-Control` | Pravila keširanja | `max-age=3600` |
| `Access-Control-Allow-Origin` | CORS zaglavlje | `*` |

#### 3. Telo

Stvarni podaci koje vraća server — HTML stranica, JSON odgovor, slika, fajl, itd.

### HTTP/1.1 vs HTTP/2

| Funkcionalnost | HTTP/1.1 | HTTP/2 |
|---------------|----------|--------|
| Format | Tekstualni | Binarni |
| Konekcije | Jedan zahtev po konekciji (ili keep-alive) | Više zahteva na jednoj konekciji (multipleksiranje) |
| Kompresija zaglavlja | Ne | Da (HPACK) |
| Server push | Ne | Da (server može slati resurse pre nego što klijent to traži) |
| Prioritet | Ne | Da (klijent može da prioritizuje zahteve) |

HTTP/1.1 šalje zahteve jedan za drugim na konekciji. Ako je jedan zahtev spor, blokira ostale (head-of-line blokiranje). HTTP/2 rešava ovo multipleksiranjem — šaljući više zahteva i odgovora istovremeno na jednoj konekciji.

```text
HTTP/1.1:
Client ──req1──> Server ──res1──> Client ──req2──> Server ──res2──>

HTTP/2:
Client ──req1──>
       ──req2──> Server ──res2──>
       ──req3──>        ──res1──>
                        ──res3──>
```

### Pregled HTTP Metoda

| Metoda | Svrha | Ima Telo | Idempotentna | Bezopasna |
|--------|-------|----------|-------------|----------|
| GET | Čita resurs | Ne | Da | Da |
| POST | Kreira resurs | Da | Ne | Ne |
| PUT | Zamenjuje resurs | Da | Da | Ne |
| PATCH | Delimično ažurira | Da | Ne | Ne |
| DELETE | Uklanja resurs | Obično ne | Da | Ne |
| OPTIONS | Dobija dozvoljene metode | Ne | Da | Da |
| HEAD | Isto kao GET ali bez tela | Ne | Da | Da |

**Idempotentno** znači da višestruko pozivanje daje isti rezultat. **Bezopasno** znači da ne menja ništa na serveru.

### Realni Scenario

Pretraživač učitava web stranicu. Evo šta se dešava:

```text
1. Pretraživač šalje:
   GET /index.html HTTP/1.1
   Host: example.com
   Accept: text/html

2. Server odgovara:
   HTTP/1.1 200 OK
   Content-Type: text/html
   Content-Length: 1234

   <html>...</html>

3. Pretraživač vidi <img src="/logo.png"> u HTML-u, šalje drugi zahtev:
   GET /logo.png HTTP/1.1
   Host: example.com
   Accept: image/png

4. Server odgovara:
   HTTP/1.1 200 OK
   Content-Type: image/png
   Content-Length: 5678

   [binarni podaci slike]
```

Sa HTTP/2, zahtevi 1 i 3 mogu se desiti istovremeno na jednoj konekciji umesto da se čeka jedan za drugim.

### Zaključak

HTTP zahtev sadrži metodu, URL, zaglavlja i opciono telo. HTTP odgovor sadrži status kod, zaglavlja i telo. HTTP/1.1 je tekstualni i obrađuje zahteve sekvencijalno. HTTP/2 je binarni, podržava multipleksiranje (paralelni zahtevi na jednoj konekciji), kompresiju zaglavlja i server push. Razumevanje ove strukture pomaže pri debagovanju API poziva, čitanju serverskih logova ili konfigurisanju web servera.
