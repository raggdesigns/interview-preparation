SOAP i REST su dva različita pristupa za izgradnju web servisa. SOAP je **protokol** sa strogim pravilima i XML formatom. REST je **arhitekturalni stil** koji koristi standardne HTTP metode i tipično radi sa JSON-om.

### SOAP — Simple Object Access Protocol

SOAP je protokol za razmenu strukturiranih podataka između servisa. Svaka SOAP poruka je omotana u XML omotnicu sa specifičnom strukturom.

```xml
<!-- SOAP Zahtev -->
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

<!-- SOAP Odgovor -->
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

### REST — Isti Zahtev

```
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

### Ključne Razlike

| Funkcionalnost | SOAP | REST |
|---------------|------|------|
| Tip | Protokol | Arhitekturalni stil |
| Format podataka | Samo XML | JSON, XML, YAML, čisti tekst |
| Transport | HTTP, SMTP, TCP, JMS | Samo HTTP |
| Ugovor | WSDL fajl (strogi) | OpenAPI/Swagger (opciono) |
| Stanje | Može biti statefull | Bezdržavno |
| Obrada grešaka | SOAP Fault (XML) | HTTP status kodovi (404, 500...) |
| Bezbednost | WS-Security (ugrađena) | HTTPS + OAuth/JWT |
| Performanse | Sporije (overhead XML parsiranja) | Brže (JSON je lagan) |
| Keširanje | Teško | Lako (GET zahtevi su kešibilni) |
| Kriva učenja | Visoka | Niska |

### WSDL — Web Services Description Language

WSDL je XML fajl koji potpuno opisuje SOAP servis. Definiše:
- Koje **operacije** servis nudi
- Koje **parametre** svaka operacija očekuje
- Koji **tipovi podataka** se koriste
- Gde se servis **nalazi** (endpoint URL)

```xml
<!-- Uprošćeni primer WSDL -->
<definitions name="UserService"
    xmlns="http://schemas.xmlsoap.org/wsdl/"
    targetNamespace="http://example.com/users">

    <!-- Tipovi podataka -->
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

    <!-- Operacije -->
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

Klijent može pročitati ovaj WSDL fajl i **automatski generisati** klijentski kod za pozivanje servisa. Ovo je velika prednost SOAP-a — ugovor je čitljiv mašinama.

### SOAP Klijent u PHP-u

PHP ima ugrađenu podršku za SOAP putem klase `SoapClient`:

```php
// Kreiranje klijenta iz WSDL-a — PHP automatski generiše metode
$client = new SoapClient('http://example.com/users?wsdl');

// Pozivanje servisa — deluje kao pozivanje lokalne metode
$response = $client->GetUser(['UserId' => 42]);
echo $response->Name;    // "Dragan"
echo $response->Email;   // "dragan@example.com"

// Listanje svih dostupnih operacija
var_dump($client->__getFunctions());
// ["GetUserResponse GetUser(GetUserRequest)", "CreateUserResponse CreateUser(...)"]
```

### REST Klijent u PHP-u (za poređenje)

```php
// Korišćenje Symfony HttpClient
$response = $this->httpClient->request('GET', 'http://example.com/api/users/42');
$user = $response->toArray();
echo $user['name'];    // "Dragan"
echo $user['email'];   // "dragan@example.com"
```

### Kada Se SOAP Još Koristi

SOAP se smatra "starim" po modernim web standardima, ali je još uvek aktivno u upotrebi:

1. **Bankarstvo i finansijske usluge** — banke zahtevaju WS-Security, digitalne potpise i stroge ugovore
2. **Vladini sistemi** — nasleđeni sistemi komuniciraju putem SOAP-a
3. **Integrisanje preduzeća** — SAP, Oracle i Microsoft ekosistemi intenzivno koriste SOAP
4. **Procesori plaćanja** — neke kapije za plaćanje još uvek izlažu SOAP API-je
5. **Telekomunikacije** — sistemi za naplatu i proviziju

```php
// Realni primer: komunikacija sa SOAP servisom banke
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
    // SOAP greške dolaze kao SoapFault izuzeci
    echo "Error: " . $e->getMessage();
    // Debug: vidi sirovi XML zahtev/odgovor
    echo $client->__getLastRequest();
    echo $client->__getLastResponse();
}
```

### SOAP Obrada Grešaka vs REST

```xml
<!-- SOAP Fault (odgovor greške) -->
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
// REST odgovor greške — koristi HTTP status kod 404
{
    "error": "User not found",
    "code": "USER_404",
    "message": "No user exists with ID 42"
}
```

SOAP uvek vraća HTTP 200 — čak i za greške. Informacije o grešci su unutar XML tela. REST koristi HTTP status kodove (404, 500, itd.) za označavanje grešaka.

### Realni Scenario

Gradite PHP aplikaciju koja treba da se integriše sa dva eksterna servisa:

1. **Bankarski sistem plaćanja** — nudi samo SOAP API
2. **Praćenje dostave** — nudi REST API

```php
// Servis koji se integriše sa oba
class OrderFulfillmentService
{
    public function __construct(
        private SoapClient $bankClient,           // SOAP — banka to zahteva
        private HttpClientInterface $deliveryApi,  // REST — moderni API
    ) {}

    public function processOrder(Order $order): void
    {
        // Korak 1: Obrada plaćanja putem SOAP-a
        $paymentResult = $this->bankClient->ProcessPayment([
            'Amount' => $order->getTotal(),
            'Currency' => 'EUR',
            'Reference' => $order->getId(),
        ]);

        if ($paymentResult->Status !== 'SUCCESS') {
            throw new PaymentFailedException($paymentResult->ErrorMessage);
        }

        // Korak 2: Kreiranje pošiljke putem REST-a
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

### Zaključak

REST je standard za moderne web API-je — jednostavniji je, brži, koristi JSON i prirodno radi sa HTTP-om. SOAP je teži protokol sa strogim ugovorima (WSDL), XML formatom i ugrađenim bezbednosnim funkcijama. SOAP se još uvek koristi u bankarstvu, vladama i poslovnim sistemima gde su strogi ugovori i napredna bezbednost obavezni. Na intervjuima, znajte oba — i znajte da mnogi realni backend projekti još uvek integrišu sa nasleđenim SOAP servisima čak i kada sami izlažu REST API-je.

> Vidi takođe: [REST API arhitektura](rest_api_architecture.sr.md), [SOA arhitektura](soa_architecture.sr.md), [Kako funkcioniše autentikacija](how_authentication_works.sr.md)
