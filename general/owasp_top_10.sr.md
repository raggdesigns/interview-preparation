OWASP (Open Web Application Security Project) objavljuje listu 10 najkritičnijih bezbednosnih rizika za web aplikacije. Ova lista se ažurira svake nekoliko godina. U nastavku je OWASP Top 10 (izdanje 2021) sa jednostavnim objašnjenjima i primerima.

### 1. Povređena Kontrola Pristupa

Korisnici mogu da rade stvari koje im ne bi trebalo biti dozvoljeno. Na primer, obični korisnik može da pristupi admin stranicama ili vidi podatke drugih korisnika.

```php
// Ranjivo — bez provere dozvola
public function deleteUser(int $userId): Response
{
    $this->userRepository->delete($userId); // Bilo koji prijavljeni korisnik može obrisati koga god!
    return new JsonResponse(['deleted' => true]);
}

// Popravljeno — proverite dozvole
public function deleteUser(int $userId): Response
{
    if (!$this->getUser()->hasRole('ADMIN')) {
        throw new AccessDeniedHttpException();
    }
    $this->userRepository->delete($userId);
    return new JsonResponse(['deleted' => true]);
}
```

Česti primeri:
- Promena ID-a korisnika u URL-u da biste videli tuđe podatke (`/api/users/123` → `/api/users/456`)
- Pristup admin endpointima bez admin uloge
- Zaobilaženje provera pristupa modifikacijom API zahteva

### 2. Kriptografski Neuspesi

Osetljivi podaci nisu pravilno zaštićeni. To uključuje slabu enkripciju, čuvanje lozinki u čistom tekstu, prenos podataka bez HTTPS-a ili korišćenje zastarelih algoritama.

```php
// Loše — čuvanje lozinke u čistom tekstu
$user->setPassword($_POST['password']);

// Dobro — hash-ujte lozinku
$user->setPassword(password_hash($_POST['password'], PASSWORD_BCRYPT));

// Loše — slab algoritam
$hash = md5($password);

// Dobro — jak algoritam
$hash = password_hash($password, PASSWORD_ARGON2ID);
```

Takođe uključuje:
- Nekorišćenje HTTPS-a
- Izlaganje osetljivih podataka u logovima ili porukama grešaka
- Korišćenje slabih ili zastarelih TLS verzija

### 3. Injekcija

Nepouzdani podaci se šalju interpreteru kao deo komande ili upita. Najpoznatiji tip je SQL injekcija.

```php
// Ranjivo na SQL injekciju
$query = "SELECT * FROM users WHERE email = '" . $_GET['email'] . "'";
// Napadač šalje: ' OR '1'='1' --
// Rezultat: SELECT * FROM users WHERE email = '' OR '1'='1' --'

// Popravljeno — koristite prepared statements
$stmt = $pdo->prepare("SELECT * FROM users WHERE email = ?");
$stmt->execute([$_GET['email']]);
```

Drugi tipovi injekcija:
- **Command Injection**: `exec("ping " . $_GET['host'])` — napadač šalje `; rm -rf /`
- **LDAP Injection**: injektovanje u LDAP upite
- **XSS** je takođe forma injekcije (injektovanje JavaScript-a u HTML)

> Vidi takođe: [Napadi na web aplikacije](web_application_attacks.sr.md) za detaljne primere.

### 4. Nesigurni Dizajn

Sama arhitektura aplikacije ima bezbednosne nedostatke. Radi se o nedostajućim bezbednosnim zahtevima u fazi dizajna, a ne o greškama u kodu.

Primeri:
- Nema ograničenja brzine na endpoint-u za reset lozinke (dozvoljava brute force)
- Bezbednosna pitanja sa lako pogodivim odgovorima
- Nema ograničenja na broj stavki koje korisnik može da doda u korpu (iscrpljivanje resursa)
- Nedostaje višefaktorska autentikacija za osetljive operacije

### 5. Pogrešna Bezbednosna Konfiguracija

Aplikacija ili server su nepravilno konfigurisani, ostavljajući bezbednosne rupe.

```
# Loše — debug mod u produkciji
APP_ENV=dev
APP_DEBUG=true

# Dobro — produkciona konfiguracija
APP_ENV=prod
APP_DEBUG=false
```

Česti primeri:
- Podrazumevane lozinke na admin nalozima
- Nepotrebne funkcije omogućene (listanje direktorijuma, debug toolbar)
- Nedostaju bezbednosna zaglavlja (`X-Frame-Options`, `Content-Security-Policy`)
- Previše permisivna CORS konfiguracija
- Stack trace-ovi prikazani korisnicima

### 6. Ranjive i Zastarele Komponente

Korišćenje biblioteka, radnih okvira ili sistemskih komponenti sa poznatim bezbednosnim ranjivostima.

```bash
# Proverite poznate ranjivosti u PHP zavisnostima
composer audit

# Ažurirajte zavisnosti
composer update --with-all-dependencies
```

Prevencija:
- Redovno ažurirajte zavisnosti
- Pratite bezbednosna upozorenja (Symfony Security Advisories, GitHub Dependabot)
- Uklonite nekorišćene zavisnosti
- Koristite `composer audit` u CI/CD pipeline-u

### 7. Neuspesi Identifikacije i Autentikacije

