Invarijansa, kovarijansa i kontravarijansa su termini koji opisuju kako se tip objekata može zameniti u odnosu na njihove roditeljske ili dečje tipove, posebno u kontekstu generika, povratnih tipova i prekoračenja metoda. Ovi koncepti su ključni u teoriji tipova i pomažu u razumevanju kako tipski sistemi funkcionišu u programskim jezicima.

### Invarijansa (Invariance)

Invarijansa znači da možete koristiti tip samo tačno onako kako je deklarisan; nije dozvoljen ni podtip ni nadtip. Invarijantni tip se ne menja kada se menja njegov generički parametar.

**Primer**:
U PHP-u, tipovi niza su invarijantni. Ako imate funkciju koja prihvata niz `User` objekata, ne možete proslediti niz `AdminUser` objekata, čak i ako `AdminUser` nasledi `User`.

### Kovarijansa (Covariance)

Kovarijansa dozvoljava metodi da vrati tip koji je izvedeniji od tipa metode koju prekoračuje. Slično, kovarijantni generik dozvoljava zamenu podtipa za nadtip.

**Primer**:
U PHP-u (od PHP 7.4), povratni tipovi mogu biti kovarijantni. Ako metoda roditeljske klase vraća `User`, metoda dečje klase može vratiti `AdminUser`, podklasu od `User`.

```php
class User {}
class AdminUser extends User {}

class UserRepository {
    public function findUser(): User {}
}

class AdminUserRepository extends UserRepository {
    public function findUser(): AdminUser {}
}
```

### Kontravarijansa (Contravariance)

Kontravarijansa dozvoljava metodi da prihvati parametre manje izvedenog tipa od tipa metode koju prekoračuje. Slično, kontravarijantni generik dozvoljava zamenu nadtipa za podtip.

**Primer**:
U PHP-u (od PHP 7.4), argumenti metode mogu biti kontravarijantni. Ako metoda roditeljske klase prihvata `User`, metoda dečje klase može prihvatiti `Person`, nadklasu od `User`.

```php
class Person {}
class User extends Person {}

class Action {
    public function addUser(User $user) {}
}

class UserAction extends Action {
    public function addUser(Person $person) {}
}
```

### Zaključak

Razumevanje invarijanse, kovarijanse i kontravarijanse je neophodno za ispravno korišćenje tipskih sistema u programiranju, posebno u jezicima koji podržavaju strogo tipiziranje i generičko programiranje. Ovi koncepti osiguravaju bezbednost tipova istovremeno dozvoljavajući fleksibilnost u načinu na koji klase i metode mogu biti proširene ili prekoračene.
