### Tipovi podataka i SQL koncepti

---

#### Char vs Varchar

- **CHAR(n)**: Fiksna dužina. Prostor je rezervisan za tačno `n` karaktera. Ako je uneseni string kraći od `n`, dopunjava se razmacima zdesna. Brži za podatke fiksne veličine jer MySQL zna tačan offset svakog reda.
- **VARCHAR(n)**: Promenljiva dužina. Koristi samo onoliko prostora koliko zauzima stvarni string plus 1–2 bajta overhead-a za čuvanje dužine. Efikasniji za prostor za podatke promenljive veličine.

**Kada koristiti koji:**

- Koristi `CHAR` za vrednosti koje su uvek (ili skoro uvek) iste dužine: šifre zemalja, šifre valuta, MD5 hash-ovi.
- Koristi `VARCHAR` za vrednosti nepredvidive dužine: imena, email adrese, opisi.

**Primer:**

```sql
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    country_code CHAR(2)      NOT NULL,  -- Uvek 2 znaka: 'US', 'DE', 'CH'
    currency_code CHAR(3)     NOT NULL,  -- Uvek 3 znaka: 'USD', 'EUR', 'CHF'
    email VARCHAR(255)        NOT NULL,  -- Promenljivo: 'a@b.com' vs 'very.long.name@company.co.uk'
    full_name VARCHAR(100)    NOT NULL   -- Promenljivo: 'Li' vs 'Alexander Christopherson'
);

-- Poređenje skladišta:
-- CHAR(2) čuva 'US' → uvek 2 bajta (dopunjeno ako je kraće)
-- VARCHAR(255) čuva 'a@b.com' → 7 bajtova + 1 bajt prefiks dužine = 8 bajtova
-- VARCHAR(255) čuva email od 200 karaktera → 200 bajtova + 2 bajta prefiks dužine = 202 bajta

-- Ponašanje pratećih razmaka:
INSERT INTO users (country_code, currency_code, email, full_name)
VALUES ('U', 'CHF', 'test@test.com', 'John');
-- country_code se čuva kao 'U ' (dopunjeno razmakom)
-- Kada se preuzme sa SELECT, prateći razmaci se po default-u uklanjaju u CHAR-u
```

---

#### Šta je selektivnost

Selektivnost meri koliko su "jedinstvene" vrednosti kolone indeksa. Izračunava se kao:

$$\text{Selektivnost} = \frac{\text{Broj različitih vrednosti}}{\text{Ukupan broj redova}}$$

Selektivnost od **1.0** (ili blizu nje) znači da je skoro svaka vrednost jedinstvena — indeks je veoma efikasan. Selektivnost bliska **0** znači mnogo duplikata — indeks pruža malo koristi.

**Primer:**

```sql
CREATE TABLE orders (
    id INT PRIMARY KEY,
    customer_id INT,
    status ENUM('pending', 'paid', 'shipped', 'delivered', 'cancelled'),
    order_number VARCHAR(20) UNIQUE,
    created_at DATETIME
);

-- Pretpostavimo da tabela ima 1,000,000 redova

-- VISOKA selektivnost: order_number (jedinstveno)
-- Različite vrednosti: 1,000,000 / Ukupno: 1,000,000 = 1.0
-- Indeks na order_number je izuzetno efikasan
SELECT * FROM orders WHERE order_number = 'ORD-2024-123456'; -- Vraća 1 red

-- SREDNJA selektivnost: customer_id
-- Različite vrednosti: 50,000 / Ukupno: 1,000,000 = 0.05
-- Svaki kupac ima ~20 narudžbina prosečno
-- Indeks je umereno koristan
SELECT * FROM orders WHERE customer_id = 42; -- Vraća ~20 redova

-- NISKA selektivnost: status
-- Različite vrednosti: 5 / Ukupno: 1,000,000 = 0.000005
-- Svaki status ima ~200,000 redova
-- Indeks samo na status-u je skoro beskoristan — MySQL može preferirati puno skeniranje tabele
SELECT * FROM orders WHERE status = 'pending'; -- Vraća ~200,000 redova

-- Proveri selektivnost kolona:
SELECT
    COUNT(DISTINCT order_number) / COUNT(*) AS order_number_selectivity,
    COUNT(DISTINCT customer_id) / COUNT(*)  AS customer_id_selectivity,
    COUNT(DISTINCT status) / COUNT(*)       AS status_selectivity
FROM orders;
-- Rezultat: 1.0000, 0.0500, 0.0000
```

