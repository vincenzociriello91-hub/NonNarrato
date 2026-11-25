extends Node
# Comandi del gioco: tastiera, controller (integrato o Bluetooth) e tasti a schermo.
# Capisce da solo quale si sta usando e avvisa l'interfaccia quando cambia.

signal modo_cambiato(touch: bool)

const ZONA_MORTA := 0.35

var touch := false           # true = si gioca con i tasti a schermo
var controller := ""         # nome del controller collegato, se c'è
var cambi_modo := 0


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


func _definisci_azioni() -> void:
	# Nomi dei pulsanti secondo lo schema Xbox: A=0, B=1, X=2, Y=3.
	_azione("sinistra", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_azione("destra", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_azione("su", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_azione("giu", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_azione("salta", [KEY_SPACE], [JOY_BUTTON_A])
	_azione("attacca", [KEY_J], [JOY_BUTTON_X])
	_azione("rotola", [KEY_K], [JOY_BUTTON_B])
	_azione("schiva", [KEY_L], [JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER])
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
	if touch:
		Input.vibrate_handheld(int(durata * 1000.0), clampf(forza, 0.05, 1.0))
	else:
		for dispositivo in Input.get_connected_joypads():
			Input.start_joy_vibration(dispositivo, forza * 0.6, forza, durata)


func elenco_controller() -> Array:
	var elenco: Array = []
	for dispositivo in Input.get_connected_joypads():
		elenco.append({"id": dispositivo, "nome": Input.get_joy_name(dispositivo), "guid": Input.get_joy_guid(dispositivo)})
	return elenco
