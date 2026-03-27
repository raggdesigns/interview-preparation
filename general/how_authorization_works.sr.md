# Kako Funkcioniše Autorizacija

Autorizacija odlučuje **šta autentifikovani korisnik sme da radi**. Odvija se nakon autentikacije (koja odgovara na pitanje "Ko si ti?") i odgovara na pitanje: **"Čemu možeš da pristupiš?"**

> **Scenario koji se koristi kroz ovaj dokument:** CMS aplikacija gde korisnici imaju uloge (`viewer`, `editor`, `admin`). `Editor` može da kreira i uređuje članke, ali ne može da ih briše niti da upravlja korisnicima. `Admin` može sve.

## Preduslovi

- [Kako Funkcioniše Autentikacija](how_authentication_works.sr.md) — verifikacija identiteta se odvija pre autorizacije
- [Kako Funkcioniše JWT Autorizacija](how_jwt_authorization_works.sr.md) — tokeni često nose tvrdnje o ulozi/dozvoli

## Osnovna Koncepcija

Nakon što se korisnik prijavi, svaki naredni zahtev mora biti proveren:

```text
Zahtev: DELETE /api/articles/42
Zaglavlja: Authorization: Bearer <token>

1. Sloj autentikacije  → Token validan? → Da → user_id=5, roles=["editor"]
2. Sloj autorizacije   → Može li "editor" da briše članke? → Ne → 403 Forbidden
```

Ključna razlika:

| Aspekt | Autentikacija | Autorizacija |
|--------|--------------|--------------|
| Pitanje | "Ko si ti?" | "Šta možeš da radiš?" |
| Odvija se | Prvo | Nakon autentikacije |
| Greška | 401 Unauthorized | 403 Forbidden |
| Bazira se na | Kredencijalima (lozinka, token) | Ulogama, dozvolama, politikama |

## Modeli Autorizacije

### 1. Kontrola Pristupa Bazirana na Ulogama (RBAC)

Korisnicima se dodeljuju **uloge**, a svaka uloga ima fiksni skup **dozvola**. Ovo je najčešći model u web aplikacijama.

```text
Uloge i dozvole:

viewer → [article.view]
editor → [article.view, article.create, article.edit]
admin  → [article.view, article.create, article.edit, article.delete, user.manage]
```

**PHP implementacija:**

```php
final class RbacAuthorizer
{
    private const ROLE_PERMISSIONS = [
        'viewer' => ['article.view'],
        'editor' => ['article.view', 'article.create', 'article.edit'],
        'admin'  => ['article.view', 'article.create', 'article.edit', 'article.delete', 'user.manage'],
    ];

    public function isGranted(User $user, string $permission): bool
    {
        foreach ($user->getRoles() as $role) {
            if (in_array($permission, self::ROLE_PERMISSIONS[$role] ?? [], true)) {
                return true;
            }
        }

        return false;
    }
}

// Korišćenje u kontroleru
if (!$authorizer->isGranted($currentUser, 'article.delete')) {
    throw new AccessDeniedHttpException('You cannot delete articles.');
}
```

**Prednosti:** Jednostavna implementacija i revizija.
**Nedostaci:** Ne skalira se dobro kada su potrebna fino granulisana pravila (npr. "editatori mogu da uređuju samo svoje članke").

### 2. Kontrola Pristupa Bazirana na Atributima (ABAC)

Odluke se donose na osnovu **atributa** korisnika, resursa i okruženja. Fleksibilnija od RBAC-a.

```text
Pravilo: Dozvoli uređivanje AKO
  user.role == "editor"
  I resource.author_id == user.id
  I environment.time IZMEĐU 09:00 I 18:00
```

**PHP implementacija:**

```php
final class ArticleEditPolicy
{
    public function canEdit(User $user, Article $article): bool
    {
        // Provera uloge
        if (!in_array('editor', $user->getRoles(), true)) {
            return false;
        }

        // Provera vlasništva — editatori mogu da uređuju samo svoje članke
        if ($article->getAuthorId() !== $user->getId()) {
            return false;
        }

        // Vremenski uslovljena provera — uređivanje samo tokom radnog vremena
        $hour = (int) date('G');
        if ($hour < 9 || $hour > 18) {
            return false;
        }

        return true;
    }
}
```

**Prednosti:** Fino granulisane, kontekstualno svesne odluke.
**Nedostaci:** Složena implementacija, teže za reviziju ("zašto je ovo odbijeno?").

### 3. Liste Kontrole Pristupa (ACL)

Svaki **resurs** ima listu koja specificira koji korisnici ili grupe mogu obavljati koje operacije. Razmislite o dozvolama fajl sistema.

```text
Članak #42:
  user:5  → [read, write]
  user:8  → [read]
  group:editors → [read, write]
  group:admins  → [read, write, delete]
```

**Prednosti:** Granularnost na nivou resursa.
**Nedostaci:** Teško upravljati u velikom obimu (svaki resurs treba sopstvenu listu).

### Poređenje Modela

| Aspekt | RBAC | ABAC | ACL |
|--------|------|------|-----|
| Granularnost | Na nivou uloge | Na nivou atributa | Na nivou resursa |
| Složenost | Niska | Visoka | Srednja |
| Skalabilnost | Dobra za jednostavne aplikacije | Dobra za složena pravila | Loša u velikom obimu |
| Mogućnost revizije | Laka ("uloga X ima dozvolu Y") | Teška (mnogi atributi) | Srednja |
| Najpogodnije za | Većina web aplikacija | Kontekstualno zavisna pravila | Fajl sistemi, CMS |

