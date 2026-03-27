### Primer servisa koji nije bez-stanja (Non-Stateless)

U ovom primeru, servis čuva informacije o korisničkoj sesiji direktno unutar instance servisa. Ovaj pristup vezuje stanje korisničke sesije za specifičnu instancu servisa, čineći je stati-punom.

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

### Primer servisa bez-stanja (Stateless)

U dizajnu bez-stanja, servis ne čuva nikakvo stanje sesije. Umesto toga, svaki zahtev mora nositi sve potrebne informacije za obradu, uključujući podatke o autentikaciji.

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

U primeru bez-stanja, svaki zahtev mora uključivati informacije o autentikaciji (kao što je token), koji se validira sa svakim zahtevom. Ovaj dizajn se poklapa sa prirodom HTTP protokola bez-stanja i više je u skladu sa RESTful principima, čineći ga boljim izborom za veb servise i arhitekture mikro-servisa.
