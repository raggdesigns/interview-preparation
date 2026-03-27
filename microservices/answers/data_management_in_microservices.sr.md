## Upravljanje Podacima u Microservices

Efikasno upravljanje podacima je ključno u microservices arhitekturi, s obzirom da je svaki microservice odgovoran za sopstvenu bazu podataka kako bi se osiguralo labavo spajanje i autonomija servisa. Ovaj pristup predstavlja jedinstvene izazove i mogućnosti za upravljanje podacima između distribuiranih servisa.

### Baza Podataka po Servisu

Svaki microservice upravlja sopstvenom šemom baze podataka ili bazom podataka, koja nije direktno dostupna drugim servisima. Ovaj obrazac poboljšava nezavisnost servisa, ali zahteva pažljivo razmatranje konzistentnosti podataka između servisa.

### API za Deljenje Podataka

Servisi komuniciraju međusobno koristeći API-je za traženje podataka. Ovo osigurava enkapsulaciju podataka i autonomiju servisa, ali uvodi kompleksnost u agregaciji i upravljanju podacima.

### Upravljanje Transakcijama

Implementacija transakcija koje obuhvataju više servisa je složena i često se obrađuje kroz obrasce poput Saga, koji upravlja distribuiranim transakcijama bez čvrstog spajanja servisa.

### Konzistentnost Podataka

Eventualna konzistentnost je uobičajeno prihvaćena u microservices arhitekturama, sa ažuriranjima koja se propagiraju putem događaja. Ovaj pristup zahteva prelaz sa tradicionalnih ACID modela transakcija na modele eventualne konzistentnosti kako bi se osigurala pouzdanost i konzistentnost sistema.

### Primer: Sistem Online Rezervacija

Razmotrimo sistem online rezervacija izgrađen sa microservices:

- **Reservation Service**: Upravlja rezervacijama.
- **Payment Service**: Obrađuje procesiranje plaćanja.
- **Customer Service**: Upravlja profilima i preferencijama korisnika.
- **Notification Service**: Šalje potvrde rezervacija i podsetnika korisnicima.

U ovom sistemu, Reservation Service možda mora da komunicira sa Payment Service-om radi obrade plaćanja kao deo rezervacije. Umesto direktnog pristupa bazi podataka, koristiće API Payment Service-a za pokretanje procesa plaćanja. Ako je plaćanje uspešno, Reservation Service može nastaviti sa potvrdom rezervacije i može objaviti događaj koji ukazuje na uspešnu rezervaciju, koji Notification Service sluša kako bi poslao potvrdni email korisniku.

Ovaj pristup omogućava svakom servisu da ostane autonoman, upravljajući sopstvenim podacima, dok i dalje omogućava komunikaciju između servisa i osiguravajući ukupnu konzistentnost podataka i transakcioni integritet sistema.
