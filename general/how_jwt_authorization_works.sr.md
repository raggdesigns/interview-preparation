# Kako Funkcioniše JWT Autorizacija

JWT (JSON Web Token) je kompaktan, samodovoljan format tokena koji se koristi za bezbedno prenošenje tvrdnji o identitetu i autorizaciji između strana. Omogućava **bezdržavnu autentikaciju** — server ne mora da čuva sesije jer su sve potrebne informacije kodirane unutar samog tokena.

> **Scenario koji se koristi kroz ovaj dokument:** Symfony API na `api.shop.com` izdaje JWT-ove nakon prijave. React frontend čuva token i šalje ga sa svakim API zahtevom. API validira token bez pogađanja baze podataka.

## Preduslovi

- [Kako Funkcioniše Autentikacija](how_authentication_works.sr.md) — JWT se izdaje nakon uspešne autentikacije
- [Kako Funkcioniše Autorizacija](how_authorization_works.sr.md) — JWT tvrdnje se koriste za odluke o autorizaciji

## Struktura JWT-a

JWT ima tri dela odvojena tačkama: `Header.Payload.Signature`

```text
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsInJvbGVzIjpbIlJPTEVfRURJVE9SIl0sImV4cCI6MTcxMDAwMDAwMH0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
│               Header              │                    Payload                       │              Signature              │
```

**Dekodovano:**

```json
// Header — algoritam i tip tokena
{
  "alg": "HS256",
  "typ": "JWT"
}

// Payload — tvrdnje (korisnički podaci + metapodaci)
{
  "sub": "42",
  "roles": ["ROLE_EDITOR"],
  "email": "editor@shop.com",
  "exp": 1710000000,
  "iat": 1709996400
}

// Signature — osigurava da token nije izmenjen
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret_key
)
```

### Registrovane Tvrdnje

| Tvrdnja | Naziv | Svrha |
|---------|-------|-------|
| `sub` | Subject | ID korisnika |
| `exp` | Expiration | Unix timestamp kada token ističe |
| `iat` | Issued At | Kada je token kreiran |
| `nbf` | Not Before | Token nije validan pre ovog vremena |
| `iss` | Issuer | Ko je kreirao token (npr. `api.shop.com`) |
| `aud` | Audience | Za koga je token namenjen |
| `jti` | JWT ID | Jedinstveni identifikator za ovaj token |

## Kako Tok Funkcioniše

```text
1. Korisnik se prijavljuje:
   POST /api/login
   Body: {"email": "editor@shop.com", "password": "secret"}

2. Server verifikuje kredencijale → kreira JWT:
   Odgovor: {"token": "eyJhbG...w5c", "refresh_token": "dGhpcyBpcyBh..."}

3. Klijent čuva token i šalje ga sa svakim zahtevom:
   GET /api/articles
   Authorization: Bearer eyJhbG...w5c

4. Server prima zahtev:
   a) Izvlači token iz Authorization zaglavlja
   b) Verifikuje potpis koristeći tajni ključ
   c) Proverava exp tvrdnju → nije istekao?
   d) Čita tvrdnje (sub, roles) → user_id=42, roles=[ROLE_EDITOR]
   e) Prosleđuje zahtev kontroleru sa korisničkim kontekstom

5. Nije potrebno traženje sesije u bazi podataka — sve informacije su u tokenu.
```

## PHP Implementacija

Koristeći biblioteku `firebase/php-jwt`:

### Kreiranje Tokena (Login Endpoint)

```php
use Firebase\JWT\JWT;

final class AuthController
{
    public function __construct(
        private readonly UserRepository $users,
        private readonly string $jwtSecret,    // iz env: JWT_SECRET
        private readonly int $tokenTtl = 3600, // 1 sat
    ) {}

    public function login(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $user = $this->users->findByEmail($data['email']);

        if ($user === null || !password_verify($data['password'], $user->getPasswordHash())) {
            return new JsonResponse(['error' => 'Invalid credentials'], 401);
        }

        $now = time();
        $payload = [
            'sub'   => (string) $user->getId(),
            'email' => $user->getEmail(),
            'roles' => $user->getRoles(),
            'iat'   => $now,
            'exp'   => $now + $this->tokenTtl,
        ];

        $token = JWT::encode($payload, $this->jwtSecret, 'HS256');

        return new JsonResponse([
            'token'      => $token,
            'expires_in' => $this->tokenTtl,
        ]);
    }
}
```

