# Roadmap di NonNarrato

Decisa da Vincenzo nella chat con Claude (27/11/2026). Chi lavora sul progetto (Claude Code, anche su GitHub con
"@claude") legge prima `CLAUDE.md` e questo file, e lavora **un punto per volta, una versione per punto**,
solo sul punto indicato nella richiesta. Prima di ogni lavoro grosso serve il "via" di Vincenzo: su GitHub il via
è la richiesta stessa che nomina il punto.

Riferimenti: **Dead Cells** come base (stesso metodo: modelli 3D trasformati in pixel art), **Blasphemous** per peso
e cupezza dei movimenti, **Prince of Persia** (il primo) per arrampicate e aggrappi.
Dispositivo più debole su cui deve girare bene: **Pixel 8 Pro**. Livelli in più per i dispositivi più potenti.
Si possono scaricare e installare risorse CC0 e librerie (solo licenze compatibili con un repository pubblico).

## 1. Ombre giuste, senza coni neri — da fare
Oggetti, personaggio e nemici devono avere di nuovo un'ombra (dalla 0.1.28 erano state tolte: errore).
Corte e sfumate, dai piedi, dalla parte opposta alla torcia più vicina, più deboli lontano dalla luce.
Niente coni neri lunghi che partono dalle torce e attraversano il muro.

## 2. Regola: si corregge il difetto, non si toglie ciò che funziona — da fare
Scriverla in `CLAUDE.md` (fatto il 27/11/2026) e rispettarla: prima di togliere qualcosa ci si chiede se il
problema è la cosa o solo il difetto, e si confronta con Dead Cells e Blasphemous. Si toglie solo se lì non c'è.

## 3. Movimenti fluidi e naturali per tutti — da fare
Personaggio (lo stesso del bot) e ogni tipo di nemico. Oggi l'arrampicata sembra "Pinocchio, un burattino".
- piedi che non scivolano: camminata, corsa, nuoto e salita al passo con lo spostamento vero;
- niente scatti tra un'azione e l'altra (fermarsi, girarsi, attaccare, atterrare, rialzarsi, aggrapparsi,
  scavalcare in cima, lasciarsi andare): pose di passaggio;
- peso: preparazione prima di salti e colpi, ritorno dopo, corpo che si piega e oscilla;
- arrampicata: ciclo più lungo, mano e piede opposti insieme, spinta a ogni presa;
- controllo con foto fotogramma per fotogramma, confrontate con i riferimenti.

## 4. Grafica di qualità più alta — da fare
"Sembra ancora tutto fatto male": più accattivante e di qualità.
- personaggi e nemici più dettagliati (modelli CC0 migliori, per esempio Quaternius), più pixel per figura;
- animazioni da archivi gratuiti di motion capture (aiutano anche il punto 3);
- ambienti più ricchi: sfondi su più strati, pietre, muri e decorazioni curati;
- luce e atmosfera: bagliore di fiamme e magie, nebbia e polvere in movimento, raggi di luce, colori più cupi e
  uniformi, le ombre del punto 1;
- livello "ultra" per i dispositivi sopra il Pixel.
A tappe: una versione per passo, Vincenzo controlla sul Pixel prima di andare avanti.
