SOA (Service-Oriented Architecture — Servisno Orijentisana Arhitektura) je arhitekturalni pristup gde je aplikacija izgrađena kao kolekcija **servisa** koji komuniciraju putem mreže. Svaki servis je samoobuhvatna jedinica koja obavlja specifičnu poslovnu funkciju i može je koristiti drugi servisi.

### Šta Je Servis u SOA

Servis u SOA ima četiri ključne karakteristike:

1. **Samoobuhvatan** — ima sopstvenu logiku i može raditi nezavisno
2. **Ima jasan ugovor** — definiše koje operacije nudi (putem WSDL, API dokumentacije, itd.)
3. **Labavo spregnuti** — može se promeniti bez uticaja na druge servise
4. **Višekratno upotrebljiv** — više aplikacija može koristiti isti servis

```
┌──────────────────────────────────────────────────┐
│                    Preduzeće                      │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │  Servis  │  │  Servis  │  │  Servis      │   │
│  │ Narudžb. │  │ Plaćanja │  │ Inventara    │   │
│  └────┬─────┘  └─────┬────┘  └──────┬───────┘   │
│       │               │              │           │
│  ─────┴───────────────┴──────────────┴───────    │
│              Enterprise Service Bus (ESB)         │
│  ────────────────────────────────────────────     │
│       │               │              │           │
│  ┌────┴─────┐  ┌──────┴────┐  ┌─────┴───────┐   │
│  │  Servis  │  │  Servis   │  │  Servis      │   │
│  │Korisnika │  │ Dostave   │  │ Izveštavanja │   │
│  └──────────┘  └───────────┘  └──────────────┘   │
└──────────────────────────────────────────────────┘
```

### SOA vs Monolit

U monolitu, sve funkcionalnosti žive u jednoj velikoj aplikaciji:

```
Monolit:
┌──────────────────────────────────────┐
│  Narudžbine + Plaćanja + Korisnici +  │
│  Inventar + Dostava + Izveštaji       │
│  (jedna baza podataka, jedno deploy)  │
└──────────────────────────────────────┘

SOA:
┌──────────┐  ┌──────────┐  ┌──────────┐
│Narudžbine│  │ Plaćanja │  │Korisnici │
│ (svoja   │  │ (svoja   │  │ (svoja   │
│  baza)   │  │  baza)   │  │  baza)   │
└──────────┘  └──────────┘  └──────────┘
     Svaki servis može biti deploy-ovan nezavisno
```

### SOA vs Mikroservisi

SOA i mikroservisi su povezani, ali različiti:

| Funkcionalnost | SOA | Mikroservisi |
|---------------|-----|--------------|
| Veličina servisa | Veći, krupnijeg zrna | Mali, sitnijeg zrna |
| Komunikacija | ESB (Enterprise Service Bus) | Direktni HTTP/gRPC, redovi poruka |
| Podaci | Mogu deliti baze podataka | Svaki servis poseduje svoju bazu |
| Protokol | Često SOAP/XML | Obično REST/JSON ili gRPC |
| Upravljanje | Centralizovano (ESB orkestrira) | Decentralizovano |
| Ponovna upotreba | Servisi su dizajnirani za ponovnu upotrebu | Servisi su dizajnirani za nezavisnost |
| Tipičan kontekst | Preduzeća (banke, telekomunikacije) | Startapi, moderne web aplikacije |

Razmislite ovako:
- **SOA** = "Hajde da organizujemo naše poslovne sisteme u višekratno upotrebljive servise povezane kroz centralni bus"
- **Mikroservisi** = "Hajde da razlomimo naš aplikaciju na sitne, nezavisne servise koji svaki rade jednu stvar"

### Enterprise Service Bus (ESB)

ESB je centralna komponenta u SOA koja obrađuje:
- **Rutiranje poruka** — usmeravanje zahteva na pravi servis
- **Transformaciju protokola** — konverzija SOAP-a u REST, XML-a u JSON
- **Obogaćivanje poruka** — dodavanje podataka iz drugih servisa
- **Obradu grešaka** — ponovni pokušaji, redovi mrtvih pisama
- **Orkestraciju** — koordinacija višekoračnih poslovnih procesa

```
Klijentski Zahtev: "Kreiraj Narudžbinu"
       │
       ▼
   ┌───────┐
   │  ESB  │ ─── 1. Validiraj korisnika → Servis Korisnika
   │       │ ─── 2. Proveri zalihe → Servis Inventara
   │       │ ─── 3. Obradi plaćanje → Servis Plaćanja
   │       │ ─── 4. Pošalji narudžbinu → Servis Dostave
   └───┬───┘
       │
       ▼
  Odgovor: "Narudžbina Kreirana"
```

