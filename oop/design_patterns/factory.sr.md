Factory obrazac je kreacioni dizajnerski obrazac koji pruža interfejs za kreiranje objekata u nadklasi, ali dozvoljava podklasama da menjaju tip objekata koji će biti kreirani. U suštini, uključuje korišćenje fabričke metode za rešavanje problema kreiranja objekata bez potrebe za specificiranjem tačne klase objekta koji će biti kreiran. Ovo je posebno korisno u situacijama gde sistem treba biti nezavisan od načina na koji se njegovi objekti kreiraju, sastavljaju ili predstavljaju.

### Ključni koncepti Factory obrasca

- **Fabrička metoda (Factory Method)**: Metoda koja vraća objekte bazne klase, ali je prekoračena od strane izvedenih klasa za vraćanje objekata različitih tipova.
- **Proizvod (Product)**: Objekti koji se kreiraju fabričkom metodom. Proizvod je obično baziran na zajedničkom interfejsu ili baznoj klasi.
- **Klijent (Client)**: Deo aplikacije koji poziva fabričku metodu za kreiranje objekta. Klijent ne treba znati konkretnu klasu objekta koji se kreira.

### Prednosti

- **Fleksibilnost**: Klijenti su odvojeni od specifičnih klasa potrebnih za kreiranje instance željenog objekta. Dodavanje novih proizvoda ne zahteva promenu klijentskog koda, pridržavajući se principa otvoreno/zatvoreno.
- **Ponovna upotrebljivost**: Fabrička metoda se može primeniti za kreiranje instanci za različite kontekste sa različitim zahtevima.
- **Izolacija složenosti kreiranja klasa**: Enkapsulira logiku instanciranja čineći sistem lakšim za razumevanje i održavanje.

### Primer u PHP-u

Pretpostavite da razvijate aplikaciju za upravljanje dokumentima. Imate različite tipove dokumenata (npr. `WordDocument`, `PdfDocument`), ali želite da vaša aplikacija bude otvorena za buduća proširenja sa više tipova dokumenata bez menjanja klijentskog koda.

```php
interface Document {
    public function open();
    public function save();
}

class WordDocument implements Document {
    public function open() {
        echo "Opening Word document.\\n";
    }

    public function save() {
        echo "Saving Word document.\\n";
    }
}

class PdfDocument implements Document {
    public function open() {
        echo "Opening PDF document.\\n";
    }

    public function save() {
        echo "Saving PDF document.\\n";
    }
}

class DocumentFactory {
    public static function createDocument($type) {
        switch ($type) {
            case 'word':
                return new WordDocument();
            case 'pdf':
                return new PdfDocument();
            default:
                throw new Exception("Document type $type is not supported.");
        }
    }
}

// Client code
$docType = 'word'; // This could come from a configuration or user input
$document = DocumentFactory::createDocument($docType);
$document->open();
$document->save();
```

U ovom primeru, `DocumentFactory` je fabrika koja kreira `Document` objekte. Metoda `createDocument` je fabrička metoda koja odlučuje koju konkretnu klasu instancirati na osnovu ulaznog parametra. Ovaj dizajn dozvoljava dodavanje više tipova dokumenata (kao što je `ExcelDocument`) u budućnosti bez menjanja klijentskog koda koji koristi `DocumentFactory`.

Factory obrazac je moćan alat za implementaciju polimorfnog kreiranja bez vezivanja klijentskog koda za specifične podklase, negujući dizajn koji je lakši za proširivanje i održavanje.
