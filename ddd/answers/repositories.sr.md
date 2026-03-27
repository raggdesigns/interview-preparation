### Repozitorijumi u DDD-u

Repozitorijumi deluju kao kolekcija domenskih entiteta sa kojima domenka logika može da razgovara. Pružaju apstrakciju nad slojem podataka, nudeći način pristupa domenskim entitetima bez potrebe da se znaju detalji osnovne tehnologije persistencije (kao što je ORM, baza podataka ili eksterni servis). Ova enkapsulacija podržava princip neznanja persistencije unutar domenskog modela.

#### Odgovornosti uključuju:

- Preuzimanje domenskih entiteta koristeći složene upite.
- Dodavanje i uklanjanje entiteta iz skladišta persistencije.
- Skrivanje detalja mehanizma pristupa podacima.

#### Primer interfejsa repozitorijuma:

U sistemu za blogovanje, možda imaš `PostRepository` interfejs za pristup blog postovima:

```
interface PostRepository {
public function findById(PostId $postId): Post;
public function save(Post $post): void;
public function remove(Post $post): void;
// Ostale metode za preuzimanje postova...
}
```

### Primer pogrešne odluke

Pogrešna odluka u implementaciji repozitorijuma može uključivati direktno ugrađivanje logike pristupa podacima unutar domenskih entiteta ili servisa, čime se narušava razdvajanje odgovornosti. Na primer, ako domenski entitet kao što je `Post` direktno vrši upit baze podataka za persistenciju ili preuzimanje:

```
class Post {
// Domenka logika...

    public static function findById($postId) {
        // Direktni kod za pristup bazi podataka ovde...
    }
}
```

Ovaj pristup čvrsto spaja domenski model sa mehanizmom pristupa podacima, otežavajući testiranje, održavanje i razvoj domenke logike nezavisno od briga persistencije.

### Korektivna akcija

Korektivna akcija uključuje refaktorisanje logike pristupa podacima iz domenskih entiteta ili servisa u namenske klase repozitorijuma. Domenski entiteti treba da se fokusiraju na poslovnu logiku, dok repozitorijumi obrađuju sve operacije persistencije:

1. **Definiši interfejs repozitorijuma** koji odražava operacije nalik kolekcijama koje domenski model treba za interakciju sa domenskim entitetima.
2. **Implementiraj repozitorijum** u infrastrukturnom sloju, gde koristi specifičan mehanizam pristupa podacima (ORM, SQL, itd.) za ispunjavanje operacija repozitorijuma.
3. **Injektuj implementaciju repozitorijuma** u domenske servise ili aplikacione servise koji trebaju da interaguju sa domenskim entitetima, održavajući razdvajanje između domenke logike i logike pristupa podacima.

#### Nakon refaktorisanja:

Klasa `Post` se fokusira isključivo na domenku logiku, a posebni `PostRepository` obrađuje sav pristup podacima, pridržavajući se interfejsa repozitorijuma definisanog gore.

Ovaj pristup dekovupla domenski model od detalja persistencije, usklađujući se sa DDD principima i povećavajući održivost i testabilnost aplikacije.
