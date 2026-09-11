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
organisaties en andere methodieken, niet uit PRM. De Projectinitiator en de Toetser
putten wél uit de eigen database van PRM. Daarom gaat elke vraag over de opbouw,
de inhoud of de volledigheid van de PID naar een van die twee — vooruitkijkende
vragen naar de Projectinitiator, terugkijkende naar de Toetser.

Beide regels zijn expres absoluut geformuleerd ("zonder uitzondering", "twijfel je,
dan is het er een"). Een regel met ruimte erin wordt bij een korte vraag als eerste
overgeslagen, en juist dan gaat het mis: een terloops antwoord over de
hoofdstukindeling van de PID ziet er gezaghebbend uit en stuurt de gebruiker weken
de verkeerde kant op.
