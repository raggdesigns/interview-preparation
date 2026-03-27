Decorator obrazac je strukturalni dizajnerski obrazac koji dozvoljava dodavanje ponašanja individualnim objektima, statički ili dinamički, bez uticaja na ponašanje ostalih objekata iste klase. Ovaj obrazac je posebno koristan za pridržavanje principa otvoreno/zatvoreno (open/closed), jednog od SOLID principa, koji kaže da softverske entitete (klase, module, funkcije, itd.) treba biti otvoreni za proširivanje, ali zatvoreni za modifikaciju.

### Ključni koncepti Decorator obrasca

- **Interfejs komponente (Component Interface)**: Definiše interfejs za objekte kojima se mogu dinamički dodavati odgovornosti.
- **Konkretna komponenta (Concrete Component)**: Definiše objekat na koji se mogu prikvačiti dodatne odgovornosti.
- **Decorator**: Održava referencu na objekat komponente i definiše interfejs koji se poklapa sa interfejsom komponente.
- **Konkretni dekoratori (Concrete Decorators)**: Konkretne implementacije Decorator-a koje dodaju odgovornosti komponenti.

### Prednosti

- **Fleksibilnost**: Dekoratori pružaju fleksibilnu alternativu podklasiranju za proširivanje funkcionalnosti.
- **Ponovna upotrebljivost**: Možete dizajnirati nove Decorator-e za implementaciju novog ponašanja u vreme izvršavanja, promovišući ponovnu upotrebljivost.
- **Modularnost**: Pojedinačni delovi funkcionalnosti su enkapsulisani u sopstvenu klasu, prateći principe jedne odgovornosti i otvoreno/zatvoreno.

### Primer u PHP-u

Zamislite jednostavnu aplikaciju za obradu teksta gde želite dinamički dodati formatiranje tekstu.

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

### Upotreba

```php
$plainText = new PlainText("Hello, World!");
$boldText = new BoldTextDecorator($plainText);
$italicAndBoldText = new ItalicTextDecorator($boldText);

echo $plainText->render(); // Outputs: Hello, World!
echo $boldText->render(); // Outputs: <b>Hello, World!</b>
echo $italicAndBoldText->render(); // Outputs: <i><b>Hello, World!</b></i>
```

U ovom primeru, Decorator obrazac nam omogućava da dinamički dodamo "bold" i "italic" formatiranje jednostavnom tekstu bez menjanja klase `PlainText`. Svaki dekorator omata originalnu komponentu, dodajući novo ponašanje. Ovaj setup ilustruje kako se dekoratori mogu slagati za kombinovanje funkcionalnosti na fleksibilne načine.
