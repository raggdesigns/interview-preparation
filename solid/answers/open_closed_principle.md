# Open/Closed Principle (OCP)

The Open/Closed Principle (OCP) is one of the SOLID principles in software development, emphasizing that software entities (classes, modules, functions, etc.) should be open for extension but closed for modification. This means you should be able to add new functionality to an entity without changing its existing code.

### Violating the Open/Closed Principle

Consider a class responsible for generating various reports. Initially, it can generate HTML reports, but later requirements change to include generating JSON reports as well. A common violation of the OCP would involve modifying the existing class to add the new functionality.

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

In this example, every time a new report format is required, the `ReportGenerator` class must be modified, violating the OCP.

### Refactored Code Applying the Open/Closed Principle

To adhere to the OCP, we can refactor the code by defining a common interface for report generation and extending it for different report formats. This approach allows adding new formats without modifying the existing codebase.

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

### Explanation

In the refactored code:

- The `ReportGeneratorInterface` defines a standard for generating reports.
- `HtmlReportGenerator` and `JsonReportGenerator` implement this interface, each handling a specific report format.
- The `printReport` function demonstrates how the system can utilize different report generators interchangeably without knowing their concrete implementation, adhering to the OCP.

By applying the OCP, the system becomes more flexible and easier to extend, as new report types can be added with new classes without altering the existing code.