**Pravilo palca:** Indeksiraj kolone sa visokom selektivnošću kao prve u kompozitnim indeksima.

---

#### Komande ANALYZE vs EXPLAIN

- **ANALYZE TABLE**: Skenira tabelu, broji distribucije ključeva i čuva statistike. MySQL optimizator koristi ove statistike da odluči koji indeks da koristi, redosled spajanja, itd. Treba izvršiti nakon velikih promena podataka (masovna umetanja, brisanja).
- **EXPLAIN**: Prikazuje plan izvršavanja upita **bez pokretanja** upita. Govori ti koje indekse MySQL planira koristiti, tip spajanja, procenjene skenirane redove, itd.

**Primer — ANALYZE:**

```sql
-- Nakon masovnog uvoza 500k redova, statistike mogu biti zastarele
LOAD DATA INFILE '/data/orders.csv' INTO TABLE orders;

-- Ažuriraj statistike kako bi optimizator donosio dobre odluke
ANALYZE TABLE orders;

-- Izlaz:
-- +----------------+---------+----------+----------+
-- | Table          | Op      | Msg_type | Msg_text |
-- +----------------+---------+----------+----------+
-- | mydb.orders    | analyze | status   | OK       |
-- +----------------+---------+----------+----------+
```

**Primer — EXPLAIN:**

```sql
EXPLAIN SELECT o.id, o.status, c.name
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'pending'
  AND o.created_at > '2024-01-01';

-- Izlaz (pojednostavljen):
-- +----+-------+------+--------------------------+---------+------+--------+-----------------------+
-- | id | table | type | possible_keys            | key     | rows | filtered | Extra               |
-- +----+-------+------+--------------------------+---------+------+--------+-----------------------+
-- |  1 | o     | ref  | idx_status,idx_created   | idx_st  | 5000 | 30.00  | Using where          |
-- |  1 | c     | eq_ref| PRIMARY                 | PRIMARY |    1 | 100.00 | NULL                  |
-- +----+-------+------+--------------------------+---------+------+--------+-----------------------+

-- Ključne kolone za gledanje:
-- type:    eq_ref (najbolje za spajanja), ref (dobro), range (ok), ALL (puno skeniranje — loše)
-- key:     Koji indeks je MySQL stvarno izabrao
-- rows:    Procenjeni broj redova za ispitivanje (manje je bolje)
-- Extra:   "Using index" (pokrivajući indeks), "Using filesort" (skupo sortiranje)

-- EXPLAIN ANALYZE (MySQL 8.0+) zapravo pokreće upit i prikazuje stvarna vremena:
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;
-- -> Index lookup on orders using idx_customer_id (customer_id=42)
--    (cost=4.25 rows=20) (actual time=0.045..0.089 rows=18 loops=1)
```

---

#### WHERE vs HAVING

- **WHERE**: Filtrira pojedinačne redove **pre** agregacije (`GROUP BY`). Ne može se referencirati na agregatne funkcije.
- **HAVING**: Filtrira **grupe** (agregirane rezultate) **posle** `GROUP BY`. Može referencirati agregatne funkcije kao što su `COUNT()`, `SUM()`, `AVG()`.

**Primer:**

```sql
CREATE TABLE sales (
    id INT PRIMARY KEY,
    product_id INT,
    customer_id INT,
    amount DECIMAL(10,2),
    sale_date DATE
);

-- WHERE filtrira redove PRE grupiranja
-- "Uzmi u obzir samo prodaju iz 2024"
SELECT product_id, SUM(amount) AS total_sales, COUNT(*) AS num_sales
FROM sales
WHERE sale_date >= '2024-01-01'    -- Najpre filtrira pojedinačne redove
GROUP BY product_id;

-- HAVING filtrira grupe POSLE grupiranja
-- "Prikaži samo proizvode koji su prodali više od $10,000 ukupno"
SELECT product_id, SUM(amount) AS total_sales, COUNT(*) AS num_sales
FROM sales
GROUP BY product_id
HAVING SUM(amount) > 10000;        -- Filtrira agregirane grupe

-- Kombinovano: WHERE + HAVING
-- "Od prodaje iz 2024, prikaži samo proizvode sa više od 100 narudžbina"
SELECT product_id, SUM(amount) AS total_sales, COUNT(*) AS num_sales
FROM sales
WHERE sale_date >= '2024-01-01'    -- Korak 1: filtriraj redove (samo 2024)
GROUP BY product_id                -- Korak 2: grupiši preostale redove
HAVING COUNT(*) > 100;             -- Korak 3: filtriraj grupe (>100 narudžbina)

-- Redosled izvršavanja:
-- 1. FROM sales
-- 2. WHERE sale_date >= '2024-01-01'   → smanjuje redove
-- 3. GROUP BY product_id               → kreira grupe
-- 4. HAVING COUNT(*) > 100             → uklanja male grupe
-- 5. SELECT                            → proizvodi izlaz

-- Uobičajena greška: korišćenje HAVING gde WHERE treba biti korišćen
-- LOŠE (radi ali sporo — grupiše sve prvo, zatim filtrira):
SELECT product_id, SUM(amount) FROM sales GROUP BY product_id HAVING product_id = 5;
-- DOBRO (najpre filtrira, zatim grupiše — mnogo brže):
SELECT product_id, SUM(amount) FROM sales WHERE product_id = 5 GROUP BY product_id;
```

