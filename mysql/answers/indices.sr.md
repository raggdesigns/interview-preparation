### MySQL i indeksi baze podataka

U MySQL-u, indeksi igraju ključnu ulogu u optimizovanju upita baze podataka smanjujući količinu podataka koje server mora skenirati da ispuni upit. Indeksi su u suštini pokazivači na podatke u tabeli i mogu drastično poboljšati performanse operacija preuzimanja podataka.

### Tipovi indeksa u MySQL-u

MySQL podržava nekoliko tipova indeksa:

- **Primary Key Index**: Automatski kreira se na primarnom ključu tabele za sprovođenje jedinstvenosti.
- **Unique Index**: Osigurava da su sve vrednosti u koloni jedinstvene.
- **Index (Sekundarni indeks)**: Koristi se za poboljšanje brzine preuzimanja podataka, ali ne sprovodi jedinstvenost.
- **Fulltext Index**: Dizajniran za pretrage punog teksta.
- **Spatial Index**: Koristi se za prostorne podatke kojima treba pristupiti upitima o prostornim odnosima.

### Kako se indeksi čuvaju u bazi podataka

Indeksi u MySQL-u se tipično čuvaju u tipu strukture podataka poznatoj kao B-tree, koja omogućava brze pretrage, umetanja i brisanja. Listovi B-tree-a sadrže indeksirane vrednosti i pokazivače na stvarne zapise u bazi podataka.

### Algoritmička složenost

- **Sa indeksom**: Pretraga podataka koristeći indeks je generalno O(log n) operacija, gde je n broj unosa u indeksu. To je zato što B-tree struktura dozvoljava bazi podataka da prepolovi prostor pretrage sa svakim korakom.
- **Bez indeksa**: Pretraga bez indeksa može biti veoma neefikasna, često zahtevajući puno skeniranje tabele, što je O(n) operacija, gde je n broj zapisa u tabeli.

### Kompozitni indeksi

Kompozitni indeks uključuje dve ili više kolona u definiciji indeksa, što može biti korisno za performanse upita kada uslovi uključuju više kolona. Redosled kolona u kompozitnom indeksu je ključan, jer utiče na efikasnost indeksa.

### Pretraga po nekoliko indeksa

MySQL ponekad može koristiti više indeksa zajedno kroz proces koji se zove optimizacija spajanja indeksa. U ovom procesu, MySQL koristi više jednoklomnskih indeksa zajedno da proceni upit.

### Problemi korišćenja kompozitnih indeksa

Iako kompozitni indeksi mogu biti moćni, postoji nekoliko stvari koje treba razmotriti:

- **Redosled kolona**: Redosled kolona u kompozitnom indeksu je kritičan. Indeks će se koristiti efikasno samo ako uslovi upita počinju prefiksom indeksa.
- **Overhead**: Održavanje indeksa, posebno kompozitnih, može dodati overhead operacijama izmene podataka kao što su INSERT, UPDATE i DELETE, jer se strukture indeksa moraju ažurirati.
- **Selektivnost**: Indeksi su manje efikasni ako prva kolona u indeksu ima nisku selektivnost, što znači da ne identifikuje zapise dobro na jedinstven način.

### Pogrešni slučajevi i problemi

- **Ignorisanje krajnjeg levog prefiksa**: Ako upit ne koristi krajnji levi prefiks kompozitnog indeksa, indeks se možda neće koristiti, što dovodi do suboptimalnih performansi upita.
- **Preterana upotreba**: Kreiranje previše indeksa, posebno nepotrebnih kompozitnih indeksa, može zauzeti značajan prostor na disku i usporiti operacije pisanja.
- **Nerazmatranje obrazaca upita**: Indeksi bi trebali biti dizajnirani na osnovu najčešćih i najkritičnijih obrazaca upita. Indeksi koji ne odgovaraju načinu pristupa podacima su često uzaludan resurs.

### Zaključak

Pravilna upotreba indeksa u MySQL-u, uključujući razumevanje kada koristiti kompozitne indekse i kako optimizovati njihov redosled, može značajno poboljšati performanse upita. Međutim, indeksi dolaze i sa kompromisima u smislu overhead-a skladišta i održavanja, tako da njihova upotreba treba biti dobro planirana i testirana na osnovu stvarnih obrazaca upita i izmene podataka.
