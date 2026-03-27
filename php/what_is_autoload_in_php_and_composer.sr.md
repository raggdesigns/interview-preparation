Autoloading je način automatskog uključivanja PHP fajlova klasa kada su potrebni, bez ručnog pisanja `require` ili `include` za svaki fajl.

### Problem bez autoloada

Zamislite da imate projekat sa 50 klasa. Bez autoloadinga, morate pisati `require` na vrhu svakog fajla:

```php
require 'src/Database.php';
require 'src/User.php';
require 'src/Order.php';
require 'src/Product.php';
// ... 46 more lines
```

Ovo je teško za održavanje. Ako preimenujete ili premestite fajl, morate ažurirati svako mesto koje ga zahteva.

### PHP-ov ugrađeni autoload

PHP pruža `spl_autoload_register()` — funkciju koja govori PHP-u: "Kada vidiš nepoznatu klasu, pozovi ovu funkciju da pronađeš fajl."

```php
spl_autoload_register(function ($className) {
    $file = 'src/' . $className . '.php';
    if (file_exists($file)) {
        require $file;
    }
});

// Now PHP will automatically load src/User.php when you use User class
$user = new User(); // No need for "require 'src/User.php'"
```

### Kako radi Composer autoloading

Composer je dependency manager za PHP. Jedna od njegovih najkorisnijih mogućnosti je autoloading. Composer generiše autoloader koji prati standardna pravila (PSR-4 ili PSR-0) za mapiranje naziva klasa na putanje fajlova.

#### Korak 1: Konfigurišite `composer.json`

```json
{
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}
```

Ovo govori Composer-u: "Sve klase koje počinju sa `App\` su unutar foldera `src/`."

#### Korak 2: Generišite autoload fajlove

```bash
composer dump-autoload
```

#### Korak 3: Uključite Composer-ov autoloader

```php
require 'vendor/autoload.php';

// Now any class under App\ namespace is loaded automatically
$user = new App\User();        // loads src/User.php
$order = new App\Order();      // loads src/Order.php
$repo = new App\Repository\UserRepository(); // loads src/Repository/UserRepository.php
```

### PSR-4 standard

PSR-4 je najčešći standard za autoloading. Mapira delove namespace-a na strukturu foldera:

| Naziv klase | Putanja fajla |
|-------------|---------------|
| `App\User` | `src/User.php` |
| `App\Service\Mailer` | `src/Service/Mailer.php` |
| `App\Repository\ProductRepository` | `src/Repository/ProductRepository.php` |

### Ostali tipovi autoloadinga u Composer-u

```json
{
    "autoload": {
        "psr-4": { "App\\": "src/" },
        "classmap": ["legacy/"],
        "files": ["src/helpers.php"]
    }
}
```

- **classmap**: Skenira foldere i mapira svaku klasu koju pronađe. Korisno za legacy kod bez namespace-ova.
- **files**: Uvek učitava ove fajlove pri svakom zahtevu. Korisno za helper funkcije.

### Realni scenario

Radite na e-commerce projektu. Vaš projekat ima ovu strukturu:

```
src/
  Controller/
    CartController.php    → class App\Controller\CartController
    ProductController.php → class App\Controller\ProductController
  Service/
    PaymentService.php    → class App\Service\PaymentService
  Entity/
    Product.php           → class App\Entity\Product
```

Sa PSR-4 autoloadingom, nikada ne pišete ni jedan `require`. Samo koristite klasu i Composer automatski pronalazi fajl. Kada dodate novu klasu, odmah radi — nisu potrebne promene konfiguracije.

### Zaključak

Autoloading uklanja potrebu za ručnim uključivanjem fajlova. Composer-ov PSR-4 autoloading je standardni pristup u modernom PHP-u. Mapira namespace-ove na foldere, tako da PHP može automatski pronaći bilo koji fajl klase. Ovo čini projekte čistijim i lakšim za održavanje.
