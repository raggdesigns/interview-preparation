# Razumevanje CompilerPass-a u Symfony-ju

U Symfony-ju, kontejner servisa igra ključnu ulogu u upravljanju servisima i zavisnostima. CompilerPass je način interakcije sa i modifikacije kontejnera servisa tokom procesa kompajliranja. Ova funkcionalnost pruža fleksibilnost za dinamičku izmenu definicija servisa, parametara i još toga.

## Svrha CompilerPass-a

Glavna svrha CompilerPass-a je da omogući programerima modifikaciju kontejnera servisa nakon što su svi servisi učitani i pre kompajliranja kontejnera. Ovo je posebno korisno za:

- Dodavanje poziva metoda definicijama servisa na osnovu određenih kriterijuma.
- Dinamičku modifikaciju argumenata ili tagova servisa.
- Podešavanje složenih zavisnosti servisa koje se ne mogu izraziti u konfiguracionim fajlovima servisa.

## Kako kreirati CompilerPass

Da biste kreirali CompilerPass, potrebno je da kreirate klasu koja implementira `CompilerPassInterface` i definišete svoje modifikacije u metodi `process`.

### Primer

```php
namespace App\DependencyInjection\Compiler;

use Symfony\Component\DependencyInjection\Compiler\CompilerPassInterface;
use Symfony\Component\DependencyInjection\ContainerBuilder;

class MyCustomCompilerPass implements CompilerPassInterface
{
    public function process(ContainerBuilder $container)
    {
        // Example: dynamically modify a service definition
        if ($container->has('app.some_service')) {
            $definition = $container->getDefinition('app.some_service');
            $definition->addMethodCall('setSomeParameter', ['value']);
        }
    }
}
```

## Registrovanje CompilerPass-a

Nakon kreiranja CompilerPass-a, potrebno je da ga registrujete u `build` metodi vašeg bundla ili, ako ne koristite bundlove, u vašem kernelu.

### Primer za Bundle

```php
namespace App;

use App\DependencyInjection\Compiler\MyCustomCompilerPass;
use Symfony\Component\HttpKernel\Bundle\Bundle;
use Symfony\Component\DependencyInjection\ContainerBuilder;

class AppBundle extends Bundle
{
    public function build(ContainerBuilder $container)
    {
        parent::build($container);

        $container->addCompilerPass(new MyCustomCompilerPass());
    }
}
```

### Primer za Kernel (Symfony 4+ bez Bundle-a)

```php
namespace App;

use App\DependencyInjection\Compiler\MyCustomCompilerPass;
use Symfony\Component\HttpKernel\Kernel;
use Symfony\Component\DependencyInjection\ContainerBuilder;

class AppKernel extends Kernel
{
    protected function build(ContainerBuilder $container)
    {
        $container->addCompilerPass(new MyCustomCompilerPass());
    }
}
```

## Tipični slučajevi upotrebe

- **Tagovanje i sakupljanje servisa**: Čest slučaj upotrebe je tagovanje servisa u vašoj aplikaciji, a zatim sakupljanje svih tih tagiranih servisa u CompilerPass-u radi njihovog injektovanja u drugi servis.
- **Modifikacija servisa na osnovu konfiguracije**: Dinamička modifikacija servisa na osnovu vrednosti konfiguracije dostupnih tek u vreme izvođenja.
- **Napredne dekoracije servisa**: Korišćenje CompilerPass-a za dekoraciju servisa na osnovu dinamičkih uslova.

## Alternativa: Implementacija CompilerPassInterface u Kernelu

Umesto kreiranja zasebne klase CompilerPass, kernel može direktno implementirati `CompilerPassInterface`. Ovo je korisno za jednostavne slučajeve, posebno kada se radi sa tagiranim servisima:

```php
namespace App;

use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Component\DependencyInjection\Compiler\CompilerPassInterface;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;

class Kernel extends BaseKernel implements CompilerPassInterface
{
    use MicroKernelTrait;

    public function process(ContainerBuilder $container): void
    {
        // manipulate the service container:
        $container->getDefinition('app.some_private_service')->setPublic(true);

        // processing tagged services:
        foreach ($container->findTaggedServiceIds('some_tag') as $id => $tags) {
            // ...
        }
    }
}
```

## Šta radi kompajliranje kontejnera

Kompajliranje kontejnera servisa omogućava:

- Sprečavanje kružnih referenci u zavisnostima servisa
- Prethodno rešavanje parametara
- Uklanjanje nekorišćenih zavisnosti

Metoda `compile()` koristi Compiler Passes za kompajliranje. Neki Compiler Passes su unapred definisani za pravilno kompajliranje kontejnera, dok prilagođeni omogućavaju manipulaciju drugim definicijama servisa.

[Zvanična dokumentacija za compiler passes](https://symfony.com/doc/current/service_container/compiler_passes.html)

## Zaključak

CompilerPass-ovi su moćna funkcionalnost u Symfony-ju koja pruža programerima mogućnost programskog modifikovanja ponašanja kontejnera servisa, nudeći visok stepen fleksibilnosti i kontrole nad definicijama servisa i zavisnostima.