## Praktičan Primer: Symfony Voter

Symfony koristi **Voter** obrazac za centralizaciju logike autorizacije. Svaki voter odlučuje `GRANT`, `DENY` ili `ABSTAIN` za dati atribut i subjekt.

```php
// src/Security/Voter/ArticleVoter.php
final class ArticleVoter extends Voter
{
    public const EDIT   = 'ARTICLE_EDIT';
    public const DELETE = 'ARTICLE_DELETE';

    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, [self::EDIT, self::DELETE], true)
            && $subject instanceof Article;
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        $user = $token->getUser();
        if (!$user instanceof User) {
            return false;
        }

        /** @var Article $article */
        $article = $subject;

        return match ($attribute) {
            self::EDIT   => $this->canEdit($user, $article),
            self::DELETE => $this->canDelete($user, $article),
            default      => false,
        };
    }

    private function canEdit(User $user, Article $article): bool
    {
        // Admini mogu da uređuju sve
        if (in_array('ROLE_ADMIN', $user->getRoles(), true)) {
            return true;
        }

        // Editatori mogu da uređuju samo svoje članke
        return in_array('ROLE_EDITOR', $user->getRoles(), true)
            && $article->getAuthorId() === $user->getId();
    }

    private function canDelete(User $user, Article $article): bool
    {
        // Samo admini mogu da brišu
        return in_array('ROLE_ADMIN', $user->getRoles(), true);
    }
}
```

**Korišćenje voter-a u kontroleru:**

```php
#[Route('/articles/{id}', methods: ['DELETE'])]
public function delete(Article $article): JsonResponse
{
    // Symfony poziva sve registrovane voter-e i agregatuje odluku
    $this->denyAccessUnlessGranted(ArticleVoter::DELETE, $article);

    $this->articleRepository->remove($article);

    return new JsonResponse(null, Response::HTTP_NO_CONTENT);
}
```

Ako je korisnik `editor`, Symfony vraća **403 Forbidden**. Ako je korisnik `admin`, članak se briše.

## Obrazac Middleware / Guard

U radnim okvirima bez sistema voter-a, autorizacija se tipično implementira kao **middleware** koji se izvršava pre kontrolera:

```php
final class RequirePermissionMiddleware
{
    public function __construct(
        private readonly RbacAuthorizer $authorizer,
    ) {}

    public function handle(Request $request, string $permission, callable $next): Response
    {
        $user = $request->getAttribute('user');

        if ($user === null) {
            return new JsonResponse(['error' => 'Not authenticated'], 401);
        }

        if (!$this->authorizer->isGranted($user, $permission)) {
            return new JsonResponse(['error' => 'Forbidden'], 403);
        }

        return $next($request);
    }
}

// Registracija rute
$router->delete('/articles/{id}', ArticleController::delete(...))
    ->middleware(new RequirePermissionMiddleware($authorizer), 'article.delete');
```

## Česta Pitanja na Intervjuima

### P: Koja je razlika između 401 i 403?

**O:** **401 Unauthorized** znači da server ne zna ko ste — niste pružili kredencijale ili su nevažeći. **403 Forbidden** znači da server zna ko ste, ali nemate dozvolu za pristup resursu.

```text
Nema tokena     → 401 Unauthorized   (najpre se autentifikujte)
Važeći token, pogrešna uloga → 403 Forbidden (nije vam dozvoljeno)
```

### P: Kada biste odabrali ABAC umesto RBAC?

**O:** Kada jednostavne provere uloga nisu dovoljne. Primeri: "editatori mogu da uređuju samo članke koje su sami napisali," "API pristup je dozvoljen samo sa korporativnog IP opsega," "popusti su dostupni samo korisnicima koji su registrovani pre više od godinu dana." Ova pravila zavise od **atributa** (vlasništvo, IP, datum registracije), a ne samo od uloga.

### P: Kako se upravlja autorizacijom u mikroservisnoj arhitekturi?

**O:** Dva uobičajena pristupa:

1. **Autorizacija na nivou gateway-a** — API gateway validira token i proverava grube dozvole (npr. "da li je ovom korisniku dozvoljeno da poziva servis narudžbina?"). Individualni servisi veruju gateway-u.
2. **Autorizacija na nivou servisa** — svaki servis prima JWT, izvlači tvrdnje (uloge, dozvole) i donosi sopstvene odluke o autorizaciji. Bezbednije, ali zahteva da svaki servis implementira provere.

U praksi, većina timova kombinuje oba pristupa: grube provere na gateway-u, fino granulisane provere unutar svakog servisa.

## Zaključak

Autorizacija određuje koje akcije autentifikovani korisnik može da obavlja. Tri glavna modela — **RBAC** (baziran na ulogama), **ABAC** (baziran na atributima) i **ACL** (po resursu) — nude povećanu granularnost na račun složenosti. Većina web aplikacija počinje sa RBAC-om i dodaje pravila u stilu ABAC-a (poput provera vlasništva) kako zahtevi rastu. Radni okviri poput Symfony-a pružaju ugrađene obrasce (Voters) koji čisto kombinuju oba pristupa.

## Vidi Takođe

- [Kako Funkcioniše Autentikacija](how_authentication_works.sr.md)
- [Kako Funkcioniše JWT Autorizacija](how_jwt_authorization_works.sr.md)
- [OWASP Top 10](owasp_top_10.sr.md) — povređena kontrola pristupa je #1
