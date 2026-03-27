Memcached i Redis su oba in-memory skladišta podataka koja se koriste za keširanje u web aplikacijama. Imaju različite arhitekture i funkcionalnosti, tako da izbor zavisi od tvojih potreba.

### Arhitektura

**Memcached** je jednostavan keš ključ-vrednost. Čuva podatke u memoriji i koristi višenitnu arhitekturu. Dizajniran je za jednu svrhu — keširanje — i to radi dobro.

**Redis** je server struktura podataka. Jednonitni je (glavni nit) ali može efikasno upravljati mnogim konekcijama koristeći I/O multipleksiranje. Redis podržava mnogo više od samog keširanje.

### Tipovi podataka

| Funkcionalnost | Memcached | Redis |
|---------|-----------|-------|
| Stringovi | Da | Da |
| Hash-ovi | Ne | Da |
| Liste | Ne | Da |
| Skupovi | Ne | Da |
| Sortirani skupovi | Ne | Da |
| Tokovi | Ne | Da |
| Bitmape | Ne | Da |

Memcached čuva samo stringove (ili serijalizovane podatke kao stringove). Redis podržava mnoge tipove podataka nativno, što omogućava složene operacije bez dodatnog koda na strani aplikacije.

### Persistencija

**Memcached**: Nema persistencije. Svi podaci se gube kada se server restartuje. Čisto je keš.

**Redis**: Podržava dve metode persistencije:

- **RDB (snimci)** — čuva skup podataka na disk u konfigurisanim intervalima
- **AOF (Append-Only File)** — beleži svaku operaciju pisanja, može ih reprodukovati pri restartovanju

```text
# Konfiguracija persistencije Redis-a (redis.conf)
save 900 1        # Sačuvaj ako se barem 1 ključ promenio u 900 sekundi
save 300 10       # Sačuvaj ako se barem 10 ključeva promenilo u 300 sekundi
appendonly yes     # Omogući AOF
```

### Replikacija i visoka dostupnost

**Memcached**: Nema ugrađenu replikaciju. Možeš pokrenuti više instanci, ali klijentska biblioteka distribuira ključeve koristeći konzistentno heširanje. Ako jedan čvor padne, njegovi podaci se gube.

**Redis**: Ugrađena master-replika replikacija. Redis Sentinel pruža automatski failover. Redis Cluster podržava šardovanje podataka po više čvorova.

```text
# Redis replikacija — konfiguracija replike
replicaof 192.168.1.100 6379
```

### Upravljanje memorijom

**Memcached**: Koristi slab alokator. Memorija je unapred alocirana u blokovima fiksnih veličina. Ovo može dovesti do rasipanja memorije ako veličine podataka mnogo variraju.

**Redis**: Koristi `jemalloc` za alokaciju memorije. Podržava politike memorije za evikaciju kada je memorija puna:

- `allkeys-lru` — ukloni najmanje nedavno korišćene ključeve
- `volatile-lru` — ukloni LRU ključeve koji imaju postavljeno isticanje
- `noeviction` — vraća greške kada je memorija puna

### Maksimalna veličina vrednosti

| | Memcached | Redis |
|-|-----------|-------|
| Maksimalna veličina ključa | 250 bajtova | 512 MB |
| Maksimalna veličina vrednosti | 1 MB (podrazumevano) | 512 MB |

### Performanse

Oba su izuzetno brza jer čuvaju podatke u memoriji. Za jednostavne get/set operacije, imaju slične performanse. Memcached može biti malo brži za jednostavne ključ-vrednost operacije sa više niti, ali Redis mnogo bolje obrađuje složene operacije (liste, skupovi, sortirani skupovi) jer ih radi na strani servera.

### Kada koristiti Memcached

- Trebaš samo jednostavno keširanje ključ-vrednost
- Hoćeš višenitni keš za visoko-propusne jednostavne operacije
- Ne trebaš persistenciju
- Hoćeš najjednostavnije moguće podešavanje

```php
// PHP Memcached upotreba
$mc = new Memcached();
$mc->addServer('localhost', 11211);

$mc->set('user:123', serialize($userData), 3600); // TTL 3600 sekundi
$data = unserialize($mc->get('user:123'));
```

### Kada koristiti Redis

- Trebaš strukture podataka (liste, skupove, sortirane skupove, hash-ove)
- Trebaš persistenciju (podaci moraju preživeti restartove)
- Trebaš pub/sub poruke
- Trebaš atomske operacije na složenim tipovima podataka
- Trebaš replikaciju i visoku dostupnost
- Hoćeš ga koristiti kao skladište sesija, posrednik poruka ili ograničivač stope

```php
// PHP Redis upotreba
$redis = new Redis();
$redis->connect('localhost', 6379);

// Jednostavan keš
$redis->setex('user:123', 3600, serialize($userData));

// Sortirani skup za liderboard
$redis->zAdd('leaderboard', 1500, 'player:1');
$redis->zAdd('leaderboard', 2300, 'player:2');
$top10 = $redis->zRevRange('leaderboard', 0, 9, true); // Prvih 10 sa rezultatima

// Ograničavanje stope sa Redis-om
$key = 'rate:' . $userId;
$redis->incr($key);
$redis->expire($key, 60); // Resetuj brojač svakih 60 sekundi
```

### Brza tabela poređenja

| Funkcionalnost | Memcached | Redis |
|---------|-----------|-------|
| Tipovi podataka | Samo stringovi | Stringovi, hash-ovi, liste, skupovi, sortirani skupovi, tokovi |
| Persistencija | Ne | Da (RDB, AOF) |
| Replikacija | Ne | Da (master-replika) |
| Klasterisanje | Na strani klijenta | Ugrađeno (Redis Cluster) |
| Višenitnost | Višenitno | Jednonitno (main) |
| Maksimalna veličina vrednosti | 1 MB | 512 MB |
| Pub/Sub | Ne | Da |
| Lua skriptovanje | Ne | Da |
| Transakcije | Ne | Da (MULTI/EXEC) |
| Slučaj upotrebe | Jednostavno keširanje | Keširanje + strukture podataka + poruke |

### Realni scenario

Gradiš e-commerce platformu. Trebaš:

1. **Keširanje stranica** — oba Memcached i Redis rade dobro
2. **Korpa za kupovinu** — Redis je bolji (tip podataka hash prirodno čuva stavke korpe)
3. **Rangiranje proizvoda** — Redis sortirani skupovi ovo savršeno obrađuju
4. **Skladište sesija** — Redis podržava persistenciju, pa sesije preživljavaju restartove
5. **Obaveštenja u realnom vremenu** — Redis pub/sub ovo obrađuje

Za jednostavan blog koji treba samo keširanje stranica, Memcached je dovoljan i jednostavniji. Za složenu aplikaciju sa višestrukim potrebama keširanje, Redis je bolji izbor jer pokriva više slučajeva upotrebe sa jednim alatom.

### Zaključak

Memcached je brz, jednostavan, višenitni keš ključ-vrednost. Redis je bogat funkcijama server struktura podataka sa persistencijom, replikacijom i mnogo tipova podataka. Za većinu modernih aplikacija, Redis je preferirani izbor jer obrađuje više slučajeva upotrebe. Memcached još uvek ima vrednost kada trebaš samo jednostavno keširanje sa višenitnim performansama.

> Vidi takođe: [Osnove Redis-a](redis_basics.sr.md) za dublji pogled na tipove podataka i komande Redis-a.
