# Kako Funkcioniše Autentikacija

Autentikacija je proces verifikacije **ko je korisnik**. Odgovara na pitanje "Ko si ti?" i odvija se pre autorizacije (koja odlučuje šta ti je dozvoljeno da radiš). Svaka web aplikacija zahteva barem jedan metod autentikacije, a većina produkcijskih sistema kombinuje nekoliko.

> **Scenario koji se koristi kroz ovaj dokument:** E-commerce API na `api.shop.com` sa Symfony backendom. Korisnici se prijavljuju putem email/lozinke, a API izdaje JWT. Admin panel koristi autentikaciju baziranu na sesijama. Integracije trećih strana se autentikuju putem API ključeva.

## Preduslovi

- [Struktura HTTP Protokola](http_protocol_structure.sr.md) — zaglavlja, kolačići i status kodovi koji se koriste tokom autentikacije
- [Šta je CSRF](csrf.sr.md) — relevantno za autentikaciju baziranu na sesijama

## Metodi Autentikacije

### 1. Autentikacija Bazirana na Lozinci

Korisnik šalje kredencijale, a server ih verifikuje u odnosu na uskladišteni hash. **Nikada ne čuvajte lozinke u čistom tekstu.**

```php
// Registracija — hash-ujte lozinku
$hash = password_hash($plainPassword, PASSWORD_ARGON2ID);
// Čuva: $2y$... ili $argon2id$... hash u bazi podataka

// Prijava — verifikujte lozinku
$user = $userRepository->findByEmail($email);

if ($user === null || !password_verify($plainPassword, $user->getPasswordHash())) {
    return new JsonResponse(['error' => 'Invalid credentials'], 401);
}

// Lozinka je ispravna → nastavi sa izdavanjem sesije ili tokena
```

**Kako `password_hash` funkcioniše:**

```text
Ulaz:  "my-secret-password"
Izlaz: "$argon2id$v=19$m=65536,t=4,p=1$c2FsdHNhbHQ$hash..."
        │         │                  │          │
        algoritam  parametri          so        hash
```

So se generiše automatski i čuva unutar stringa hash-a, tako da svaki korisnik dobija jedinstveni hash čak i ako koriste istu lozinku.

**Bezbednosna pravila:**

- Koristite `PASSWORD_ARGON2ID` (preporučeno) ili `PASSWORD_BCRYPT`
- Implementirajte ograničenje brzine na login endpoint-ima (npr. 5 pokušaja u minuti)
- Dodajte blokadu naloga nakon ponovljenih neuspešnih pokušaja
- Uvek koristite HTTPS

### 2. Autentikacija Bazirana na Sesijama

Nakon verifikacije kredencijala, server kreira **sesiju** uskladištenu na strani servera i šalje **ID sesije** kao kolačić klijentu.

```text
Tok prijave:

1. POST /login
   Body: {"email": "user@shop.com", "password": "secret"}

2. Server verifikuje kredencijale → kreira sesiju:
   Session store (Redis):  session:abc123 → {user_id: 42, roles: ["editor"]}

3. Odgovor:
   HTTP/1.1 200 OK
   Set-Cookie: PHPSESSID=abc123; HttpOnly; Secure; SameSite=Strict

4. Naknadni zahtevi — pretraživač automatski šalje kolačić:
   GET /api/profile
   Cookie: PHPSESSID=abc123

5. Server traži session:abc123 u Redis-u → nalazi user_id=42 → autorizovano
```

**PHP implementacija:**

```php
// Prijava
session_start();

$user = $userRepository->findByEmail($email);
if ($user !== null && password_verify($password, $user->getPasswordHash())) {
    // Regeneriši ID sesije da biste sprečili fiksaciju sesije
    session_regenerate_id(true);

    $_SESSION['user_id'] = $user->getId();
    $_SESSION['roles']   = $user->getRoles();
}

// Zaštićeni endpoint
session_start();
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    exit;
}
$userId = $_SESSION['user_id'];
```

**Prednosti:** Server može odmah poništiti sesiju (samo je obrišite iz Redis-a).
**Nedostaci:** Zahteva deljeno skladište sesija za horizontalno skaliranje (više servera).

