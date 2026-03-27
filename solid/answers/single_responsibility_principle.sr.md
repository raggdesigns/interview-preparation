# Single Responsibility Principle (SRP)

Single Responsibility Principle (SRP), jedan od SOLID principa objektno-orijentisanog dizajna, navodi da klasa treba da ima samo jedan razlog za promenu. To znači da svaka klasa treba da bude odgovorna za jedan deo funkcionalnosti koji softver pruža, i ta odgovornost treba da bude u potpunosti enkapsulirana unutar klase.

## Način razmišljanja

- Grupišite zajedno stvari koje se menjaju iz istog razloga.
- Odvojite one stvari koje se menjaju iz različitih razloga.
- Držite zajedno samo srodni sadržaj.

## Kršenje SRP

Razmotrite PHP klasu koja se bavi i upravljanjem podacima o korisnicima i slanjem obaveštenja. Ova klasa krši SRP jer ima više od jednog razloga za promenu — promene u logici upravljanja korisnicima i promene u načinu slanja obaveštenja.

```php
class UserManager {
    public function createUser($userData) {
        // Logic to create a user
        echo "User created\n";
    }

    public function sendEmail($user) {
        // Logic to send an email to the user
        echo "Email sent to user\n";
    }
}

$userManager = new UserManager();
$userManager->createUser(['name' => 'John Doe']);
$userManager->sendEmail('john.doe@example.com');
```

## Refactored kod koji primenjuje SRP

```text
class UserManager {
    public function createUser($userData) {
        // Logic to create a user
        echo "User created\n";
        // Delegate email sending to UserNotifier
        (new UserNotifier())->sendEmail($userData['email']);
    }
}

class UserNotifier {
    public function sendEmail($email) {
        // Logic to send an email
        echo "Email sent to $email\n";
    }
}

$userManager = new UserManager();
$userManager->createUser(['name' => 'John Doe', 'email' => 'john.doe@example.com']);
```

Da bi se poštovao SRP, gornji scenario možemo refactoring-ovati tako što ga podelimo u dve klase: jednu za upravljanje podacima korisnika (`UserManager`) i drugu za obradu obaveštenja korisnicima (`UserNotifier`).

## Objašnjenje

Refactoring-om koda sada imamo dve klase, svaka sa jednom odgovornošću. `UserManager` je odgovoran samo za zadatke upravljanja korisnicima, a `UserNotifier` se bavi slanjem obaveštenja korisnicima. Ovo je u skladu sa SRP i čini naš kod modularnim, lakšim za razumevanje i održavanje.

## Prednosti primene SRP

- **Poboljšana modularnost**: Svaka klasa ima jasan, jedinstven fokus, što je čini lakšom za razumevanje i izmenu.
- **Lakoća testiranja**: Manje klase sa jednom odgovornošću lakše je testirati jediničnim testovima.
- **Niže sprezanje**: Razdvajanje klasa dovodi do fleksibilnijeg i lakšeg za održavanje koda.
- **Lakši refactoring i dodavanje funkcionalnosti**: Sa dobro razdvojenim odgovornostima, dodavanje novih funkcionalnosti ili menjanje postojećeg ponašanja postaje manje rizično i složeno.
