CSRF (Cross-Site Request Forgery) je napad u kome zlonamerna veb stranica navodi pregledač korisnika da izvrši neželjenu akciju na veb stranici na kojoj je korisnik već prijavljen.

### Kako napad funkcioniše

Napad eksploatiše činjenicu da pregledači automatski šalju kolačiće (uključujući sesijske kolačiće) uz svaki zahtev prema veb stranici.

#### Korak po korak

1. **Korisnik se prijavljuje** na `bank.com`. Pregledač čuva sesijski kolačić.
2. **Korisnik poseti** zlonamerni sajt (`evil.com`) dok je i dalje prijavljen na `bank.com`.
3. **Zlonamerna stranica** sadrži kod koji šalje zahtev ka `bank.com`:

```html
<!-- Na evil.com — skriveni formular koji se automatski podnosi -->
<form action="https://bank.com/transfer" method="POST" id="attack">
    <input type="hidden" name="to" value="attacker-account">
    <input type="hidden" name="amount" value="5000">
</form>
<script>document.getElementById('attack').submit();</script>
```

1. **Pregledač šalje** zahtev ka `bank.com` sa korisnikovim sesijskim kolačićem priloženim.
2. **bank.com prima** zahtev i vidi validnu sesiju → obrađuje prenos.

Korisnik nije nameravao da izvrši prenos. Nije čak ni video formular — bio je skriven i automatski podnet.

#### Zašto funkcioniše

```text
Pregledač korisnika ima kolačić: session_id=abc123

Kada evil.com šalje zahtev ka bank.com:
  POST /transfer
  Cookie: session_id=abc123    ← pregledač ovo prilaže automatski!
  Body: to=attacker&amount=5000

bank.com vidi validnu sesiju → obrađuje zahtev
```

Server ne može razlikovati legitimni zahtev korisnika od falsifikovanog zahteva sa evil.com, jer oba dolaze iz istog pregledača sa istim kolačićima.

### Šta CSRF može da uradi

CSRF napadi mogu izvršiti bilo koju akciju koju korisnik sme da uradi:

- Prenos novca
- Promena email-a ili lozinke
- Promena podešavanja naloga
- Kupovine
- Brisanje podataka
- Dodavanje admin korisnika

CSRF **ne može** čitati odgovor — može samo pokretati akcije (operacije pisanja).

### Metode prevencije

#### 1. CSRF tokeni (Synchronizer Token Pattern)

Uključi jedinstven, nepredvidljiv token u svaki formular. Server verifikuje ovaj token pri podnošenju. Napadač ne može znati token, pa ne može kreirati validan zahtev.

```php
// Generate token and include in form
session_start();
$token = bin2hex(random_bytes(32));
$_SESSION['csrf_token'] = $token;
```

```html
<form method="POST" action="/transfer">
    <input type="hidden" name="csrf_token" value="<?= $token ?>">
    <input name="to" placeholder="Recipient">
    <input name="amount" placeholder="Amount">
    <button>Transfer</button>
</form>
```

```php
// Verify token on the server
if (!isset($_POST['csrf_token']) || $_POST['csrf_token'] !== $_SESSION['csrf_token']) {
    http_response_code(403);
    die('Invalid CSRF token');
}
```

Napadač na `evil.com` ne može pročitati token jer se nalazi na drugom domenu (blokira ga Same-Origin Policy).

#### 2. Symfony CSRF zaštita

Symfony ima ugrađenu CSRF podršku:

```php
// In a Twig form
{{ form_start(form) }}
    {# CSRF token is automatically included #}
    {{ form_row(form.amount) }}
    {{ form_row(form.recipient) }}
    <button>Transfer</button>
{{ form_end(form) }}
```

Za ručne formulare:

```html
<form method="POST">
    <input type="hidden" name="_token" value="{{ csrf_token('transfer') }}">
    <!-- form fields -->
</form>
```

```php
// In the controller
use Symfony\Component\Security\Csrf\CsrfToken;

public function transfer(Request $request): Response
{
    $token = new CsrfToken('transfer', $request->request->get('_token'));

    if (!$this->csrfTokenManager->isTokenValid($token)) {
        throw new AccessDeniedHttpException('Invalid CSRF token');
    }

    // Process the transfer...
}
```

#### 3. SameSite atribut kolačića

