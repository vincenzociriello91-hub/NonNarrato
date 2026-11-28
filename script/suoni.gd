extends Node
# Suoni del gioco: effetti, ambiente e musica (tutti sintetizzati da strumenti/genera_suoni.py).
# Musica a strati (0.1.29): tre brani da 64 s che suonano sempre insieme e a tempo (AudioStreamSynchronized):
# base (esplorazione), presenza (nemici svegli vicini), lotta (combattimento). La stanza dice quanta tensione c'è
# (tensione 0/1/2) e gli strati entrano in 1,5 s ed escono in 3,5 s. Ambiente: cripta e sotterraneo in dissolvenza.
# Sott'acqua tutto si fa ovattato (filtro passa-basso); nella cripta un po' d'eco, nel sotterraneo di più.
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
	"bracere": "[fiamma]", "balzo": "[balzo]", "tuffo": "[tuffo]", "muro_rotto": "[muro che crolla]",
	"legno_rotto": "[legno spezzato]", "affanno": "[senza fiato]", "crepa": "[la pietra si crepa]",
	"mimic_ruggito": "[un forziere ringhia]", "mimic_morso": "[il mimic sta per mordere]",
	"carica": "[un colpo si carica]", "carica_piena": "[carica piena]", "colpo_pesante": "[colpo pesante]",
	"parata_perfetta": "[parata perfetta]", "esecuzione": "[esecuzione]", "stordito": "[nemico stordito]",
}

var _effetti: Array[AudioStreamPlayer2D] = []
var _piatti: Array[AudioStreamPlayer] = []
var _prossimo := 0
var _prossimo_piatto := 0
const STRATI := ["musica_base", "musica_presenza", "musica_lotta"]
const LIVELLI_TENSIONE := [[1.0, 0.0, 0.0], [1.0, 0.75, 0.0], [0.85, 0.6, 1.0]]   # guadagno di ogni strato
const ENTRATA_S := 1.5
const USCITA_S := 3.5
const AMBIENTI := ["ambiente_cripta", "ambiente_sotto"]
const ECO := {"cripta": [0.55, 0.1], "sotto": [0.8, 0.2]}   # zona -> [grandezza della stanza, quantità d'eco]

var _musica: AudioStreamPlayer
var _strati: AudioStreamSynchronized
var _guadagni := [1.0, 0.0, 0.0]
var tensione := 0                  # 0 esplorazione, 1 presenza, 2 lotta (la decide la stanza)
var _ambienti: Array[AudioStreamPlayer] = []
var _guadagni_ambiente := [1.0, 0.0]
var zona := "cripta"
var sotto_acqua := false
var _ovattati: Array[AudioEffectLowPassFilter] = []
var _eco: AudioEffectReverb
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
	_crea_musica()
	for nome: String in AMBIENTI:
		_ambienti.append(_lungo(nome, &"Ambiente"))
	Impostazioni.cambiata.connect(_su_impostazione)
	Dispositivo.audio_cambiato.connect(applica)
	Dispositivo.profilo_cambiato.connect(_applica_eco)
	applica()
	_applica_mix()
	_applica_eco()
	if not Dispositivo.in_prova:
		_musica.play()
		for p in _ambienti:
			p.play()


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
	# Sott'acqua: musica, effetti e ambiente ovattati (l'interfaccia no). Spenti finché non si va sotto.
	for nome: String in ["Musica", "Effetti", "Ambiente"]:
		var filtro := AudioEffectLowPassFilter.new()
		filtro.cutoff_hz = 650.0
		filtro.resonance = 0.6
		var i := AudioServer.get_bus_index(nome)
		AudioServer.add_bus_effect(i, filtro, 0)
		AudioServer.set_bus_effect_enabled(i, 0, false)
		_ovattati.append(filtro)
	# Eco della pietra sugli effetti (spenta con la grafica "bassa": costa un po' di calcolo).
	_eco = AudioEffectReverb.new()
	_eco.damping = 0.5
	_eco.spread = 0.8
	_eco.predelay_msec = 70.0
	_eco.hipass = 0.15
	_eco.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Effetti"), _eco)


