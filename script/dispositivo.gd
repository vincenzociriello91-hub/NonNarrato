extends Node
# Riconosce il dispositivo su cui gira il gioco, sceglie il livello di qualità
# e lo abbassa da solo se il dispositivo scalda, se il gioco va a scatti o se il telefono
# è in risparmio energetico (o nella modalità gioco "batteria" di Android).
# Sul telefono il plugin legge memoria, processore, versione di Android, classe di prestazioni,
# spazio libero e sensori (infoDispositivo) e lo stato dell'energia (statoEnergia).
# Regola fissa: la salute del dispositivo viene prima della grafica.

signal profilo_cambiato
signal audio_cambiato

const ALTEZZA_BASE := 360
const LIVELLI: Array[String] = ["bassa", "media", "alta", "ultra"]
const PROFILI := {
	# Ombre delle torce: le ombre del motore facevano strisce scure fino al soffitto (Vincenzo, 26/11/2026) e furono
	# spente; dalla 0.1.32 le fa il materiale del muro, corte e sfumate (Effetti.materiale_muro): "luci_con_ombra" 0/1.
	# I corpi hanno ombre corte e sfumate (Ombra): "ombre_corpi" = quante luci danno la sagoma (0 = solo la macchia).
	# "figure" (0.1.37): personaggi e nemici in doppia definizione, con il mondo disegnato al doppio (vedi densita_figure).
	# "campo_largo" (0.1.43): la telecamera da regista allarga l'inquadratura nei saloni alti (solo con le figure doppie).
	"bassa": {"luci_con_ombra": 0, "ombre_corpi": 0, "ombre_morbide": false, "luci_doppie": false, "particelle": 0.4, "nebbia": false, "figura_normali": false, "bagliore": 0, "raggi": false, "toni": false, "figure": false, "campo_largo": false},
	"media": {"luci_con_ombra": 1, "ombre_corpi": 1, "ombre_morbide": false, "luci_doppie": true, "particelle": 0.7, "nebbia": true, "figura_normali": true, "bagliore": 1, "raggi": true, "toni": true, "figure": false, "campo_largo": false},
	"alta": {"luci_con_ombra": 1, "ombre_corpi": 2, "ombre_morbide": true, "luci_doppie": true, "particelle": 1.0, "nebbia": true, "figura_normali": true, "bagliore": 1, "raggi": true, "toni": true, "figure": true, "campo_largo": true},
	# Ultra (0.1.36): solo per i telefoni più potenti del Pixel 8 Pro (il più debole su cui tutto deve girare bene in "alta").
	"ultra": {"luci_con_ombra": 1, "ombre_corpi": 2, "ombre_morbide": true, "luci_doppie": true, "particelle": 1.4, "nebbia": true, "figura_normali": true, "bagliore": 2, "raggi": true, "toni": true, "figure": true, "campo_largo": true},
}
# Grafica da "ultra": più potente di quella del Pixel 8 Pro (Mali-G715), con molta memoria.
const GPU_ULTRA: Array[String] = ["adreno (tm) 75", "adreno 75", "adreno (tm) 8", "adreno 8", "immortalis-g72", "immortalis-g92", "immortalis-g93"]
const GPU_FORTI: Array[String] = [
	"adreno (tm) 7", "adreno (tm) 8", "adreno 7", "adreno 8", "immortalis",
	"mali-g71", "mali-g72", "mali-g78", "mali-g9", "xclipse 9", "apple", "nvidia", "geforce", "radeon rx",
]
# Nomi commerciali dei processori più comuni (Android dà solo la sigla).
const NOMI_PROCESSORI := {
	"SM8750": "Snapdragon 8 Elite", "SM8650": "Snapdragon 8 Gen 3", "SM8635": "Snapdragon 8s Gen 3",
	"SM8550": "Snapdragon 8 Gen 2", "SM8475": "Snapdragon 8+ Gen 1", "SM8450": "Snapdragon 8 Gen 1",
	"SM8350": "Snapdragon 888", "SM8250": "Snapdragon 865", "SM7675": "Snapdragon 7+ Gen 3",
	"SM7550": "Snapdragon 7 Gen 3", "SM6450": "Snapdragon 6 Gen 1",
	"GS101": "Google Tensor", "GS201": "Google Tensor G2", "ZUMA": "Google Tensor G3", "ZUMAPRO": "Google Tensor G4",
	"GS301": "Google Tensor G3", "GS401": "Google Tensor G4", "LAGUNA": "Google Tensor G5",
}
const MODI_GIOCO := {0: "non disponibile", 1: "normale", 2: "prestazioni", 3: "batteria", 4: "personalizzata"}
const SEGNO_JNI := "user://lettura_android_in_corso"
const SEGNO_FREQUENZA := "user://frequenza_in_corso"
const TASTO_COLPO_MM := 13.0      # diametro voluto del tasto principale a schermo

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
var bot_attivo := false          # mentre gioca il bot la qualità non si adatta da sola (misure pulite)
var sdk := 0                     # livello delle API di Android (0 = non Android)

