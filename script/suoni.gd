extends Node
# Suoni del gioco: effetti, ambiente e musica (tutti sintetizzati da strumenti/genera_suoni.py).
# Cinque canali (bus) con il loro volume: Generale (Master), Musica, Effetti, Ambiente, Interfaccia.
# Si regola da solo in base a dove va il suono (altoparlante, cuffie, Bluetooth) e alla suoneria del telefono:
# sull'altoparlante gamma dinamica ridotta e bassi più leggeri, in cuffia suono pieno.

const CARTELLA := "res://arte/suoni/"
const POSIZIONALI := 14          # suoni contemporanei nel mondo
const PIATTI := 4                # suoni dell'interfaccia
# Effetti che finiscono nel bus Ambiente invece che in Effetti.
const DI_AMBIENTE := ["porta", "crollo", "bracere", "pendolo", "ondata", "sogno_quieto"]
# Didascalie per i suoni importanti (accessibilità).
const DIDASCALIE := {
	"avviso_attacco": "[un nemico carica il colpo]", "sfera_nemica": "[sfera magica]", "dardo_nemico": "[dardo in volo]",
	"ruggito": "[ruggito]", "pipistrello": "[stridio d'ala]", "risveglio": "[ossa che si alzano]",
	"porta": "[pietra che scorre]", "crollo": "[crollo]", "spuntoni": "[spuntoni]", "pendolo": "[lama che oscilla]",
	"ondata": "[corno lontano]", "nemesi": "[una presenza ti riconosce]", "esplosione": "[esplosione]",
	"forziere": "[forziere aperto]", "balestra": "[scatto di balestra]", "colpito": "[ferito]",
	"bracere": "[fiamma]", "balzo": "[balzo]",
}

var _effetti: Array[AudioStreamPlayer2D] = []
var _piatti: Array[AudioStreamPlayer] = []
var _prossimo := 0
var _prossimo_piatto := 0
var _musica: AudioStreamPlayer
var _ambiente: AudioStreamPlayer
var _flussi := {}
var _ultimo_suono := {}          # nome -> tempo: lo stesso suono non si accavalla più di tanto
var _compressore: AudioEffectCompressor
var _bassi: AudioEffectLowShelfFilter
var _mono: AudioEffectStereoEnhance
var _in_pausa := false
var suonati := 0                 # per le prove e il rapporto
var ultimi: Array[String] = []   # ultimi suoni (per le prove)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crea_bus()
	for i in POSIZIONALI:
		var p := AudioStreamPlayer2D.new()
		p.bus = &"Effetti"
		p.max_distance = 900.0
		p.attenuation = 1.6
		p.panning_strength = 0.8
		add_child(p)
		_effetti.append(p)
	for i in PIATTI:
		var p := AudioStreamPlayer.new()
		p.bus = &"Interfaccia"
		add_child(p)
		_piatti.append(p)
	_musica = _lungo("musica", &"Musica")
	_ambiente = _lungo("ambiente", &"Ambiente")
	Impostazioni.cambiata.connect(_su_impostazione)
	Dispositivo.audio_cambiato.connect(applica)
	applica()
	if not Dispositivo.in_prova:
		_musica.play()
		_ambiente.play()


func _crea_bus() -> void:
	for nome: String in ["Musica", "Effetti", "Ambiente", "Interfaccia"]:
		if AudioServer.get_bus_index(nome) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nome)
			AudioServer.set_bus_send(i, &"Master")
	# Sul generale: bassi (scaffale basso), "modalità notte" (compressore), mono (stereo azzerato), limitatore.
	_bassi = AudioEffectLowShelfFilter.new()
	_bassi.cutoff_hz = 180.0
	_compressore = AudioEffectCompressor.new()
	_compressore.threshold = -20.0
	_compressore.ratio = 4.0
	_compressore.attack_us = 2000.0
	_compressore.release_ms = 180.0
	_compressore.gain = 6.0
	_mono = AudioEffectStereoEnhance.new()
	_mono.pan_pullout = 0.0
	var limitatore := AudioEffectHardLimiter.new()
	limitatore.ceiling_db = -0.5
	var master := AudioServer.get_bus_index(&"Master")
	for e: AudioEffect in [_bassi, _compressore, _mono, limitatore]:
		AudioServer.add_bus_effect(master, e)


