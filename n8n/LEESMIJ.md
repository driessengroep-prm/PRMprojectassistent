# n8n-onderdelen voor losse afhandeling

Duurt een vraag langer dan de gateway van n8n Cloud toestaat — rond de honderd
seconden — dan verbreekt die de verbinding terwijl de workflow gewoon doorloopt.
Deze twee bestanden bouwen de opzet waarin n8n meteen bevestigt en de pagina het
resultaat daarna apart ophaalt.

Het resultaat gaat via een Excel-werkmap in OneDrive of SharePoint, met de node
**Microsoft Excel 365**. De pagina verzint per vraag een `beurtId`, n8n schrijft
het antwoord onder dat kenmerk weg, en de pagina vraagt er net zolang naar tot
het klaarstaat.

## De werkmap

Maak een werkmap in OneDrive of SharePoint met één werkblad `resultaten`. Zet in
rij 1 exact deze koppen:

```
beurtId | sessionId | output | forum1 | forum2 | forum3 | forum4 | forum5 | forum6 | tijd
```

Selecteer die koprij en maak er een **tabel** van (Invoegen → Tabel, met
"Mijn tabel bevat kopteksten" aan). Zonder tabel kan de node niet gericht
zoeken en moet het hele blad bij elke peiling worden ingelezen.

Die zes forum-kolommen zijn nodig omdat een cel in Excel **maximaal 32.767
tekens** houdt — minder dan Google Sheets aankan. Het forum wordt in stukken van
30.000 geknipt en bij het lezen weer aan elkaar geplakt. Samen is dat 180.000
tekens; gaat een forum daar nog overheen, dan wordt het overleg weggelaten en
blijft het advies staan.

## `nodes-voor-hoofdflow.json`

Drie nodes om aan de bestaande workflow toe te voegen. **Niet importeren als
workflow** — kopieer de inhoud en plak hem op het canvas van de bestaande
workflow. Importeren maakt een nieuwe workflow met een nieuwe webhook-URL, en
dan verandert het adres van de chat.

- **Meteen bevestigen** — tussen de Chat Trigger en de Regisseur. Zet op de Chat
  Trigger ook Response Mode op *Using 'Respond to Webhook' Node*.
- **Resultaat klaarzetten** — achter *Forumweergave*. Knipt het forum in stukken.
- **Resultaat wegschrijven** — Microsoft Excel 365, resource *Worksheet*,
  operatie *Append*, met Data Mode op *Auto-Map Input Data*. De veldnamen uit de
  Code-node komen dan overeen met de kopteksten.

## `resultaat-ophalen.json`

Een complete workflow die je wél als workflow importeert. De pagina peilt deze
webhook tot het antwoord klaarstaat.

Na import: open *Rij zoeken*, kies je Microsoft-credential en selecteer werkmap,
werkblad en tabel opnieuw uit de dropdowns — die staan op een tijdelijke
aanduiding. De bewerking moet op *Table → Lookup* staan, met kolom `beurtId`.
Activeer daarna de workflow en plak de production-URL in de overlegruimte onder
Instellingen, bij **Resultaat-URL**.

Op *Rij zoeken* staat **Always Output Data** aan. Zonder dat stopt de workflow
zodra de rij er nog niet is, komt de Respond-node niet aan de beurt en krijgt de
pagina niets terug in plaats van `bezig`.

## Testen, in deze volgorde

Test de resultaat-workflow los, vóór je de pagina koppelt:

1. Zet met de hand een rij in de tabel met `beurtId` = `test123`, iets in
   `output` en `[]` in `forum1`.
2. Open `<resultaat-URL>?beurtId=test123` in je browser. Verwacht:
   `{"status":"klaar",...}`.
3. Vraag een `beurtId` op dat niet bestaat. Verwacht: `{"status":"bezig"}` — geen
   leeg antwoord en geen fout. Krijg je niets, dan staat *Always Output Data*
   nog uit.

Pas als beide kloppen: resultaat-URL invullen op de pagina en een echte vraag
stellen.

## Nog te doen

**Opruimen.** Zonder opruiming groeit de tabel oneindig. Een workflow met een
Schedule Trigger die dagelijks alles ouder dan een week verwijdert, volstaat.

**Executions.** Elke peiling is een run van *Resultaat ophalen*. Een vraag van
drie minuten kost er ongeveer achttien. Houd het verbruik de eerste week in de
gaten.

**CORS.** De webhook heeft bewust geen authenticatie: het `beurtId` is een
willekeurige UUID en werkt zelf als sleutel. Zet je er toch Basic Auth op, houd
er dan rekening mee dat de browser eerst een preflight stuurt.

## Wat wel en niet is getest

De JavaScript in beide Code-nodes is los uitgevoerd tegen de Excel-grens van
32.767 tekens per cel, met forums van 3 kB tot 250 kB. Tot 170 kB komt het forum
ongeschonden terug; daarboven blijft alleen het advies over, zoals bedoeld. Een
ontbrekende rij geeft `bezig`, onleesbare JSON kost het overleg maar niet het
advies.

Wat níet is getest, is of de velden op de Excel-nodes exact overeenkomen met wat
jouw n8n-versie verwacht. Loop die na en selecteer werkmap, werkblad en tabel
opnieuw uit de dropdowns; n8n vult de juiste waarden dan zelf in.

Een eerdere versie van deze bestanden gebruikte Google Sheets. Die staat nog in
de git-historie, mocht dat ooit alsnog een optie zijn.
