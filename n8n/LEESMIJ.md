# n8n-onderdelen voor losse afhandeling

Duurt een vraag langer dan de gateway van n8n Cloud toestaat — rond de honderd
seconden — dan verbreekt die de verbinding terwijl de workflow gewoon doorloopt.
Het antwoord is dan wél gemaakt, maar de pagina kan het niet meer ontvangen.

De oplossing is niet dat n8n sneller antwoordt, maar dat de pagina niet meer op
dat antwoord wacht. Ze verstuurt de vraag met een eigen kenmerk (`beurtId`),
laat de verbinding los, en haalt het resultaat daarna apart op uit een
Excel-werkmap. Hoe lang de workflow erover doet, maakt dan niet meer uit.

Dat betekent ook: **de hoofdworkflow hoeft niets bijzonders te doen met zijn
antwoord.** Response Mode blijft gewoon op *When Last Node Finishes*. Er is geen
Respond-node nodig, en dat is bewust — zie [Waarom geen 'meteen
bevestigen'](#waarom-geen-meteen-bevestigen).

## De werkmap

Maak een werkmap in OneDrive of SharePoint. Zet in rij 1 van een werkblad exact
deze koppen:

```
beurtId | sessionId | output | forum1 | forum2 | forum3 | forum4 | forum5 | forum6 | tijd
```

Selecteer die koprij en maak er een **tabel** van (Invoegen → Tabel, met
"Mijn tabel bevat kopteksten" aan). Beide workflows werken op die tabel, niet op
het blad: schrijven en zoeken moeten hetzelfde bereik gebruiken, anders komt een
weggeschreven rij buiten de tabel te staan en vindt de peiling hem nooit.

Hoe het blad heet doet er niet toe — `Blad1` is prima. Je kiest werkmap,
werkblad en tabel overal uit de dropdowns.

Die zes forum-kolommen zijn nodig omdat een cel in Excel **maximaal 32.767
tekens** houdt — minder dan Google Sheets aankan. Het forum wordt in stukken van
30.000 geknipt en bij het lezen weer aan elkaar geplakt. Samen is dat 180.000
tekens; gaat een forum daar nog overheen, dan wordt het overleg weggelaten en
blijft het advies staan.

## `nodes-voor-hoofdflow.json`

Twee nodes om aan de bestaande workflow toe te voegen. **Niet importeren als
workflow** — kopieer de inhoud en plak hem op het canvas van de bestaande
workflow. Importeren maakt een nieuwe workflow met een nieuwe webhook-URL, en
dan verandert het adres van de chat.

- **Resultaat klaarzetten** — achter *Forumweergave*. Knipt het forum in stukken
  en leest het `beurtId` uit de trigger.
- **Resultaat wegschrijven** — Microsoft Excel 365, resource **Table**, operatie
  **Append**, Data Mode op **Auto-Map Input Data**. De veldnamen uit de
  Code-node komen dan overeen met de kopteksten. Kies werkmap, werkblad en tabel
  uit de dropdowns; in het bestand staan tijdelijke aanduidingen.

## `resultaat-ophalen.json`

Een complete workflow die je wél als workflow importeert. De pagina peilt deze
webhook tot het antwoord klaarstaat.

Na import: open *Rij zoeken*, kies je Microsoft-credential en selecteer werkmap,
werkblad en tabel uit de dropdowns. De bewerking moet op *Table → Lookup* staan,
met kolom `beurtId`. Activeer daarna de workflow en plak de production-URL in de
Projectenassistent onder Instellingen, bij **Resultaat-URL**.

Op *Rij zoeken* staat **Always Output Data** aan. Zonder dat stopt de workflow
zodra de rij er nog niet is, komt de Respond-node niet aan de beurt en krijgt de
pagina niets terug in plaats van `bezig`.

## Waarom geen 'meteen bevestigen'

Een eerdere opzet zette een *Respond to Webhook* achter de Chat Trigger, om
meteen `{"status":"bezig"}` terug te geven. Dat werkt niet, en het is nuttig te
weten waarom.

De Chat Trigger kent voor Response Mode de stand *Using Response Nodes*. Die
wacht op een **Respond to Chat**-node, niet op een *Respond to Webhook*. Zet je
er toch een Respond to Webhook neer, dan komt het antwoord waar de trigger op
wacht nooit, en blijft de uitvoering staan op die node — precies het beeld van
een run die blijft hangen bij *Meteen bevestigen*.

Het is bovendien overbodig. De pagina hoeft dat `bezig` helemaal niet te
ontvangen: ze weet zelf dat ze net een vraag verstuurd heeft. Daarom laat ze de
verbinding nu gewoon los en begint ze te peilen. Wordt de vraag meteen geweigerd
— verkeerd wachtwoord, workflow niet actief — dan meldt de pagina dat wel; die
fout komt binnen enkele seconden en gaat langs de peiling heen.

## Wat je in de hoofdworkflow moet nalopen

1. **Chat Trigger** — Response Mode op *When Last Node Finishes*. Staat er nog
   een node *Meteen bevestigen*: verwijderen, en de Chat Trigger rechtstreeks op
   de Regisseur aansluiten.
2. **Zoekdienst (Perplexity)** — open de node en kies bij Workflow opnieuw
   *PRM 2 - Zoekdienst (Perplexity)* uit de lijst. Staat daar een id dat niet bij
   die workflow hoort, dan wordt de zoekdienst nooit aangeroepen en merk je daar
   niets van: de Onderzoeker verzint dan zijn eigen antwoord.
3. **Resultaat wegschrijven** — resource *Table*, operatie *Append*, en werkmap,
   werkblad en tabel uit de dropdowns.
4. **Resultaat klaarzetten** — moet de versie uit dit bestand zijn, die het
   `beurtId` op meerdere plekken zoekt.

## Testen, in deze volgorde

Test de resultaat-workflow los, vóór je de pagina koppelt:

1. Zet met de hand een rij in de tabel met `beurtId` = `test123`, iets in
   `output` en `[]` in `forum1`.
2. Open `<resultaat-URL>?beurtId=test123` in je browser. Verwacht:
   `{"status":"klaar",...}`.
3. Vraag een `beurtId` op dat niet bestaat. Verwacht: `{"status":"bezig"}` — geen
   leeg antwoord en geen fout. Krijg je niets, dan staat *Always Output Data*
   nog uit.

Test daarna de hoofdworkflow los: stel een vraag en kijk in de uitvoering of
*Resultaat wegschrijven* groen is en er een rij bij komt met een gevuld
`beurtId`. Is dat leeg, dan vindt de peiling de rij nooit; kijk dan in de
uitvoering wat de Chat Trigger werkelijk teruggeeft.

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

Wat níet is getest, is de aanroep van Perplexity zelf: het adres
`https://api.perplexity.ai/v1/agent` met een `preset`/`input`-body heeft nog
nooit gedraaid, omdat de zoekdienst tot nu toe naar een verkeerd workflow-id
wees. Reken erop dat daar nog een ronde overheen moet.

Ook niet getest is of de velden op de Excel-nodes exact overeenkomen met wat
jouw n8n-versie verwacht. Loop die na en selecteer werkmap, werkblad en tabel
opnieuw uit de dropdowns; n8n vult de juiste waarden dan zelf in.

Een eerdere versie van deze bestanden gebruikte Google Sheets. Die staat nog in
de git-historie, mocht dat ooit alsnog een optie zijn.
