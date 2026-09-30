# Systemprompts

De prompts van de agents staan in n8n zelf, op de node. Hier liggen ze ook, zodat
je kunt terugzien wat er wanneer is veranderd en waarom — dat scheelt gokken als
een agent zich ineens anders gedraagt.

**Deze bestanden doen niets.** n8n leest ze niet. Wijzig je hier iets, plak het
dan ook in de node; wijzig je iets in de node, zet het dan hier terug.

| bestand | node in n8n |
|---|---|
| `regisseur.md` | *Regisseur programmabureau PRM* (PRM 1) |

## De keuze snel of grondig

De pagina stuurt bij elke vraag een veld `modus` mee, met `snel` of `grondig`.
De gebruiker kiest dat onderin het scherm; grondig is de standaard.

**Dat werkt pas als n8n het doorgeeft aan de regisseur.** Eenmalig instellen:

1. Open in PRM 1 de node *Regisseur programmabureau PRM*.
2. Zet **Source for Prompt (User Message)** van *Take from previous node
   automatically* op **Define below**.
3. Vul in het tekstveld deze expressie in:

   ```
   {{ $json.chatInput }}

   [Werkwijze voor deze vraag: {{ $json.modus === 'snel' ? 'snel' : 'grondig' }}]
   ```

Zonder stap 2 en 3 komt de keuze wel binnen bij de workflow, maar ziet de
regisseur hem niet en verandert er niets aan zijn gedrag.

## Meegestuurde bestanden

De pagina leest een meegestuurd bestand zelf uit en stuurt alleen de tekst mee,
als `bijlagen`: een lijst van `{ naam, tekst }`. Er wordt niets opgeslagen — het
hoort bij die ene vraag. Ondersteund zijn `.txt`, `.md`, `.csv` en `.docx`; een
tekst boven de 40.000 tekens wordt afgekapt, met een zichtbare melding eronder.

Ook dit moet in dezelfde prompt-expressie terechtkomen, anders ziet de regisseur
het niet. De volledige expressie op de node *Regisseur programmabureau PRM*,
inclusief de werkwijze uit de vorige paragraaf:

```
{{ $json.chatInput }}

[Werkwijze voor deze vraag: {{ $json.modus === 'snel' ? 'snel' : 'grondig' }}]

{{ ($json.bijlagen || []).map(b => `--- MEEGESTUURD STUK: ${b.naam} ---\n${b.tekst}`).join('\n\n') }}
```

Staat er niets meegestuurd, dan levert het laatste blok een lege regel op en
verandert er niets.

Waar de winst zit: de Onderzoeker doet standaard **vijf** zoekopdrachten, elk met
wachttijd en een timeout. Daar komen die drie minuten vandaan. In de stand *snel*
draagt de regisseur hem op er hooguit twee te doen.

Let op wat er in de prompt bewust **niet** staat: dat *snel* betekent dat hij
feiten zelf mag invullen. De regels over onderzoeksvragen en de PID gelden ook
dan. Snel gaat over minder breedte, niet over minder zorgvuldigheid — anders
ruil je wachttijd in voor verzonnen antwoorden.

## Waarom de harde regels erin staan

Twee dingen mag de regisseur niet zelf invullen, en allebei om dezelfde reden:
hij zou het kunnen, het klinkt goed, en het is fout.

**Onderzoek.** Wat hij meent te weten over de buitenwereld is ongedateerd en niet
herleidbaar. Daarom gaat elke feitelijke vraag naar de Onderzoeker.

**De PID.** Wat hij weet over projectinitiatiedocumenten komt uit andere
organisaties en andere methodieken, niet uit PRM. Aan de eigen database van PRM —
met het vaste template, de checklist en de bijbehorende documenten — hangen drie
agents:

| agent | stadium | rol rond de PID |
|---|---|---|
| Projectinitiator | PID moet nog gebouwd worden | vooruitkijkend: wat moet erin, wat moet ik doen om er te komen |
| Toetser | er ligt materiaal | terugkijkend: is het compleet, wat ontbreekt |
| PIDtcher | het document moet geschreven worden | schrijft de PID op het vaste template, en de pitch |

De regisseur schrijft de PID dus nooit zelf. Hij levert het dossier, de PIDtcher
levert het document. Vaste volgorde bij een schrijfverzoek: eerst de Toetser
(wat is gedekt), dan de PIDtcher (schrijven).

Beide regels zijn expres absoluut geformuleerd ("zonder uitzondering", "twijfel je,
dan is het er een"). Een regel met ruimte erin wordt bij een korte vraag als eerste
overgeslagen, en juist dan gaat het mis: een terloops antwoord over de
hoofdstukindeling van de PID ziet er gezaghebbend uit en stuurt de gebruiker weken
de verkeerde kant op.
