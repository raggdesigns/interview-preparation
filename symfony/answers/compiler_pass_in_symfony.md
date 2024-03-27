# Understanding CompilerPass in Symfony

In Symfony, the service container plays a crucial role in managing services and dependencies. A CompilerPass is a way to
interact with and modify the service container during its compilation process. This feature provides the flexibility to
dynamically alter service definitions, parameters, and more.

## Purpose of a CompilerPass

The main purpose of a CompilerPass is to allow developers to modify the service container after all services have been
loaded and before the container is compiled. This is particularly useful for:

- Adding method calls to service definitions based on certain criteria.
- Modifying service arguments or tags dynamically.
- Setting up complex service dependencies that cannot be expressed in the service configuration files.

## How to Create a CompilerPass

To create a CompilerPass, you need to create a class that implements the `CompilerPassInterface` and define your
modifications in the `process` method.

### Example:

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

## Registering a CompilerPass

After creating your CompilerPass, you need to register it in your bundle's `build` method or, if you're not using
bundles, in your kernel.

### Example for Bundle:

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

### Example for Kernel (Symfony 4+ without Bundle):

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

## Typical Use Cases

- **Tagging and Collecting Services**: A common use case is to tag services in your application and then collect all
  these tagged services in a CompilerPass to inject them into another service.
- **Configuration-Based Service Modification**: Dynamically modifying services based on configuration values that are
  only available at runtime.
- **Advanced Service Decorations**: Using CompilerPasses to decorate services based on dynamic conditions.

## Conclusion

CompilerPasses are a powerful feature in Symfony that provides developers with the capability to programmatically modify
the service container's behavior, offering a high degree of flexibility and control over service definitions and
dependencies.
