# Autowiring dve instance istog servisa u Symfony-ju

U Symfony-ju, možete naići na situaciju gde trebate autowire-ovati dve instance istog servisa u klasu, ali sa različitim konfiguracijama. Ovaj scenario može se rešiti definisanjem aliasa servisa i korišćenjem binding argumenata.

## Kako funkcioniše

Symfony-jev sistem autowiringa je dovoljno pametan da uparuje argumente servisa sa servisima definisanim u `services.yaml` po njihovim imenima. Kada definišete aliase servisa sa specifičnim imenima, a zatim koristite ta imena kao parametre konstruktora, Symfony razume da se referišete na te specifične instance.

## Detaljno objašnjenje

Kada definišete aliase u `services.yaml` na sledeći način:

```yaml
services:
  monolog.logger.order:
    class: Monolog\Logger
    arguments: ['order']
    tags:
      - { name: 'monolog.logger', channel: 'order' }

  monolog.logger.user:
    class: Monolog\Logger
    arguments: ['user']
    tags:
      - { name: 'monolog.logger', channel: 'user' }

  Psr\Log\LoggerInterface $orderLogger:
    alias: 'monolog.logger.order'

  Psr\Log\LoggerInterface $userLogger:
    alias: 'monolog.logger.user'
```

Govorite Symfony-jevom Dependency Injection kontejneru da kada se naiđe na argument konstruktora tipa `LoggerInterface` nazvan `$orderLogger`, treba da injektuje servis poznat kao `monolog.logger.order`. Slično, za `$userLogger` injektuje `monolog.logger.user`.

Ova konvencija imenovanja omogućava vam da imate različite konfiguracije za `order` i `user` kanale logovanja i da ih koristite na odgovarajući način u vašim servisima.

# Razumevanje uloge aliasa u konstruktorima servisa u Symfony-ju

Kada autowire-ujete servise u Symfony-ju, aliasi igraju ključnu ulogu u specificiranju koje instance servisa treba injektovati u vaše klase, posebno kada imate više instanci istog interfejsa. Razjasnimo šta alias predstavlja i kako se koristi u kontekstu konstruktora servisa.

## Alias: Pokazivač na specifičnu instancu servisa

U konfiguraciji servisa, kada definišete alias, u suštini dajete ime specifičnoj instanci servisa. Ovo ime se zatim može koristiti za referenciranje te specifične instance drugde u vašoj Symfony aplikaciji, posebno kod autowiringa servisa.

U ovoj konfiguraciji, `$orderLogger` i `$userLogger` su aliasi koji pokazuju na specifične instance logger servisa konfigurisane za logovanje u različite kanale (`order` i `user`).

## Kako se aliasi rešavaju u injektovanju konstruktora

Kada tipski naznačite `LoggerInterface` u konstruktoru svog servisa i imenujete parametre `$orderLogger` i `$userLogger`, Symfony-jev sistem autowiringa traži aliase definisane u konfiguraciji servisa koji odgovaraju ovim imenima parametara. Zatim injektuje servise na koje ovi aliasi pokazuju u konstruktor.

```php
public function __construct(LoggerInterface $orderLogger, LoggerInterface $userLogger)
{
    $this->orderLogger = $orderLogger;
    $this->userLogger = $userLogger;
}
```

Evo šta se dešava iza scene:

- Symfony vidi argument `LoggerInterface $orderLogger` u konstruktoru.
- Traži alias ili definiciju servisa koja odgovara ovom imenu (`$orderLogger`).
- Pronalazeći alias `Psr\Log\LoggerInterface $orderLogger` u `services.yaml`, rešava ovaj alias do servisa na koji pokazuje (`monolog.logger.order`).
- Instanca `LoggerInterface` konfigurisana za `order` logovanje injektuje se kao `$orderLogger`.
- Isti proces se primenjuje na `$userLogger`, što rezultira injektovanjem instance `user` loggera.

## Uloga aliasa

Alias efektivno služi kao most između konfiguracije servisa i konstruktora servisa, omogućavajući injektovanje specifičnih instanci servisa na osnovu imena parametara konstruktora. Ovo je posebno korisno za razlikovanje između više instanci istog interfejsa.

## Zaključak

Razumevanje uloge aliasa u Symfony-ju pomaže da se razjasni kako se specifične instance servisa biraju i injektuju u vaše klase. Ovaj mehanizam pruža moćan i fleksibilan način upravljanja zavisnostima servisa u Symfony aplikaciji.

## Primer servisa koji koristi različite loggere

```php
namespace App\Service;

use Psr\Log\LoggerInterface;

class UserService
{
    private $orderLogger;
    private $userLogger;

    public function __construct(LoggerInterface $orderLogger, LoggerInterface $userLogger)
    {
        $this->orderLogger = $orderLogger;
        $this->userLogger = $userLogger;
    }

    public function logOrderActivity(string $message): void
    {
        // This uses the order logger instance
        $this->orderLogger->info($message);
    }

    public function logUserActivity(string $message): void
    {
        // This uses the user logger instance
        $this->userLogger->info($message);
    }
}
```

U ovom podešavanju, `$orderLogger` i `$userLogger` su distinktne instance `LoggerInterface` koje automatski rešava i injektuje Symfony na osnovu konvencije imenovanja korišćene i u konfiguraciji servisa i u argumentima konstruktora vaše klase servisa.

## Zaključak

Ovaj mehanizam razlikovanja servisa po imenima argumenata konstruktora i njihovog uparivanja sa aliasima servisa je moćna funkcionalnost Symfony-jevog sistema autowiringa, koji omogućava fleksibilne i čitljive konfiguracije servisa.
