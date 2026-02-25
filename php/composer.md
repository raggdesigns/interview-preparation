Composer is the standard dependency manager for PHP. It manages libraries (packages) that your project needs, installs them, and generates an autoloader so you can use them without manual `require` statements.

### Purpose and Possibilities

Composer does several things:

1. **Dependency management** — download and install packages your project needs
2. **Version management** — make sure compatible versions of packages are installed
3. **Autoloading** — generate an autoloader for all installed packages and your own code
4. **Scripts** — run custom commands before or after install/update
5. **Package repository** — Packagist.org is the main repository where packages are published

#### composer.json

This file describes your project and its dependencies:

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

- `require` — packages needed for production
- `require-dev` — packages needed only for development (tests, code analyzers)
- `autoload` — tells Composer how to autoload your own code

#### composer.lock

This file is created automatically after you run `composer install` or `composer update`. It records the **exact** versions of all installed packages. You should commit this file to Git so that all developers on the team use the same versions.

### composer install vs composer update

These two commands do very different things:

#### `composer install`

- Reads `composer.lock` (if it exists) and installs the exact versions listed there
- If `composer.lock` does not exist, it reads `composer.json`, resolves versions, installs them, and creates `composer.lock`
- **Safe for production** — you always get the same versions

```bash
# Typical usage
composer install

# Production (skip dev dependencies)
composer install --no-dev
```

#### `composer update`

- Ignores `composer.lock`
- Reads `composer.json`, finds the latest versions that match the constraints, installs them, and updates `composer.lock`
- **Not safe for production** — you may get new, untested versions

```bash
# Update all packages
composer update

# Update only one package
composer update symfony/http-foundation
```

#### Quick Summary

| Action | `composer install` | `composer update` |
|--------|-------------------|-------------------|
| Reads | `composer.lock` | `composer.json` |
| Creates/updates lock file | Only if missing | Always |
| Gets latest versions | No | Yes |
| Use in production | Yes | No |
| Use in development | Yes | When you want updates |

### Main Steps of `composer install` Command

Here is what happens step by step when you run `composer install`:

1. **Read `composer.lock`** — Composer reads the lock file to find the exact versions of every package. If the lock file does not exist, it reads `composer.json` and resolves versions first.

2. **Check already installed packages** — Composer looks at the `vendor/` directory to see what is already installed. It compares installed packages with the lock file.

3. **Download missing packages** — For packages that are not yet installed, Composer downloads them from the configured repository (usually Packagist) or from the cache.

4. **Install packages into `vendor/`** — Downloaded packages are extracted into the `vendor/` directory, each in its own folder (e.g., `vendor/symfony/http-foundation/`).

5. **Generate autoloader** — Composer creates `vendor/autoload.php` and the files in `vendor/composer/`. This autoloader maps namespaces and class names to file paths.

6. **Run post-install scripts** — If `composer.json` defines any scripts for the `post-install-cmd` event, they run now. Symfony, for example, clears cache and installs assets in this step.

```
composer install
├── 1. Read composer.lock
├── 2. Check vendor/ for existing packages
├── 3. Download missing packages (or use cache)
├── 4. Install into vendor/
├── 5. Generate autoload files
└── 6. Run post-install scripts
```

### Real Scenario

A new developer joins your team and clones the project:

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

Everyone on the team runs `composer install` and gets **exactly the same versions**. This avoids "it works on my machine" problems.

When the lead developer decides to update Symfony to the latest patch version:

```bash
# Only the lead developer runs this
composer update symfony/*

# Output:
# Updating symfony/http-foundation (v6.3.1 => v6.3.8)
# Generating autoload files
```

Then they commit the updated `composer.lock`:

```bash
git add composer.lock
git commit -m "Update Symfony packages"
git push
```

Other developers pull the change and run `composer install` to get the new versions. This way, version updates are controlled and intentional.

### Conclusion

Composer manages PHP dependencies, handles version resolution, and generates autoloaders. Use `composer install` to install exact versions from `composer.lock` (safe for production). Use `composer update` to get the latest compatible versions and update the lock file (only in development). The lock file should always be committed to Git.
