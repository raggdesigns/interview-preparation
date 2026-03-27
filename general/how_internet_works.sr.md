# Kako Funkcioniše Internet

Kada unesete URL u pretraživač i pritisnete Enter, složen lanac mrežnih protokola radi zajedno kako bi preuzeo i prikazao stranicu. Razumevanje ovog životnog ciklusa zahteva — od DNS rezolucije do renderovanja stranice — fundamentalna je tema za intervjue.

> **Scenario koji se koristi kroz ovaj dokument:** Korisnik upisuje `https://shop.com/products` u pretraživač.

## Preduslovi

- [Struktura HTTP Protokola](http_protocol_structure.sr.md) — format zahteva/odgovora
- [REST API Arhitektura](rest_api_architecture.sr.md) — kako su API-ji strukturirani

## Kompletan Životni Ciklus Zahteva

```text
Korisnik upisuje https://shop.com/products
  |
  v
1. DNS Rezolucija       -> "Koja IP adresa je shop.com?"
  |                        shop.com -> 93.184.216.34
  v
2. TCP Konekcija        -> Trosmerno rukovanje sa serverom
  |                        SYN -> SYN-ACK -> ACK
  v
3. TLS Rukovanje        -> Uspostavljanje enkriptovane konekcije (HTTPS)
  |                        Pregovaranje šifre, razmena ključeva
  v
4. HTTP Zahtev          -> Slanje stvarnog zahteva
  |                        GET /products HTTP/1.1
  v
5. Obrada na Serveru    -> Backend obrađuje zahtev
  |                        Ruta -> Kontroler -> Baza podataka -> Odgovor
  v
6. HTTP Odgovor         -> Server šalje podatke nazad
  |                        200 OK + HTML/JSON telo
  v
7. Renderovanje         -> Pretraživač parsira HTML, učitava CSS/JS, crta
  |
  v
Stranica prikazana
```

## Korak 1: DNS Rezolucija

DNS (Domain Name System) prevodi čitljiva domenska imena u IP adrese. Radi kao telefonski imenik za internet.

```text
Pretraživač: "Koja je IP adresa shop.com?"

1. Keš pretraživača   -> proverava se prvo (keširano iz prethodnih poseta)
2. OS keš             -> proverava se sledeće (DNS keš na nivou sistema)
3. Keš rutera         -> vaš kućni ruter može da kešira DNS odgovore
4. DNS resolver ISP-a -> rekurzivni resolver vašeg ISP-a

Ako nijedan nema odgovor, resolver upituje DNS hijerarhiju:

5. Root nameserver    -> "Ne znam shop.com, ali .com obrađuju ovi serveri"
6. TLD nameserver     -> "Ne znam shop.com, ali njegov nameserver je ns1.cloudflare.com"
7. Autoritativni NS   -> "shop.com je 93.184.216.34" (sa TTL: 3600s)

Odgovor se prostire nazad kroz lanac, svaki sloj ga kešira.
```

**Rekurzivni vs. iterativni upiti:**

```text
Rekurzivni (šta radi vaš pretraživač):
  Pretraživač -> ISP resolver: "Daj mi konačan odgovor za shop.com"
  ISP resolver obavlja sav posao i vraća 93.184.216.34

Iterativni (šta resolver radi interno):
  Resolver -> Root NS: "Gde je shop.com?"  -> "Pitaj .com TLD"
  Resolver -> TLD NS:  "Gde je shop.com?"  -> "Pitaj ns1.cloudflare.com"
  Resolver -> Auth NS: "Gde je shop.com?"  -> "93.184.216.34"
```

## Korak 2: TCP Trosmerno Rukovanje

TCP (Transmission Control Protocol) uspostavlja pouzdanu konekciju između klijenta i servera. Trosmerno rukovanje osigurava da su obe strane spremne.

```text
Klijent                         Server (93.184.216.34:443)
  |                                |
  |---- SYN (seq=100) ----------->|  "Želim da se povežem"
  |                                |
  |<--- SYN-ACK (seq=300, ack=101)|  "OK, i ja sam spreman"
  |                                |
  |---- ACK (ack=301) ----------->|  "Odlično, konekcija uspostavljena"
  |                                |
  |       Konekcija uspostavljena  |
```

**Zašto tri koraka?** Obe strane moraju potvrditi da mogu da šalju I primaju. SYN dokazuje da klijent može da šalje. SYN-ACK dokazuje da server može da šalje i prima. ACK dokazuje da klijent može da prima.

## Korak 3: TLS Rukovanje (HTTPS)

Za HTTPS, TLS rukovanje se izvodi na vrhu TCP konekcije radi uspostavljanja enkripcije.

