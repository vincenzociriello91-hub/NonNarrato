extends Node
# La partita in corso (il sogno di adesso), per il tasto "Continua" della schermata iniziale.
# Si salva a ogni nuova ondata, a ogni nuovo sogno, ogni 20 secondi di gioco, quando il gioco va in secondo
# piano (Android può chiuderlo da lì senza avvisare) e quando si torna al titolo. Scrittura sicura: Salvataggio.
# Cosa resta fra un sogno e l'altro (nemesi, veterani, aspetto, tesori) sta già in Memoria ed Equipaggiamento:
# qui c'è solo il sogno di adesso. Riprendendo si riparte dall'inizio della stanza, all'ondata salvata.

const VERSIONE := 1
const OGNI := 20.0

var percorso := "user://partita.cfg"   # le prove usano un file a parte
var dati := {}                          # vuoto = nessuna partita da riprendere
var attiva := false                     # si salva solo mentre chi gioca sta giocando (no titolo, no bot, no prove)
var salvataggi := 0
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	carica()


func carica() -> void:
	var cfg := ConfigFile.new()
	dati = {}
	if Salvataggio.leggi_cfg(cfg, percorso) != OK:
		return
	var versione := int(cfg.get_value("partita", "versione", 0))
	var letti: Variant = cfg.get_value("partita", "dati", {})
	if versione < 1 or versione > VERSIONE or not letti is Dictionary or not (letti as Dictionary).has("sogno"):
		return   # formato sconosciuto: meglio nessuna partita che una partita sbagliata
	dati = letti


func esiste() -> bool:
	return not dati.is_empty()


func salva(principale: Node) -> bool:
	# Fotografa il sogno di adesso dalla scena principale (sogno, stanza, giocatore).
	if principale == null or not "stanza" in principale:
		return false
	var stanza: Stanza = principale.get("stanza")
	if not is_instance_valid(stanza) or not is_instance_valid(stanza.giocatore):
		return false
	var g := stanza.giocatore
	if g.stato == Giocatore.Stato.MORTO:
		return false   # durante la morte si salva dopo, a sogno nuovo
	dati = {
		"sogno": int(principale.get("sogno")),
		"ondata": stanza.ondata,
		"completato": stanza.sogno_completato,
		"vita": g.vita,
		"energia": g.energia,
		"munizioni": g.munizioni.duplicate(),
		"arma": g.arma_distanza,
		"quando": Time.get_unix_time_from_system(),
	}
	var cfg := ConfigFile.new()
	cfg.set_value("partita", "versione", VERSIONE)
	cfg.set_value("partita", "dati", dati)
	_t = 0.0
	var ok := Salvataggio.scrivi_cfg(cfg, percorso)
	if ok:
		salvataggi += 1
	return ok


func applica(stanza: Stanza) -> void:
	# Rimette nel giocatore della stanza appena creata quello che aveva (la stanza è già all'ondata giusta).
	if not esiste() or not is_instance_valid(stanza) or not is_instance_valid(stanza.giocatore):
		return
	var g := stanza.giocatore
	g.vita = clampi(int(dati.get("vita", Giocatore.VITA_MASSIMA)), 1, Giocatore.VITA_MASSIMA)
	g.energia = clampf(float(dati.get("energia", Giocatore.ENERGIA_MASSIMA)), 0.0, Giocatore.ENERGIA_MASSIMA)
	var m: Variant = dati.get("munizioni", {})
	if m is Dictionary:
		for tipo: String in Giocatore.MUNIZIONI_MASSIME:
			g.munizioni[tipo] = clampi(int((m as Dictionary).get(tipo, g.munizioni[tipo])), 0, int(Giocatore.MUNIZIONI_MASSIME[tipo]))
	var arma := String(dati.get("arma", g.arma_distanza))
	if Giocatore.ARMI_DISTANZA.has(arma):
		g.arma_distanza = arma


func cancella() -> void:
	Salvataggio.cancella(percorso)
	dati = {}


func descrizione() -> String:
	# Per il tasto "Continua": "Sogno 3 · seconda ondata".
	if not esiste():
		return ""
	var nomi := ["", "prima", "seconda", "terza", "quarta", "quinta", "sesta"]
	var o := int(dati.get("ondata", 1))
	var testo := "Sogno %d · %s ondata" % [int(dati.get("sogno", 1)), nomi[o] if o < nomi.size() else str(o) + "ª"]
	if bool(dati.get("completato", false)):
		testo = "Sogno %d · tutte le ondate superate" % int(dati.get("sogno", 1))
	return testo


func _process(delta: float) -> void:
	if not attiva or get_tree().paused:
		return
	_t += delta
	if _t >= OGNI:
		salva(get_tree().current_scene)


func _notification(cosa: int) -> void:
	if cosa in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if attiva and is_inside_tree():
			salva(get_tree().current_scene)
