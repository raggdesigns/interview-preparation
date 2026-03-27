## Mikroservisi vs. Monolitna arhitektura

Prilikom razvoja softverskih aplikacija, arhitekte moraju da biraju između dva glavna arhitekturna stila: **Mikroservisi** i **Monolitna arhitektura**. Oba pristupa imaju svoje prednosti i izazove, a izbor uglavnom zavisi od specifičnih potreba projekta.

### Monolitna arhitektura

```plaintext
A Monolithic Architecture is a traditional model of software structure where all the components of the application (interface, business logic, database interactions, etc.) are tightly integrated and deployed as a single unit.
```

#### Primer:

Razmotrimo web aplikaciju razvijenu kao monolit:

````plaintext
- The user interface
- Business logic
- Database access
- Application integration
  ````

Sve je smešteno u jednoj kodnoj bazi i deplojuje se zajedno. Svako ažuriranje ili promena zahteva ponovni deplojment celokupne aplikacije.

### Arhitektura mikroservisa

Arhitektura mikroservisa, s druge strane, deli aplikaciju na manje, nezavisne servise. Svaki servis se izvršava u sopstvenom procesu i komunicira s drugima putem dobro definisanog interfejsa koristeći lagane mehanizme, tipično HTTP-zasnovane API-je.

#### Primer:

Zamislimo platformu za e-trgovinu izgrađenu korišćenjem mikroservisa:

````plaintext
- User Service: Handles user registration, authentication, and profile management.
- Product Service: Manages product listings, descriptions, and stock levels.
- Order Service: Takes care of order placements, tracking, and history.
- Payment Service: Processes payments, refunds, and billing.
  ````

Svaki servis se razvija, deplojuje i skalira nezavisno, što omogućava fleksibilnije razvojne i deplojment prakse.

### Ključne razlike:

- **Deplojment**: U monolitnoj arhitekturi, svaka promena zahteva ponovni deplojment celokupne aplikacije, dok mikroservisi omogućavaju nezavisan deplojment servisa.
- **Skalabilnost**: Mikroservisi se mogu individualno skalirati, što pruža efikasnije korišćenje resursa u poredenju sa skaliranjem celokupne monolitne aplikacije.
- **Razvoj i održavanje**: Mikroservise mogu razvijati i održavati zasebni timovi, potencijalno koristeći različite tehnološke stekove najpogodnije za njihove specifične funkcionalnosti. Monolitne aplikacije, mada su inicijalno jednostavnije za razvoj, mogu postati teške za održavanje kako rastu.
- **Izolacija grešaka**: Greške u arhitekturi mikroservisa su izolovane na zahvaćeni servis, smanjujući rizik od sistema-opsežnog ispada. Nasuprot tome, greška u monolitnoj aplikaciji može srušiti ceo sistem.

Izbor između mikroservisa i monolitne arhitekture zavisi od raznih faktora, uključujući veličinu i opseg projekta, organizacionu kulturu i specifične tehničke zahteve. Mikroservisi nude veću fleksibilnost i skalabilnost, čineći ih privlačnim izborom za složene, promenljive aplikacije. Monolitna arhitektura, međutim, može biti jednostavnija za deplojment i upravljanje kod manjih, manje složenih aplikacija.