`SameSite` atribut na kolačićima govori pregledaču kada da uključi kolačić u zahteve sa drugog sajta:

| Vrednost | Ponašanje |
|----------|-----------|
| `Strict` | Kolačić se nikada ne šalje uz zahteve sa drugog sajta |
| `Lax` | Kolačić se šalje uz GET zahteve sa drugog sajta (linkovi), ali ne uz POST |
| `None` | Kolačić se uvek šalje (mora biti korišćen `Secure` flag) |

```php
// PHP configuration
session.cookie_samesite = "Lax"

// Or set in code
session_set_cookie_params([
    'samesite' => 'Lax',
    'secure' => true,
    'httponly' => true,
]);
```

`Lax` je dobar podrazumevani izbor — blokira CSRF putem POST formulara sa drugih sajtova, ali i dalje dozvoljava normalnu navigaciju putem linkova.

#### 4. Double Submit Cookie

Pošalji CSRF token i u kolačiću i u telu zahteva. Server ih poredi — ako se poklapaju, zahtev je legitiman. Ovo funkcioniše jer napadač može slati kolačiće (pregledač to radi automatski), ali ne može ih čitati sa drugog domena.

#### 5. Provjeri Referer/Origin zaglavlje

```php
$origin = $request->headers->get('Origin') ?? $request->headers->get('Referer');
$allowed = 'https://myapp.com';

if ($origin !== null && !str_starts_with($origin, $allowed)) {
    throw new AccessDeniedHttpException('Invalid origin');
}
```

Ovo nije glavna odbrana (zaglavlja mogu biti odsutna), ali dodaje dodatni sloj zaštite.

### CSRF i REST API-ji

REST API-ji koji koriste autentikaciju zasnovanu na tokenima (Bearer tokeni u Authorization zaglavlju) **nisu ranjivi** na CSRF. Razlog je:

- Pregledač ne šalje automatski `Authorization` zaglavlje
- Token mora biti eksplicitno dodat od strane JavaScript-a
- Stranica napadača ne može pristupiti tokenu (Same-Origin Policy)

```text
// Cookie-based auth — RANJIVO na CSRF
POST /api/transfer
Cookie: session_id=abc123    ← pregledač automatski šalje

// Token-based auth — NIJE ranjivo na CSRF
POST /api/transfer
Authorization: Bearer eyJhbGci...    ← mora biti eksplicitno dodat od strane JavaScript-a
```

### Stvarni scenario

Gradiš stranicu za podešavanja korisnika u Symfony-u. Bez CSRF zaštite:

```php
// Opasno — nema CSRF provere
#[Route('/settings/email', methods: ['POST'])]
public function changeEmail(Request $request): Response
{
    $user = $this->getUser();
    $user->setEmail($request->request->get('email'));
    $this->entityManager->flush();

    return new Response('Email updated');
}
// Napadač kreira stranicu sa skrivenim formularom koji pokazuje na /settings/email
// Bilo koji prijavljeni korisnik koji poseti stranicu napadača dobija promenjen email
```

Sa CSRF zaštitom:

```php
#[Route('/settings/email', methods: ['POST'])]
public function changeEmail(Request $request): Response
{
    $token = new CsrfToken('change_email', $request->request->get('_token'));
    if (!$this->csrfTokenManager->isTokenValid($token)) {
        throw new AccessDeniedHttpException('Invalid CSRF token');
    }

    $user = $this->getUser();
    $user->setEmail($request->request->get('email'));
    $this->entityManager->flush();

    return new Response('Email updated');
}
```

Sada napadač ne može falsifikovati zahtev jer ne zna vrednost CSRF tokena.

### Zaključak

CSRF napadi navode pregledač da izvrši neželjene akcije eksploatišući automatsko slanje kolačića. Glavne odbrane su: CSRF tokeni (jedinstveni po formularu), SameSite kolačići (`Lax` ili `Strict`), i provjera Origin/Referer zaglavlja. API-ji zasnovani na tokenima (Bearer tokeni) nisu ranjivi jer pregledač ne šalje token automatski. Symfony pruža ugrađenu CSRF zaštitu za formulare.

> Vidi takođe: [OWASP Top 10](owasp_top_10.sr.md), [Glavni napadi na veb aplikacije](web_application_attacks.sr.md), [Šta je CORS](cors.sr.md)