var _frequenza_chiesta := 0
var _esito_frequenza := ""
var plugin: Object = null        # plugin Android di NonNarrato (vedi android_plugin/), se c'è
var modi_schermo: Array = []     # [{id, w, h, hz}] letti da Android
var modo_attuale := 0
var hdr := false
var uscita_audio := ""           # altoparlante, cuffie, bluetooth, usb, hdmi, altro ("" = non si sa)
var suoneria := -1               # 0 silenzioso, 1 vibrazione, 2 normale, -1 non si sa
var _modo_chiesto := -1
var risparmio_energetico := -1   # 1 = attivo, 0 = no, -1 = non si sa
var modalita_gioco := 0          # vedi MODI_GIOCO
var riduzione_energia := 0       # 1 = risparmio energetico o modalità "batteria": qualità e FPS più bassi
var motivo_consiglio := ""       # perché il gioco ha scelto quel livello (si legge nel menu)

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
	if Engine.has_singleton("NonNarratoAndroid"):
		plugin = Engine.get_singleton("NonNarratoAndroid")
	_prepara_letture_android()
	_leggi_android()
	var scelta := consiglia_da(info)
	livello_consigliato = scelta[0]
	motivo_consiglio = scelta[1]
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
		if sdk == 0:
			var versione: Variant = JavaClassWrapper.wrap("android.os.Build$VERSION").get("SDK_INT")
			sdk = versione if typeof(versione) == TYPE_INT else 0
			info["sdk"] = sdk
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
		if gestore_energia != null and sdk >= 29:
			var stato: Variant = gestore_energia.call("getCurrentThermalStatus")
			if typeof(stato) == TYPE_INT:
				stato_termico = stato
			if sdk >= 30:
				var margine: Variant = gestore_energia.call("getThermalHeadroom", 0)
				if typeof(margine) == TYPE_FLOAT and not is_nan(margine):
					margine_termico = margine
	if plugin != null:
		_leggi_plugin()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEGNO_JNI))


func _leggi_plugin() -> void:
	# Modi dello schermo (una volta sola), uscita del suono e suoneria (a ogni controllo).
	if modi_schermo.is_empty():
		var testo := String(plugin.call("modiSchermo"))
		var parti := testo.split("|")
		for voce in parti[0].split(";", false):
			var v := voce.split(",")
			if v.size() == 4:
				modi_schermo.append({"id": v[0].to_int(), "w": v[1].to_int(), "h": v[2].to_int(), "hz": snappedf(v[3].to_float(), 0.1)})
		if parti.size() >= 3:
			modo_attuale = parti[1].to_int()
			hdr = parti[2] == "1"
		info["modi_schermo"] = modi_schermo
		info["hdr"] = hdr
		info["installatore"] = String(plugin.call("installatore"))
		_unisci_info(String(plugin.call("infoDispositivo")))
	var energia := String(plugin.call("statoEnergia")).split("|")
	if energia.size() == 2:
		aggiorna_energia(energia[0].to_int(), energia[1].to_int())
	var uscita := String(plugin.call("uscitaAudio"))
	var squillo := int(plugin.call("suoneria"))
	if uscita != uscita_audio or squillo != suoneria:
		var prima := uscita_audio
		uscita_audio = uscita
		suoneria = squillo
		info["uscita_audio"] = uscita
		if prima != "":
			_evento("uscita_audio", {"uscita": uscita, "suoneria": squillo})
		audio_cambiato.emit()


