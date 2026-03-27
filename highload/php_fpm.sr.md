PHP-FPM (FastCGI Process Manager) je standardni način pokretanja PHP-a u produkciji. Upravlja skupom PHP worker procesa koji obrađuju web zahteve. Nginx (ili drugi web server) komunicira sa PHP-FPM-om koristeći FastCGI protokol.

### Kako funkcioniše PHP-FPM

PHP-FPM ima **master proces** i **worker procese**.

#### Master proces

Master proces se pokreće kada se PHP-FPM pokrene. Njegov posao je:

- Čitanje konfiguracionih fajlova
- Kreiranje i upravljanje worker procesima
- Slušanje na socketu (TCP ili Unix) za dolazne zahteve
- Restartovanje worker-a koji se sruše ili prekorače memorijska/vremenska ograničenja

#### Worker procesi

Svaki worker proces obrađuje jedan zahtev odjednom. Worker:

1. Prima FastCGI zahtev od mastera
2. Inicijalizuje PHP okruženje (učitava ekstenzije, autoload klase)
3. Izvršava PHP skriptu
4. Šalje odgovor nazad kroz master
5. Resetuje stanje i čeka sledeći zahtev

```text
Master proces (PID 1)
├── Worker 1 (PID 100) ← obrađuje zahtev
├── Worker 2 (PID 101) ← obrađuje zahtev
├── Worker 3 (PID 102) ← neaktivan, čeka
├── Worker 4 (PID 103) ← neaktivan, čeka
└── Worker 5 (PID 104) ← obrađuje zahtev
```

**Važno:** Svaki worker obrađuje samo JEDAN zahtev odjednom. Ako su svi worker-i zauzeti, novi zahtevi čekaju u redu (backlog). Ako je red pun, zahtevi se odbijaju.

### Režimi upravljača procesa

PHP-FPM ima tri režima za upravljanje brojem worker procesa:

#### 1. `pm = static`

Uvek radi fiksni broj worker-a.

```ini
pm = static
pm.max_children = 20
```

- Uvek tačno 20 worker-a
- Troši više memorije kada je saobraćaj nizak
- Najbolje kada je saobraćaj predvidiv i konstantan

#### 2. `pm = dynamic`

Broj worker-a se prilagođava prema potražnji.

```ini
pm = dynamic
pm.max_children = 50        ; maksimalni broj worker-a
pm.start_servers = 10       ; worker-i kreirani pri pokretanju
pm.min_spare_servers = 5    ; minimum neaktivnih worker-a
pm.max_spare_servers = 15   ; maksimum neaktivnih worker-a
```

- Počinje sa 10 worker-a
- Ako manje od 5 neaktivnih worker-a → kreiraj više (do 50)
- Ako više od 15 neaktivnih worker-a → ubij višak
- Dobra ravnoteža između potrošnje memorije i performansi

#### 3. `pm = ondemand`

Worker-i se kreiraju samo kada zahtev stigne. Nema worker-a kada je neaktivno.

```ini
pm = ondemand
pm.max_children = 50
pm.process_idle_timeout = 10s  ; ubij neaktivne worker-e posle 10 sekundi
```

- Nula worker-a kada nema zahteva
- Štedi memoriju na serverima sa malim saobraćajem
- Malo sporije za prvi zahtev (treba pokrenuti worker-a)

### Ključne opcije konfiguracije

```ini
[www]
; Socket — kako se Nginx povezuje sa PHP-FPM-om
listen = /run/php/php8.2-fpm.sock     ; Unix socket (brži, isti server)
; listen = 127.0.0.1:9000             ; TCP socket (može biti na drugom serveru)

; Upravljanje procesima
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 15

; Sigurnosna ograničenja
pm.max_requests = 500                  ; Restartuj worker-a posle 500 zahteva (sprečava curenje memorije)
request_terminate_timeout = 30s        ; Ubij worker-a ako zahtev traje duže od 30s
php_admin_value[memory_limit] = 256M   ; Maksimalna memorija po worker-u
```

### Kako PHP-FPM radi sa Nginx-om

Nginx je web server koji obrađuje HTTP konekcije. **Ne** izvršava PHP kod. Umesto toga, prosleđuje PHP zahteve PHP-FPM-u koristeći FastCGI protokol.

#### Kompletan tok zahteva

```text
Klijent (Browser)
    │
    │ HTTP zahtev: GET /api/users
    ▼
┌─────────┐
│  Nginx  │  1. Prima HTTP zahtev
│         │  2. Proverava pravila lokacije
│         │  3. Statički fajlovi → servira direktno
│         │  4. PHP fajlovi → prosleđuje PHP-FPM-u
└────┬────┘
     │ FastCGI protokol (putem Unix socketa ili TCP)
     ▼
┌──────────┐
│ PHP-FPM  │  5. Master dodeljuje zahtev slobodnom worker-u
│ (Master) │
└────┬─────┘
     │
     ▼
┌──────────┐
│  Worker  │  6. Izvršava PHP skriptu (index.php → router → controller)
│          │  7. Šalje odgovor nazad masteru
└────┬─────┘
     │ FastCGI odgovor
     ▼
┌─────────┐
│  Nginx  │  8. Prima PHP-FPM odgovor
│         │  9. Šalje HTTP odgovor klijentu
└────┬────┘
     │ HTTP odgovor
     ▼
Klijent (Browser)
```