U mikroservisima, nema ESB-a. Servisi komuniciraju direktno ili putem laganih brokera poruka kao što je RabbitMQ.

### Principi SOA

1. **Standardizovani ugovori** — svaki servis objavljuje jasan interfejs (WSDL, OpenAPI)
2. **Labava spregnutost** — servisi zavise od ugovora, ne od implementacija
3. **Apstrakcija** — interni detalji su skriveni
4. **Višekratna upotrebljivost** — servisi su dizajnirani da ih koriste višestruki potrošači
5. **Kompozabilnost** — servisi se mogu kombinovati za kreiranje novih poslovnih procesa
6. **Bezdržavnost** — servisi ne bi trebalo da čuvaju klijentsko stanje između poziva
7. **Otkrivost** — servisi se mogu pronaći u registru servisa

### Primer SOA iz Stvarnog Sveta

Banka koristi SOA za povezivanje različitih sistema:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Mobilna App │     │  Web Portal │     │ ATM Sistem  │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌──────┴──────┐
                    │     ESB     │
                    └──────┬──────┘
                           │
       ┌───────────────────┼───────────────────┐
       │                   │                   │
┌──────┴──────┐     ┌──────┴──────┐     ┌──────┴──────┐
│  Servis     │     │  Servis     │     │  Detekcija  │
│  Računa     │     │  Transfera  │     │  Prevara    │
│  (SOAP)     │     │  (SOAP)     │     │  (SOAP)     │
└─────────────┘     └─────────────┘     └─────────────┘
```

Sve tri klijentske aplikacije (mobilna, web, bankomat) koriste iste servise. ESB obrađuje konverziju protokola — mobilna aplikacija šalje REST zahteve, a ESB ih konvertuje u SOAP za backend servise.

### SOA u PHP Kontekstu

Dok PHP aplikacije retko koriste puni ESB-style SOA, koncepti se pojavljuju u modernom PHP-u:

```php
// SOA-like pristup u Symfony-ju
// Svaki ograničeni kontekst je "servis" sa jasnim API-jem

// Servis Narudžbina — izlaže endpoint-e za upravljanje narudžbinama
#[Route('/api/orders')]
class OrderController extends AbstractController
{
    #[Route('', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        // Poziva druge servise putem HTTP-a
        $userValid = $this->userServiceClient->validateUser($userId);
        $stockAvailable = $this->inventoryClient->checkStock($productId);

        if (!$userValid || !$stockAvailable) {
            return $this->json(['error' => 'Cannot create order'], 400);
        }

        $order = $this->orderService->create($request->toArray());

        // Asinhrono obaveštenje ostalim servisima putem reda poruka
        $this->messageBus->dispatch(new OrderCreated($order->getId()));

        return $this->json($order, 201);
    }
}
```

### Kada Koristiti SOA

**SOA ima smisla kada:**
- Imate veliko preduzeće sa mnogo aplikacija kojima je potrebno deliti servise
- Različiti timovi ili odeljenja trebaju koristiti istu poslovnu logiku
- Trebate integrisati nasleđene sisteme (SOAP) sa modernim (REST)
- Trebate centralizovano upravljanje i monitoring

**SOA je preterivanje kada:**
- Imate jednu aplikaciju
- Vaš tim je mali (< 10 programera)
- Ne trebate deliti servise između aplikacija
- Možete početi sa dobro strukturiranim monolitom

### Zaključak

SOA je arhitekturalni obrazac preduzeća gde je poslovna funkcionalnost organizovana u višekratno upotrebljive servise povezane putem ESB-a. Prethodnik je mikroservisa — oba dele ideju deljenja aplikacija na nezavisne servise, ali SOA je centralizovanija (ESB orkestracija, SOAP ugovori) dok su mikroservisi decentralizovani (direktna komunikacija, REST/gRPC). Većina modernih PHP aplikacija naginje ka mikroservisima umesto tradicionalnoj SOA, ali osnovna načela — labava spregnutost, jasni ugovori, višekratna upotrebljivost servisa — ostaju fundamentalna za dobru arhitekturu.

> Vidi takođe: [REST API arhitektura](rest_api_architecture.sr.md), [SOAP vs REST](soap_vs_rest.sr.md), [REST API vs JSON-RPC](rest_api_vs_json_rpc.sr.md)
