extends Node
# Impostazioni del gioco, salvate in user://impostazioni.cfg.
# Il gioco sceglie da solo i valori di partenza (riconosce dispositivo, schermo e uscita audio):
# qui restano solo le scelte fatte a mano. Convenzione: -1 (o "auto") = scelta automatica.
# Le schede del menu (Gioco, Schermo, Grafica, Audio, Accessibilità) raggruppano le chiavi in SCHEDE.

signal cambiata(chiave: String)

const PERCORSO := "user://impostazioni.cfg"

const PREDEFINITE := {
	# --- Gioco: comandi e partita
	"controlli/modo": "auto",            # auto, touch, controller
	"controlli/dimensione_touch": -1.0,  # -1 = adatta allo schermo (tasto principale di circa 13 mm)
	"controlli/opacita_touch": 0.6,
	"controlli/mancino": false,          # leva a destra e tasti a sinistra
	"controlli/zona_morta": 0.35,        # leve analogiche e leva a schermo
	"controlli/vibrazione": true,
	"controlli/forza_vibrazione": 1.0,
	"gioco/numeri_danno": false,         # numeri dei danni sopra i nemici
	"gioco/messaggi": true,              # frasi delle nemesi e messaggi della storia
	"gioco/debug": false,                # schermata con FPS e dati del dispositivo (copre l'angolo: spenta di base)
	"gioco/controlla_aggiornamenti": true,
	# --- Schermo
	"schermo/scala": 0,                  # 0 = automatica; altrimenti pixel dello schermo per pixel del gioco
	"schermo/adatta": "intera",          # intera (pixel perfetti) o riempi (sempre 360 righe, scala non intera)
	"schermo/proporzioni": "riempi",     # riempi tutto lo schermo, oppure 16:9 con bande
	"grafica/limite_fps": 0,             # 0 = consigliato (60); 30, 60, 90, 120 se lo schermo li regge
	"schermo/modo": 0,                   # 0 = sceglie Android; altrimenti un modo dello schermo (risoluzione e Hz)
	"schermo/vsync": true,
	"schermo/luminosita": 1.0,
	"schermo/contrasto": 1.0,
	"schermo/margini": -1.0,             # -1 = area sicura del telefono (foro della fotocamera); altrimenti quota in più
	"schermo/orientamento": "sensore",   # sensore (si gira da solo), normale, capovolto
	"schermo/sempre_acceso": true,
	# --- Grafica
	"grafica/qualita": "auto",           # auto, bassa, media, alta
	"grafica/luci_ombra": -1,            # torce con ombra (0-4)
	"grafica/ombre_morbide": -1,         # -1 auto, 0 no, 1 sì
	"grafica/luci_doppie": -1,           # luce di riempimento davanti
	"grafica/normali_figura": -1,        # rilievo del personaggio (foto delle normali)
	"grafica/nebbia": -1,
	"grafica/primo_piano": -1,           # sagome scure in primo piano
	"grafica/particelle": -1.0,          # quantità (0,2-1)
	"grafica/atlante_ombre": -1,         # dettaglio delle ombre: 512, 1024, 2048
	"grafica/palette": true,             # filtro "palette fissa" in pixel art
	"grafica/adattamento": true,         # abbassa da solo la qualità se il gioco va a scatti (il caldo la abbassa sempre)
	"grafica/risoluzione": 1.0,          # risoluzione interna: 1, 0,75, 0,5
	"grafica/filtro": "nitido",          # ingrandimento: nitido, liscio, sgsr
	"grafica/nitidezza": 0.5,            # solo per sgsr
	# --- Audio
	"audio/generale": 0.8,
	"audio/musica": 0.55,
	"audio/effetti": 0.9,
	"audio/ambiente": 0.7,
	"audio/interfaccia": 0.6,
	"audio/mono": false,
	"audio/notte": -1,                   # gamma dinamica ridotta: -1 auto (sì sull'altoparlante), 0 no, 1 sì
	"audio/bassi": -1,                   # -1 auto, 0 ridotti, 1 normali, 2 forti
	"audio/silenzioso": true,            # rispetta la modalità silenziosa del telefono
	"audio/pausa_attenua": true,         # in pausa la musica si abbassa
	# --- Accessibilità
	"acc/velocita": 1.0,                 # velocità del gioco (0,5-1)
	"acc/danni": 1.0,                    # danni ricevuti (1, 0,75, 0,5, 0,25, 0 = invincibile)
	"acc/mira": 1,                       # aiuto alla mira: 0 spento, 1 normale, 2 forte
	"acc/scuotimento": 1.0,              # scosse dello schermo
	"acc/meno_lampi": false,             # niente lampi bianchi né fermi immagine
	"acc/contorni": false,               # contorni chiari attorno a personaggio, nemici e tiri
	"acc/daltonismo": "no",              # no, protanopia, deuteranopia, tritanopia
	"acc/testo": 1.0,                    # grandezza di testi e interfaccia
	"acc/carica": "tieni",               # tieni premuto oppure premi una volta per caricare i tiri
	"acc/didascalie": false,             # scritte per i suoni importanti
	"acc/stamina_infinita": false,       # arrampicarsi senza stancarsi
	"acc/respiro_infinito": false,       # sott'acqua senza bisogno di respirare
}

