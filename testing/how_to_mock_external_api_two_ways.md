Mocking external API calls is essential in unit testing to ensure tests are fast, reliable, and not dependent on
external services. There are several approaches to achieve this, but two common methods are using mock objects within
your testing framework and utilizing HTTP mocking libraries.

### 1. Using Mock Objects

This approach involves creating a mock object that simulates the behavior of the class responsible for making the
external API calls. You can configure the mock to return predefined responses.

**Example in PHP with PHPUnit**:

Assume you have a `WeatherService` class that fetches weather data from an external API. You can mock this service in
your tests.

```php
class WeatherService {
    public function getWeather($location) {
        // Makes an external API call
    }
}

class WeatherServiceTest extends PHPUnit\Framework\TestCase {
    public function testGetWeatherReturnsExpectedData() {
        $weatherServiceMock = $this->createMock(WeatherService::class);
        $weatherServiceMock->method('getWeather')->willReturn('Sunny');
        
        $this->assertEquals('Sunny', $weatherServiceMock->getWeather('Anywhere'));
    }
}
```

This test ensures that your application can handle the 'Sunny' response correctly without actually calling the external
API.

### 2. HTTP Mocking Libraries

HTTP mocking libraries allow you to intercept HTTP requests and return predefined responses. This is useful for more
complex scenarios where you need to simulate different responses from the external API.

**Example in PHP with Guzzle and its Mock Handler**:

If your application uses Guzzle for HTTP requests, you can use Guzzle's built-in mocking capabilities.

```php
use GuzzleHttp\Client;
use GuzzleHttp\Handler\MockHandler;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Psr7\Response;

class WeatherClientTest extends PHPUnit\Framework\TestCase {
    public function testGetWeather() {
        $mock = new MockHandler([
            new Response(200, [], '{"weather": "Sunny"}'),
            // You can add more responses to simulate different scenarios
        ]);

        $handlerStack = HandlerStack::create($mock);
        $client = new Client(['handler' => $handlerStack]);

        $response = $client->request('GET', 'http://example.com/weather');
        $data = json_decode($response->getBody()->getContents(), true);

        $this->assertEquals('Sunny', $data['weather']);
    }
}
```

This approach is powerful because it tests the HTTP request layer directly, providing a more integrated testing
experience without depending on the external service.

### Conclusion

Mocking external APIs is a critical aspect of unit testing applications that rely on third-party services. Whether you
choose to use mock objects for simplicity or HTTP mocking libraries for more comprehensive testing, both methods allow
you to create predictable, isolated tests that improve your application's reliability and maintainability.
