### Slojevi u Domain-Driven Design-u (DDD)

U Domain-Driven Design-u (DDD), arhitektura softverske aplikacije je tipično organizovana u različite slojeve. Ova slojevita arhitektura promoviše razdvajanje odgovornosti, čineći sistem lakšim za upravljanje i prilagodljiv promenama poslovnih zahteva ili tehnologije.

### Osnovni slojevi

1. **Prezentacioni sloj**: Ovaj spoljni sloj je odgovoran za interakciju sa korisnikom. Prikazuje informacije i interpretira korisničke komande.
2. **Aplikacioni sloj**: Ovaj sloj koordinira aktivnosti aplikacije. Ne sadrži poslovnu logiku ili stanje, ali koordinira zadatke i delegira posao saradnjama domenskih objekata u sledećem sloju.
3. **Domenski sloj**: Srce poslovnog softvera. Ovde su implementirani poslovni koncepti, poslovna logika i poslovna pravila. Sačinjen je od entiteta, value objects, fabrika, agregata i domain events.
4. **Infrastrukturni sloj**: Pruža tehničke kapacitete koji podržavaju druge slojeve. Ovo uključuje mehanizme persistencije, sisteme fajlova, mrežni pristup, pristup bazi podataka itd.

### Primer pogrešne odluke

Pogrešna odluka može nastati kada poslovna logika, koja bi trebala biti u **Domenskom sloju**, bude implementirana u **Aplikacionom sloju** ili čak u **Prezentacionom sloju**. Ovo zamućuje razdvajanje odgovornosti, čineći sistem težim za održavanje i razvoj.

Na primer, ako validaciona logika koja pripada domenskom modelu (poput osiguranja da ukupan iznos narudžbine nije negativan) bude smeštena u aplikacioni sloj, to dovodi do scenarija gde su osnovna poslovna pravila rasuta po sistemu, smanjujući koheziju sistema i čineći domensku logiku težom za razumevanje i održavanje.

### Korektivna akcija

Korektivna akcija bi uključivala refactoring pogrešno postavljene poslovne logike nazad u domenski sloj. U našem primeru, to znači premeštanje validacione logike za ukupan iznos narudžbine u odgovarajući domenski servis ili entitet unutar **Domenskog sloja**. Ovo osigurava da su poslovna pravila enkapsulirana unutar domenskog modela, gde i pripadaju, poboljšavajući održivost i razumljivost koda.

### Zaključak

Pridržavanje slojevite arhitekture u DDD-u pomaže da se osigura da se svaka komponenta sistema fokusira na svoju namenjenu ulogu. Poboljšava održivost i fleksibilnost sistema, olakšavajući prilagođavanje novim zahtevima ili tehnologijama uz očuvanje osnovne domenke logike netaknute i jasno definisane.