### Verifikacija Tokena (Middleware)

```php
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\ExpiredException;
use Firebase\JWT\SignatureInvalidException;

final class JwtAuthMiddleware
{
    public function __construct(
        private readonly string $jwtSecret,
    ) {}

    public function handle(Request $request, callable $next): Response
    {
        $header = $request->headers->get('Authorization', '');

        if (!str_starts_with($header, 'Bearer ')) {
            return new JsonResponse(['error' => 'Token missing'], 401);
        }

        $token = substr($header, 7);

        try {
            $decoded = JWT::decode($token, new Key($this->jwtSecret, 'HS256'));
        } catch (ExpiredException) {
            return new JsonResponse(['error' => 'Token expired'], 401);
        } catch (SignatureInvalidException) {
            return new JsonResponse(['error' => 'Invalid token'], 401);
        } catch (\Exception) {
            return new JsonResponse(['error' => 'Token error'], 401);
        }

        // Priložite korisnički kontekst zahtevu za kontrolere
        $request->attributes->set('user_id', $decoded->sub);
        $request->attributes->set('user_roles', $decoded->roles);

        return $next($request);
    }
}
```

## Tok Refresh Tokena

Access tokeni su kratkoročni (minute do 1 sat). **Refresh tokeni** su dugoročni i koriste se za dobijanje novih access tokena bez ponovnog unosa kredencijala.

```text
Vremenski okvir:

0:00  → Korisnik se prijavljuje → prima access_token (1h) + refresh_token (30d)
0:59  → Access token uskoro ističe
1:00  → Klijent šalje refresh token:
          POST /api/token/refresh
          Body: {"refresh_token": "dGhpcyBpcyBh..."}
        → Server validira refresh token → izdaje novi access_token (1h)
1:01  → Klijent nastavlja sa novim access tokenom
```

**Ključna pravila:**

- Refresh tokeni se čuvaju **u bazi podataka** (za razliku od access tokena) tako da mogu biti opozvani
- Kada se refresh token upotrebi, **rotirajte ga** — izdajte novi i poništite stari
- Ako se refresh token upotrebi dva puta, znači da je ukraden — **poništite celu porodicu**

```php
public function refresh(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);
    $storedToken = $this->refreshTokenRepository->findByToken($data['refresh_token']);

    if ($storedToken === null || $storedToken->isExpired()) {
        return new JsonResponse(['error' => 'Invalid refresh token'], 401);
    }

    // Rotacija: poništite stari, kreirajte novi
    $this->refreshTokenRepository->revoke($storedToken);

    $user = $this->users->find($storedToken->getUserId());
    $newAccessToken = $this->createAccessToken($user);
    $newRefreshToken = $this->createRefreshToken($user);

    return new JsonResponse([
        'token'         => $newAccessToken,
        'refresh_token' => $newRefreshToken,
        'expires_in'    => $this->tokenTtl,
    ]);
}
```

## Skladištenje Tokena: Gde Čuvati JWT

| Skladište | Bezbedan od XSS? | Bezbedan od CSRF? | Preporučeno? |
|-----------|-----------------|-------------------|--------------|
| `localStorage` | Ne — bilo koji JS može da ga pročita | Da — ne šalje se automatski | Ne za osetljive aplikacije |
| `sessionStorage` | Ne — bilo koji JS može da ga pročita | Da — ne šalje se automatski | Ne za osetljive aplikacije |
| HttpOnly kolačić | Da — JS ne može da pristupi | Ne — šalje se sa svakim zahtevom | Da, sa CSRF tokenom |
| Memorija (JS promenljiva) | Da — nema persistencije | Da | Da, ali se gubi pri osvežavanju |

**Preporučena praksa:** Čuvajte access token u **HttpOnly, Secure, SameSite=Strict kolačiću**. Ovo sprečava XSS od krađe tokena, a `SameSite=Strict` ublažava CSRF.

## Bezbednosne Zamke

### 1. Napad `alg: none`

Neke JWT biblioteke prihvataju `"alg": "none"`, što znači **bez verifikacije potpisa**. Napadač može da falsifikuje bilo koji token.

```json
// Falsifikovani token — potpis nije potreban
{"alg": "none", "typ": "JWT"}
{"sub": "1", "roles": ["ROLE_ADMIN"], "exp": 9999999999}
```

**Prevencija:** Uvek eksplicitno navedite dozvoljeni algoritam u kodu za verifikaciju:

