extends Node
# Comandi del gioco: tastiera, controller (integrato o Bluetooth) e tasti a schermo.
# Capisce da solo quale si sta usando e avvisa l'interfaccia quando cambia.

signal modo_cambiato(touch: bool)

const ZONA_MORTA := 0.35

var touch := false           # true = si gioca con i tasti a schermo
var controller := ""         # nome del controller collegato, se c'è
var cambi_modo := 0
var ritmi_chiesti := {}      # nome del ritmo -> quante volte (anche con la vibrazione spenta: serve a prove e rapporto)
var _sequenza := 0           # numero del ritmo in corso: un ritmo nuovo interrompe quello vecchio

# Vibrazione a ritmi (0.1.43): ogni evento ha il suo disegno, [forza 0-1, durata s, pausa dopo s] per passo.
# Colpi leggeri = un tocco corto e debole; pesanti = più lunghi; parata perfetta = doppio colpetto;
# esecuzione = tre colpi che crescono e uno lungo.
const RITMI := {
	"colpo_leggero": [[0.3, 0.05, 0.0]],
	"colpo_medio": [[0.5, 0.08, 0.0]],
	"colpo_pesante": [[0.85, 0.07, 0.04], [0.55, 0.12, 0.0]],
	"colpo_caricato": [[0.5, 0.05, 0.04], [1.0, 0.16, 0.05], [0.5, 0.1, 0.0]],
	"carica_piena": [[0.35, 0.04, 0.05], [0.6, 0.06, 0.0]],
	"parata": [[0.45, 0.06, 0.0]],
	"parata_perfetta": [[0.9, 0.04, 0.06], [0.9, 0.04, 0.0]],
	"deviazione": [[0.6, 0.03, 0.05], [0.35, 0.07, 0.0]],
	"esecuzione": [[0.3, 0.05, 0.04], [0.5, 0.06, 0.04], [0.75, 0.08, 0.05], [1.0, 0.22, 0.0]],
	"ferito": [[0.8, 0.2, 0.0]],
	"atterraggio": [[0.2, 0.05, 0.0]],
	"atterraggio_pesante": [[0.55, 0.1, 0.04], [0.3, 0.1, 0.0]],
	"ultimo_nemico": [[0.4, 0.08, 0.07], [0.7, 0.14, 0.08], [0.3, 0.3, 0.0]],
	"morte": [[1.0, 0.25, 0.08], [0.7, 0.4, 0.0]],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_definisci_azioni()
	Input.joy_connection_changed.connect(_su_controller)
	var collegati := Input.get_connected_joypads()
	if not collegati.is_empty():
		controller = Input.get_joy_name(collegati[0])
		touch = false
	else:
		touch = DisplayServer.is_touchscreen_available()
	Impostazioni.cambiata.connect(_su_impostazione)
	_applica_zona_morta()
	_applica_modo()


func _su_impostazione(chiave: String) -> void:
	if chiave == "controlli/zona_morta":
		_applica_zona_morta()
	elif chiave == "controlli/modo":
		_applica_modo()


func _applica_zona_morta() -> void:
	var zona: float = clampf(Impostazioni.leggi("controlli/zona_morta"), 0.05, 0.9)
	for nome in ["sinistra", "destra", "su", "giu"]:
		if InputMap.has_action(nome):
			InputMap.action_set_deadzone(nome, zona)


func modo_forzato() -> String:
	# "auto" = si capisce da solo; "touch" o "controller" = scelto nelle impostazioni.
	return String(Impostazioni.leggi("controlli/modo"))


func _applica_modo() -> void:
	var forzato := modo_forzato()
	var nuovo := touch
	if forzato == "touch":
		nuovo = true
	elif forzato == "controller":
		nuovo = false
	if nuovo != touch:
		touch = nuovo
		cambi_modo += 1
		modo_cambiato.emit(touch)


func _definisci_azioni() -> void:
	# Nomi dei pulsanti secondo lo schema Xbox: A=0, B=1, X=2, Y=3.
	_azione("sinistra", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_azione("destra", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_azione("su", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_azione("giu", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_azione("salta", [KEY_SPACE], [JOY_BUTTON_A])
	_azione("attacca", [KEY_J], [JOY_BUTTON_X])
	_azione("rotola", [KEY_K], [JOY_BUTTON_B])
	_azione("schiva", [KEY_L], [JOY_BUTTON_Y])
	_azione("afferra", [KEY_E], [JOY_BUTTON_LEFT_SHOULDER])
	_azione("tira", [KEY_I], [JOY_BUTTON_RIGHT_SHOULDER], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_azione("cambia_arma", [KEY_Q], [], JOY_AXIS_TRIGGER_LEFT, 1.0)
	_azione("pausa", [KEY_ESCAPE], [JOY_BUTTON_START])
	_azione("debug", [KEY_F3], [JOY_BUTTON_BACK])


func _azione(nome: String, tasti: Array, pulsanti: Array, asse: int = -1, verso: float = 0.0) -> void:
	if not InputMap.has_action(nome):
		InputMap.add_action(nome, ZONA_MORTA)
	for tasto: int in tasti:
		var e := InputEventKey.new()
		e.physical_keycode = tasto as Key
		e.device = -1
		InputMap.action_add_event(nome, e)
	for pulsante: int in pulsanti:
		var e := InputEventJoypadButton.new()
		e.button_index = pulsante as JoyButton
		e.device = -1
		InputMap.action_add_event(nome, e)
	if asse >= 0:
		var e := InputEventJoypadMotion.new()
		e.axis = asse as JoyAxis
		e.axis_value = verso
		e.device = -1
		InputMap.action_add_event(nome, e)


func _input(evento: InputEvent) -> void:
	# Vale l'ultimo comando usato: tocco lo schermo -> tasti a schermo; premo un tasto fisico -> spariscono.
	if modo_forzato() != "auto":
		return
	var nuovo := touch
	if evento is InputEventScreenTouch or evento is InputEventScreenDrag:
		nuovo = true
	elif evento is InputEventJoypadButton:
		nuovo = false
	elif evento is InputEventJoypadMotion:
		if absf((evento as InputEventJoypadMotion).axis_value) > 0.5:
			nuovo = false
	elif evento is InputEventKey and not evento.is_echo():
		nuovo = false
	if nuovo != touch:
		touch = nuovo
		cambi_modo += 1
		modo_cambiato.emit(touch)
		Rapporto.evento("comandi", {"modo": nome_modo()})


func _su_controller(dispositivo: int, collegato: bool) -> void:
	if modo_forzato() != "auto":
		controller = Input.get_joy_name(dispositivo) if collegato else ""
		Rapporto.evento("controller", {"collegato": collegato, "nome": Input.get_joy_name(dispositivo), "guid": Input.get_joy_guid(dispositivo)})
		return
	if collegato:
		controller = Input.get_joy_name(dispositivo)
		if touch:
			touch = false
			cambi_modo += 1
			modo_cambiato.emit(touch)
	else:
		var rimasti := Input.get_connected_joypads()
		controller = Input.get_joy_name(rimasti[0]) if not rimasti.is_empty() else ""
		if rimasti.is_empty() and DisplayServer.is_touchscreen_available() and not touch:
			touch = true
			cambi_modo += 1
			modo_cambiato.emit(touch)
	Rapporto.evento("controller", {"collegato": collegato, "nome": Input.get_joy_name(dispositivo), "guid": Input.get_joy_guid(dispositivo)})


func nome_modo() -> String:
	if touch:
		return "touch"
	return "controller" if controller != "" else "tastiera"


func vibra(forza: float, durata: float) -> void:
	if not Impostazioni.leggi("controlli/vibrazione"):
		return
	forza *= clampf(Impostazioni.leggi("controlli/forza_vibrazione"), 0.1, 1.0)
	if touch:
		Input.vibrate_handheld(int(durata * 1000.0), clampf(forza, 0.05, 1.0))
	else:
		for dispositivo in Input.get_connected_joypads():
			Input.start_joy_vibration(dispositivo, forza * 0.6, forza, durata)


func vibra_ritmo(nome: String) -> void:
	# Un ritmo di RITMI. Si conta sempre (anche a vibrazione spenta: il bot la spegne); suona passo dopo passo
	# con timer che non risentono del rallentatore né della pausa.
	ritmi_chiesti[nome] = int(ritmi_chiesti.get(nome, 0)) + 1
	if not RITMI.has(nome) or not Impostazioni.leggi("controlli/vibrazione"):
		return
	_sequenza += 1
	var mia := _sequenza
	var passi: Array = RITMI[nome]
	for i in passi.size():
		var passo: Array = passi[i]
		vibra(float(passo[0]), float(passo[1]))
		var attesa := float(passo[1]) + float(passo[2])
		if i == passi.size() - 1:
			return
		await get_tree().create_timer(attesa, true, false, true).timeout
		if mia != _sequenza:
			return   # è arrivato un ritmo più recente


func elenco_controller() -> Array:
	var elenco: Array = []
	for dispositivo in Input.get_connected_joypads():
		elenco.append({"id": dispositivo, "nome": Input.get_joy_name(dispositivo), "guid": Input.get_joy_guid(dispositivo)})
	return elenco
