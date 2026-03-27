
# Symfony Security Component

Symfony Security Component je sveobuhvatan sistem za rukovanje autentifikacijom i autorizacijom u Symfony aplikacijama. Pruža širok spektar funkcionalnosti za obezbeđivanje vaše aplikacije upravljanjem autentifikacijom korisnika, autorizacijom i zaštitom od uobičajenih ranjivosti.

## Osnovni koncepti

- **Autentifikacija**: Verifikacija identiteta korisnika. Ovo može da uključuje forme za prijavljivanje, API tokene ili druge metode.
- **Autorizacija**: Određivanje da li autentifikovani korisnik ima dozvolu da pristupi određenim resursima ili izvrši specifične akcije.
- **Provajderi**: Definišu kako se korisnici učitavaju iz vašeg skladišta podataka (npr. baza podataka, memorija itd.).
- **Zaštitni zidovi (Firewalls)**: Definišu kako se autentifikacija obrađuje za različite delove vaše aplikacije.
- **Kontrola pristupa**: Pravila za ograničavanje pristupa specifičnim putanjama ili URL-ovima na osnovu uloga ili drugih uslova.
- **Glasači (Voters)**: Implementiraju složenu logiku za odlučivanje da li korisnik može da izvrši akciju na specifičnom objektu.

## Prednosti

- **Fleksibilnost**: Podržava širok spektar metoda autentifikacije i provajdera korisnika.
- **Proširivost**: Prilagođeni glasači i stražari mogu biti kreirani za implementaciju složene logike autorizacije.
- **Jednostavnost upotrebe**: Pojednostavljuje razvoj bezbednih aplikacija kroz integraciju sa Symfony framework-om.

## Primer upotrebe

### Konfigurisanje provajdera korisnika

Prvo, konfigurisajte provajdera korisnika u `config/packages/security.yaml`:

```yaml
security:
    providers:
        in_memory: { memory: null }
```

### Podešavanje zaštitnog zida

Zatim, definišite zaštitni zid za vašu aplikaciju:

```yaml
security:
    firewalls:
        main:
            anonymous: true
            http_basic: true
```

Ovaj osnovni primer koristi HTTP Basic autentifikaciju radi jednostavnosti.

### Kreiranje glasača

Za implementaciju prilagođene logike autorizacije, možete kreirati glasača:

```php
namespace App\Security;

use Symfony\Component\Security\Core\Authorization\Voter\Voter;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;

class PostVoter extends Voter
{
    protected function supports(string $attribute, $subject): bool
    {
        // Logic to determine if the voter supports the given attribute and subject
    }

    protected function voteOnAttribute(string $attribute, $subject, TokenInterface $token): bool
    {
        // Implement the logic to vote on the attribute and subject
    }
}
```

### Korišćenje kontrole pristupa

Pravila kontrole pristupa mogu biti definisana u `security.yaml` za ograničavanje pristupa na osnovu putanja i uloga:

```yaml
security:
    access_control:
        - { path: ^/admin, roles: ROLE_ADMIN }
```

Ovo pravilo ograničava pristup svim URL-ovima koji počinju sa `/admin` na korisnike sa ulogom `ROLE_ADMIN`.

## Zaključak

Symfony Security Component nudi moćan i fleksibilan sistem za upravljanje autentifikacijom i autorizacijom u vašim Symfony aplikacijama. Korišćenjem njegovih funkcionalnosti, možete izgraditi bezbedne aplikacije koje štite osetljive podatke i osiguravaju da korisnici mogu da pristupe samo resursima i izvršavaju samo akcije koje im je dozvoljeno.