func _unisci_info(testo: String) -> void:
	# Quello che legge il plugin prende il posto dei valori vuoti di Godot (memoria, processore).
	var dati: Variant = JSON.parse_string(testo)
	if typeof(dati) != TYPE_DICTIONARY:
		info["info_plugin"] = "illeggibile"
		return
	var d: Dictionary = dati
	for chiave: String in d:
		if chiave in ["modello", "core"]:
			continue
		info[chiave] = d[chiave]
	if int(d.get("core", 0)) > 0:
		info["core"] = int(d["core"])
	if String(d.get("modello", "")) != "":
		info["modello"] = "%s %s" % [String(d.get("produttore", "")).capitalize(), d["modello"]]
	info["ram_mb"] = int(d.get("ram_mb", info.get("ram_mb", -1)))
	info["processore"] = nome_processore(d)
	info["versione_sistema"] = "Android %s" % d.get("android", "?")
	var scelta := consiglia_da(info)
	livello_consigliato = scelta[0]
	motivo_consiglio = scelta[1]


static func nome_processore(d: Dictionary) -> String:
	var sigla := String(d.get("soc_modello", "")).strip_edges()
	if sigla == "" or sigla == "unknown":
		sigla = String(d.get("hardware", "")).strip_edges()
	var nome: String = NOMI_PROCESSORI.get(sigla.to_upper(), "")
	var produttore := String(d.get("soc_produttore", "")).strip_edges()
	if nome != "":
		return "%s (%s)" % [nome, sigla]
	if produttore != "" and produttore.to_lower() != "unknown":
		return "%s %s" % [produttore, sigla]
	return sigla


static func consiglia_da(dati: Dictionary) -> Array:
	# [livello, motivo]. Poca memoria o pochi core: bassa. Grafica forte (o classe di prestazioni alta di
	# Android) con memoria sufficiente: alta. Il resto: media.
	var gpu := String(dati.get("gpu", "")).to_lower()
	var ram: int = int(dati.get("ram_mb", -1))
	var core: int = int(dati.get("core", 4))
	var classe: int = int(dati.get("classe_prestazioni", 0))
	if dati.get("poca_memoria", false):
		return ["bassa", "Android lo dichiara un dispositivo a poca memoria"]
	if ram > 0 and ram < 3500:
		return ["bassa", "memoria di %.1f GB" % (ram / 1024.0)]
	if core <= 4:
		return ["bassa", "%d core" % core]
	var memoria_ok := ram < 0 or ram >= 5500
	for chiave in GPU_ULTRA:
		if gpu.contains(chiave) and ram >= 11000:
			return ["ultra", "grafica molto potente (%s), %.0f GB" % [dati.get("gpu", "?"), ram / 1024.0]]
	for chiave in GPU_FORTI:
		if gpu.contains(chiave) and memoria_ok:
			return ["alta", "grafica potente (%s)%s" % [dati.get("gpu", "?"), (", %.0f GB" % (ram / 1024.0)) if ram > 0 else ""]]
	if classe >= 33 and memoria_ok:
		return ["alta", "Android lo dichiara di classe prestazioni %d" % classe]
	return ["media", "dispositivo di fascia media"]