const SCHEDE := {
	"gioco": ["controlli/", "gioco/"],
	"schermo": ["schermo/", "grafica/limite_fps"],
	"grafica": ["grafica/"],
	"audio": ["audio/"],
	"accessibilita": ["acc/"],
}

const DETTAGLI_GRAFICA := ["grafica/luci_ombra", "grafica/ombre_morbide", "grafica/luci_doppie", "grafica/normali_figura",
	"grafica/nebbia", "grafica/primo_piano", "grafica/particelle", "grafica/atlante_ombre"]

var _valori := {}


func _ready() -> void:
	_valori = PREDEFINITE.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PERCORSO) != OK:
		return
	for chiave: String in PREDEFINITE:
		var parti := chiave.split("/")
		if cfg.has_section_key(parti[0], parti[1]):
			var v: Variant = cfg.get_value(parti[0], parti[1])
			if typeof(v) == typeof(PREDEFINITE[chiave]):
				_valori[chiave] = v
			elif typeof(PREDEFINITE[chiave]) == TYPE_FLOAT and typeof(v) == TYPE_INT:
				_valori[chiave] = float(v)


func leggi(chiave: String) -> Variant:
	return _valori.get(chiave, PREDEFINITE.get(chiave))


func scrivi(chiave: String, valore: Variant) -> void:
	if not PREDEFINITE.has(chiave):
		push_warning("impostazione sconosciuta: " + chiave)
		return
	if typeof(PREDEFINITE[chiave]) == TYPE_FLOAT and typeof(valore) == TYPE_INT:
		valore = float(valore)
	if _valori.get(chiave) == valore:
		return
	_valori[chiave] = valore
	_salva()
	cambiata.emit(chiave)


func ripristina() -> void:
	_valori = PREDEFINITE.duplicate()
	_salva()
	for chiave: String in PREDEFINITE:
		cambiata.emit(chiave)


static func scheda_di(chiave: String) -> String:
	if chiave == "grafica/limite_fps":
		return "schermo"  # sta nella scheda Schermo, anche se il nome è vecchio
	for scheda: String in SCHEDE:
		for prefisso: String in SCHEDE[scheda]:
			if chiave.begins_with(prefisso):
				return scheda
	return ""


func ripristina_scheda(scheda: String) -> void:
	# Torna ai valori consigliati solo per le chiavi di una scheda del menu.
	var cambiate: Array[String] = []
	for chiave: String in PREDEFINITE:
		if scheda_di(chiave) == scheda and _valori[chiave] != PREDEFINITE[chiave]:
			_valori[chiave] = PREDEFINITE[chiave]
			cambiate.append(chiave)
	if cambiate.is_empty():
		return
	_salva()
	for chiave in cambiate:
		cambiata.emit(chiave)


func scegli_qualita(livello: String) -> void:
	# Un livello di qualità riporta in automatico tutti i dettagli che ne dipendono.
	for chiave: String in DETTAGLI_GRAFICA:
		_valori[chiave] = PREDEFINITE[chiave]
	_valori["grafica/qualita"] = livello
	_salva()
	cambiata.emit("grafica/qualita")


func personalizzata() -> bool:
	for chiave: String in DETTAGLI_GRAFICA:
		if _valori[chiave] != PREDEFINITE[chiave]:
			return true
	return false


func tutte() -> Dictionary:
	return _valori.duplicate()


func _salva() -> void:
	var cfg := ConfigFile.new()
	for chiave: String in _valori:
		var parti := chiave.split("/")
		cfg.set_value(parti[0], parti[1], _valori[chiave])
	cfg.save(PERCORSO)