### 3. Autentikacija Bazirana na Tokenima (JWT)

Bezdržavni pristup — server izdaje potpisani token koji sadrži korisničke tvrdnje. Nije potrebno serversko skladište sesija. Pogledajte [Kako Funkcioniše JWT Autorizacija](how_jwt_authorization_works.sr.md) za potpune detalje.

```text
Tok prijave:

1. POST /api/login → server verifikuje kredencijale → izdaje JWT
2. Klijent čuva token (HttpOnly kolačić ili memorija)
3. Svaki zahtev: Authorization: Bearer eyJhbG...
4. Server verifikuje potpis + istek → izvlači user_id i uloge
```

**Ključna razlika od sesija:** Sam token nosi sve korisničke podatke. Bilo koji server sa tajnim ključem može ga validirati — nije potreban deljeni storage sesija.

### 4. Višefaktorska Autentikacija (MFA)

Kombinuje dva ili više nezavisnih faktora:

| Faktor | Tip | Primeri |
|--------|-----|---------|
| Nešto što **znate** | Znanje | Lozinka, PIN |
| Nešto što **imate** | Posedovanje | Telefon (TOTP aplikacija), hardverski ključ (YubiKey) |
| Nešto što **jeste** | Inherencija | Otisak prsta, prepoznavanje lica |

**TOTP (Vremenski Jednookratna Lozinka) tok:**

```text
1. Korisnik omogućava MFA → server generiše deljenu tajnu
2. Server prikazuje QR kod → korisnik ga skenira sa Google Authenticator-om
3. Pri prijavi, nakon verifikacije lozinke:
   - Server traži 6-cifreni kod
   - Korisnik otvara autentikator aplikaciju → unosi kod
   - Server izračunava očekivani kod iz deljene tajne + trenutnog vremena
   - Ako se kodovi podudaraju → autentifikovano
```

```php
// Korišćenje pragmarx/google2fa
use PragmaRX\Google2FA\Google2FA;

$google2fa = new Google2FA();

// Podešavanje: generišite tajnu za korisnika (čuvajte u DB)
$secret = $google2fa->generateSecretKey();

// Verifikacija: proverite da li je korisnički kod validan
$isValid = $google2fa->verifyKey($user->getTotpSecret(), $codeFromUser);

if (!$isValid) {
    return new JsonResponse(['error' => 'Invalid 2FA code'], 401);
}
```

### 5. OAuth 2.0 / OpenID Connect

Delegira autentikaciju **provajderu identiteta treće strane** (Google, GitHub, itd.). Korisnik nikada ne deli svoju lozinku sa vašom aplikacijom.

**Tok Authorization Code Grant:**

```text
1. Korisnik klikne "Prijavi se sa Google-om"
   → Pretraživač preusmerava na:
     https://accounts.google.com/o/oauth2/v2/auth?
       client_id=YOUR_CLIENT_ID
       &redirect_uri=https://shop.com/callback
       &response_type=code
       &scope=openid email profile

2. Korisnik se autentifikuje sa Google-om → daje pristanak

3. Google preusmerava nazad sa authorization kodom:
     https://shop.com/callback?code=AUTH_CODE_HERE

4. Server zamenjuje kod za tokene (server-to-server):
   POST https://oauth2.googleapis.com/token
   Body: {
     "code": "AUTH_CODE_HERE",
     "client_id": "YOUR_CLIENT_ID",
     "client_secret": "YOUR_SECRET",
     "redirect_uri": "https://shop.com/callback",
     "grant_type": "authorization_code"
   }

   Odgovor: {
     "access_token": "ya29.a0...",
     "id_token": "eyJhbG...",    ← JWT sa podacima o korisniku
     "expires_in": 3600
   }

5. Server dekodira id_token → dobija korisnikov email, ime → kreira/pronalazi lokalnog korisnika
```

**OpenID Connect** dodaje sloj identiteta na vrh OAuth 2.0 — `id_token` je JWT koji sadrži tvrdnje o korisniku (`sub`, `email`, `name`).

### 6. API Key Autentikacija