func aggiorna_energia(risparmio: int, modo: int) -> void:
	# Risparmio energetico o modalità gioco "batteria": un livello in meno e 30 FPS (solo con le scelte
	# automatiche). La modalità "prestazioni" scelta per il gioco vince sul risparmio.
	var nuova := 1 if (risparmio == 1 or modo == 3) and modo != 2 else 0
	var cambiato := risparmio != risparmio_energetico or modo != modalita_gioco
	risparmio_energetico = risparmio
	modalita_gioco = modo
	info["risparmio_energetico"] = risparmio
	info["modalita_gioco"] = MODI_GIOCO.get(modo, str(modo))
	if nuova != riduzione_energia:
		riduzione_energia = nuova
		_evento("energia", {"risparmio": risparmio, "modalita_gioco": info["modalita_gioco"], "riduzione": nuova})
		applica()
	elif cambiato:
		profilo_cambiato.emit()


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
		indice -= riduzione_scatti + riduzione_energia
	livello = LIVELLI[maxi(0, indice)]
	profilo = (PROFILI[livello] as Dictionary).duplicate()
	profilo["primo_piano"] = livello != "bassa"
	profilo["atlante_ombre"] = 2048 if livello in ["alta", "ultra"] else 1024
	# Dettagli scelti a mano (-1 = come il livello). Il caldo vince sempre: con il dispositivo caldo
	# le ombre scelte a mano si riducono comunque.
	var scelti := {
		"luci_con_ombra": int(Impostazioni.leggi("grafica/luci_ombra")),
		"ombre_corpi": int(Impostazioni.leggi("grafica/ombre_corpi")),
		"ombre_morbide": int(Impostazioni.leggi("grafica/ombre_morbide")),
		"luci_doppie": int(Impostazioni.leggi("grafica/luci_doppie")),
		"figura_normali": int(Impostazioni.leggi("grafica/normali_figura")),
		"nebbia": int(Impostazioni.leggi("grafica/nebbia")),
		"primo_piano": int(Impostazioni.leggi("grafica/primo_piano")),
		"atlante_ombre": int(Impostazioni.leggi("grafica/atlante_ombre")),
		"bagliore": int(Impostazioni.leggi("grafica/bagliore")),
		"raggi": int(Impostazioni.leggi("grafica/raggi")),
		"toni": int(Impostazioni.leggi("grafica/toni")),
		"figure": int(Impostazioni.leggi("grafica/figure")),
	}
	for chiave: String in scelti:
		var v: int = scelti[chiave]
		if v < 0:
			continue
		if chiave in ["luci_con_ombra", "ombre_corpi", "atlante_ombre", "bagliore"]:
			profilo[chiave] = mini(v, 1) if chiave == "luci_con_ombra" else v
		else:
			profilo[chiave] = v == 1
	var particelle: float = Impostazioni.leggi("grafica/particelle")
	if particelle > 0.0:
		profilo["particelle"] = particelle
	if riduzione_caldo > 0:
		profilo["luci_con_ombra"] = mini(int(profilo["luci_con_ombra"]), 2 - mini(riduzione_caldo, 2))
		profilo["ombre_corpi"] = mini(int(profilo["ombre_corpi"]), 2 - mini(riduzione_caldo, 2))
		profilo["particelle"] = minf(float(profilo["particelle"]), 0.7 if riduzione_caldo == 1 else 0.4)
		profilo["bagliore"] = mini(int(profilo["bagliore"]), 2 - mini(riduzione_caldo, 2))
		profilo["raggi"] = bool(profilo["raggi"]) and riduzione_caldo < 2
		profilo["figure"] = false   # il mondo al doppio costa: col caldo si torna alla definizione normale
		profilo["campo_largo"] = false   # e la telecamera larga con lui (vedi Regia)
	profilo["palette"] = Impostazioni.leggi("grafica/palette")
	RenderingServer.canvas_set_shadow_texture_size(int(profilo["atlante_ombre"]))
	var limite: int = Impostazioni.leggi("grafica/limite_fps")
	fps_obiettivo = limite if limite > 0 else 60
	if limite <= 0 and riduzione_energia > 0:
		fps_obiettivo = 30   # risparmio energetico: il telefono va trattato con riguardo
	if riduzione_caldo >= 2:
		fps_obiettivo = mini(fps_obiettivo, 30)
	elif riduzione_caldo == 1:
		fps_obiettivo = mini(fps_obiettivo, 60)
	if not in_prova:
		Engine.max_fps = fps_obiettivo
		_applica_schermo()
	_richiedi_frequenza.call_deferred()
	profilo_cambiato.emit()


