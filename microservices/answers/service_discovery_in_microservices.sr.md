## Otkrivanje servisa u mikroservisima

Otkrivanje servisa (service discovery) je kritična komponenta u arhitekturi mikroservisa, koja servisima omogućava
dinamičko otkrivanje i komunikaciju jedni s drugima. Ovo je neophodno za kreiranje fleksibilnog, otpornog i
skalabilnog sistema.

### Dinamička registracija i otkrivanje servisa

Servisi se dinamički registruju u servis za otkrivanje kada postanu dostupni, i odjavljuju se pri gašenju. Drugi
servisi upituju servis za otkrivanje radi pronalaženja dostupnih instanci.

### Otkrivanje na strani klijenta vs. na strani servera

- **Otkrivanje na strani klijenta**: Klijenti su odgovorni za utvrdjivanje lokacija dostupnih instanci servisa i
  load balancing zahteva.
- **Otkrivanje na strani servera**: Server ili gateway je odgovoran za praćenje instanci servisa i rutiranje zahteva
  klijenata.

### Automatski load balancing

Integracija otkrivanja servisa sa load balancingom omogućava automatsku distribuciju zahteva kroz dostupne instance
servisa, optimizujući korišćenje resursa i vreme odgovora.

### Provera zdravlja

Sistemi za otkrivanje servisa često uključuju mehanizme provere zdravlja kako bi se osiguralo da se zahtevi rutiraju
samo na zdrave instance servisa, poboljšavajući ukupnu pouzdanost sistema.

### Primer: Platforma za strimovanje videa

Razmotrimo platformu za strimovanje videa koja koristi mikroservise za svoju arhitekturu:

- **Servis za sadržaj**: Upravlja video sadržajem, metapodacima i URL-ovima za strimovanje.
- **Servis za korisničke profile**: Upravlja korisničkim profilima, preferencijama i istorijom gledanja.
- **Servis za preporuke**: Generiše personalizovane preporuke sadržaja.
- **Servis za autentikaciju**: Upravlja autentikacijom i autorizacijom korisnika.

Sa otkrivanjem servisa na mestu, servis za preporuke može dinamički otkrivati i komunicirati sa servisom za sadržaj
i servisom za korisničke profile radi generisanja preporuka. Ovo omogućava platformi da se prilagodjava promenama,
kao što su deployment novih instanci servisa ili kvar postojećih, osiguravajući neprekidnu i optimizovanu uslugu
korisnicima.
