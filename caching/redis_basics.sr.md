Redis je open-source, in-memory skladište struktura podataka, koje se koristi kao baza podataka, keš i posrednik poruka. Podržava strukture podataka kao što su stringovi, hash-ovi, liste, skupovi, sortirani skupovi sa upitima opsega, bitmape, hyperloglogs, geoprostorni indeksi sa upitima radijusa i tokovi. Redis ima ugrađenu replikaciju, Lua skriptovanje, LRU evikaciju, transakcije i različite nivoe persistencije na disku, i pruža visoku dostupnost putem Redis Sentinel i automatsko particionisanje sa Redis Cluster-om.

### Ključne funkcionalnosti

- **Performanse**: Redis radi sa skupom podataka u memoriji, osiguravajući visoke performanse i nisko kašnjenje.
- **Strukture podataka**: Podržava raznovrsne strukture podataka, čineći ga svestranim za različite potrebe aplikacije.
- **Persistencija**: Nudi opcije za trajnost, uključujući RDB snimke i AOF (Append Only File) persistenciju log-a.
- **Replikacija i visoka dostupnost**: Podržava master-slave replikaciju, olakšavajući visoku dostupnost i horizontalno skaliranje.
- **Atomske operacije**: Redis podržava atomske operacije na složenim tipovima podataka, poboljšavajući integritet podataka.
- **Pub/Sub**: Implementira Publish/Subscribe kapacitete za scenarije middleware-a orijentisanog na poruke.

### Osnovne komande

- `SET key value` - Postavlja string vrednost ključa.
- `GET key` - Dobija vrednost ključa.
- `DEL key` - Briše ključ.
- `LPUSH key value` - Dodaje vrednost na početak liste.
- `RPUSH key value` - Dodaje vrednost na kraj liste.
- `LPOP key` - Uklanja i dobija prvi element u listi.
- `RPOP key` - Uklanja i dobija poslednji element u listi.
- `SADD key member` - Dodaje člana u skup.
- `SMEMBERS key` - Dobija sve članove u skupu.
- `ZADD key score member` - Dodaje člana u sortirani skup, ili ažurira rezultat ako već postoji.

### Početak rada sa Redis-om u PHP-u

Da bi koristio Redis kao sloj keširanje ili skladište sesija u PHP-u, trebaš instaliranu i konfigurisanu `redis` ekstenziju sa tvojim PHP okruženjem.

```php
$redis = new Redis();
$redis->connect('127.0.0.1', 6379);
$redis->set('key', 'value');
echo $redis->get('key');
```

U ovom primeru, uspostavlja se konekcija sa Redis serverom, postavlja se ključ sa vrednošću, a zatim se vrednost preuzima i ispisuje.

### Zaključak

Redis-ova kombinacija visokih performansi, podrške za bogate tipove podataka i robusnih funkcionalnosti kao što su replikacija i persistencija čine ga odličnim izborom za implementaciju keširanje, upravljanja sesijama i kao NoSQL baze podataka opšte namene. Njegov jednostavan model i atomske operacije dozvoljavaju programerima da grade složene funkcionalnosti uz minimalni napor.