func _applica_schermo() -> void:
	# V-Sync, orientamento, schermo sempre acceso e, se scelto, un modo dello schermo (risoluzione e Hz).
	var vsync: bool = Impostazioni.leggi("schermo/vsync")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	DisplayServer.screen_set_keep_on(Impostazioni.leggi("schermo/sempre_acceso"))
	if OS.get_name() == "Android":
		var verso: String = Impostazioni.leggi("schermo/orientamento")
		var orientamento := DisplayServer.SCREEN_SENSOR_LANDSCAPE
		if verso == "normale":
			orientamento = DisplayServer.SCREEN_LANDSCAPE
		elif verso == "capovolto":
			orientamento = DisplayServer.SCREEN_REVERSE_LANDSCAPE
		DisplayServer.screen_set_orientation(orientamento)
	var modo: int = Impostazioni.leggi("schermo/modo")
	if plugin != null and letture_android and modo != _modo_chiesto and (modo > 0 or _modo_chiesto > 0):
		var hz := 0.0
		for m: Dictionary in modi_schermo:
			if int(m["id"]) == modo:
				hz = float(m["hz"])
		plugin.call("chiediModo", modo, hz)
		_modo_chiesto = modo
		_evento("modo_schermo", {"modo": modo, "hz": hz})


func fps_possibili() -> Array[int]:
	# Limiti di FPS che lo schermo regge davvero (30 e 60 sempre, 90 e 120 solo se il pannello li ha).
	var massimo := 60.0
	for m: Dictionary in modi_schermo:
		massimo = maxf(massimo, float(m["hz"]))
	var hz_info: float = info.get("hz", 60.0)
	massimo = maxf(massimo, hz_info)
	var elenco: Array[int] = [30, 60]
	for f in [90, 120, 144]:
		if massimo >= f - 1.0:
			elenco.append(f)
	return elenco


func risoluzioni_schermo() -> Array:
	# Una voce per ogni risoluzione del pannello, con la frequenza più alta: [{id, w, h, hz}].
	var per_dimensione := {}
	for m: Dictionary in modi_schermo:
		var chiave := "%dx%d" % [int(m["w"]), int(m["h"])]
		if not per_dimensione.has(chiave) or float(m["hz"]) > float(per_dimensione[chiave]["hz"]):
			per_dimensione[chiave] = m
	var elenco: Array = per_dimensione.values()
	elenco.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["w"]) * int(a["h"]) > int(b["w"]) * int(b["h"]))
	return elenco


func _notification(cosa: int) -> void:
	if cosa == NOTIFICATION_APPLICATION_RESUMED and _frequenza_chiesta > 0:
		# Tornando dal secondo piano Android può aver rifatto la superficie: richiedo di nuovo.
		_frequenza_chiesta = 0
		get_tree().create_timer(1.0).timeout.connect(_richiedi_frequenza)


# ------------------------------------------------------------------ frequenza dello schermo

