MVC (Model-View-Controller) je arhitekturalni obrazac koji razdvaja logiku aplikacije u tri međusobno povezane komponente. Uveden je 1970-ih za desktop aplikacije, a sada je standardni obrazac za veb frejmvorke kao što su Symfony, Laravel, Ruby on Rails i ASP.NET.

### Tri komponente

**Model** — poslovna logika i podaci. Model ne zna ništa o tome kako se podaci prikazuju ili kako korisnički unos stiže. On se bavi:

- Upitima prema bazi podataka i trajnošću podataka
- Poslovnim pravilima i validacijom
- Domenskom logikom

**View** — prezentacijski sloj. View prikazuje podatke iz Modela u formatu koji korisnik može videti. On se bavi:

- HTML šablonima u tradicionalnim veb aplikacijama
- JSON/XML odgovorima u REST API-jima
- Izlazom konzole u CLI aplikacijama

**Controller** — upravljač unosom. Controller prima korisnički unos, poziva odgovarajuću logiku Modela i bira View za prikaz rezultata. On se bavi:

- Primanjem HTTP zahteva
- Validacijom unosa
- Pozivanjem servisa/repozitorijuma
- Vraćanjem odgovora

### Kako MVC funkcioniše — Tok

```text
User Request → Controller → Model → Controller → View → Response

1. User sends HTTP request: GET /users/42
2. Controller receives the request
3. Controller asks Model for data: $userRepository->find(42)
4. Model queries database and returns User object
5. Controller passes User to View
6. View renders the data (HTML page, JSON response, etc.)
7. Response sent back to user
```

### MVC u Symfony-ju (REST API)

U modernim REST API-jima, "View" je jednostavno JSON odgovor. Nema HTML šablona — Controller vraća podatke koji se serijalizuju u JSON.

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

### MVC sa HTML šablonima (Tradicionalna veb aplikacija)

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

### Uobičajene greške

**1. Debeli Controller — previše logike u Controlleru**

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

**2. Model direktno komunicira sa View-om**

Model nikada ne bi trebalo da zna o HTTP zahtevima, JSON-u, HTML-u ili bilo kojoj prezentacionoj komponenti. Radi samo sa domenskim objektima i podacima.

### MVC vs ostali obrasci

| Obrazac | Ključna razlika u odnosu na MVC |
|---------|--------------------------------|
| **MVVM** | ViewModel zamenjuje Controller, vezuje View za podatke (frontend frejmvorci kao Vue, React) |
| **MVP** | Presenter rukuje svom logikom View-a, View je pasivan |
| **ADR** | Action-Domain-Responder — specijalizovan za HTTP, svaka Action je jedan endpoint |
| **Hexagonal** | Domena je potpuno izolovana od ulaza i izlaza |

### Realni scenario

Gradite funkcionalnost registracije korisnika:

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

### Zaključak

MVC razdvaja odgovornosti na tri sloja: Model (poslovna logika i podaci), View (prezentacija) i Controller (upravljanje unosom). U REST API-jima, View je jednostavno JSON serijalizacija. Ključno pravilo je da Controlleri budu tanki — trebaju samo da prime unos, pozovu Model (servise) i vrate odgovor. Poslovna logika pripada sloju Modela (servisi, entiteti, repozitorijumi). MVC je polazna tačka — kako projekti rastu, obrasci kao Heksagonalna Arhitektura ili CQRS pružaju bolju separaciju.

> Vidi takođe: [Hexagonal Architecture](../architecture/hexagonal_architecture.sr.md), [CQRS](../architecture/cqrs.sr.md), [Separation of Concerns](soc.sr.md), [REST API architecture](../general/rest_api_architecture.sr.md)
