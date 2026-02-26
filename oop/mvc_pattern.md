MVC (Model-View-Controller) is an architectural pattern that separates application logic into three interconnected components. It was introduced in the 1970s for desktop applications but is now the standard pattern for web frameworks like Symfony, Laravel, Ruby on Rails, and ASP.NET.

### The Three Components

**Model** — business logic and data. The Model knows nothing about how data is displayed or how user input arrives. It handles:
- Database queries and data persistence
- Business rules and validation
- Domain logic

**View** — presentation layer. The View renders data from the Model in a format the user can see. It handles:
- HTML templates in traditional web apps
- JSON/XML responses in REST APIs
- Console output in CLI applications

**Controller** — input handler. The Controller receives user input, calls the appropriate Model logic, and selects a View to present the result. It handles:
- Receiving HTTP requests
- Validating input
- Calling services/repositories
- Returning responses

### How MVC Works — The Flow

```
User Request → Controller → Model → Controller → View → Response

1. User sends HTTP request: GET /users/42
2. Controller receives the request
3. Controller asks Model for data: $userRepository->find(42)
4. Model queries database and returns User object
5. Controller passes User to View
6. View renders the data (HTML page, JSON response, etc.)
7. Response sent back to user
```

### MVC in Symfony (REST API)

In modern REST APIs, the "View" is simply the JSON response. There are no HTML templates — the Controller returns data that gets serialized to JSON.

```php
#[Route('/api/users')]
class UserController extends AbstractController
{
    public function __construct(
        private UserRepository $userRepository,  // Model layer
        private UserService $userService,
    ) {}

    // Controller — receives input, calls Model, returns View (JSON)
    #[Route('/{id}', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        // Ask Model for data
        $user = $this->userRepository->find($id);

        if (!$user) {
            return $this->json(['error' => 'User not found'], 404);
        }

        // View = JSON response
        return $this->json([
            'id' => $user->getId(),
            'name' => $user->getName(),
            'email' => $user->getEmail(),
        ]);
    }

    #[Route('', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        // Controller validates input
        if (empty($data['name']) || empty($data['email'])) {
            return $this->json(['error' => 'Name and email are required'], 400);
        }

        // Controller calls Model (service) to handle business logic
        $user = $this->userService->createUser($data['name'], $data['email']);

        // View = JSON response
        return $this->json(
            ['id' => $user->getId(), 'name' => $user->getName()],
            201
        );
    }
}
```

### MVC with HTML Templates (Traditional Web App)

```php
#[Route('/users')]
class UserController extends AbstractController
{
    #[Route('/{id}', methods: ['GET'])]
    public function show(int $id): Response
    {
        $user = $this->userRepository->find($id);

        // View = Twig template
        return $this->render('user/show.html.twig', [
            'user' => $user,
        ]);
    }
}
```

```twig
{# templates/user/show.html.twig — View layer #}
<h1>{{ user.name }}</h1>
<p>Email: {{ user.email }}</p>
<p>Joined: {{ user.createdAt|date('Y-m-d') }}</p>
```

### Common Mistakes

**1. Fat Controller — too much logic in Controller**

```php
// BAD — Controller does everything
#[Route('/orders', methods: ['POST'])]
public function create(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);
    
    // Business logic should NOT be in Controller
    $user = $this->userRepository->find($data['userId']);
    $product = $this->productRepository->find($data['productId']);
    
    if ($product->getStock() < $data['quantity']) {
        return $this->json(['error' => 'Out of stock'], 400);
    }
    
    $total = $product->getPrice() * $data['quantity'];
    $tax = $total * 0.20;
    
    $order = new Order();
    $order->setUser($user);
    $order->setProduct($product);
    $order->setTotal($total + $tax);
    
    $this->em->persist($order);
    $this->em->flush();
    
    // Send email
    $this->mailer->send(new OrderConfirmation($order));
    
    return $this->json(['orderId' => $order->getId()], 201);
}
```

```php
// GOOD — Controller is thin, business logic is in Service (Model layer)
#[Route('/orders', methods: ['POST'])]
public function create(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);
    
    $order = $this->orderService->createOrder(
        userId: $data['userId'],
        productId: $data['productId'],
        quantity: $data['quantity'],
    );
    
    return $this->json(['orderId' => $order->getId()], 201);
}
```

**2. Model talking to View directly**

The Model should never know about HTTP requests, JSON, HTML, or any presentation concern. It works only with domain objects and data.

### MVC vs Other Patterns

| Pattern | Key difference from MVC |
|---------|------------------------|
| **MVVM** | ViewModel replaces Controller, binds View to data (frontend frameworks like Vue, React) |
| **MVP** | Presenter handles all View logic, View is passive |
| **ADR** | Action-Domain-Responder — specialized for HTTP, each Action is a single endpoint |
| **Hexagonal** | Domain is completely isolated from both input and output |

### Real Scenario

You are building a user registration feature:

```php
// Controller — thin, only handles HTTP
#[Route('/register', methods: ['POST'])]
public function register(Request $request): JsonResponse
{
    $dto = new RegisterUserDto(
        name: $request->get('name'),
        email: $request->get('email'),
        password: $request->get('password'),
    );

    try {
        $user = $this->registrationService->register($dto);
    } catch (EmailAlreadyUsedException $e) {
        return $this->json(['error' => 'Email already in use'], 409);
    }

    return $this->json(['id' => $user->getId()], 201);
}

// Model (Service) — business logic
class RegistrationService
{
    public function register(RegisterUserDto $dto): User
    {
        if ($this->userRepository->findByEmail($dto->email)) {
            throw new EmailAlreadyUsedException();
        }

        $user = new User(
            name: $dto->name,
            email: $dto->email,
            password: $this->hasher->hashPassword($dto->password),
        );

        $this->userRepository->save($user);
        $this->eventDispatcher->dispatch(new UserRegistered($user));

        return $user;
    }
}

// Model (Repository) — data access
class UserRepository
{
    public function findByEmail(string $email): ?User
    {
        return $this->em->getRepository(User::class)
            ->findOneBy(['email' => $email]);
    }

    public function save(User $user): void
    {
        $this->em->persist($user);
        $this->em->flush();
    }
}
```

### Conclusion

MVC separates concerns into three layers: Model (business logic and data), View (presentation), and Controller (input handling). In REST APIs, the View is simply JSON serialization. The key rule is to keep Controllers thin — they should only receive input, call the Model (services), and return a response. Business logic belongs in the Model layer (services, entities, repositories). MVC is a starting point — as projects grow, patterns like Hexagonal Architecture or CQRS provide better separation.

> See also: [Hexagonal Architecture](../architecture/hexagonal_architecture.md), [CQRS](../architecture/cqrs.md), [Separation of Concerns](soc.md), [REST API architecture](../general/rest_api_architecture.md)
