## Decentralizovano Upravljanje Podacima

Decentralizovano upravljanje podacima je temeljni princip microservices arhitektura, koji promoviše autonomiju podataka i enkapsulaciju na nivou servisa. Ovaj pristup utiče na to kako se podaci čuvaju, pristupa im i njima upravlja između servisa.

### Baza Podataka po Servisu

Svaki microservice upravlja sopstvenom bazom podataka, ili skupom baza podataka, koja nije direktno dostupna drugim servisima. Ovo razdvajanje osigurava da je microservice jedini izvor promena za svoje podatke, čuvajući integritet podataka i nezavisnost servisa.

### Dupliranje Podataka

Određeno dupliranje podataka između servisa je prihvatljivo i često neophodno za postizanje autonomije podataka. Event-driven arhitekture mogu pomoći u sinhronizaciji dupliranih podataka emitovanjem promena putem događaja.

### Event Sourcing i CQRS

Event sourcing uključuje čuvanje promena stanja kao sekvence događaja, koji se zatim mogu reprodukovati za rekonstrukciju stanja. U kombinaciji sa Command Query Responsibility Segregation (CQRS), koji odvaja operacije čitanja i pisanja, ovi obrasci mogu efikasno upravljati decentralizovanim podacima u microservices arhitekturi.

### Izazovi

Decentralizovano upravljanje podacima uvodi izazove poput održavanja konzistentnosti podataka, implementacije složenih transakcija i upravljanja distribuiranim šemama podataka.

### Strategije

- **Implementacija transactional outbox obrazaca** i **SAGA-a** za upravljanje distribuiranim transakcijama.
- **Korišćenje API kompozicije** za agregaciju podataka iz više servisa za složene upite.
- **Usvajanje schema registry-a** za upravljanje i razvijanje deljenih šema podataka između servisa.

### Primer: Aplikacija za Deljenje Prevoza

Razmotrimo Aplikaciju za Deljenje Prevoza koja se sastoji od microservices:

- **Rider Service**: Upravlja nalozima i profilnim informacijama putnika.
- **Driver Service**: Obrađuje registraciju vozača, profile i ažuriranja statusa.
- **Trip Service**: Upravlja rezervacijom, praćenjem i istorijom putovanja.
- **Payment Service**: Obrađuje plaćanja i naplatu za vožnje.

U ovoj aplikaciji, svaki servis poseduje podatke vezane za putnike, vozače, putovanja i plaćanja. Trip Service, na primer, može da čuva ID-ove vozača i putnika, ali detaljni profili se upravljaju od strane odgovarajućih Driver i Rider servisa. Promene u profilu putnika se objavljuju kao događaji od strane Rider Service-a, koje Trip Service može konzumirati za ažuriranje svog pogleda na podatke o putnicima. Event sourcing i CQRS omogućavaju Trip Service-u da efikasno upravlja stanjima i upitima za putovanja, uprkos decentralizovanom modelu podataka.
