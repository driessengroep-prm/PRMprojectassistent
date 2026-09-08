# n8n-onderdelen voor losse afhandeling

Duurt een vraag langer dan de gateway van n8n Cloud toestaat — rond de honderd
seconden — dan verbreekt die de verbinding terwijl de workflow gewoon doorloopt.
Deze twee bestanden bouwen de opzet waarin n8n meteen bevestigt en de pagina het
resultaat daarna apart ophaalt.

Het resultaat gaat via een Google Sheet. De pagina verzint per vraag een
`beurtId`, n8n schrijft het antwoord onder dat kenmerk weg, en de pagina vraagt
er net zolang naar tot het klaarstaat.

## Het blad

Eén tabblad `resultaten`, met in rij 1 exact deze koppen:

```
beurtId | sessionId | output | forum1 | forum2 | forum3 | forum4 | tijd
```

Die vier forum-kolommen zijn nodig omdat een cel in Google Sheets maximaal
50.000 tekens houdt. Het forum wordt in stukken van 45.000 geknipt en bij het
lezen weer aan elkaar geplakt.

## `nodes-voor-hoofdflow.json`

Drie nodes om aan de bestaande workflow toe te voegen. **Niet importeren als
workflow** — kopieer de inhoud en plak hem op het canvas van de bestaande
workflow. Importeren maakt een nieuwe workflow met een nieuwe webhook-URL, en
dan verandert het adres van de chat.

- **Meteen bevestigen** — tussen de Chat Trigger en de Regisseur. Zet op de Chat
  Trigger ook Response Mode op *Using 'Respond to Webhook' Node*.
- **Resultaat klaarzetten** — achter *Forumweergave*. Knipt het forum in stukken.
- **Resultaat wegschrijven** — schrijft de rij weg met *Append or Update Row*,
  gematcht op `beurtId`.

## `resultaat-ophalen.json`

Een complete workflow die je wél als workflow importeert. De pagina peilt deze
webhook tot het antwoord klaarstaat.

Na import: open *Rij zoeken*, kies je Google-credential en selecteer het
spreadsheet en tabblad opnieuw uit de dropdowns — het document staat op een
tijdelijke aanduiding. Activeer daarna de workflow en plak de production-URL in
de overlegruimte onder Instellingen, bij **Resultaat-URL**.

Op *Rij zoeken* staat **Always Output Data** aan. Zonder dat stopt de workflow
zodra de rij er nog niet is, komt de Respond-node niet aan de beurt en krijgt de
pagina niets terug in plaats van `bezig`.

## Testen, in deze volgorde

Test de resultaat-workflow los, vóór je de pagina koppelt:

1. Zet met de hand een rij in het blad met `beurtId` = `test123`, iets in
   `output` en `[]` in `forum1`.
2. Open `<resultaat-URL>?beurtId=test123` in je browser. Verwacht:
   `{"status":"klaar",...}`.
3. Vraag een `beurtId` op dat niet bestaat. Verwacht: `{"status":"bezig"}` — geen
   leeg antwoord en geen fout. Krijg je niets, dan staat *Always Output Data*
   nog uit.

Pas als beide kloppen: resultaat-URL invullen op de pagina en een echte vraag
stellen.

## Nog te doen

**Opruimen.** Zonder opruiming groeit het blad oneindig. Een workflow met een
Schedule Trigger die dagelijks alles ouder dan een week verwijdert, volstaat.

**Executions.** Elke peiling is een run van *Resultaat ophalen*. Een vraag van
drie minuten kost er ongeveer achttien. Houd het verbruik de eerste week in de
gaten.

**CORS.** De webhook heeft bewust geen authenticatie: het `beurtId` is een
willekeurige UUID en werkt zelf als sleutel. Zet je er toch Basic Auth op, houd
er dan rekening mee dat de browser eerst een preflight stuurt.
