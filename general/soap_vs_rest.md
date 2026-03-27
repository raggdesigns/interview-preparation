SOAP and REST are two different approaches for building web services. SOAP is a **protocol** with strict rules and XML format. REST is an **architectural style** that uses standard HTTP methods and typically works with JSON.

### SOAP — Simple Object Access Protocol

SOAP is a protocol for exchanging structured data between services. Every SOAP message is wrapped in an XML envelope with a specific structure.

```xml
<!-- SOAP Request -->
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Header>
        <auth:Token xmlns:auth="http://example.com/auth">abc123</auth:Token>
    </soap:Header>
    <soap:Body>
        <GetUser xmlns="http://example.com/users">
            <UserId>42</UserId>
        </GetUser>
    </soap:Body>
</soap:Envelope>

<!-- SOAP Response -->
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
        <GetUserResponse xmlns="http://example.com/users">
            <User>
                <Id>42</Id>
                <Name>Dragan</Name>
                <Email>dragan@example.com</Email>
            </User>
        </GetUserResponse>
    </soap:Body>
</soap:Envelope>
```

### REST — The Same Request

```text
GET /api/users/42 HTTP/1.1
Host: example.com
Authorization: Bearer abc123
Accept: application/json
```

```json
{
    "id": 42,
    "name": "Dragan",
    "email": "dragan@example.com"
}
```

### Key Differences

| Feature | SOAP | REST |
|---------|------|------|
| Type | Protocol | Architectural style |
| Data format | XML only | JSON, XML, YAML, plain text |
| Transport | HTTP, SMTP, TCP, JMS | HTTP only |
| Contract | WSDL file (strict) | OpenAPI/Swagger (optional) |
| State | Can be stateful | Stateless |
| Error handling | SOAP Fault (XML) | HTTP status codes (404, 500...) |
| Security | WS-Security (built-in) | HTTPS + OAuth/JWT |
| Performance | Slower (XML parsing overhead) | Faster (JSON is lightweight) |
| Caching | Difficult | Easy (GET requests are cacheable) |
| Learning curve | High | Low |

### WSDL — Web Services Description Language

WSDL is an XML file that describes a SOAP service completely. It defines:

- What **operations** the service offers
- What **parameters** each operation expects
- What **data types** are used
- Where the service is **located** (endpoint URL)

```xml
<!-- Simplified WSDL example -->
<definitions name="UserService"
    xmlns="http://schemas.xmlsoap.org/wsdl/"
    targetNamespace="http://example.com/users">

    <!-- Data types -->
    <types>
        <schema>
            <element name="GetUserRequest">
                <complexType>
                    <sequence>
                        <element name="UserId" type="int"/>
                    </sequence>
                </complexType>
            </element>
            <element name="GetUserResponse">
                <complexType>
                    <sequence>
                        <element name="Name" type="string"/>
                        <element name="Email" type="string"/>
                    </sequence>
                </complexType>
            </element>
        </schema>
    </types>

    <!-- Operations -->
    <portType name="UserPortType">
        <operation name="GetUser">
            <input message="GetUserRequest"/>
            <output message="GetUserResponse"/>
        </operation>
    </portType>

    <!-- Endpoint -->
    <service name="UserService">
        <port name="UserPort" binding="UserBinding">
            <soap:address location="http://example.com/soap/users"/>
        </port>
    </service>
</definitions>
```

A client can read this WSDL file and **automatically generate** client code to call the service. This is a big advantage of SOAP — the contract is machine-readable.

### SOAP Client in PHP

PHP has built-in SOAP support through the `SoapClient` class:

```php
// Create client from WSDL — PHP auto-generates methods
$client = new SoapClient('http://example.com/users?wsdl');

// Call the service — feels like calling a local method
$response = $client->GetUser(['UserId' => 42]);
echo $response->Name;    // "Dragan"
echo $response->Email;   // "dragan@example.com"

// List all available operations
var_dump($client->__getFunctions());
// ["GetUserResponse GetUser(GetUserRequest)", "CreateUserResponse CreateUser(...)"]
```

