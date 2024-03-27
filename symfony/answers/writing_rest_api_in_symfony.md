# Writing a REST API in Symfony

Creating a REST API in Symfony involves several steps, from setting up controllers to defining routes and handling
requests and responses. This guide provides an overview of these steps, illustrated with examples.

## Step 1: Setup Symfony Project

First, ensure you have Symfony and Composer installed. Create a new Symfony project if you haven't already:

```bash
composer create-project symfony/skeleton my_project_name
```

## Step 2: Install Required Dependencies

For a REST API, you might need the Symfony Serializer, Validator, and orm-pack. Install them using Composer:

```bash
composer require symfony/serializer symfony/validator symfony/orm-pack
```

## Step 3: Create a Controller

Controllers handle incoming HTTP requests and return responses. Create a controller for your API:

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

## Step 4: Configure Routes

Symfony routes can be configured using annotations (as seen above) or YAML. Ensure your controller methods are properly
annotated or configured in `config/routes.yaml`.

## Step 5: Serialization and Deserialization

For complex objects, use Symfony's Serializer component to convert object data into JSON or XML and vice versa:

```php
use Symfony\Component\Serializer\SerializerInterface;

public function createBook(Request $request, SerializerInterface $serializer): Response
{
    $book = $serializer->deserialize($request->getContent(), Book::class, 'json');

    // Save the book entity...

    return $this->json($book);
}
```

## Step 6: Validation

Use Symfony's Validator component to validate data:

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

## Step 7: Exception Handling

Handle exceptions appropriately to return meaningful error responses. Symfony's event listener can catch exceptions and
format them before sending to the client.

## Conclusion

Building a REST API in Symfony involves setting up a project, creating controllers for handling API requests, and
configuring routing. Utilize the Serializer and Validator components for data transformation and validation. Proper
exception handling ensures a robust API.