func _lungo(nome: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = _brano(nome)
	add_child(p)
	return p


func _brano(nome: String) -> AudioStreamOggVorbis:
	# Brani lunghi in OGG, ripetuti senza fine (sono costruiti per ricominciare senza scatti).
	var percorso := CARTELLA + nome + ".ogg"
	if not ResourceLoader.exists(percorso):
		return null
	var b := (load(percorso) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	b.loop = true
	return b


func _crea_musica() -> void:
	_strati = AudioStreamSynchronized.new()
	_strati.stream_count = STRATI.size()
	for i in STRATI.size():
		_strati.set_sync_stream(i, _brano(STRATI[i]))
	_musica = AudioStreamPlayer.new()
	_musica.bus = &"Musica"
	_musica.stream = _strati
	add_child(_musica)


func imposta_tensione(livello: int) -> void:
	tensione = clampi(livello, 0, 2)


func imposta_zona(sotto: bool) -> void:
	var nuova := "sotto" if sotto else "cripta"
	if nuova != zona:
		zona = nuova
		_applica_eco()


func imposta_sott_acqua(si: bool) -> void:
	if si == sotto_acqua:
		return
	sotto_acqua = si
	for nome: String in ["Musica", "Effetti", "Ambiente"]:
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(nome), 0, si)


func _applica_eco() -> void:
	var valori: Array = ECO[zona]
	_eco.room_size = valori[0]
	_eco.wet = valori[1]
	var i := AudioServer.get_bus_index(&"Effetti")
	AudioServer.set_bus_effect_enabled(i, AudioServer.get_bus_effect_count(i) - 1, Dispositivo.livello != "bassa")


func _process(delta: float) -> void:
	# Gli strati vanno verso i guadagni della tensione di adesso: salgono in fretta, scendono piano.
	var obiettivo: Array = LIVELLI_TENSIONE[tensione]
	var cambiato := false
	for i in _guadagni.size():
		var g: float = _guadagni[i]
		var o: float = obiettivo[i]
		if not is_equal_approx(g, o):
			var passo := delta / (ENTRATA_S if o > g else USCITA_S)
			_guadagni[i] = move_toward(g, o, passo)
			cambiato = true
	var ambiente_obiettivo := [1.0, 0.0] if zona == "cripta" else [0.0, 1.0]
	for i in _guadagni_ambiente.size():
		if not is_equal_approx(_guadagni_ambiente[i], ambiente_obiettivo[i]):
			_guadagni_ambiente[i] = move_toward(_guadagni_ambiente[i], ambiente_obiettivo[i], delta / 2.0)
			cambiato = true
	if cambiato:
		_applica_mix()


func _applica_mix() -> void:
	for i in _guadagni.size():
		_strati.set_sync_stream_volume(i, linear_to_db(maxf(float(_guadagni[i]), 0.0001)))
	for i in _ambienti.size():
		_ambienti[i].volume_db = linear_to_db(maxf(float(_guadagni_ambiente[i]), 0.0001))


func guadagni_musica() -> Array:
	return _guadagni.duplicate()


func guadagni_ambiente() -> Array:
	return _guadagni_ambiente.duplicate()


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
	# La stanza nuova parte dalla cripta, fuori dall'acqua e senza nemici svegli.
	imposta_zona(false)
	imposta_sott_acqua(false)
	imposta_tensione(0)
	for p in _effetti:
		if p.get_parent() != self:
			if p.get_parent() != null:
				p.get_parent().remove_child(p)
			add_child(p)


func stato() -> Dictionary:
	return {
		"uscita": Dispositivo.uscita_audio, "suoneria": Dispositivo.suoneria, "notte": notte_attiva(),
		"bassi": bassi_scelti(), "mono": Impostazioni.leggi("audio/mono"), "silenziato": silenziato(), "suonati": suonati,
		"tensione": tensione, "zona": zona, "sott_acqua": sotto_acqua,
	}
