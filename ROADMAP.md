# Roadmap di NonNarrato

Decisa da Vincenzo nella chat con Claude (27/11/2026). Chi lavora sul progetto (Claude Code, anche su GitHub con
"@claude") legge prima `CLAUDE.md` e questo file, e lavora **un punto per volta, una versione per punto**,
solo sul punto indicato nella richiesta. Prima di ogni lavoro grosso serve il "via" di Vincenzo: su GitHub il via
è la richiesta stessa che nomina il punto.

Riferimenti: **Dead Cells** come base (stesso metodo: modelli 3D trasformati in pixel art), **Blasphemous** per peso
e cupezza dei movimenti, **Prince of Persia** (il primo) per arrampicate e aggrappi.
Dispositivo più debole su cui deve girare bene: **Pixel 8 Pro**. Livelli in più per i dispositivi più potenti.
Si possono scaricare e installare risorse CC0 e librerie (solo licenze compatibili con un repository pubblico).

## 1. Ombre giuste, senza coni neri — fatto (0.1.31 corpi, 0.1.32 muri e pilastri)
Oggetti, personaggio e nemici devono avere di nuovo un'ombra (dalla 0.1.28 erano state tolte: errore).
Corte e sfumate, dai piedi, dalla parte opposta alla torcia più vicina, più deboli lontano dalla luce.
Niente coni neri lunghi che partono dalle torce e attraversano il muro.

## 2. Regola: si corregge il difetto, non si toglie ciò che funziona — fatto (0.1.32)
Scriverla in `CLAUDE.md` (fatto il 27/11/2026) e rispettarla: prima di togliere qualcosa ci si chiede se il
problema è la cosa o solo il difetto, e si confronta con Dead Cells e Blasphemous. Si toglie solo se lì non c'è.

## 3. Movimenti fluidi e naturali per tutti — fatto (0.1.34 e 0.1.35)
Personaggio (lo stesso del bot) e ogni tipo di nemico. Oggi l'arrampicata sembra "Pinocchio, un burattino".
- piedi che non scivolano: camminata, corsa, nuoto e salita al passo con lo spostamento vero;
- niente scatti tra un'azione e l'altra (fermarsi, girarsi, attaccare, atterrare, rialzarsi, aggrapparsi,
  scavalcare in cima, lasciarsi andare): pose di passaggio;
- peso: preparazione prima di salti e colpi, ritorno dopo, corpo che si piega e oscilla;
- arrampicata: ciclo più lungo, mano e piede opposti insieme, spinta a ogni presa;
- controllo con foto fotogramma per fotogramma, confrontate con i riferimenti.

Fatto nella 0.1.34 (lavoro della 0.1.33, uscito con la compilazione 34): tutte le animazioni ad almeno 24 fotogrammi
al secondo (personaggio e nemici, stesse durate); corsa e camminata al passo con lo spostamento; salto ad arco guidato
dalla velocità con sospensione in cima; spigoli scansati; inclinazione nello slancio e nella frenata; issata dal bordo
(appeso, trazione, ginocchio, in piedi); nemici che partono e frenano senza scatti, senza passettini sul posto.
Resta: ciclo dell'arrampicata (più lungo, mano e piede opposti, spinta a ogni presa), nuoto al passo, pose di passaggio
(girarsi, attaccare, atterrare, rialzarsi, lasciarsi andare), preparazione e ritorno di salti e colpi.

Fatto nella 0.1.35: arrampicata con un ciclo vero (mano e piede opposti, spinta a ogni presa, mani ferme sulla roccia),
pose di passaggio fra tutte le azioni del personaggio, mezzo giro di personaggio e nemici, slancio e schiacciamento nei
salti, nuoto al passo.

## 4. Grafica di qualità più alta — in corso
"Sembra ancora tutto fatto male": più accattivante e di qualità.
- personaggi e nemici più dettagliati (modelli CC0 migliori, per esempio Quaternius), più pixel per figura;
- animazioni da archivi gratuiti di motion capture (aiutano anche il punto 3);
- ambienti più ricchi: sfondi su più strati, pietre, muri e decorazioni curati;
- luce e atmosfera: bagliore di fiamme e magie, nebbia e polvere in movimento, raggi di luce, colori più cupi e
  uniformi, le ombre del punto 1;
- livello "ultra" per i dispositivi sopra il Pixel.
A tappe: una versione per passo, Vincenzo controlla sul Pixel prima di andare avanti.

Tappa 1 fatta nella 0.1.36: bagliore di fiamme e magie, raggi di luce dalle finestre con la polvere, colori del film,
livello "ultra".
Tappa 2, prima parte, fatta nella 0.1.37: personaggio e nemici in doppia definizione (il doppio dei pixel), mondo
disegnato al doppio in "alta" e "ultra", fogli ritagliati.
Decisione di Vincenzo (27/11/2026, dopo le foto di confronto): stile Quaternius con proporzioni vere per tutto il
gioco, coerente e omogeneo, con la libreria più ampia possibile (siti CC0 aperti: vedi CLAUDE.md).
Tappa 2, seconda parte, fatta nella 0.1.38: il Non Narrato col corpo Quaternius, vestiti modulari, mantelli generati,
animazioni UAL e KayKit adattate. Tappa 2, terza parte, fatta nella 0.1.39: i nemici con gli stessi pezzi e le stesse
animazioni del protagonista (sepolto risorto, mago, balestriere, bestione incappucciato, ghoul). Pipistrello e mimic
restano: il mimic nasce dal forziere e cambierà con gli ambienti. Tappa 2, quarta parte, fatta nella 0.1.40: armi, scudi, elmi, pozioni, pipistrello e munizioni dalle fonti CC0 verificate
(dieci giri di ricerca). Tappa 2, quinta parte, fatta nella 0.1.41: gli ambienti (muri, pavimenti, colonne, casse, barili,
forzieri e mimic, torce, bracieri, montacarichi, leve e balestre murate) e gli arredi (catene, gabbie, lampadario, stendardi,
libri, statua, sarcofago, ossa, rocce, monete, edera). Restano a forme semplici le grate, gli spuntoni e la sega del pendolo.