---

#### Događaji na kojima se može dodati trigger

Trigger-i se izvršavaju automatski kao odgovor na DML događaje na tabeli. Svaki trigger je vezan za **vreme** (`BEFORE` / `AFTER`) i **događaj** (`INSERT`, `UPDATE`, `DELETE`), što daje 6 mogućih kombinacija.

| Vreme | INSERT | UPDATE | DELETE |
|--------|--------|--------|--------|
| BEFORE | ✅ | ✅ | ✅ |
| AFTER  | ✅ | ✅ | ✅ |

- **BEFORE trigger-i**: Mogu modifikovati dolazne podatke ili odbiti operaciju. Korisni za validaciju/normalizaciju.
- **AFTER trigger-i**: Podaci su već commitovani. Korisni za reviziju, kaskadne promene ili sinhronizaciju.

**Primer:**

```sql
CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    price DECIMAL(10,2),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_audit (
    id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT,
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- BEFORE INSERT: Validacija i normalizacija podataka pre čuvanja
DELIMITER //
CREATE TRIGGER before_product_insert
BEFORE INSERT ON products
FOR EACH ROW
BEGIN
    -- Osiguraj da cena nikada nije negativna
    IF NEW.price < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Price cannot be negative';
    END IF;
    -- Normalizuj ime (ukloni razmake)
    SET NEW.name = TRIM(NEW.name);
END//
DELIMITER ;

-- AFTER UPDATE: Trag revizije za promene cena
DELIMITER //
CREATE TRIGGER after_product_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF OLD.price != NEW.price THEN
        INSERT INTO product_audit (product_id, old_price, new_price, changed_by)
        VALUES (OLD.id, OLD.price, NEW.price, CURRENT_USER());
    END IF;
END//
DELIMITER ;

-- BEFORE DELETE: Sprečavanje brisanja kritičnih zapisa
DELIMITER //
CREATE TRIGGER before_product_delete
BEFORE DELETE ON products
FOR EACH ROW
BEGIN
    IF OLD.name = 'Core Product' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete the core product';
    END IF;
END//
DELIMITER ;

-- Testiranje:
INSERT INTO products (name, price) VALUES ('  Widget  ', 29.99);
-- Trigger uklanja razmake iz naziva → čuva se kao 'Widget'

UPDATE products SET price = 34.99 WHERE id = 1;
-- Kreira se unos u audit log: old_price=29.99, new_price=34.99

INSERT INTO products (name, price) VALUES ('Test', -5.00);
-- ERROR: Price cannot be negative
```

---

#### Strani ključevi — Zašto se koriste

Strani ključevi sprovode **referencijalnu integritet**: garantuju da relacija između dve tabele ostaje konzistentna. Strani ključ u child tabeli mora referencirati postojeću vrednost u primarnom/jedinstvenom ključu parent tabele.

**Bez stranih ključeva**, kod tvoje aplikacije je jedini odgovoran za konzistentnost — a bagovi, uslovi trke ili ručno uređivanje DB-a mogu kreirati zapise siročiće.

**Primer:**

