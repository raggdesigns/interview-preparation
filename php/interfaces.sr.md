Interfejs u PHP-u definiše ugovor — govori klasi **koje metode mora imati**, ali ne i **kako** te metode treba da rade. Zamislite ga kao listu pravila koje klasa obećava da će poštovati.

### Osnovni interfejs

```php
interface PaymentMethodInterface
{
    public function pay(float $amount): bool;
    public function refund(float $amount): bool;
}
```

Svaka klasa koja implementira ovaj interfejs **mora** definisati i metodu `pay()` i metodu `refund()`:

```php
class CreditCardPayment implements PaymentMethodInterface
{
    public function pay(float $amount): bool
    {
        // Process credit card payment
        return true;
    }

    public function refund(float $amount): bool
    {
        // Process credit card refund
        return true;
    }
}
```

Ako zaboravite da implementirate neku metodu, PHP će baciti fatalni error.

### Zašto koristiti interfejse?

- **Doslednost**: Sve klase koje implementiraju interfejs imaju iste metode.
- **Type Hinting**: Možete koristiti type hint na interfejs umesto na konkretnu klasu, što čini kod fleksibilnim.
- **Višestruke implementacije**: Različite klase mogu implementirati isti interfejs na različite načine.

```php
function processPayment(PaymentMethodInterface $method, float $amount): void
{
    $method->pay($amount); // Works with ANY class that implements the interface
}

processPayment(new CreditCardPayment(), 100.00);
processPayment(new PaypalPayment(), 50.00);
```

### Pravila interfejsa

- Sve metode u interfejsu moraju biti **public**.
- Interfejs **ne može** imati properties (dozvoljene su samo konstante).
- Interfejs **ne može** imati tela metoda (pre PHP 8.0).
- Klasa **može** implementirati više interfejsa.

```php
class OnlineStore implements PaymentMethodInterface, LoggableInterface, NotifiableInterface
{
    // Must implement ALL methods from all three interfaces
}
```

### Konstante interfejsa

Interfejsi mogu definisati konstante. Ove konstante ne mogu biti prepisane od strane klasa koje implementiraju interfejs.

```php
interface StatusInterface
{
    const ACTIVE = 'active';
    const INACTIVE = 'inactive';
}

class User implements StatusInterface
{
    public function getStatus(): string
    {
        return self::ACTIVE; // 'active'
    }
}
```

### Nasleđivanje interfejsa

Interfejsi mogu **proširivati** druge interfejse, baš kao što klase proširuju druge klase. Ovo se naziva nasleđivanje interfejsa.

```php
interface VehicleInterface
{
    public function start(): void;
    public function stop(): void;
}

interface ElectricVehicleInterface extends VehicleInterface
{
    public function chargeBattery(): void;
}
```

Sada svaka klasa koja implementira `ElectricVehicleInterface` mora imati **tri** metode: `start()`, `stop()` i `chargeBattery()`.

#### Višestruko nasleđivanje interfejsa

Za razliku od klasa, interfejsi **mogu** proširivati više interfejsa odjednom:

```php
interface FlyableInterface
{
    public function fly(): void;
}

interface SwimmableInterface
{
    public function swim(): void;
}

interface DuckInterface extends FlyableInterface, SwimmableInterface
{
    public function quack(): void;
}

// A class implementing DuckInterface must have fly(), swim(), and quack()
class Duck implements DuckInterface
{
    public function fly(): void { /* ... */ }
    public function swim(): void { /* ... */ }
    public function quack(): void { /* ... */ }
}
```

### Realni scenario

Gradite sistem za obaveštenja. Različiti kanali (email, SMS, Slack) šalju poruke na različite načine, ali svi moraju imati istu metodu:

```php
interface NotificationChannelInterface
{
    public function send(string $recipient, string $message): bool;
}

class EmailChannel implements NotificationChannelInterface
{
    public function send(string $recipient, string $message): bool
    {
        return mail($recipient, 'Notification', $message);
    }
}

class SmsChannel implements NotificationChannelInterface
{
    public function send(string $recipient, string $message): bool
    {
        // Use Twilio API to send SMS
        return true;
    }
}

class NotificationService
{
    /** @param NotificationChannelInterface[] $channels */
    public function notify(array $channels, string $recipient, string $message): void
    {
        foreach ($channels as $channel) {
            $channel->send($recipient, $message);
        }
    }
}
```

Korišćenjem interfejsa, možete dodavati nove kanale (Telegram, push notifikacije) bez promene klase `NotificationService`.

### Zaključak

Interfejsi definišu ugovor metoda koje klase moraju implementirati. Pružaju doslednost i fleksibilnost kroz type hinting. Interfejsi mogu proširivati druge interfejse (čak i više njih), što omogućava izgradnju složenih ugovora od jednostavnijih. Ovo je jedan od glavnih alata za postizanje polimorfizma u PHP-u.
