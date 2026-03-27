## Obrasci Komunikacije Microservices

Efikasna komunikacija između microservices je od vitalnog značaja za osiguranje koherentnog rada unutar distribuiranog sistema. Ovo uključuje odabir odgovarajućih obrazaca komunikacije na osnovu prirode interakcije i zahteva svakog servisa.

### Sinhrona vs. Asinhrona Komunikacija

- **Sinhrona Komunikacija**: Servisi komuniciraju u realnom vremenu, sa pozivaocem koji čeka odgovor. RESTful API-ji preko HTTP/S su uobičajeni pristup, pogodan za direktne interakcije između servisa.
- **Asinhrona Komunikacija**: Servisi komuniciraju bez čekanja na odgovor, često kroz event stream-ove ili redove poruka. Ovaj obrazac je idealan za dekovane, event-driven arhitekture.

### RESTful API-ji

RESTful API-ji su popularan izbor za sinhronoj komunikaciji, nudeći jednostavnost, bezstanjsku prirodu i poznat HTTP-baziran model interakcije.

### Sistemi za Poruke

Sistemi za poruke poput RabbitMQ, Apache Kafka i Amazon SQS pružaju robusnu infrastrukturu za asinhronoj komunikaciji, podržavajući obrasce poput event sourcing-a i publish-subscribe.

### Service Mesh

Service mesh apstrahuje kompleksnosti komunikacije, pružajući namenski infrastrukturni sloj za upravljanje komunikacijom između servisa, olakšavajući funkcionalnosti poput load balancing-a, service discovery-ja i bezbednih komunikacija.

### Izazovi

Komunikacija microservices uvodi izazove poput mrežnog kašnjenja, overhead-a serializacije/deserializacije poruka i osiguravanja konzistentnosti podataka između servisa.

### Strategije

- **Korišćenje API Gateway-a** za upravljanje dolaznim zahtevima, rutiranjem do odgovarajućih microservices.
- **Implementacija Backpressure** mehanizama za sprečavanje preopterećenja sistema tokom vršnog saobraćaja.
- **Usvajanje Circuit Breaker-a** za graciozan rad u slučaju kvarova i sprečavanje kaskadnih kvarova.

### Primer: Platforma za Online Maloprodaju

Razmotrimo Platformu za Online Maloprodaju koja koristi različite obrasce komunikacije:

- **Catalog Service**: Pruža informacije o proizvodima korisnicima.
- **Order Service**: Upravlja procesom naručivanja.
- **Inventory Service**: Prati nivoe zaliha.
- **Shipping Service**: Obrađuje logistiku dostave porudžbina.

Catalog Service izlaže RESTful API za sinhrone zahteve od front end-a. Order i Inventory servisi komuniciraju asinhrono koristeći redove poruka kako bi dekovaili proces naručivanja od upravljanja inventarom, poboljšavajući otpornost i skalabilnost. Service mesh osigurava bezbednu i efikasnu komunikaciju između servisa unutar platforme, dok API Gateway rutira zahteve korisnika do odgovarajućih servisa.
