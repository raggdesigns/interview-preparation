Load balancer raspoređuje dolazni saobraćaj po više servera kako nijedan server ne bi bio preopterećen. Ovo je fundamentalna komponenta skalabilne backend arhitekture, ali kreira problem — **kako rukovati korisničkim sesijama** kada zahtevi mogu ići na različite servere.

### Šta je load balancer

Load balancer se nalazi između klijenta i tvojih aplikacijskih servera. Prima sve dolazne zahteve i prosleđuje ih jednom od dostupnih backend servera.

```text
                        ┌──────────┐
                   ┌───→│ Server 1 │
                   │    └──────────┘
┌────────┐    ┌────┴───┐
│ Client │───→│  Load  │ ┌──────────┐
│        │    │Balancer│─→│ Server 2 │
└────────┘    └────┬───┘ └──────────┘
                   │    ┌──────────┐
                   └───→│ Server 3 │
                        └──────────┘
```

### Algoritmi za balansiranje opterećenja

| Algoritam | Kako funkcioniše | Najbolje za |
|-----------|-------------|----------|
| **Round Robin** | Šalje zahteve serverima po rotaciji (1→2→3→1→2→3) | Servere jednakog kapaciteta |
| **Least Connections** | Šalje serveru sa najmanje aktivnih konekcija | Različita trajanja zahteva |
| **Weighted Round Robin** | Moćniji serveri dobijaju više zahteva | Servere mešanog kapaciteta |
| **IP Hash** | Isti klijentski IP uvek ide na isti server | Jednostavan session affinity |
| **Random** | Bira nasumičan server | Jednostavna podešavanja |

```nginx
# Nginx konfiguracija load balancera

# Round Robin (podrazumevano)
upstream backend {
    server 192.168.1.10:80;
    server 192.168.1.11:80;
    server 192.168.1.12:80;
}

# Weighted — server 1 dobija 3x više saobraćaja
upstream backend {
    server 192.168.1.10:80 weight=3;
    server 192.168.1.11:80 weight=1;
    server 192.168.1.12:80 weight=1;
}

# Least connections
upstream backend {
    least_conn;
    server 192.168.1.10:80;
    server 192.168.1.11:80;
    server 192.168.1.12:80;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}
```

### Problem sesija

Podrazumevano, PHP čuva sesije kao **fajlove na lokalnom serveru** (`/tmp/sess_abc123`). Kada imaš više servera iza load balancera, ovo se kvari:

```text
Zahtev 1: Korisnik se prijavljuje → Load Balancer → Server 1
           Server 1 kreira fajl sesije: /tmp/sess_abc123

Zahtev 2: Korisnik učitava dashboard → Load Balancer → Server 2
           Server 2 traži /tmp/sess_abc123 → NIJE PRONAĐEN
           Korisnik izgleda odjavljeno!
```

Ovo se dešava jer Server 2 nema fajl sesije koji je Server 1 kreirao. Postoje tri glavna rešenja.

### Rešenje 1: Sticky sesije (Session Affinity)

Load balancer pamti na koji server je korisnik poslat i uvek ga šalje na isti server.

```nginx
# Nginx sticky sesije koristeći IP hash
upstream backend {
    ip_hash;
    server 192.168.1.10:80;
    server 192.168.1.11:80;
    server 192.168.1.12:80;
}

# Ili koristeći cookie
upstream backend {
    server 192.168.1.10:80;
    server 192.168.1.11:80;

    sticky cookie srv_id expires=1h;
}
```

**Kako funkcioniše:**

```text
Zahtev 1: Korisnik → LB → Server 1 (LB postavlja cookie: srv_id=server1)
Zahtev 2: Korisnik → LB vidi cookie srv_id=server1 → Server 1 ✓
Zahtev 3: Korisnik → LB vidi cookie srv_id=server1 → Server 1 ✓
```

**Prednosti:**

- Jednostavno konfigurisati
- Nema promena u kodu aplikacije

**Nedostaci:**

- Ako Server 1 padne, svi njegovi korisnici gube sesije
- Neravnomerno opterećenje — neki serveri mogu dobiti više "sticky" korisnika
- Teško skalirati gore/dole

### Rešenje 2: Centralizovano skladište sesija (Redis) — Preporučeno

Čuvaj sesije na centralnom mestu dostupnom svim serverima — tipično **Redis** ili **Memcached**. Ovo je standardno rešenje u produkciji.

```text
┌──────────┐     ┌──────────┐     ┌──────────┐
│ Server 1 │     │ Server 2 │     │ Server 3 │
└─────┬────┘     └─────┬────┘     └─────┬────┘
      │                │                │
      └────────────────┼────────────────┘
                       │
                 ┌─────┴─────┐
                 │   Redis   │
                 │ (sesije)  │
                 └───────────┘
```

**Svaki server može čitati svaku sesiju** jer su sve sesije sačuvane u Redis-u.

```php
// php.ini konfiguracija — promeni session handler sa fajlova na Redis
session.save_handler = redis
session.save_path = "tcp://redis-server:6379"

// To je to! Nema potrebe za promenama PHP koda.
// session_start() sada čita/piše u Redis umesto lokalnih fajlova.
```

**Ili konfiguriši u Symfony-ju:**

```yaml
# config/packages/framework.yaml
framework:
    session:
        handler_id: '%env(REDIS_URL)%'
        cookie_secure: auto
        cookie_samesite: lax

# .env
REDIS_URL=redis://redis-server:6379
```

**Ili konfiguriši ručno u PHP-u:**

