extends Node
# Riconosce il dispositivo su cui gira il gioco, sceglie il livello di qualità
# e lo abbassa da solo se il dispositivo scalda o se il gioco va a scatti.
# Regola fissa: la salute del dispositivo viene prima della grafica.

signal profilo_cambiato

const ALTEZZA_BASE := 360
const LIVELLI: Array[String] = ["bassa", "media", "alta"]
const PROFILI := {
	"bassa": {"luci_con_ombra": 0, "ombre_morbide": false, "luci_doppie": false, "particelle": 0.4, "nebbia": false},
	"media": {"luci_con_ombra": 2, "ombre_morbide": false, "luci_doppie": true, "particelle": 0.7, "nebbia": true},
	"alta": {"luci_con_ombra": 4, "ombre_morbide": true, "luci_doppie": true, "particelle": 1.0, "nebbia": true},
}
const GPU_FORTI: Array[String] = [
	"adreno (tm) 7", "adreno (tm) 8", "adreno 7", "adreno 8", "immortalis",
	"mali-g71", "mali-g72", "mali-g78", "mali-g9", "xclipse 9", "apple", "nvidia", "geforce", "radeon rx",
]
const SEGNO_JNI := "user://lettura_android_in_corso"

var info := {}
var livello_consigliato := "media"
var livello := "media"
var profilo := {}
var fps_obiettivo := 60
var stato_termico := -1          # 0 nessuno ... 6 spegnimento; -1 = non disponibile
var margine_termico := -1.0      # 1.0 = soglia "grave"; -1 = non disponibile
var batteria := -1
var riduzione_caldo := 0
var riduzione_scatti := 0
var letture_android := false
var forzato := ""                # livello imposto da riga di comando (prove)
var in_prova := false

var _tempo := 0.0
var _fotogrammi := 0
var _finestre_lente := 0
var _attesa_iniziale := 8.0
var _fps_prima_di_ridurre := 0.0
var _finestre_di_verifica := 0
var _adattamento_fermo := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qualita="):
			forzato = arg.trim_prefix("--qualita=")
		elif arg == "--prova":
			in_prova = true
	_leggi_hardware()
	_prepara_letture_android()
	_leggi_android()
	livello_consigliato = _consiglia()
	Impostazioni.cambiata.connect(func(_chiave: String) -> void: applica())
	applica()
	var timer := Timer.new()
	timer.wait_time = 8.0
	timer.autostart = true
	timer.timeout.connect(_controllo_periodico)
	add_child(timer)