Problemi sa sistemima za prijavu, upravljanjem sesijama ili verifikacijom identiteta.

Primeri:
- Dozvoljavanje slabih lozinki (`123456`)
- Nema zaštite od brute force napada (nema ograničenja brzine pri prijavi)
- ID-ovi sesija u URL-ovima
- Kredencijali se šalju putem HTTP-a umesto HTTPS-a
- Sesije se ne poništavaju nakon promene lozinke

```php
// Loše — nema zaštite od brute force
public function login(string $email, string $password): bool
{
    $user = $this->userRepository->findByEmail($email);
    return password_verify($password, $user->getPassword());
}

// Bolje — sa ograničenjem brzine
public function login(string $email, string $password): bool
{
    if ($this->rateLimiter->isBlocked($email)) {
        throw new TooManyRequestsException('Too many login attempts');
    }

    $user = $this->userRepository->findByEmail($email);
    if (!$user || !password_verify($password, $user->getPassword())) {
        $this->rateLimiter->recordFailure($email);
        return false;
    }

    $this->rateLimiter->reset($email);
    return true;
}
```

### 8. Neuspesi Integriteta Softvera i Podataka

Neverifikovanje integriteta ažuriranja softvera, CI/CD pipeline-ova ili podataka. Na primer, korišćenje biblioteka iz nepouzdanih izvora bez provere njihovog integriteta.

Primeri:
- Neverifikovanje checksum-ova preuzetih paketa
- Nesiguran CI/CD pipeline (napadač može injektovati zlonamerni kod tokom build-a)
- Nesigurna deserijalizacija — deserijalizacija nepouzdanih podataka može dovesti do izvršavanja koda

```php
// Opasno — deserijalizacija korisničkog unosa može izvršiti proizvoljni kod
$data = unserialize($_POST['data']); // NIKADA ne radite ovo!

// Bezbedno — koristite JSON
$data = json_decode($_POST['data'], true);
```

### 9. Neuspesi Bezbednosnog Logovanja i Monitoringa

Nepravilno logovanje bezbednosnih događaja. Bez dobrog logovanja, ne možete detektovati napade.

Šta logovati:
- Neuspele pokušaje prijave
- Neuspehe kontrole pristupa
- Neuspehe validacije unosa
- Greške servera

```php
// Logujte bezbednosno relevantne događaje
$this->logger->warning('Failed login attempt', [
    'email' => $email,
    'ip' => $request->getClientIp(),
    'timestamp' => new \DateTime(),
]);

$this->logger->alert('Unauthorized access attempt', [
    'user_id' => $user->getId(),
    'attempted_resource' => '/admin/users',
]);
```

Takođe važno: postavite upozorenja za sumnjive obrasce (mnogo neuspelih prijava sa jedne IP adrese, pokušaji pristupa admin endpointima).

### 10. Server-Side Request Forgery (SSRF)

Aplikacija preuzima URL koji pruža korisnik bez pravilne validacije. Napadač može naterati server da šalje zahteve internim servisima.

```php
// Ranjivo na SSRF
$url = $_GET['url'];
$content = file_get_contents($url);
// Napadač šalje: url=http://169.254.169.254/latest/meta-data/ (AWS metapodaci)
// Ili: url=http://localhost:6379/ (interni Redis)

// Popravljeno — validirajte i dozvolite samo specifične URL-ove
$url = $_GET['url'];
$parsed = parse_url($url);
$allowed = ['api.example.com', 'cdn.example.com'];
if (!in_array($parsed['host'], $allowed)) {
    throw new InvalidArgumentException('URL not allowed');
}
$content = file_get_contents($url);
```

### Realni Scenario

Radite bezbednosni pregled PHP aplikacije. Pronalazite ove probleme:

1. Admin panel nema proveru kontrole pristupa — svako sa URL-om može mu pristupiti → **Povređena Kontrola Pristupa (#1)**
2. Korisničke lozinke se čuvaju kao MD5 hash-evi → **Kriptografski Neuspesi (#2)**
3. Funkcija pretrage koristi `$_GET['q']` direktno u SQL upitu → **Injekcija (#3)**
4. Aplikacija radi u debug modu u produkciji → **Pogrešna Bezbednosna Konfiguracija (#5)**
5. Symfony verzija ima poznati CVE → **Ranjive Komponente (#6)**
6. Nema ograničenja brzine na login endpoint-u → **Neuspesi Autentikacije (#7)**
7. Nema log fajla za neuspele pokušaje prijave → **Neuspesi Logovanja (#9)**

Svaki od ovih direktno se mapira na OWASP Top 10 kategoriju, i svaki ima jasno rešenje.

### Zaključak

OWASP Top 10 pokriva najkritičnije rizike web bezbednosti: povređena kontrola pristupa, kriptografski neuspesi, injekcija, nesigurni dizajn, pogrešna konfiguracija, zastarele komponente, neuspesi autentikacije, neuspesi integriteta, neuspesi logovanja i SSRF. Poznavanje ovih pomaže vam da identifikujete i sprečite ranjivosti tokom razvoja i pregleda koda.

> Vidi takođe: [Glavni napadi na web aplikacije](web_application_attacks.sr.md), [Šta je CSRF](csrf.sr.md), [Šta je CORS](cors.sr.md)
