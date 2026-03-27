Composer je standardni menadžer zavisnosti za PHP. Upravlja bibliotekama (paketima) koje vaš projekat potrebuje, instalira ih i generiše autoloader kako biste ih mogli koristiti bez ručnih `require` naredbi.

### Svrha i mogućnosti

Composer radi nekoliko stvari:

1. **Upravljanje zavisnostima** — preuzimanje i instalacija paketa koje vaš projekat potrebuje
2. **Upravljanje verzijama** — osiguravanje da su instalirane kompatibilne verzije paketa
3. **Autoloading** — generisanje autoloader-a za sve instalirane pakete i vaš sopstveni kod
4. **Skripte** — pokretanje prilagođenih komandi pre ili posle instalacije/ažuriranja
5. **Repozitorijum paketa** — Packagist.org je glavni repozitorijum gde se paketi objavljuju

#### composer.json

Ova datoteka opisuje vaš projekat i njegove zavisnosti:

```json
{
    "name": "mycompany/my-project",
    "require": {
        "php": ">=8.1",
        "symfony/http-foundation": "^6.0",
        "doctrine/orm": "^2.14"
    },
    "require-dev": {
        "phpunit/phpunit": "^10.0"
    },
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}
```

- `require` — paketi potrebni za produkciju
- `require-dev` — paketi potrebni samo za razvoj (testovi, analizatori koda)
- `autoload` — govori Composer-u kako da autoloaduje vaš sopstveni kod

#### composer.lock

Ova datoteka se kreira automatski nakon pokretanja `composer install` ili `composer update`. Beleži **tačne** verzije svih instaliranih paketa. Trebali biste da commitujete ovu datoteku u Git kako bi svi programeri u timu koristili iste verzije.

### composer install vs composer update

Ove dve komande rade veoma različite stvari:

#### `composer install`

- Čita `composer.lock` (ako postoji) i instalira tačne verzije navedene tamo
- Ako `composer.lock` ne postoji, čita `composer.json`, rešava verzije, instalira ih i kreira `composer.lock`
- **Bezbedno za produkciju** — uvek dobijate iste verzije

```bash
# Typical usage
composer install

# Production (skip dev dependencies)
composer install --no-dev
```

#### `composer update`

- Ignoriše `composer.lock`
- Čita `composer.json`, pronalazi najnovije verzije koje odgovaraju ograničenjima, instalira ih i ažurira `composer.lock`
- **Nije bezbedno za produkciju** — možete dobiti nove, netestirane verzije

```bash
# Update all packages
composer update

# Update only one package
composer update symfony/http-foundation
```

#### Kratki pregled

| Akcija | `composer install` | `composer update` |
|--------|-------------------|-------------------|
| Čita | `composer.lock` | `composer.json` |
| Kreira/ažurira lock datoteku | Samo ako nedostaje | Uvek |
| Dobija najnovije verzije | Ne | Da |
| Koristite u produkciji | Da | Ne |
| Koristite u razvoju | Da | Kada želite ažuriranja |

### Glavni koraci komande `composer install`

Evo šta se dešava korak po korak kada pokrenete `composer install`:

1. **Čitanje `composer.lock`** — Composer čita lock datoteku kako bi pronašao tačne verzije svakog paketa. Ako lock datoteka ne postoji, čita `composer.json` i prvo rešava verzije.

2. **Provera već instaliranih paketa** — Composer gleda u `vendor/` direktorijum šta je već instalirano. Poredi instalirane pakete sa lock datotekom.

3. **Preuzimanje nedostajućih paketa** — Za pakete koji još nisu instalirani, Composer ih preuzima iz konfigurisanog repozitorijuma (obično Packagist) ili iz cache-a.

4. **Instalacija paketa u `vendor/`** — Preuzeti paketi se raspakuju u `vendor/` direktorijum, svaki u sopstvenom folderu (npr. `vendor/symfony/http-foundation/`).

5. **Generisanje autoloader-a** — Composer kreira `vendor/autoload.php` i datoteke u `vendor/composer/`. Ovaj autoloader mapira namespace-ove i nazive klasa na putanje datoteka.

6. **Pokretanje post-install skripti** — Ako `composer.json` definiše skripte za `post-install-cmd` događaj, one se sada pokreću. Symfony, na primer, čisti cache i instalira assete u ovom koraku.

```text
composer install
├── 1. Read composer.lock
├── 2. Check vendor/ for existing packages
├── 3. Download missing packages (or use cache)
├── 4. Install into vendor/
├── 5. Generate autoload files
└── 6. Run post-install scripts
```

### Realni scenario

Novi programer se pridružuje vašem timu i klonira projekat:

```bash
git clone https://github.com/company/project.git
cd project

# Step 1: Install dependencies (uses composer.lock for exact versions)
composer install

# Output:
# Installing symfony/http-foundation (v6.3.1)
# Installing doctrine/orm (2.14.3)
# Installing phpunit/phpunit (10.2.4)
# Generating autoload files
```

Svi u timu pokreću `composer install` i dobijaju **tačno iste verzije**. Ovo izbegava probleme tipa "radi kod mene".

Kada lead programer odluči da ažurira Symfony na najnoviju patch verziju:

```bash
# Only the lead developer runs this
composer update symfony/*

# Output:
# Updating symfony/http-foundation (v6.3.1 => v6.3.8)
# Generating autoload files
```

Zatim commituje ažurirani `composer.lock`:

```bash
git add composer.lock
git commit -m "Update Symfony packages"
git push
```

Drugi programeri povlače promenu i pokreću `composer install` kako bi dobili nove verzije. Na taj način, ažuriranja verzija su kontrolisana i namerna.

### Zaključak

Composer upravlja PHP zavisnostima, rešava verzije i generiše autoloader-e. Koristite `composer install` za instalaciju tačnih verzija iz `composer.lock` (bezbedno za produkciju). Koristite `composer update` za dobijanje najnovijih kompatibilnih verzija i ažuriranje lock datoteke (samo u razvoju). Lock datoteka uvek treba da bude commitovana u Git.
