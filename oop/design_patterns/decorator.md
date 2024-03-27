The Decorator pattern is a structural design pattern that allows behavior to be added to individual objects, either statically or dynamically, without affecting the behavior of other objects from the same class. This pattern is particularly useful for adhering to the open/closed principle, one of the SOLID principles, which states that software entities (classes, modules, functions, etc.) should be open for extension, but closed for modification.

### Key Concepts of the Decorator Pattern:

- **Component Interface**: This defines the interface for objects that can have responsibilities added to them dynamically.
- **Concrete Component**: Defines an object to which additional responsibilities can be attached.
- **Decorator**: Maintains a reference to a Component object and defines an interface that conforms to Component's interface.
- **Concrete Decorators**: Concrete implementations of the Decorator that add responsibilities to the component.

### Benefits:

- **Flexibility**: Decorators provide a flexible alternative to subclassing for extending functionality.
- **Reusability**: You can design new Decorators to implement new behavior at runtime, promoting reusability.
- **Modularity**: Individual pieces of functionality are encapsulated in their own class, following single responsibility and open/closed principles.

### Example in PHP:

Imagine a simple text processing application where you want to dynamically add formatting to text.

```php
interface TextComponent {
    public function render();
}

class PlainText implements TextComponent {
    protected $text;

    public function __construct($text) {
        $this->text = $text;
    }

    public function render() {
        return $this->text;
    }
}

// Decorator
abstract class TextDecorator implements TextComponent {
    protected $component;

    public function __construct(TextComponent $component) {
        $this->component = $component;
    }
}

// Concrete Decorators
class BoldTextDecorator extends TextDecorator {
    public function render() {
        return '<b>' . $this->component->render() . '</b>';
    }
}

class ItalicTextDecorator extends TextDecorator {
    public function render() {
        return '<i>' . $this->component->render() . '</i>';
    }
}
```

### Usage:

```php
$plainText = new PlainText("Hello, World!");
$boldText = new BoldTextDecorator($plainText);
$italicAndBoldText = new ItalicTextDecorator($boldText);

echo $plainText->render(); // Outputs: Hello, World!
echo $boldText->render(); // Outputs: <b>Hello, World!</b>
echo $italicAndBoldText->render(); // Outputs: <i><b>Hello, World!</b></i>
```

In this example, the Decorator pattern allows us to dynamically add "bold" and "italic" formatting to the plain text without changing the `PlainText` class. Each decorator wraps the original component, adding new behavior. This setup exemplifies how decorators can be stacked to combine functionality in flexible ways.
