## Skaliranje mikroservisa

Skaliranje mikroservisa je neophodno za prilagodjavanje promenljivim opterećenjima i osiguravanje responzivnosti i dostupnosti aplikacije. Efikasne strategije skaliranja su kritične u arhitekturi mikroservisa zbog njene distribuirane prirode.

### Horizontalno skaliranje

Povećavati ili smanjivati broj instanci servisa radi podudaranja sa potražnjom. Ova strategija je dobro prilagodjena mikroservisima, omogućavajući skaliranje specifičnih delova aplikacije po potrebi bez uticaja na ceo sistem.

### Vertikalno skaliranje

Podrazumeva povećanje resursa (CPU, RAM) postojećih instanci servisa radi povećanja kapaciteta. Ovaj pristup ima ograničenja i rjedje se koristi u mikroservisima u poredenju sa horizontalnim skaliranjem.

### Auto-skaliranje

Automatski prilagodjavati broj instanci ili resursa na osnovu potražnje u realnom vremenu. Cloud platforme nude mogućnosti auto-skaliranja koje se mogu konfigurisati na osnovu specifičnih metrika kao što su iskorišćenost CPU-a ili stope zahteva.

### Load Balancing

Distribuira dolazne zahteve kroz više instanci servisa radi osiguravanja ravnomerne distribucije opterećenja, maksimiziranja propusnosti i smanjenja kašnjenja.

### Particionisanje

Deli podatke i radno opterećenje u zasebne segmente kojima mogu upravljati odvojene instance ili grupe servisa, što se u bazama podataka često naziva sharding.

### Keširanje

Poboljšava vreme odgovora i smanjuje opterećenje na instancee servisa privremenim čuvanjem kopija često pristupanih podataka.

### Izazovi

- **Otkrivanje servisa**: Osiguravanje da nove instance brzo budu otkrivene od strane potrošača.
- **Upravljanje stanjem**: Upravljanje stanjem kroz distribuirane instance, posebno za servise sa stanjem.
- **Konzistentno heširanje**: Implementacija efikasnih mehanizama rutiranja koji minimizuju smetnje tokom operacija skaliranja.

### Strategije

- **Implementirati elastični load balancing**: Koristiti elastične load balancere koji se automatski prilagodjuju promenama u saobraćaju i broju instanci.
- **Bezstanjski dizajn**: Dizajnirati servise da budu bezstanjski gde je moguće, pojednostavljujući skaliranje i deplojment.
- **Distribuirano keširanje**: Koristiti distribuirana rešenja za keširanje radi nezavisnog skaliranja keširanja od instanci servisa.

### Primer: Platforma društvenih mreža

Razmotrimo platformu društvenih mreža koja se u velikoj meri oslanja na mikroservise za upravljanje različitim aspektima svog poslovanja:

- **Servis za isporuku sadržaja**: Efikasno distribuira sadržaj koji kreiraju korisnici.
- **Servis za aktivnosti korisnika**: Prati interakcije i ponašanje korisnika.
- **Servis za obaveštenja**: Šalje obaveštenja na osnovu aktivnosti i preferencija korisnika.

Platforma koristi horizontalno skaliranje i auto-skaliranje za servise za isporuku sadržaja i aktivnosti korisnika radi upravljanja skokovima u korisničkom saobraćaju, posebno tokom dogadjaja sa visokim angažovanjem. Load balancing osigurava ravnomjernu distribuciju zahteva, poboljšavajući korisničko iskustvo. Keširanje se intenzivno koristi u servisu za isporuku sadržaja radi smanjenja kašnjenja i opterećenja pozadinskog sistema, dok particionisanje pomaže u efikasnom upravljanju velikim skupovima podataka servisa za aktivnosti korisnika.