Jednostavna metoda za komunikaciju **mašina-sa-mašinom**. Klijent uključuje ključ u zaglavlju zahteva.

```text
GET /api/products
X-API-Key: sk_live_a1b2c3d4e5f6...
```

**Ograničenja:** Nema korisničkog konteksta, pristup je sve-ili-ništa, rotacija ključeva je ručna. Koristite API ključeve za pozive servis-ka-servisu, ne za autentikaciju krajnjih korisnika.

## Tabela Poređenja

| Metod | Statefull? | Skalabilnost | Opoziv | Najpogodnije za |
|-------|-----------|-------------|--------|-----------------|
| Sesija | Da (server-side) | Potreban deljeni storage | Trenutni (briši sesiju) | Server-renderirane web aplikacije |
| JWT | Ne (bezdržavno) | Lako (nema deljenog stanja) | Teško (potrebna blocklist) | API-ji, mikroservisi, SPA |
| OAuth 2.0 | Zavisi od tipa tokena | Lako | Zavisi od provajdera | Prijava trećih strana, SSO |
| API Key | Ne | Lako | Rotiraj ključ | Mašina-sa-mašinom |
| MFA | Dodaje se svakom metodu | Isto kao bazni metod | Isto kao bazni metod | Nalozi visoke bezbednosti |

## Česta Pitanja na Intervjuima

### P: Autentikacija bazirana na sesijama vs. autentikacija bazirana na tokenima — kada biste odabrali koju?

**O:** Koristite **sesije** za tradicionalne server-renderovane aplikacije gde server kontroliše HTML — sesije su jednostavne, odmah se mogu opozvati i prirodno rade sa pregledačkim kolačićima. Koristite **JWT tokene** za API-je koje koriste SPA, mobilne aplikacije ili mikroservisi — tokeni su bezdržavni, ne trebaju deljeni storage i rade između domena bez komplikacija sa CORS kolačićima.

### P: Kako bezbedno čuvate lozinke?

**O:** Koristite `password_hash()` sa `PASSWORD_ARGON2ID` — automatski generiše jedinstvenu so po lozinci i proizvodi jednosmerni hash. Pri prijavi, koristite `password_verify()` za poređenje. Nikada ne koristite MD5, SHA1 ili SHA256 samostalno — previše su brzi i ranjivi na rainbow table napade. Argon2 i bcrypt su namerno spori, čineći napade grubom silom nepraktičnim.

### P: Koja je razlika između OAuth 2.0 i OpenID Connect?

**O:** OAuth 2.0 je **autorizacioni** okvir — daje vašoj aplikaciji access token za pozivanje API-ja u ime korisnika, ali ne govori vam ko je korisnik. OpenID Connect je **autentikacioni** sloj na vrhu OAuth 2.0 — dodaje `id_token` (JWT) koji sadrži tvrdnje o identitetu korisnika (`sub`, `email`, `name`). Ukratko: OAuth = "daj pristup", OIDC = "daj pristup + dokaži identitet."

## Zaključak

Autentikacija verifikuje identitet korisnika putem kredencijala, tokena ili delegiranih provajdera identiteta. Izbor između autentikacije zasnovane na sesijama i autentikacije zasnovane na tokenima zavisi od vaše arhitekture: sesije za server-renderovane aplikacije sa lakim opozivom, JWT-ovi za bezdržavne API-je sa horizontalnom skalabilnošću. U praksi, većina produkcijskih sistema kombinuje više metoda — lozinka + MFA za prijavu, JWT za API pristup, OAuth za integracije trećih strana i API ključevi za komunikaciju servis-ka-servisu.

## Vidi Takođe

- [Kako Funkcioniše Autorizacija](how_authorization_works.sr.md) — šta se dešava nakon autentikacije
- [Kako Funkcioniše JWT Autorizacija](how_jwt_authorization_works.sr.md) — dubinska analiza JWT strukture i bezbednosti
- [Šta je CSRF](csrf.sr.md) — autentikacija bazirana na sesijama zahteva CSRF zaštitu
- [OWASP Top 10](owasp_top_10.sr.md) — neuspesi autentikacije su u top 10
