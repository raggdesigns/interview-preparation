U Domain-Driven Design-u (DDD), Ubiquitous Language je temeljni koncept koji ima za cilj premošćavanje komunikacionog jaza između softverskih programera i domenskih stručnjaka (ne-tehničkih zainteresovanih strana, kao što su poslovni analitičari, vlasnici proizvoda i korisnici). Radi se o kreiranju zajedničkog, deljenog jezika koji koriste svi članovi tima, i kada razgovaraju o sistemu i u samom kodu. Ovo osigurava da termini i fraze nose isto značenje tokom razgovora, dokumentacije i implementacije, smanjujući nesporazume i povećavajući jasnoću.

### Primer: E-commerce aplikacija

Razmotrimo e-commerce aplikaciju da ilustrujemo koncept Ubiquitous Language. U ovom scenariju, domenski stručnjaci i programeri sarađuju na definisanju poslovne domene. Razgovaraju o različitim aspektima e-commerce poslovanja, kao što su upravljanje inventarom, obrada narudžbina i upravljanje kupcima.

Kroz ove razgovore, mogu definisati termine kao što su:

- **Product (Proizvod)**: Artikal koji je naveden za prodaju na e-commerce platformi. Ima properties poput naziva, opisa, cene i količine na stanju.

- **Order (Narudžbina)**: Zahtev koji je kupac napravio za kupovinu jednog ili više proizvoda. Narudžbina uključuje detalje poput datuma narudžbine, adrese za dostavu i statusa narudžbine (npr. pending, shipped, delivered).

- **Customer (Kupac)**: Pojedinac koji kupuje proizvode. Kupac ima atribute poput ID-a kupca, imena, email adrese i adrese za dostavu.

- **Cart (Korpa)**: Kolekcija proizvoda koje kupac namerava da kupi. Korpa može biti ažurirana dodavanjem ili uklanjanjem proizvoda i pretvara se u narudžbinu kada kupac završi kupovinu.

U ovom kontekstu, ovi termini imaju specifična značenja koja razumeju svi članovi tima. Na primer, kada programer radi na "Order" delu sistema, tačno razume šta je narudžbina, koje properties ima i kako se odnosi prema drugim entitetima kao što su proizvodi i kupci.

### Prednosti Ubiquitous Language

1. **Poboljšana komunikacija**: Omogućava jasnu i efikasnu komunikaciju između članova tima, smanjujući rizik od nesporazuma.

2. **Konzistentan rečnik**: Korišćenjem istog jezika u razgovorima, dokumentaciji i kodu, tim osigurava konzistentnost tokom celog projekta.

3. **Bolje usklađivanje**: Pomaže usklađivanju softverskog dizajna sa poslovnom domenom, osiguravajući da softver efikasno zadovoljava poslovne potrebe.

4. **Lakše upoznavanje**: Novi članovi tima mogu brže stići do brzine jer su jezik i koncepti koji se koriste u projektu jasni i dobro definisani.

U praksi, uspostavljanje i održavanje Ubiquitous Language je kontinuiran proces. Razvija se kako tim stiče dublje uvide u domenu i kako se sama aplikacija razvija. Ključno je da domenski stručnjaci i programeri nastave svoju saradnju, rafinirajući jezik kako bi osigurali da tačno odražava domenu u kojoj rade.