func _leggi_hardware() -> void:
	var memoria := OS.get_memory_info()
	var ram: int = int(memoria.get("physical", -1))
	var schermo := DisplayServer.screen_get_size()
	var sicura := DisplayServer.get_display_safe_area()
	var ritagli: Array = []
	for r: Rect2 in DisplayServer.get_display_cutouts():
		ritagli.append([int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)])
	info = {
		"sistema": OS.get_name(),
		"distribuzione": OS.get_distribution_name(),
		"versione_sistema": OS.get_version(),
		"modello": OS.get_model_name(),
		"processore": OS.get_processor_name(),
		"core": OS.get_processor_count(),
		"ram_mb": int(ram / 1048576.0) if ram > 0 else -1,
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_produttore": RenderingServer.get_video_adapter_vendor(),
		"gpu_api": RenderingServer.get_video_adapter_api_version(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver_grafico": RenderingServer.get_current_rendering_driver_name(),
		"schermo": [schermo.x, schermo.y],
		"dpi": DisplayServer.screen_get_dpi(),
		"hz": _frequenza_schermo(),
		"touch": DisplayServer.is_touchscreen_available(),
		"area_sicura": [sicura.position.x, sicura.position.y, sicura.size.x, sicura.size.y],
		"ritagli": ritagli,
		"lingua": OS.get_locale_language(),
	}


func _frequenza_schermo() -> float:
	# Alcuni sistemi non la dichiarano: in quel caso -1.
	var hz := DisplayServer.screen_get_refresh_rate()
	if not is_finite(hz) or hz <= 0.0:
		return -1.0
	return snappedf(hz, 0.1)


func _prepara_letture_android() -> void:
	# Batteria e temperatura si leggono parlando direttamente con Android.
	# Se una lettura non finisce (il gioco si è chiuso a metà), al riavvio non riprovo.
	letture_android = false
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	if FileAccess.file_exists(SEGNO_JNI):
		info["letture_android"] = "saltate: la volta scorsa non sono finite"
		return
	letture_android = true
	info["letture_android"] = "attive"


func _leggi_android() -> void:
	if not letture_android:
		return
	var segno := FileAccess.open(SEGNO_JNI, FileAccess.WRITE)
	if segno != null:
		segno.store_string("1")
		segno.close()
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var attivita: Variant = runtime.call("getActivity")
	if attivita != null:
		var android := OS.get_version().to_int()
		var gestore_batteria: Variant = attivita.call("getSystemService", "batterymanager")
		if gestore_batteria != null:
			var carica: Variant = gestore_batteria.call("getIntProperty", 4)  # BATTERY_PROPERTY_CAPACITY
			if typeof(carica) == TYPE_INT:
				batteria = carica
		if not info.has("poca_memoria"):
			# Android dichiara da sé se il dispositivo è "a poca memoria".
			var gestore_attivita: Variant = attivita.call("getSystemService", "activity")
			if gestore_attivita != null:
				var poca: Variant = gestore_attivita.call("isLowRamDevice")
				info["poca_memoria"] = poca if typeof(poca) == TYPE_BOOL else false
		var gestore_energia: Variant = attivita.call("getSystemService", "power")
		if gestore_energia != null and android >= 10:
			var stato: Variant = gestore_energia.call("getCurrentThermalStatus")
			if typeof(stato) == TYPE_INT:
				stato_termico = stato
			if android >= 11:
				var margine: Variant = gestore_energia.call("getThermalHeadroom", 0)
				if typeof(margine) == TYPE_FLOAT and not is_nan(margine):
					margine_termico = margine
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEGNO_JNI))


func _consiglia() -> String:
	var gpu := String(info.get("gpu", "")).to_lower()
	var ram: int = info.get("ram_mb", -1)
	var core: int = info.get("core", 4)
	if (ram > 0 and ram < 3500) or core <= 4 or info.get("poca_memoria", false):
		return "bassa"
	for chiave in GPU_FORTI:
		if gpu.contains(chiave) and (ram < 0 or ram >= 5500):
			return "alta"
	return "media"


func applica() -> void:
	var scelta: String = Impostazioni.leggi("grafica/qualita")
	if forzato != "":
		scelta = forzato
	var automatica := scelta == "auto"
	var indice := LIVELLI.find(livello_consigliato if automatica else scelta)
	if indice < 0:
		indice = 1
	# Il caldo abbassa sempre la qualità; gli scatti solo se la scelta è automatica.
	indice -= riduzione_caldo
	if automatica:
		indice -= riduzione_scatti
	livello = LIVELLI[maxi(0, indice)]
	profilo = (PROFILI[livello] as Dictionary).duplicate()
	if not Impostazioni.leggi("grafica/ombre"):
		profilo["luci_con_ombra"] = 0
	profilo["palette"] = Impostazioni.leggi("grafica/palette")
	var limite: int = Impostazioni.leggi("grafica/limite_fps")
	fps_obiettivo = limite if limite > 0 else 60
	if riduzione_caldo >= 2:
		fps_obiettivo = mini(fps_obiettivo, 30)
	elif riduzione_caldo == 1:
		fps_obiettivo = mini(fps_obiettivo, 60)
	if not in_prova:
		Engine.max_fps = fps_obiettivo
	profilo_cambiato.emit()


func risoluzione_interna(finestra: Vector2i) -> Dictionary:
	# Ogni pixel del gioco occupa un numero intero di pixel dello schermo:
	# così la pixel art resta nitida su qualsiasi risoluzione.
	var scala := maxi(1, roundi(float(finestra.y) / float(ALTEZZA_BASE)))
	var dimensione := Vector2i(ceili(float(finestra.x) / scala), ceili(float(finestra.y) / scala))
	return {"scala": scala, "dimensione": dimensione}