#### Nginx konfiguracija

```nginx
server {
    listen 80;
    server_name example.com;
    root /var/www/project/public;

    # Serviraj statičke fajlove direktno (CSS, JS, slike)
    location ~* \.(css|js|png|jpg|gif|ico)$ {
        expires 30d;
        access_log off;
    }

    # Prosleđuj PHP zahteve PHP-FPM-u
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Symfony/Laravel front controller obrazac
    location / {
        try_files $uri /index.php$is_args$args;
    }
}
```

Šta se dešava:

1. Zahtev za `/css/style.css` → Nginx servira fajl direktno (PHP nije uključen)
2. Zahtev za `/api/users` → `try_files` ne uspeva → prepisuje u `/index.php` → prosleđuje PHP-FPM-u
3. PHP-FPM worker izvršava `index.php` → Symfony/Laravel router → controller → odgovor

#### Zašto Nginx + PHP-FPM?

| Osobina | Objašnjenje |
|---------|-------------|
| Razdvajanje | Nginx obrađuje HTTP, PHP-FPM obrađuje PHP — svaki radi ono u čemu je najbolji |
| Statički fajlovi | Nginx servira statičke fajlove veoma brzo bez uključivanja PHP-a |
| Konkurentnost | Nginx obrađuje hiljade konekcija sa malo niti (event-driven) |
| Baferovanje | Nginx baferuje PHP-FPM odgovor, pa brže oslobađa worker-a |
| Balansiranje opterećenja | Nginx može distribuirati zahteve na više PHP-FPM pool-ova ili servera |

### Izračunavanje `pm.max_children`

Najvažnije podešavanje. Prenisko → zahtevi čekaju u redu. Previsoko → serveru ponestaje memorije.

Formula:

```text
max_children = Dostupna memorija / Prosečna memorija po worker-u

Primer:
  Server: 4 GB RAM
  OS + Nginx + MySQL: ~1.5 GB
  Dostupno za PHP: 2.5 GB
  Prosečan worker: ~50 MB

  max_children = 2500 MB / 50 MB = 50 worker-a
```

Proveri stvarnu memoriju po worker-u:

```bash
# Prikaži memoriju PHP-FPM worker-a
ps -eo pid,rss,command | grep php-fpm | awk '{print $1, $2/1024 " MB", $3}'
```

### Monitoring PHP-FPM-a

Omogući stranicu statusa:

```ini
; php-fpm pool konfiguracija
pm.status_path = /fpm-status
```

```nginx
location /fpm-status {
    fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
    allow 127.0.0.1;
    deny all;
}
```

```bash
curl http://localhost/fpm-status
# Prikazuje: aktivne procese, neaktivne procese, ukupne zahteve, dužinu reda slušanja
```

Ključne metrike za praćenje:

- **listen queue** — zahtevi koji čekaju slobodnog worker-a (treba biti 0)
- **active processes** — worker-i koji trenutno obrađuju zahteve
- **max children reached** — ako je > 0, treba ti više worker-a

### Realni scenario

Postavljaš Symfony aplikaciju na server sa 8 GB RAM-a:

```ini
; /etc/php/8.2/fpm/pool.d/www.conf

[www]
user = www-data
group = www-data

listen = /run/php/php8.2-fpm.sock
listen.owner = www-data

pm = dynamic
pm.max_children = 80          ; 8 GB - 3 GB (OS/DB) = 5 GB / ~60 MB po worker-u ≈ 80
pm.start_servers = 20
pm.min_spare_servers = 10
pm.max_spare_servers = 30
pm.max_requests = 1000        ; Restartuj worker-a posle 1000 zahteva

request_terminate_timeout = 60s
php_admin_value[memory_limit] = 128M
```

```nginx
# /etc/nginx/sites-available/myapp.conf
server {
    listen 443 ssl http2;
    server_name myapp.com;
    root /var/www/myapp/public;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        internal;
    }
}
```

Pod opterećenjem, proveraš `/fpm-status` i vidiš `listen queue: 15`. To znači da 15 zahteva čeka na worker-a. Moraš ili povećati `pm.max_children` (ako imaš slobodne memorije) ili optimizovati PHP kod da obradi zahteve brže.

### Zaključak

PHP-FPM upravlja skupom worker procesa. Svaki worker obrađuje jedan zahtev odjednom. Master proces kreira, prati i ubija worker-e na osnovu `pm` režima (static, dynamic, ondemand). Nginx obrađuje HTTP konekcije i prosleđuje PHP zahteve PHP-FPM-u putem FastCGI (Unix ili TCP socket). Nginx servira statičke fajlove direktno, dok PHP-FPM obrađuje samo PHP skripte. Ključni parametar za podešavanje je `pm.max_children`, izračunat na osnovu dostupne memorije podeljene sa prosečnom memorijom po worker-u.
