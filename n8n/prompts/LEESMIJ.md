# Systemprompts

De prompts van de agents staan in n8n zelf, op de node. Hier liggen ze ook, zodat
je kunt terugzien wat er wanneer is veranderd en waarom — dat scheelt gokken als
een agent zich ineens anders gedraagt.

**Deze bestanden doen niets.** n8n leest ze niet. Wijzig je hier iets, plak het
dan ook in de node; wijzig je iets in de node, zet het dan hier terug.

| bestand | node in n8n |
|---|---|
| `regisseur.md` | *Regisseur programmabureau PRM* (PRM 1) |

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