```text
Klijent                             Server
  |                                    |
  |-- ClientHello ----------------->  |  Podržane šifre, TLS verzija
  |                                    |
  |<-- ServerHello + Sertifikat ----  |  Odabrana šifra + javni ključ servera
  |                                    |
  |   Klijent verifikuje sertifikat:   |
  |   - Da li ga je potpisao CA od poverenja? |
  |   - Da li je istekao?              |
  |   - Da li se domen poklapa?        |
  |                                    |
  |-- Razmena Ključeva ------------->  |  Klijent generiše pre-master tajnu,
  |                                    |  enkriptuje je javnim ključem servera
  |                                    |
  |<-- Završeno --------------------   |  Obe strane izvode ključeve sesije
  |                                    |
  |   Počinje enkriptovana komunikacija|
```

Nakon TLS-a, svi podaci su enkriptovani — čak i ako neko presretne pakete, ne može da pročita sadržaj.

## Korak 4: HTTP Zahtev

Pretraživač šalje HTTP zahtev preko enkriptovane konekcije:

```http
GET /products HTTP/1.1
Host: shop.com
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)
Accept: text/html,application/xhtml+xml
Accept-Language: en-US,en;q=0.9
Accept-Encoding: gzip, deflate, br
Connection: keep-alive
Cookie: session_id=abc123
```

Ključna zaglavlja:

- `Host` — koji veb sajt (važno za virtuelni hosting — jedan server, mnogo sajtova)
- `Accept` — koje tipove sadržaja pretraživač može da obradi
- `Cookie` — podaci sesije iz prethodnih poseta
- `Connection: keep-alive` — ponovo koristite ovu TCP konekciju za naknadne zahteve

## Korak 5: Obrada na Serveru

Server prima zahtev i rutira ga kroz aplikaciju:

```text
Nginx (web server / reverse proxy)
  |
  | Statički fajl? (.css, .js, .jpg)
  |   -> Da -> Servira direktno sa diska (brzo)
  |   -> Ne  -> Prosleđuje PHP-FPM-u
  |
  v
PHP-FPM (aplikacioni server)
  |
  | Ruta: GET /products -> ProductController::list()
  |
  v
ProductController
  |
  | $products = $repository->findAll();  -> MySQL upit
  | return $this->render('products.html', ['products' => $products]);
  |
  v
Template engine renderuje HTML
  |
  v
Odgovor se šalje nazad Nginx-u -> Klijentu
```

## Korak 6: HTTP Odgovor

```http
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
Content-Length: 4523
Content-Encoding: gzip
Cache-Control: public, max-age=300
Set-Cookie: session_id=abc123; HttpOnly; Secure; SameSite=Strict

<!DOCTYPE html>
<html>
<head><title>Products - Shop</title>
<link rel="stylesheet" href="/css/styles.css">
</head>
<body>
  <h1>Products</h1>
  <!-- lista proizvoda -->
  <script src="/js/app.js"></script>
</body>
</html>
```

## Korak 7: Renderovanje u Pretraživaču

Nakon primanja HTML-a, pretraživač obavlja više koraka:

```text
1. Parsiranje HTML-a       -> Izgradnja DOM stabla (Document Object Model)
2. Otkrivanje resursa     -> Pronalaženje <link>, <script>, <img> tagova
3. Preuzimanje resursa    -> Paralelni HTTP zahtevi za CSS, JS, slike
   (svaki prolazi kroz DNS -> TCP -> TLS -> HTTP ponovo, osim ako je keširan)
4. Parsiranje CSS-a       -> Izgradnja CSSOM (CSS Object Model)
5. Izvršavanje JavaScript-a -> Može da modifikuje DOM
6. Raspored               -> Izračunavanje pozicije i veličine elemenata
7. Bojenje                -> Crtanje piksela na ekran
8. Kompozicija            -> Kombinovanje slojeva (GPU-ubrzano)
```

**Ključna optimizacija:** Pretraživač preuzima resurse **paralelno** (do 6 konekcija po domenu u HTTP/1.1, muxovano u HTTP/2).

## Raščlamba Vremena

Tipično učitavanje stranice uključuje ova kumulativna kašnjenja:

```text
DNS pretraga:          ~20-120ms  (keširano: 0ms)
TCP rukovanje:         ~20-80ms   (1 povratni put)
TLS rukovanje:         ~40-160ms  (2 povratna puta)
HTTP zahtev/odgovor:   ~50-200ms  (zavisi od obrade servera + mreže)
--------------------------------------------------
Ukupno do prvog bajta: ~130-560ms

Učitavanje resursa:    ~200-1000ms (CSS, JS, slike paralelno)
Renderovanje:          ~50-200ms  (parsiranje, raspored, bojenje)
--------------------------------------------------
Ukupno vidljiva stranica: ~380-1760ms
```

## HTTP/1.1 vs HTTP/2