func _process(delta: float) -> void:
	if _attesa_iniziale > 0.0:
		_attesa_iniziale -= delta
		return
	if in_prova or _adattamento_fermo or get_tree().paused:
		return
	_tempo += delta
	_fotogrammi += 1
	if _tempo < 4.0:
		return
	var medio := float(_fotogrammi) / _tempo
	_tempo = 0.0
	_fotogrammi = 0
	if _finestre_di_verifica > 0:
		# Ho appena abbassato la qualità: se non è servito, il problema non è la grafica.
		_finestre_di_verifica -= 1
		if _finestre_di_verifica == 0 and medio < _fps_prima_di_ridurre * 1.1:
			riduzione_scatti = maxi(0, riduzione_scatti - 1)
			_adattamento_fermo = true
			_evento("qualita_ripristinata", {"fps_prima": snappedf(_fps_prima_di_ridurre, 0.1), "fps_dopo": snappedf(medio, 0.1)})
			applica()
		return
	var hz: float = info.get("hz", 60.0)
	var atteso := float(fps_obiettivo)
	if hz > 1.0:
		atteso = minf(atteso, hz)
	if medio < atteso * 0.75:
		_finestre_lente += 1
	else:
		_finestre_lente = 0
	if _finestre_lente < 2:
		return
	_finestre_lente = 0
	if Impostazioni.leggi("grafica/qualita") != "auto" or forzato != "" or LIVELLI.find(livello) <= 0:
		return
	_fps_prima_di_ridurre = medio
	_finestre_di_verifica = 2
	riduzione_scatti += 1
	_evento("qualita_ridotta", {"motivo": "scatti", "fps": snappedf(medio, 0.1)})
	applica()


func _controllo_periodico() -> void:
	if not letture_android:
		return
	_leggi_android()
	var nuova := 0
	if stato_termico >= 3:
		nuova = 2
	elif stato_termico == 2:
		nuova = 1
	var rapporto := get_node_or_null("/root/Rapporto")
	if rapporto != null:
		rapporto.lettura_termica(stato_termico, margine_termico, batteria)
	if nuova != riduzione_caldo:
		riduzione_caldo = nuova
		_evento("termico", {"stato": stato_termico, "margine": snappedf(margine_termico, 0.01), "riduzione": nuova})
		applica()


func _evento(tipo: String, dati: Dictionary) -> void:
	var rapporto := get_node_or_null("/root/Rapporto")
	if rapporto != null:
		rapporto.evento(tipo, dati)


func righe_debug() -> PackedStringArray:
	var righe := PackedStringArray()
	righe.append("%s  %s %s" % [info.get("modello", "?"), info.get("distribuzione", ""), info.get("versione_sistema", "")])
	var ram: int = info.get("ram_mb", -1)
	var testo_ram := ("%d MB" % ram) if ram > 0 else "memoria n.d."
	righe.append(("%s  (%d core, %s)" % [info.get("processore", ""), info.get("core", 0), testo_ram]).strip_edges())
	righe.append("%s  [%s/%s]" % [info.get("gpu", "?"), info.get("renderer", "?"), info.get("driver_grafico", "?")])
	var schermo: Array = info.get("schermo", [0, 0])
	righe.append("Schermo %dx%d  %s Hz  %d dpi" % [schermo[0], schermo[1], str(info.get("hz", 0)), info.get("dpi", 0)])
	var termico := "n.d."
	if stato_termico >= 0:
		termico = str(stato_termico)
		if margine_termico >= 0.0:
			termico += " (margine %.2f)" % margine_termico
	righe.append("Qualità %s (consigliata %s)  obiettivo %d FPS" % [livello, livello_consigliato, fps_obiettivo])
	righe.append("Calore %s  batteria %s" % [termico, (str(batteria) + "%") if batteria >= 0 else "n.d."])
	return righe
