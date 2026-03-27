# Pisanje REST API-ja u Symfony-u

Kreiranje REST API-ja u Symfony-u uključuje nekoliko koraka, od podešavanja kontrolera do definisanja ruta i rukovanja zahtevima i odgovorima. Ovaj vodič pruža pregled ovih koraka, ilustrovan primerima.

## Korak 1: Podešavanje Symfony projekta

Prvo, uverite se da imate instaliran Symfony i Composer. Kreirajte novi Symfony projekat ako već niste:

```bash
composer create-project symfony/skeleton my_project_name
```

## Korak 2: Instalacija potrebnih zavisnosti

Za REST API, možda će vam biti potrebni Symfony Serializer, Validator i orm-pack. Instalirajte ih korišćenjem Composer-a:

```bash
composer require symfony/serializer symfony/validator symfony/orm-pack
```

## Korak 3: Kreiranje kontrolera

Kontroleri rukuju dolaznim HTTP zahtevima i vraćaju odgovore. Kreirajte kontroler za vaš API:

```php
// src/Controller/Api/BookController.php
namespace App\Controller\Api;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class BookController extends AbstractController
{
    /**
     * @Route("/api/books", name="get_books", methods={"GET"})
     */
    public function getBooks(): Response
    {
        $books = [
            ['id' => 1, 'title' => '1984', 'author' => 'George Orwell'],
            ['id' => 2, 'title' => 'The Great Gatsby', 'author' => 'F. Scott Fitzgerald'],
        ];

        return $this->json($books);
    }
}
```

## Korak 4: Konfigurisanje ruta

Symfony rute mogu biti konfigurisane korišćenjem anotacija (kao što je prikazano gore) ili YAML formata. Uverite se da su metode vašeg kontrolera pravilno anotovane ili konfigurisane u `config/routes.yaml`.

## Korak 5: Serijalizacija i deserijalizacija

Za složene objekte, koristite Symfony-jevu Serializer komponentu za konvertovanje podataka objekta u JSON ili XML i obrnuto:

```php
use Symfony\Component\Serializer\SerializerInterface;

public function createBook(Request $request, SerializerInterface $serializer): Response
{
    $book = $serializer->deserialize($request->getContent(), Book::class, 'json');

    // Save the book entity...

    return $this->json($book);
}
```

## Korak 6: Validacija

Koristite Symfony-jevu Validator komponentu za validaciju podataka:

```php
use Symfony\Component\Validator\Validator\ValidatorInterface;

public function createBook(Request $request, SerializerInterface $serializer, ValidatorInterface $validator): Response
{
    $book = $serializer->deserialize($request->getContent(), Book::class, 'json');

    $errors = $validator->validate($book);
    if (count($errors) > 0) {
        return $this->json($errors, Response::HTTP_BAD_REQUEST);
    }

    // Save the book entity...

    return $this->json($book);
}
```

## Korak 7: Rukovanje izuzecima

Pravilno rukujte izuzecima kako biste vraćali smislene odgovore sa greškama. Symfony-jev osluškivač dogadjaja može hvatati izuzetke i formatirati ih pre slanja klijentu.

## Zaključak

Izgradnja REST API-ja u Symfony-u uključuje podešavanje projekta, kreiranje kontrolera za rukovanje API zahtevima i konfigurisanje rutiranja. Koristite Serializer i Validator komponente za transformaciju podataka i validaciju. Pravilno rukovanje izuzecima osigurava robustan API.