```sql
CREATE TABLE customers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    total DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Ograničenje stranog ključa
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE RESTRICT        -- Spreči brisanje kupca koji ima narudžbine
        ON UPDATE CASCADE         -- Ako se customer.id promeni, ažuriraj i narudžbine
);

CREATE TABLE order_items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_name VARCHAR(100),
    quantity INT,
    price DECIMAL(10,2),

    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE         -- Brisanje narudžbine automatski uklanja njene stavke
);

-- Šta FK sprečava:

-- 1. Umetanje narudžbine za nepostojećeg kupca
INSERT INTO orders (customer_id, total) VALUES (9999, 50.00);
-- ERROR 1452: Cannot add or update a child row:
-- a foreign key constraint fails (fk_orders_customer)

-- 2. Brisanje kupca koji ima narudžbine (ON DELETE RESTRICT)
DELETE FROM customers WHERE id = 1;
-- ERROR 1451: Cannot delete or update a parent row:
-- a foreign key constraint fails

-- 3. CASCADE u akciji: briši narudžbinu → stavke se automatski brišu
DELETE FROM orders WHERE id = 1;
-- Svi redovi u order_items sa order_id = 1 se automatski uklanjaju

-- Opcije ON DELETE:
-- RESTRICT   → Blokiraj brisanje (podrazumevano)
-- CASCADE    → Briši child redove takođe
-- SET NULL   → Postavi FK kolonu na NULL u child redovima
-- SET DEFAULT→ Postavi FK kolonu na default (nije podržano u InnoDB)
-- NO ACTION  → Isto kao RESTRICT u MySQL-u
```

---

#### Zaključavanja (Pesimistično, Optimistično, Advisory)

##### Pesimistično zaključavanje

Pretpostavlja da **će** doći do konflikata. Odmah zaključava red/resurs pri čitanju, sprečavajući bilo koju drugu transakciju da ga modifikuje dok zaključavanje nije oslobođeno. Koristi kada je sukobljavanje visoko.

```sql
-- Scenario: Dva korisnika pokušavaju da rezervišu poslednje sedište na letu

-- Transakcija A (Korisnik 1):
START TRANSACTION;

-- Zaključaj red — nijedna druga transakcija ne može čitati FOR UPDATE ili modifikovati ga
SELECT available_seats FROM flights WHERE id = 42 FOR UPDATE;
-- Rezultat: available_seats = 1

-- Ako neko drugi pokuša SELECT ... FOR UPDATE na istom redu, BLOKIRA se ovde

UPDATE flights SET available_seats = available_seats - 1 WHERE id = 42;
COMMIT;
-- Zaključavanje oslobođeno

-- Transakcija B (Korisnik 2) — pokrenuta u isto vreme:
START TRANSACTION;
SELECT available_seats FROM flights WHERE id = 42 FOR UPDATE;
-- ⏳ BLOKIRA dok Transakcija A ne commituje

-- Nakon A-ovog commit-a, B dobija zaključavanje i vidi:
-- available_seats = 0
-- B zna da nema sedišta i može to elegantno obraditi
ROLLBACK;

-- Ostali režimi zaključavanja:
-- SELECT ... FOR SHARE (aka LOCK IN SHARE MODE)
--   → Više transakcija može čitati, ali nijedna ne može pisati
-- SELECT ... FOR UPDATE
--   → Ekskluzivno zaključavanje: samo jedna transakcija može da ga drži
-- SELECT ... FOR UPDATE NOWAIT (MySQL 8.0+)
--   → Odmah ne uspeva ako je red već zaključan (bez čekanja)
-- SELECT ... FOR UPDATE SKIP LOCKED (MySQL 8.0+)
--   → Preskače zaključane redove (korisno za redove čekanja zadataka)
```

**Kako izabrati režim zaključavanja (brzi vodič za odlučivanje):**

1. Trebaš bezbedno čitati redove, ali ne modifikovati ih direktno? → `FOR SHARE`
2. Trebaš čitati a zatim ažurirati/brisati iste redove? → `FOR UPDATE`
3. Trebaš `FOR UPDATE`, ali ne možeš priuštiti čekanje? → `FOR UPDATE NOWAIT`
4. Gradiš red čekanja sa više radnika i svaki treba da uzme različite redove? → `FOR UPDATE SKIP LOCKED`

**1) `SELECT ... FOR SHARE`**

- **Šta garantuje:** Možeš čitati stabilne vrednosti redova dok blokiraš istovremene pisce.
- **Šta drugi mogu raditi:** Druge transakcije mogu i dalje čitati (uključujući `FOR SHARE`), ali ne mogu ažurirati/brisati zaključane redove dok ne commituješ.
- **Tipičan slučaj upotrebe:** Validacija pre kreiranja zavisnih zapisa (npr. provjera stanja kupca/računa).