```php
// ✅ Bezbedno — prihvata samo HS256
JWT::decode($token, new Key($secret, 'HS256'));

// ❌ Nebezbedno — biblioteka može prihvatiti alg:none
JWT::decode($token, $secret);  // ne radite ovo
```

### 2. Čuvanje Osetljivih Podataka u Payload-u

JWT payload-ovi su **base64-enkodovani, nisu enkriptovani**. Svako ih može dekodovati:

```bash
echo "eyJzdWIiOiI0MiIsInJvbGVzIjpbIlJPTEVfRURJVE9SIl19" | base64 -d
# {"sub":"42","roles":["ROLE_EDITOR"]}
```

**Nikada ne stavljajte lozinke, brojeve kreditnih kartica ili tajne u payload.**

### 3. Problem Opoziva Tokena

JWT-ovi su bezdržavni — server ne može da poništi jedan token jednom kada je izdat. Ako je token ukraden, ostaje validan dok ne istekne.

**Ublažavanja:**

- Držite TTL access tokena kratkim (15 minuta)
- Održavajte **blocklist tokena** u Redis-u za prisilne odjave
- Koristite rotaciju refresh tokena da biste ograničili vremenski prozor štete

## JWT vs. Autentikacija Bazirana na Sesijama

| Aspekt | JWT | Sesija |
|--------|-----|--------|
| Stanje | Bezdržavno (token ima sve podatke) | Statefull (sesija uskladištena na serveru) |
| Skalabilnost | Lako — nema deljenog stanja između servera | Teško — potreban deljeni storage sesija (Redis) |
| Opoziv | Teško — ne može se poništiti bez blocklist-e | Lako — obrišite sesiju iz storage-a |
| Veličina | Veći (payload u svakom zahtevu) | Mali (samo ID kolačić sesije) |
| Najpogodnije za | API-ji, mikroservisi, mobilne aplikacije | Tradicionalne server-renderovane web aplikacije |

## Česta Pitanja na Intervjuima

### P: Zašto koristiti JWT umesto sesija?

**O:** JWT-ovi dobro rade za API-je i mikroservise jer su **bezdržavni** — bilo koji server može da validira token koristeći tajni ključ bez pogađanja baze podataka. Sesije zahtevaju **deljeni storage sesija** (Redis, baza podataka), što dodaje infrastrukturnu složenost. JWT-ovi su takođe **prijateljski prema međudomenskim pozivima** — `Authorization` zaglavlje radi između različitih domena, dok su kolačići vezani pravilima istog porekla.

### P: Kako se upravlja istekom JWT-a i odjavom?

**O:** Koristite **kratkoročne access tokene** (15-60 minuta) kombinovane sa **refresh tokenima** (dani/sedmice). Za odjavu, klijent odbacuje token, a za prisilnu odjavu na strani servera, dodajte `jti` tokena u **Redis blocklist** koji middleware za validaciju proverava. Unosi blocklist-e automatski ističu kada bi token inače istekao.

### P: Šta se dešava ako je JWT ukraden?

**O:** Napadač ga može koristiti dok ne istekne — ovo je glavni nedostatak bezdržavnih tokena. Ublažavanja: držite TTL access tokena kratkim (15 min), koristite **rotaciju refresh tokena** (svaka upotreba poništava stari token), čuvajte tokene u **HttpOnly kolačićima** da biste sprečili XSS krađu i implementirajte **token blocklist** za hitni opoziv.

## Zaključak

JWT autorizacija omogućava bezdržavnu API autentikaciju kodiranjem korisničkog identiteta i tvrdnji direktno u tokenu. Trodelna struktura (Header, Payload, Signature) osigurava integritet bez serverskog skladišta. Kompromis je jasan: dobijate horizontalnu skalabilnost i međuservisnu kompatibilnost, ali gubite lak opoziv. U praksi, većina produkcijskih sistema kombinuje kratkoročne JWT-ove sa rotacijom refresh tokena i Redis blocklist-om za prisilne odjave.

## Vidi Takođe

- [Kako Funkcioniše Autentikacija](how_authentication_works.sr.md)
- [Kako Funkcioniše Autorizacija](how_authorization_works.sr.md)
- [Šta je CSRF](csrf.sr.md) — relevantno za skladištenje tokena u kolačićima
- [Šta je CORS](cors.sr.md) — relevantno za međudomeniske API pozive sa Bearer tokenima