```php
// Prilagođeni Redis session handler
$redis = new Redis();
$redis->connect('redis-server', 6379);

$handler = new RedisSessionHandler($redis);
session_set_save_handler($handler, true);
session_start();

// Sada su sesije sačuvane u Redis-u:
// Ključ: PHPREDIS_SESSION:abc123
// Vrednost: serijalizovani podaci sesije
// TTL: session.gc_maxlifetime (podrazumevano 1440 sekundi)
```

**Prednosti:**

- Sesije preživljavaju padove servera
- Svaki server može obraditi svaki zahtev — pravo balansiranje opterećenja
- Lako skalirati gore/dole servere
- Redis je brz — čitanje sesija traje < 1ms

**Nedostaci:**

- Redis postaje jedinstvena tačka otkaza (ublaži sa Redis Sentinel ili Cluster)
- Malo mrežno kašnjenje za čitanje sesija (zanemarljivo u praksi)

### Rešenje 3: Skladište sesija u bazi podataka

Čuvaj sesije u MySQL ili PostgreSQL. Funkcioniše ali sporije od Redis-a.

```php
// Symfony — sesije u bazi podataka
// config/packages/framework.yaml
framework:
    session:
        handler_id: Symfony\Component\HttpFoundation\Session\Storage\Handler\PdoSessionHandler

// services.yaml
Symfony\Component\HttpFoundation\Session\Storage\Handler\PdoSessionHandler:
    arguments:
        - '%env(DATABASE_URL)%'
```

```sql
-- Tabela sesija
CREATE TABLE sessions (
    sess_id VARCHAR(128) NOT NULL PRIMARY KEY,
    sess_data BLOB NOT NULL,
    sess_lifetime INT NOT NULL,
    sess_time INT UNSIGNED NOT NULL,
    INDEX sess_lifetime_idx (sess_lifetime)
) ENGINE=InnoDB;
```

**Prednosti:** Koristi postojeću infrastrukturu baze podataka
**Nedostaci:** Sporije od Redis-a, dodaje opterećenje bazi, tabela sesija može narasti

### Rešenje 4: Bezstatusna autentifikacija (JWT)

Izbegni server-side sesije u potpunosti. Koristi JWT tokene koji sadrže sve potrebne korisničke podatke.

```php
// Nije potrebna sesija — korisnički podaci su u JWT tokenu
#[Route('/api/orders')]
class OrderController extends AbstractController
{
    #[Route('', methods: ['GET'])]
    public function list(): JsonResponse
    {
        // Korisnički podaci dolaze iz JWT tokena u Authorization header-u
        // Nije potrebno čitati sesiju — svaki server može obraditi ovo
        $user = $this->getUser();
        $orders = $this->orderRepository->findByUser($user);

        return $this->json($orders);
    }
}
```

**Prednosti:** Istinski bezstatusno — nema uopšte skladišta sesija
**Nedostaci:** Teško poništiti tokene, veličina tokena raste sa podacima

### Health check-ovi

Load balanceri moraju znati da li je server zdrav. Ako server padne, load balancer treba da prestane da mu šalje saobraćaj.

```nginx
upstream backend {
    server 192.168.1.10:80 max_fails=3 fail_timeout=30s;
    server 192.168.1.11:80 max_fails=3 fail_timeout=30s;
    server 192.168.1.12:80 max_fails=3 fail_timeout=30s;
}
```

```php
// Health check endpoint
#[Route('/health')]
class HealthController extends AbstractController
{
    #[Route('', methods: ['GET'])]
    public function check(): JsonResponse
    {
        // Proveri kritične zavisnosti
        try {
            $this->em->getConnection()->executeQuery('SELECT 1');
            $this->redis->ping();
        } catch (\Exception $e) {
            return $this->json(['status' => 'unhealthy'], 503);
        }

        return $this->json(['status' => 'healthy'], 200);
    }
}
```

### Realni scenario

Imaš e-commerce aplikaciju koja radi na 3 servera iza Nginx-a. Korisnici se žale da se nasumično odjavljuju:

```text
Problem: Sesije sačuvane u lokalnim fajlovima → korisnici gube sesiju kada LB šalje
         zahtev na drugi server.

Rešenje:
1. Instaliraj Redis na namenski server
2. Konfiguriši PHP da koristi Redis za sesije
3. Koristi round-robin balansiranje (nije potreban sticky sessions)
4. Dodaj Redis Sentinel za visoku dostupnost
```

```ini
; php.ini na SVA 3 servera
session.save_handler = redis
session.save_path = "tcp://redis-sentinel:26379?auth=secret"
```

```nginx
# nginx.conf — jednostavan round robin, sticky sessions nisu potrebne
upstream app {
    server app1:9000;
    server app2:9000;
    server app3:9000;
}
```

Rezultat:

- Korisnici nikada ne gube sesije — svaki server može obraditi svaki zahtev
- Ako Server 2 padne, saobraćaj ide na Server 1 i Server 3 — sesije i dalje rade
- Možeš dodati Server 4 i Server 5 bez ikakvih problema sa sesijama

### Zaključak

Load balancer raspoređuje saobraćaj po više servera radi poboljšanja pouzdanosti i performansi. Glavni izazov je rukovanje korisničkim sesijama — sesije sačuvane kao lokalni fajlovi se kvare kada zahtevi idu na različite servere. Preporučeno rešenje je **centralizovano skladište sesija u Redis-u**, što dozvoljava svakom serveru da obradi svaki zahtev. Sticky sesije su jednostavnija, ali manje pouzdana alternativa. Za aplikacije zasnovane samo na API-ju, JWT tokeni mogu u potpunosti eliminisati server-side sesije.

> Vidi takođe: [Sharding](sharding.sr.md), [Kako suziti probleme na PHP strani](how_to_narrow_problems_on_php_side_of_an_application.sr.md), [Optimizovanje sporog GET endpoint-a](optimizing_slow_get_endpoint.sr.md)
