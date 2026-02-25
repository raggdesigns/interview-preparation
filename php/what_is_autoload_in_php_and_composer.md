Autoloading is a way to automatically include PHP class files when they are needed, without writing `require` or `include` manually for every file.

### The Problem Without Autoload

Imagine you have a project with 50 classes. Without autoloading, you must write `require` at the top of every file:

```php
require 'src/Database.php';
require 'src/User.php';
require 'src/Order.php';
require 'src/Product.php';
// ... 46 more lines
```

This is hard to maintain. If you rename or move a file, you must update every place that requires it.

### PHP's Built-in Autoload

PHP provides `spl_autoload_register()` — a function that tells PHP: "When you see an unknown class, call this function to find the file."

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

### How Composer Autoloading Works

Composer is a dependency manager for PHP. One of its most useful features is autoloading. Composer generates an autoloader that follows standard rules (PSR-4 or PSR-0) to map class names to file paths.

#### Step 1: Configure `composer.json`

```json
{
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}
```

This tells Composer: "All classes starting with `App\` are inside the `src/` folder."

#### Step 2: Generate Autoload Files

```bash
composer dump-autoload
```

#### Step 3: Include Composer's Autoloader

```php
require 'vendor/autoload.php';

// Now any class under App\ namespace is loaded automatically
$user = new App\User();        // loads src/User.php
$order = new App\Order();      // loads src/Order.php
$repo = new App\Repository\UserRepository(); // loads src/Repository/UserRepository.php
```

### PSR-4 Standard

PSR-4 is the most common autoloading standard. It maps namespace parts to folder structure:

| Class name | File path |
|------------|-----------|
| `App\User` | `src/User.php` |
| `App\Service\Mailer` | `src/Service/Mailer.php` |
| `App\Repository\ProductRepository` | `src/Repository/ProductRepository.php` |

### Other Autoload Types in Composer

```json
{
    "autoload": {
        "psr-4": { "App\\": "src/" },
        "classmap": ["legacy/"],
        "files": ["src/helpers.php"]
    }
}
```

- **classmap**: Scans folders and maps every class it finds. Useful for legacy code without namespaces.
- **files**: Always loads these files on every request. Useful for helper functions.

### Real Scenario

You work on an e-commerce project. Your project has this structure:

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

With PSR-4 autoloading, you never write a single `require`. You just use the class, and Composer finds the file automatically. When you add a new class, it works immediately — no configuration changes needed.

### Conclusion

Autoloading removes the need to manually include files. Composer's PSR-4 autoloading is the standard approach in modern PHP. It maps namespaces to folders, so PHP can find any class file automatically. This makes projects cleaner and easier to maintain.