```sql
-- Tx A: Validiraj kupca pre kreiranja narudžbine
START TRANSACTION;
SELECT id, status, credit_limit
FROM customers
WHERE id = 42
FOR SHARE;

-- bezbedno koristiti vrednosti za poslovne provjere ovde
INSERT INTO orders (customer_id, total) VALUES (42, 120.00);
COMMIT;

-- Tx B (u isto vreme):
UPDATE customers SET credit_limit = 5000 WHERE id = 42;
-- čeka dok Tx A ne commituje
```

**Zašto ovaj režim:** Štiti od istovremenih modifikacija dok još uvek dozvoljava visoku konkurentnost čitanja.

**2) `SELECT ... FOR UPDATE`**

- **Šta garantuje:** Ekskluzivno zaključavanje za tok čitanje-pa-pisanje na odabranim redovima.
- **Šta drugi mogu raditi:** Suprotstavljeni pokušaji zaključavanja i pisanja čekaju.
- **Tipičan slučaj upotrebe:** Smanjenje zaliha, rezervacija sedišta, transfer novca.

```sql
-- Bezbedan rezerviši jedno sedište
START TRANSACTION;
SELECT available_seats
FROM flights
WHERE id = 42
FOR UPDATE;

UPDATE flights
SET available_seats = available_seats - 1
WHERE id = 42 AND available_seats > 0;
COMMIT;
```

**Zašto ovaj režim:** Sprečava izgubljene izmene/preprodaju kada više transakcija cilja isti red.

**3) `SELECT ... FOR UPDATE NOWAIT` (MySQL 8.0+)**

- **Šta garantuje:** Ista semantika zaključavanja kao `FOR UPDATE`, ali sa trenutnim neuspehom ako zaključavanje ne može biti preuzeto.
- **Šta drugi mogu raditi:** Ako neko već drži zaključavanje, tvoj iskaz odmah greši.
- **Tipičan slučaj upotrebe:** API-ji/UI tokovi sa niskim kašnjenjem gde je brzi ponovni pokušaj bolji od blokiranja.

```sql
START TRANSACTION;
SELECT id, balance
FROM wallets
WHERE user_id = 7
FOR UPDATE NOWAIT;

-- Ako je red zaključan negde drugde: trenutna greška
-- Obrazac aplikacije: uhvati grešku -> vrati "resurs zauzet, pokušaj ponovo"
```

**Zašto ovaj režim:** Izbegava duga čekanja i gomilanje zaključavanja pri visokom sukobljavanju.

**4) `SELECT ... FOR UPDATE SKIP LOCKED` (MySQL 8.0+)**

- **Šta garantuje:** Zaključava samo trenutno slobodne redove i ignoriše redove koje su već zaključali drugi.
- **Šta drugi mogu raditi:** Više radnika može nastaviti istovremeno bez blokiranja jedni na druge na istim redovima.
- **Tipičan slučaj upotrebe:** Konzumenti reda čekanja zadataka.

```sql
-- Worker uzima naredne zahtevne zadatke bez čekanja na zaključane
START TRANSACTION;

SELECT id
FROM jobs
WHERE status = 'pending'
ORDER BY id
LIMIT 10
FOR UPDATE SKIP LOCKED;

-- Zatim označi odabrane zadatke kao u toku u istoj transakciji
-- (id-evi vraćeni gore)
UPDATE jobs
SET status = 'processing', worker_id = 3
WHERE id IN (101, 102, 103);

COMMIT;
```

**Zašto ovaj režim:** Maksimizuje propusnost za paralelne radnike eliminišući vreme čekanja zaključavanja na već preuzetim redovima.

**Praktične napomene:**

- Koristi ove klauzule sa `START TRANSACTION`; u autocommit režimu, zaključavanja se oslobađaju na kraju iskaza.
- Dodaj odgovarajuće indekse kako bi izbegli zaključavanje/skeniranje više redova nego što je namenjeno.
- Drži transakcije kratke kako bi smanjio sukobljavanje i rizik od deadlock-a.

##### Optimistično zaključavanje

Pretpostavlja da su konflikti **retki**. NE zaključava red. Umesto toga, detektuje konflikte pri pisanju proveravajući da li su se podaci promenili od kad su pročitani, tipično koristeći kolonu `version` ili timestamp `updated_at`.