func _lungo(nome: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	var flusso := _flusso(nome) as AudioStreamWAV
	if flusso != null:
		flusso = flusso.duplicate() as AudioStreamWAV
		flusso.loop_mode = AudioStreamWAV.LOOP_FORWARD
		flusso.loop_begin = 0
		flusso.loop_end = int(flusso.get_length() * flusso.mix_rate)
		p.stream = flusso
	add_child(p)
	return p


func _flusso(nome: String) -> AudioStream:
	if not _flussi.has(nome):
		var percorso := CARTELLA + nome + ".wav"
		_flussi[nome] = load(percorso) if ResourceLoader.exists(percorso) else null
	return _flussi[nome]


# ------------------------------------------------------------------ impostazioni e dispositivo

func _su_impostazione(chiave: String) -> void:
	if chiave.begins_with("audio/"):
		applica()


func notte_attiva() -> bool:
	var scelta: int = Impostazioni.leggi("audio/notte")
	if scelta >= 0:
		return scelta == 1
	return Dispositivo.uscita_audio in ["altoparlante", ""] and OS.has_feature("mobile")


func bassi_scelti() -> int:
	var scelta: int = Impostazioni.leggi("audio/bassi")
	if scelta >= 0:
		return scelta
	# Altoparlante piccolo del telefono: bassi più leggeri (non li riproduce e sporcano il resto).
	return 0 if Dispositivo.uscita_audio in ["altoparlante", ""] and OS.has_feature("mobile") else 1


func silenziato() -> bool:
	# Telefono in modalità silenziosa o vibrazione: il gioco tace (se lo si vuole).
	return Impostazioni.leggi("audio/silenzioso") and Dispositivo.suoneria in [0, 1]


func applica() -> void:
	var volumi := {
		&"Master": "audio/generale", &"Musica": "audio/musica", &"Effetti": "audio/effetti",
		&"Ambiente": "audio/ambiente", &"Interfaccia": "audio/interfaccia",
	}
	for bus: StringName in volumi:
		var i := AudioServer.get_bus_index(bus)
		var v: float = clampf(Impostazioni.leggi(volumi[bus]), 0.0, 1.0)
		if bus == &"Musica" and _in_pausa and Impostazioni.leggi("audio/pausa_attenua"):
			v *= 0.4
		AudioServer.set_bus_volume_linear(i, v)
		AudioServer.set_bus_mute(i, v <= 0.001)
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master, silenziato() or float(Impostazioni.leggi("audio/generale")) <= 0.001)
	var b := bassi_scelti()
	_bassi.gain = [0.5, 1.0, 1.6][clampi(b, 0, 2)]
	AudioServer.set_bus_effect_enabled(master, 0, b != 1)
	AudioServer.set_bus_effect_enabled(master, 1, notte_attiva())
	AudioServer.set_bus_effect_enabled(master, 2, Impostazioni.leggi("audio/mono"))


func in_pausa(si: bool) -> void:
	_in_pausa = si
	applica()


# ------------------------------------------------------------------ suonare

func suona(nome: String, dove: Variant = null, volume_db: float = 0.0, tono: float = 1.0) -> void:
	# dove = posizione nel mondo (suono che viene da lì) oppure null (suono "piatto").
	var flusso := _flusso(nome)
	if flusso == null:
		_didascalia(nome, dove)  # alcuni nomi hanno solo la didascalia (per esempio "dardo_nemico")
		return
	var adesso := Time.get_ticks_msec()
	if adesso - int(_ultimo_suono.get(nome, -1000)) < 35:
		return  # lo stesso suono due volte nello stesso istante: uno basta
	_ultimo_suono[nome] = adesso
	suonati += 1
	ultimi.append(nome)
	if ultimi.size() > 40:
		ultimi.remove_at(0)
	var variazione := tono * randf_range(0.94, 1.06)
	if dove is Vector2:
		var p := _effetti[_prossimo]
		_prossimo = (_prossimo + 1) % _effetti.size()
		_sposta_nel_mondo(p)
		p.stream = flusso
		p.bus = &"Ambiente" if nome in DI_AMBIENTE else &"Effetti"
		p.global_position = dove
		p.volume_db = volume_db
		p.pitch_scale = variazione
		p.play()
		_didascalia(nome, dove)
	else:
		var q := _piatti[_prossimo_piatto]
		_prossimo_piatto = (_prossimo_piatto + 1) % _piatti.size()
		q.stream = flusso
		q.bus = &"Interfaccia" if nome.begins_with("ui_") else (&"Ambiente" if nome in DI_AMBIENTE else &"Effetti")
		q.volume_db = volume_db
		q.pitch_scale = variazione if not nome.begins_with("ui_") else 1.0
		q.play()
		_didascalia(nome, null)


func _sposta_nel_mondo(p: AudioStreamPlayer2D) -> void:
	# I suoni posizionali devono stare nel viewport del mondo, dove c'è la telecamera che "ascolta".
	var principale := get_tree().current_scene
	var stanza: Node = principale.get("stanza") if principale != null and "stanza" in principale else null
	if not is_instance_valid(stanza):
		return
	if p.get_parent() != stanza:
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
		stanza.add_child(p)


func _didascalia(nome: String, dove: Variant) -> void:
	if not DIDASCALIE.has(nome) or not Impostazioni.leggi("acc/didascalie"):
		return
	var testo: String = DIDASCALIE[nome]
	var principale := get_tree().current_scene
	if dove is Vector2 and principale != null and "stanza" in principale:
		var stanza: Node = principale.get("stanza")
		if is_instance_valid(stanza) and "giocatore" in stanza:
			var g: Node2D = stanza.get("giocatore")
			var dx: float = (dove as Vector2).x - g.global_position.x
			if absf(dx) > 60.0:
				testo += " a destra" if dx > 0.0 else " a sinistra"
	get_tree().call_group("hud", "didascalia", testo)


func stanza_tolta() -> void:
	# Prima di liberare una stanza i lettori posizionali tornano qui, altrimenti sparirebbero con lei.
	for p in _effetti:
		if p.get_parent() != self:
			if p.get_parent() != null:
				p.get_parent().remove_child(p)
			add_child(p)


func stato() -> Dictionary:
	return {
		"uscita": Dispositivo.uscita_audio, "suoneria": Dispositivo.suoneria, "notte": notte_attiva(),
		"bassi": bassi_scelti(), "mono": Impostazioni.leggi("audio/mono"), "silenziato": silenziato(), "suonati": suonati,
	}