func _richiedi_frequenza() -> void:
	# Su Android 15 e successivi (Pixel compresi) i giochi restano a 60 Hz finché non chiedono di più.
	# La richiesta parte solo se l'utente ha scelto più di 60 FPS, o per tornare a 60 dopo averne chiesti di più.
	if not letture_android or sdk < 30:
		return
	if fps_obiettivo == _frequenza_chiesta or (fps_obiettivo <= 60 and _frequenza_chiesta == 0):
		return
	if FileAccess.file_exists(SEGNO_FREQUENZA):
		info["frequenza"] = "saltata: la volta scorsa la richiesta non è finita"
		return
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var attivita: Variant = runtime.call("getActivity")
	if attivita == null:
		return
	var segno := FileAccess.open(SEGNO_FREQUENZA, FileAccess.WRITE)
	if segno != null:
		segno.store_string(str(fps_obiettivo))
		segno.close()
	_frequenza_chiesta = fps_obiettivo
	_esito_frequenza = ""
	var hz := float(fps_obiettivo)
	var livello_api := sdk
	# Le viste di Android si toccano solo dal loro thread: la richiesta passa da runOnUiThread.
	var lavoro := func() -> void:
		_esito_frequenza = _imposta_frequenza(attivita, hz, livello_api)
	attivita.call("runOnUiThread", runtime.call("createRunnableFromGodotCallable", lavoro))
	get_tree().create_timer(2.5).timeout.connect(_dopo_frequenza)


static func _imposta_frequenza(attivita: Variant, hz: float, livello_api: int) -> String:
	var finestra: Variant = attivita.call("getWindow")
	if finestra == null:
		return "finestra non trovata"
	var superficie_vista: Variant = _cerca_superficie(finestra.call("getDecorView"), 0)
	if superficie_vista == null:
		return "superficie non trovata"
	var contenitore: Variant = superficie_vista.call("getHolder")
	var superficie: Variant = contenitore.call("getSurface") if contenitore != null else null
	if superficie == null:
		return "superficie non pronta"
	if livello_api >= 31:
		superficie.call("setFrameRate", hz, 0, 1)  # compatibilità predefinita, cambio sempre permesso
	else:
		superficie.call("setFrameRate", hz, 0)
	var errore: Variant = JavaClassWrapper.get_exception()
	if errore != null:
		return "errore: " + str(errore.call("toString")).left(200)
	return "chiesti %d Hz" % int(hz)


static func _cerca_superficie(vista: Variant, profondita: int) -> Variant:
	if vista == null or profondita > 8:
		return null
	if vista.has_java_method("getHolder"):
		return vista
	if not vista.has_java_method("getChildCount"):
		return null
	var quanti: Variant = vista.call("getChildCount")
	if typeof(quanti) != TYPE_INT:
		return null
	for i in quanti:
		var trovata: Variant = _cerca_superficie(vista.call("getChildAt", i), profondita + 1)
		if trovata != null:
			return trovata
	return null


func _dopo_frequenza() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEGNO_FREQUENZA))
	info["frequenza"] = _esito_frequenza if _esito_frequenza != "" else "nessuna risposta"
	info["hz"] = _frequenza_schermo()
	_evento("frequenza", {"richiesta": _frequenza_chiesta, "esito": info["frequenza"], "hz_schermo": info["hz"]})


# ------------------------------------------------------------------ tasti a schermo

func scala_touch() -> float:
	# Grandezza dei tasti a schermo: quella scelta dall'utente, oppure quella adatta allo schermo.
	var scelta: float = Impostazioni.leggi("controlli/dimensione_touch")
	return scelta if scelta > 0.0 else scala_touch_consigliata()


func scala_touch_consigliata() -> float:
	# Il tasto "Colpo" deve misurare circa 13 mm sul vetro, qualunque sia il telefono.
	var dpi := float(DisplayServer.screen_get_dpi())
	var finestra := Vector2(DisplayServer.window_get_size())
	if dpi <= 0.0 or finestra.y <= 0.0 or not DisplayServer.is_touchscreen_available():
		return 1.0
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
			ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	var pixel_per_unita := minf(finestra.x / base.x, finestra.y / base.y)
	var mm_per_unita := pixel_per_unita / dpi * 25.4
	var diametro := 92.0 * mm_per_unita
	return clampf(snappedf(TASTO_COLPO_MM / maxf(diametro, 0.1), 0.05), 1.0, 1.6)


