### MySQL Engine-i

MySQL podržava više storage engine-a, svaki dizajniran za specifične slučajeve upotrebe i pruža različite karakteristike performansi.

#### Pregled MySQL Engine-a

- **InnoDB**: Podrazumevani engine bezbedan za transakcije sa podrškom za strane ključeve. Optimizovan za performanse i pouzdanost.
- **MyISAM**: Stariji storage engine, optimizovan za radna opterećenja sa intenzivnim čitanjem, ali ne podržava transakcije.
- **Memory**: Čuva podatke u RAM-u, nudeći veoma brze vremene pristupa na račun nestabilnosti.
- **Archive**: Optimizovan za čuvanje velikih količina arhivskih ili istorijskih podataka.
- **Ostali**: Blackhole, CSV, Merge i drugi, svaki sa specijalizovanim upotrebama.

### MyISAM vs InnoDB

- **Transakcije**: InnoDB podržava transakcije (COMMIT i ROLLBACK), dok MyISAM ne podržava.
- **Zaključavanje tabele vs zaključavanje reda**: MyISAM zaključava celu tabelu što može biti usko grlo. InnoDB podržava zaključavanje na nivou reda što je efikasnije za baze podataka sa intenzivnim pisanjem.
- **Strani ključevi**: InnoDB podržava strane ključeve i referencijalnu integritet, dok MyISAM ne podržava.
- **Oporavak od pada**: InnoDB pruža bolji oporavak od pada u poređenju sa MyISAM-om.
- **Konkurentnost**: InnoDB nudi bolju konkurentnost jer dozvoljava višestruke čitaoce i pisce da pristupaju istim podacima istovremeno.
