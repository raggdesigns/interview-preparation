# Open/Closed Principle (OCP)

Open/Closed Principle (OCP) je jedan od SOLID principa u razvoju softvera koji naglašava da softverski entiteti (klase, moduli, funkcije, itd.) treba da budu otvoreni za proširenje, ali zatvoreni za modifikaciju. To znači da bi trebalo da možete da dodate novu funkcionalnost entitetu bez promene njegovog postojećeg koda.

## Način razmišljanja

- Trebalo bi da možete da promenite šta klasa radi bez promene njenog postojećeg koda.
- Zamislite buduće promene koje će vam verovatno biti potrebne, a zatim dizajnirajte klasu tako da dozvoli te promene bez potrebe za modifikacijom same klase.

### Kršenje Open/Closed Principle

Razmotrite klasu odgovornu za generisanje različitih izveštaja. U početku može da generiše HTML izveštaje, ali kasnije zahtevi se menjaju i uključuju generisanje JSON izveštaja. Uobičajeno kršenje OCP bi podrazumevalo modifikaciju postojeće klase radi dodavanja nove funkcionalnosti.

```php
class ReportGenerator {
    public function generateReport($content, $type) {
        if ($type === 'HTML') {
            return "<html><body>$content</body></html>";
        } elseif ($type === 'JSON') {
            return json_encode(['content' => $content]);
        }
    }
}

$reportGenerator = new ReportGenerator();
echo $reportGenerator->generateReport('Report Content', 'HTML');
```

U ovom primeru, svaki put kada je potreban novi format izveštaja, klasa `ReportGenerator` mora da se modifikuje, čime se krši OCP.

### Refactored kod koji primenjuje Open/Closed Principle

Da bi se poštovao OCP, možemo refactoring-ovati kod definisanjem zajedničkog interfejsa za generisanje izveštaja i proširivanjem za različite formate izveštaja. Ovaj pristup omogućava dodavanje novih formata bez modifikacije postojeće baze koda.

```php
interface ReportGeneratorInterface {
    public function generateReport($content);
}

class HtmlReportGenerator implements ReportGeneratorInterface {
    public function generateReport($content) {
        return "<html><body>$content</body></html>";
    }
}

class JsonReportGenerator implements ReportGeneratorInterface {
    public function generateReport($content) {
        return json_encode(['content' => $content]);
    }
}

function printReport(ReportGeneratorInterface $reportGenerator, $content) {
    echo $reportGenerator->generateReport($content);
}

printReport(new HtmlReportGenerator(), 'Report Content');
printReport(new JsonReportGenerator(), 'Report Content');
```

### Objašnjenje

U refactored kodu:

- `ReportGeneratorInterface` definiše standard za generisanje izveštaja.
- `HtmlReportGenerator` i `JsonReportGenerator` implementiraju ovaj interfejs, svaki obrađujući određeni format izveštaja.
- Funkcija `printReport` demonstrira kako sistem može da koristi različite generatore izveštaja naizmenično bez poznavanja njihove konkretne implementacije, pridržavajući se OCP.

Primenom OCP, sistem postaje fleksibilniji i lakši za proširenje, jer se novi tipovi izveštaja mogu dodati novim klasama bez izmene postojećeg koda.