func area_di_gioco(finestra: Vector2i) -> Vector2i:
	# Con "16:9" il gioco resta in 16:9 e ai lati (o sopra e sotto) restano bande scure.
	if Impostazioni.leggi("schermo/proporzioni") != "16:9" or finestra.y <= 0:
		return finestra
	var voluto := 16.0 / 9.0
	if float(finestra.x) / float(finestra.y) > voluto:
		return Vector2i(roundi(finestra.y * voluto), finestra.y)
	return Vector2i(finestra.x, roundi(finestra.x / voluto))


func scala_consigliata(area: Vector2i) -> int:
	# Circa 360 righe di gioco, con ogni pixel grande un numero intero di pixel dello schermo.
	return maxi(1, roundi(float(area.y) / float(ALTEZZA_BASE)))


func scale_possibili(area: Vector2i) -> Array[int]:
	# Scale intere che lasciano fra 240 e 560 righe di gioco (sotto si vede troppo poco, sopra è minuscolo).
	var elenco: Array[int] = []
	for s in range(1, 9):
		var righe := float(area.y) / s
		if righe >= 240.0 and righe <= 560.0:
			elenco.append(s)
	if elenco.is_empty():
		elenco.append(scala_consigliata(area))
	return elenco


func risoluzione_interna(finestra: Vector2i) -> Dictionary:
	# Ogni pixel del gioco occupa un numero intero di pixel dello schermo ("intera"):
	# così la pixel art resta nitida su qualsiasi risoluzione. Con "riempi" il gioco ha sempre 360 righe
	# e la scala non è intera (il filtro di ingrandimento decide come appare).
	# "resa" è la risoluzione a cui si disegna davvero: più bassa con la risoluzione interna sotto il 100%.
	var area := area_di_gioco(finestra)
	var scala := float(scala_consigliata(area))
	if Impostazioni.leggi("schermo/adatta") == "riempi":
		scala = maxf(0.5, float(area.y) / float(ALTEZZA_BASE))
	else:
		var scelta: int = Impostazioni.leggi("schermo/scala")
		if scelta > 0 and scale_possibili(area).has(scelta):
			scala = float(scelta)
	var dimensione := Vector2i(ceili(float(area.x) / scala), ceili(float(area.y) / scala))
	var quota: float = clampf(Impostazioni.leggi("grafica/risoluzione"), 0.25, 1.0)
	# Doppia definizione delle figure (0.1.37): il mondo si disegna al doppio, così una figura col doppio
	# dei pixel si vede intera. Solo se lo schermo ha almeno 2 pixel veri per pixel di gioco e la risoluzione
	# interna è piena (al 50% i pixel in più andrebbero persi).
	var densita := 2 if bool(profilo.get("figure", false)) and scala >= 2.0 and quota >= 1.0 else 1
	var resa := Vector2i(maxi(1, roundi(dimensione.x * quota * densita)), maxi(1, roundi(dimensione.y * quota * densita)))
	return {"scala": scala, "dimensione": dimensione, "resa": resa, "area": area, "densita": densita}


func _process(delta: float) -> void:
	if _attesa_iniziale > 0.0:
		_attesa_iniziale -= delta
		return
	if in_prova or bot_attivo or _adattamento_fermo or get_tree().paused:
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
	if Impostazioni.leggi("grafica/qualita") != "auto" or not Impostazioni.leggi("grafica/adattamento") \
			or forzato != "" or LIVELLI.find(livello) <= 0:
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
	righe.append("Qualità %s (consigliata %s)  obiettivo %d FPS%s" % [livello, livello_consigliato, fps_obiettivo,
			"  risparmio energetico" if riduzione_energia > 0 else ""])
	righe.append("Calore %s  batteria %s" % [termico, (str(batteria) + "%") if batteria >= 0 else "n.d."])
	return righe
