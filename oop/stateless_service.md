### Non-Stateless Service Example

In this example, the service maintains user session information directly within the service instance. This approach ties
the user's session state to a specific service instance, making it stateful.

```php
class AuthenticationService {
    private $loggedInUsers = []; // Stores user session information

    public function login($username, $password) {
        if ($this->validateUser($username, $password)) {
            $sessionId = $this->createSession($username);
            $this->loggedInUsers[$sessionId] = $username;
            return $sessionId;
        }
        return null;
    }

    public function isLoggedIn($sessionId) {
        return isset($this->loggedInUsers[$sessionId]);
    }

    private function validateUser($username, $password) {
        // Assume this function validates a user's credentials against a database
        return true;
    }

    private function createSession($username) {
        // Generates a unique session ID for the user
        return md5($username . time());
    }
}
```

### Stateless Service Example

In a stateless design, the service does not store any session state. Instead, each request must carry all necessary
information for its processing, including authentication data.

```php
class StatelessAuthenticationService {

    public function authenticateRequest($request) {
        $token = $request->getAuthToken(); // Assume each request carries an auth token
        if ($this->validateToken($token)) {
            // Proceed with request handling
            return true;
        }
        return false;
    }

    private function validateToken($token) {
        // Token validation logic, e.g., checking the token's validity against a database or a token service
        return true;
    }
}
```

In the stateless example, each request must include authentication information (like a token), which is validated with
every request. This design conforms to the stateless nature of HTTP and is more aligned with RESTful principles, making
it a better choice for web services and microservices architectures.