```sql
-- Scenario: Dva administratora istovremeno uređuju cenu istog proizvoda

CREATE TABLE products (
    id INT PRIMARY KEY,
    name VARCHAR(100),
    price DECIMAL(10,2),
    version INT DEFAULT 1          -- Kolona verzije za optimistično zaključavanje
);

-- Admin A čita proizvod:
SELECT id, name, price, version FROM products WHERE id = 1;
-- Rezultat: id=1, name='Widget', price=29.99, version=3

-- Admin B takođe čita isti proizvod u isto vreme:
SELECT id, name, price, version FROM products WHERE id = 1;
-- Rezultat: id=1, name='Widget', price=29.99, version=3

-- Admin A ažurira (uključuje proveru verzije u WHERE klauzuli):
UPDATE products
SET price = 34.99, version = version + 1
WHERE id = 1 AND version = 3;
-- Pogođeni redovi: 1 ✅ — uspeh, verzija je sada 4

-- Admin B pokušava ažurirati (još uvek ima version=3 iz svog čitanja):
UPDATE products
SET price = 39.99, version = version + 1
WHERE id = 1 AND version = 3;
-- Pogođeni redovi: 0 ❌ — verzija je sada 4, ne 3!
-- Aplikacija detektuje 0 pogođenih redova → govori Adminu B:
-- "Ovaj proizvod je izmenjen od strane nekoga drugog. Molimo osvežite i pokušajte ponovo."

-- U kodu aplikacije (PHP/pseudo-kod):
-- $affectedRows = $db->execute($updateQuery);
-- if ($affectedRows === 0) {
--     throw new OptimisticLockException('Concurrent modification detected');
-- }
```

##### Advisory zaključavanja

Advisory zaključavanja su **kooperativna** — baza podataka ih NE sprovodi automatski pri pristupu podacima. Oni su signali na nivou aplikacije koje procesi dobrovoljno proveravaju. Korisni za koordinaciju rada između instanci aplikacije.

```sql
-- Scenario: Osiguraj da samo jedan cron zadatak obrađuje red čekanja email-ova odjednom

-- Proces A (Cron zadatak 1):
SELECT GET_LOCK('email_queue_processor', 10);
-- Vraća 1 → Zaključavanje preuzeto (čekalo do 10 sekundi ako je potrebno)
-- Sada bezbedno obradi red čekanja email-ova...

-- Proces B (Cron zadatak 2) pokreće se u isto vreme:
SELECT GET_LOCK('email_queue_processor', 10);
-- Vraća 0 → Nije mogao preuzeti zaključavanje u roku od 10 sekundi (A ga drži)
-- Proces B preskače ovaj run ili pokušava ponovo kasnije

-- Proces A završava:
SELECT RELEASE_LOCK('email_queue_processor');
-- Vraća 1 → Zaključavanje oslobođeno

-- Provjeri da li je zaključavanje zauzeto (bez preuzimanja):
SELECT IS_FREE_LOCK('email_queue_processor');
-- Vraća 1 ako je slobodno, 0 ako je zauzeto

-- Ključne razlike od zaključavanja na nivou reda:
-- 1. Advisory zaključavanja NISU vezana za nijednu tabelu ili red
-- 2. Traju dok se eksplicitno ne oslobode ili sesija ne završi
-- 3. Identifikovana su po string imenu, ne redu
-- 4. DB ih nikada ne proverava automatski — tvoja aplikacija mora proveriti

-- Slučajevi upotrebe u realnom svetu:
-- • Sprečavanje duplog izvršavanja cron zadataka
-- • Koordinisanje migracija sheme po više serverima aplikacije
-- • Implementacija distribuiranih mutexa bez eksternih alata (Redis, itd.)
-- • Osiguranje da samo jedan proces obnavlja keš odjednom
```

##### Rezime poređenja

| Aspekt | Pesimistično | Optimistično | Advisory |
|---|---|---|---|
| **Zaključava podatke?** | Da, odmah | Ne (proverava pri pisanju) | Ne (dobrovoljno) |
| **Najbolje kada** | Visoko sukobljavanje | Malo sukobljavanje | Koordinacija između procesa |
| **Performanse** | Niže (blokiranje) | Više (bez blokiranja) | Zavisi od upotrebe |
| **Rukovanje konfliktima** | Prevencija | Detekcija | Definisano aplikacijom |
| **MySQL sintaksa** | `FOR UPDATE` / `FOR SHARE` | `WHERE version = N` | `GET_LOCK()` / `RELEASE_LOCK()` |
