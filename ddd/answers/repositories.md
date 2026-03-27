### Repositories in DDD

Repositories act as a collection of domain entities to which the domain logic can speak. They provide an abstraction
over the data layer, offering a way to access domain entities without needing to know the details of the underlying
persistence technology (like an ORM, a database, or an external service). This encapsulation supports the principle of
persistence ignorance within the domain model.

#### Responsibilities include

- Retrieving domain entities using complex queries.
- Adding and removing entities from the persistence store.
- Hiding the details of the data access mechanism.

#### Example of a Repository Interface

In a blogging system, you might have a `PostRepository` interface for accessing blog posts:

```text
interface PostRepository {
public function findById(PostId $postId): Post;
public function save(Post $post): void;
public function remove(Post $post): void;
// Other methods for retrieving posts...
}
```

### Incorrect Decision Example

An incorrect decision in implementing repositories could involve directly embedding data access logic within domain
entities or services, thus violating the separation of concerns. For example, having a domain entity like `Post`
directly query the database for persistence or retrieval:

```text
class Post {
// Domain logic...

    public static function findById($postId) {
        // Direct database access code here...
    }
}
```

This approach tightly couples the domain model to the data access mechanism, making it harder to test, maintain, and
evolve the domain logic independently from persistence concerns.

### Corrective Action

The corrective action involves refactoring data access logic out of the domain entities or services and into dedicated
repository classes. The domain entities should focus on business logic, with repositories handling all persistence
operations:

1. **Define a Repository Interface** that reflects the collection-like operations needed by the domain model to interact
   with domain entities.
2. **Implement the Repository** in the infrastructure layer, where it uses the specific data access mechanism (ORM, SQL,
   etc.) to fulfill the repository operations.
3. **Inject the Repository Implementation** into the domain services or application services that need to interact with
   domain entities, maintaining separation between the domain logic and data access logic.

#### After Refactoring

The `Post` class focuses solely on domain logic, and a separate `PostRepository` handles all data access, adhering to
the repository interface defined above.

This approach decouples the domain model from persistence details, aligning with DDD principles and enhancing the
maintainability and testability of the application.