| Aspekt | HTTP/1.1 | HTTP/2 |
|--------|----------|--------|
| Konekcije | Više TCP konekcija (6 po domenu) | Jedna muxovana konekcija |
| Format zaglavlja | Tekstualni, ponavlja se po zahtevu | Binarni, komprimovan (HPACK) |
| Obrada zahteva | Sekvencijalna po konekciji | Paralelni tokovi na jednoj konekciji |
| Server push | Nije podržan | Server može da gura resurse pre nego što ih klijent traži |
| Head-of-line blokiranje | Da (jedan spor odgovor blokira ostale) | Ne (tokovi su nezavisni) |

## Slojevi Keširanja

Više slojeva keširanja smanjuje ponavljanje posla:

```text
Keš pretraživača       -> Čuva resurse lokalno (CSS, JS, slike)
                          Kontrolišu: Cache-Control, ETag, Expires zaglavlja

CDN (npr. Cloudflare)  -> Kešira odgovore na edge lokacijama širom sveta
                          Smanjuje latenciju serviranjem sa obližnjeg servera

Reverse proxy (Nginx)  -> Kešira odgovore od PHP-FPM-a
                          Izbegava pogađanje aplikacije za ponovljene zahteve

Keš aplikacije (Redis) -> Kešira rezultate upita u bazi podataka
                          Izbegava pogađanje MySQL-a za ponovljene upite

Keš upita baze podataka -> MySQL kešira rezultate upita interno
```

## Česta Pitanja na Intervjuima

### P: Šta se dešava kada unesete URL u pretraživač?

**O:** Šest glavnih koraka: (1) **DNS rezolucija** — pretraživač prevodi domen u IP adresu, proveravajući keš pretraživača, OS keš i ISP resolver. (2) **TCP rukovanje** — trosmerno rukovanje (SYN, SYN-ACK, ACK) uspostavlja pouzdanu konekciju. (3) **TLS rukovanje** — za HTTPS, klijent i server pregovaraju o enkripciji i razmenjuju ključeve. (4) **HTTP zahtev** — pretraživač šalje GET zahtev sa zaglavljima (Host, Accept, Cookie). (5) **Obrada na serveru** — web server rutira do aplikacije, koja upituje bazu podataka i generiše HTML. (6) **Renderovanje** — pretraživač parsira HTML, preuzima CSS/JS/slike, gradi DOM i crta stranicu.

### P: Koja je razlika između HTTP i HTTPS?

**O:** HTTPS dodaje **TLS enkriptovani sloj** između TCP-a i HTTP-a. Podaci su enkriptovani u prenosu, tako da čak i ako su paketi presretnuti (man-in-the-middle), ne mogu se čitati. HTTPS takođe pruža **autentikaciju** (server dokazuje svoj identitet putem sertifikata potpisanog od strane pouzdanog CA) i **integritet** (podaci ne mogu biti modifikovani u prenosu bez detekcije). Cena je 1-2 dodatna povratna puta za TLS rukovanje, što je zanemarljivo sa modernim hardverom.

### P: Kako funkcioniše DNS keširanje?

**O:** DNS odgovori uključuju vrednost **TTL** (Time to Live) koja određuje koliko dugo rezultat može biti keširan. Kada pretraživač razreši `shop.com` na `93.184.216.34` sa TTL=3600, svaki sloj u lancu (pretraživač, OS, ruter, ISP resolver) kešira ovo mapiranje na 1 sat. Naknadni zahtevi preskakuju celu DNS hijerarhiju. Niži TTL-ovi (300s) omogućavaju brže preusmeravanje (npr. prelaz na rezervni server), dok viši TTL-ovi (86400s) smanjuju DNS saobraćaj, ali odlažu propagaciju promena IP-a.

## Zaključak

Jedan URL zahtev pokreće DNS rezoluciju, TCP i TLS rukovanja, HTTP zahtev-odgovor, obradu na strani servera i renderovanje u pretraživaču. Svaki sloj — DNS, transport, bezbednost, aplikacija, keširanje — služi specifičnoj svrsi u činjenju veba pouzdanim, bezbednim i brzim. HTTP/2 i CDN keširanje su najimpresivnije moderne optimizacije, eliminišući overhead konekcije i smanjujući latenciju serviranjem sadržaja sa edge lokacija blizu korisnika.

## Vidi Takođe

- [Struktura HTTP Protokola](http_protocol_structure.sr.md) — detaljan format zahteva/odgovora
- [HTTP 4xx vs 5xx Greške](http_4xx_vs_5xx_errors.sr.md) — objašnjeni status kodovi
- [Šta je CORS](cors.sr.md) — ograničenja između porekla u pretraživačima
- [Šta je CSRF](csrf.sr.md) — kako kolačići rade između zahteva