### REST Client in PHP (for comparison)

```php
// Using Symfony HttpClient
$response = $this->httpClient->request('GET', 'http://example.com/api/users/42');
$user = $response->toArray();
echo $user['name'];    // "Dragan"
echo $user['email'];   // "dragan@example.com"
```

### When SOAP Is Still Used

SOAP is considered "old" by modern web standards, but it is still actively used in:

1. **Banking and financial services** — banks require WS-Security, digital signatures, and strict contracts
2. **Government systems** — legacy systems communicate via SOAP
3. **Enterprise integration** — SAP, Oracle, and Microsoft ecosystems use SOAP heavily
4. **Payment processors** — some payment gateways still expose SOAP APIs
5. **Telecom** — billing and provisioning systems

```php
// Real example: communicating with a bank SOAP service
$client = new SoapClient('https://bank.example.com/payments?wsdl', [
    'soap_version' => SOAP_1_2,
    'trace' => true,
    'cache_wsdl' => WSDL_CACHE_BOTH,
]);

try {
    $result = $client->ProcessPayment([
        'Amount' => 150.00,
        'Currency' => 'EUR',
        'AccountFrom' => 'RS35260005601001611379',
        'AccountTo' => 'RS35105008123123123456',
    ]);
} catch (SoapFault $e) {
    // SOAP errors come as SoapFault exceptions
    echo "Error: " . $e->getMessage();
    // Debug: see raw XML request/response
    echo $client->__getLastRequest();
    echo $client->__getLastResponse();
}
```

### SOAP Error Handling vs REST

```xml
<!-- SOAP Fault (error response) -->
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
        <soap:Fault>
            <faultcode>soap:Client</faultcode>
            <faultstring>User not found</faultstring>
            <detail>
                <errorCode>USER_404</errorCode>
                <message>No user exists with ID 42</message>
            </detail>
        </soap:Fault>
    </soap:Body>
</soap:Envelope>
```

```json
// REST error response — uses HTTP 404 status code
{
    "error": "User not found",
    "code": "USER_404",
    "message": "No user exists with ID 42"
}
```

SOAP always returns HTTP 200 — even for errors. The error information is inside the XML body. REST uses HTTP status codes (404, 500, etc.) to indicate errors.

### Real Scenario

You are building a PHP application that needs to integrate with two external services:

1. **Bank payment system** — only offers SOAP API
2. **Delivery tracking** — offers REST API

```php
// Service that integrates with both
class OrderFulfillmentService
{
    public function __construct(
        private SoapClient $bankClient,           // SOAP — bank requires it
        private HttpClientInterface $deliveryApi,  // REST — modern API
    ) {}

    public function processOrder(Order $order): void
    {
        // Step 1: Process payment via SOAP
        $paymentResult = $this->bankClient->ProcessPayment([
            'Amount' => $order->getTotal(),
            'Currency' => 'EUR',
            'Reference' => $order->getId(),
        ]);

        if ($paymentResult->Status !== 'SUCCESS') {
            throw new PaymentFailedException($paymentResult->ErrorMessage);
        }

        // Step 2: Create shipment via REST
        $response = $this->deliveryApi->request('POST', '/api/shipments', [
            'json' => [
                'orderId' => $order->getId(),
                'address' => $order->getShippingAddress(),
                'weight' => $order->getTotalWeight(),
            ],
        ]);

        $shipment = $response->toArray();
        $order->setTrackingNumber($shipment['trackingNumber']);
    }
}
```

### Conclusion

REST is the standard for modern web APIs — it is simpler, faster, uses JSON, and works naturally with HTTP. SOAP is a heavier protocol with strict contracts (WSDL), XML format, and built-in security features. SOAP is still used in banking, government, and enterprise systems where strict contracts and advanced security are required. In interviews, know both — and know that many real backend projects still integrate with legacy SOAP services even though they expose REST APIs themselves.

> See also: [REST API architecture](rest_api_architecture.md), [SOA architecture](soa_architecture.md), [How authentication works](how_authentication_works.md)
