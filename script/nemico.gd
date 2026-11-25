class_name Nemico
extends CharacterBody2D
# Nemici con un piccolo cervello: osservano, decidono, agiscono, verificano e ricordano.
#  - "scheletro": guerriero. Può partire addormentato, si risveglia se ti avvicini o se fai rumore,
#    pattuglia, ti insegue, ti cerca dove ti ha visto l'ultima volta e colpisce da vicino con un colpo
#    lento ma annunciato. Sceglie una tattica (diretto, attesa, affondo, finta) secondo quello che ha
#    funzionato contro di te finora, e a volte fa un balzo indietro quando attacchi.
#  - "mago": tiene le distanze e lancia sfere di luce (dritte, anticipate dove andrai, o a raffica).
#  - "arciere": tiene le distanze e tira dardi di balestra (dritti, anticipati, o due di fila).
#  - "pipistrello": dorme appeso, poi vola e scende in picchiata (dritto, girandoti alle spalle,
#    o aspettando che tu sia scoperto). Si colpisce mentre scende o risale, o da lontano.
#  - "bestione": lento e corazzato. Da davanti para i colpi di spada: si colpisce alle spalle,
#    dopo un suo colpo (quando è scoperto), con la magia o con le trappole. Colpisce forte e carica.
#  - "saltatore": piccolo e veloce, ti balza addosso (dritto, a zig-zag o dall'alto) e ti segue
#    saltando da una piattaforma all'altra.
# Una nemesi (vedi Memoria) è lo stesso nemico, ma più forte, con un nome, un titolo e una frase.
# Chi ha imparato che colpisci da lontano ("schiva_tiri") schiva i tuoi tiri.

enum Stato { DORME, RISVEGLIO, FERMO, PATTUGLIA, INSEGUE, ATTACCO, LANCIA, COLPITO, MORTO }

const TIPI := {
	"scheletro": {"foglio": "scheletro", "vita": 3, "passo": 30.0, "corsa": 54.0, "vista": 170.0, "portata": 38.0},
	"mago": {"foglio": "mago", "vita": 2, "passo": 26.0, "corsa": 26.0, "vista": 250.0, "portata": 0.0},
	"arciere": {"foglio": "arciere", "vita": 2, "passo": 28.0, "corsa": 28.0, "vista": 260.0, "portata": 0.0},
	"pipistrello": {"foglio": "pipistrello", "vita": 1, "passo": 34.0, "corsa": 190.0, "vista": 190.0, "portata": 0.0},
	"bestione": {"foglio": "bestione", "vita": 6, "passo": 22.0, "corsa": 38.0, "vista": 190.0, "portata": 50.0},
	"saltatore": {"foglio": "saltatore", "vita": 2, "passo": 44.0, "corsa": 84.0, "vista": 210.0, "portata": 30.0},
}
const TIRATORI := ["mago", "arciere"]
const GRAVITA := 1200.0
const ATTACCO_DURATA := 0.86
const ATTACCO_INIZIO := 0.40
const ATTACCO_FINE := 0.56
const TEMPI_BESTIONE := [1.14, 0.62, 0.78]   # durata, inizio e fine del colpo d'ascia
const FINTA_MOMENTO := 0.22
const AFFONDO_VELOCITA := 95.0
const AFFONDO_PORTATA := 14.0
const LANCIO_DURATA := 0.83
const LANCIO_MOMENTO := 0.45
const RICARICA_MAGO := 2.4
const VELOCITA_SFERA := 115.0
const VELOCITA_DARDO := 210.0
const UDITO := 150.0
const RICERCA_MASSIMA := 3.5
const BALZO_DURATA := 0.86
const GIRO_BESTIONE := 0.8      # secondi che il bestione impiega a girarsi

var tipo := "scheletro"
var dorme := false
var stato := Stato.PATTUGLIA
var verso := -1
var vita := 3
var sprite: SpriteAnimato
var nemesi := {}                 # se non è vuoto, questo nemico è una nemesi (record di Memoria)
var potere := 0
var tattica := ""
var annunciato := false

var _dati := {}
var _t_stato := 0.0
var _t_ricarica := 1.0
var _t_senza_vista := 0.0
var _t_tattica := 0.0
var _t_pausa := 0.0
var _t_balzo := 0.0
var _t_finestra := 0.0           # chi gioca ha appena finito un rotolo/uno scatto: è il momento
var _t_schiva := 0.0
var _t_giro := 0.0
var _colpo_dato := false
var _lanciato := false
var _secondo := false
var _affondo := false
var _finta := false
var _carica := false
var _in_balzo := false
var _mancati := 0
var _ultimo_visto := Vector2.ZERO
var _ha_ricordo := false
var _stato_giocatore_prima := -1
var _casa := Vector2.ZERO        # pipistrello: dove torna a volare
var _fase_volo := ""             # pipistrello: "giro", "scende", "risale"
var _meta_volo := Vector2.ZERO
var _caso := RandomNumberGenerator.new()
var _bersaglio: Area2D
var _colpo: Area2D
var _forma_colpo: CollisionShape2D
var _ombra: LightOccluder2D
var _centro_locale := Vector2.ZERO


func _ready() -> void:
	_dati = (TIPI.get(tipo, TIPI["scheletro"]) as Dictionary).duplicate()
	_caso.seed = hash(Vector2i(position)) + int(Memoria.sogni) * 7919
	if not nemesi.is_empty():
		potere = int(nemesi.get("potere", 1))
		_dati["vita"] = int(_dati["vita"]) + potere
		_dati["corsa"] = float(_dati["corsa"]) * (1.0 + 0.1 * potere)
		_dati["vista"] = float(_dati["vista"]) + 30.0 * potere
	vita = _dati["vita"]
	_casa = position
	collision_layer = Effetti.S_NEMICI
	collision_mask = Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI
	floor_snap_length = 4.0
	z_index = 5

	# Misure: corpo, zona in cui lo si colpisce, zona del suo colpo.
	var corpo := Vector2(14, 40)
	var bersaglio := Vector2(18, 40)
	var colpo := Vector2(34, 42)
	match tipo:
		"bestione":
			corpo = Vector2(22, 56)
			bersaglio = Vector2(26, 56)
			colpo = Vector2(48, 56)
		"saltatore":
			corpo = Vector2(12, 32)
			bersaglio = Vector2(16, 32)
			colpo = Vector2(30, 34)
		"pipistrello":
			corpo = Vector2(14, 12)
			bersaglio = Vector2(22, 18)
			colpo = Vector2(20, 16)
	var vola := tipo == "pipistrello"
	if vola:
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		collision_mask = Effetti.S_MONDO   # vola attraverso le piattaforme
	var centro := 0.0 if vola else -1.0  # chi vola ha la posizione al centro del corpo, gli altri ai piedi

	var rett := RectangleShape2D.new()
	rett.size = corpo
	var forma := CollisionShape2D.new()
	forma.shape = rett
	forma.position = Vector2(0, corpo.y * 0.5 * centro)
	add_child(forma)

	sprite = SpriteAnimato.new()
	sprite.carica(_dati["foglio"])
	sprite.light_mask = Effetti.L_DAVANTI
	add_child(sprite)

	_bersaglio = Area2D.new()
	_bersaglio.collision_layer = Effetti.S_BERSAGLI
	_bersaglio.collision_mask = 0
	_bersaglio.monitoring = false
	_bersaglio.set_meta("bersaglio", self)
	var rett_b := RectangleShape2D.new()
	rett_b.size = bersaglio
	var forma_b := CollisionShape2D.new()
	forma_b.shape = rett_b
	forma_b.position = Vector2(0, bersaglio.y * 0.5 * centro)
	_centro_locale = forma_b.position
	_bersaglio.add_child(forma_b)
	add_child(_bersaglio)

	_colpo = Area2D.new()
	_colpo.collision_layer = Effetti.S_COLPI_NEMICI
	_colpo.collision_mask = Effetti.S_BERSAGLIO_GIOCATORE
	_colpo.monitorable = false
	var rett_c := RectangleShape2D.new()
	rett_c.size = colpo
	_forma_colpo = CollisionShape2D.new()
	_forma_colpo.shape = rett_c
	_forma_colpo.position = Vector2(0, 0) if vola else Vector2(colpo.x * 0.6, -colpo.y * 0.5)
	_colpo.add_child(_forma_colpo)
	add_child(_colpo)

	_ombra = Effetti.occlusore(self, Rect2(-5, -6, 10, 10) if vola else Rect2(-5, -corpo.y + 2.0, 10, corpo.y - 4.0))
	if not nemesi.is_empty():
		_aspetto_nemesi()

	if dorme and sprite.ha("dorme"):
		stato = Stato.DORME
		sprite.riproduci("dorme")
		_bersaglio.monitorable = vola  # il pipistrello appeso si può colpire
		_ombra.visible = false
	else:
		stato = Stato.PATTUGLIA
		sprite.riproduci("vola" if vola else "cammina")


func _aspetto_nemesi() -> void:
	# Si riconosce subito: tinta di sangue se ti ha battuto, di cenere se torna per vendetta, occhi accesi.
	sprite.modulate = Color(0.8, 0.82, 1.0) if nemesi.get("cicatrice", false) else Color(1.0, 0.7, 0.62)
	if Dispositivo.profilo.get("luci_doppie", true):
		var occhi := Effetti.luce(Color(1.0, 0.25, 0.2), 26.0, 0.9, 12.0)
		occhi.position = Vector2(0, -2) if tipo == "pipistrello" else Vector2(0, -34)
		add_child(occhi)


func centro() -> Vector2:
	# Il centro del corpo (dove mirano i tiri di chi gioca).
	return global_position + _centro_locale


func bersagliabile() -> bool:
	return stato != Stato.MORTO and _bersaglio != null and _bersaglio.monitorable


func tempi_attacco() -> Array:
	# Durata, inizio e fine della parte del colpo che fa male (il bot li legge per difendersi).
	return TEMPI_BESTIONE if tipo == "bestione" else [ATTACCO_DURATA, ATTACCO_INIZIO, ATTACCO_FINE]


func _physics_process(delta: float) -> void:
	_t_stato += delta
	_t_tattica += delta
	_t_ricarica = maxf(0.0, _t_ricarica - delta)
	_t_pausa = maxf(0.0, _t_pausa - delta)
	_t_balzo = maxf(0.0, _t_balzo - delta)
	_t_finestra = maxf(0.0, _t_finestra - delta)
	_t_schiva = maxf(0.0, _t_schiva - delta)
	var vola := tipo == "pipistrello" and stato != Stato.MORTO
	if not vola:
		velocity.y = minf(velocity.y + GRAVITA * delta, 500.0)

	# Osserva.
	var g := get_tree().get_first_node_in_group("giocatore") as Giocatore
	var dx := 0.0
	var dy := 0.0
	var visto := false
	var sentito := false
	if g != null and g.stato != Giocatore.Stato.MORTO:
		dx = g.global_position.x - global_position.x
		dy = g.global_position.y - global_position.y
		var quota := 200.0 if tipo in TIRATORI or vola else (120.0 if tipo == "saltatore" else 80.0)
		visto = absf(dx) < float(_dati["vista"]) and absf(dy) < quota and _vede(g)
		sentito = _sente(g, dx, dy)
		_osserva_giocatore(g)
		if visto or sentito:
			_ultimo_visto = g.global_position
			_ha_ricordo = true
		if visto and not annunciato and not nemesi.is_empty() and stato != Stato.DORME:
			_annuncia()
		if stato in [Stato.INSEGUE, Stato.FERMO, Stato.PATTUGLIA] and _schiva_tiri():
			move_and_slide()
			sprite.flip_h = verso < 0
			return

	if tipo == "pipistrello" and stato not in [Stato.COLPITO, Stato.MORTO]:
		_pipistrello(g, delta, dx, dy, visto or sentito)
	else:
		match stato:
			Stato.DORME:
				velocity.x = 0.0
				if g != null and ((absf(dx) < 120.0 and absf(dy) < 70.0) or sentito):
					_risvegliati()
			Stato.RISVEGLIO:
				velocity.x = 0.0
				if _t_stato >= sprite.durata("risveglio"):
					_bersaglio.set_deferred("monitorable", true)
					_ombra.visible = true
					_cambia(Stato.INSEGUE)
			Stato.PATTUGLIA:
				_pattuglia(visto or sentito)
			Stato.FERMO:
				_tiratore(g, dx, dy, visto, delta)
			Stato.INSEGUE:
				if tipo == "saltatore":
					_saltatore(g, delta, dx, dy, visto)
				else:
					_insegui(g, delta, dx, dy, visto)
			Stato.ATTACCO:
				if _in_balzo:
					_balzo(g)
				else:
					_attacca(g)
			Stato.LANCIA:
				_lancia(g)
			Stato.COLPITO:
				if tipo == "pipistrello":
					velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
				else:
					velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
				if _t_stato >= 0.3:
					_cambia(Stato.FERMO if tipo in TIRATORI else Stato.INSEGUE)
					if tipo == "pipistrello":
						_fase_volo = "risale"
			Stato.MORTO:
				velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
				if _t_stato >= 2.6:
					sprite.modulate.a = maxf(0.0, sprite.modulate.a - delta * 1.6)
					if sprite.modulate.a <= 0.0:
						queue_free()

	move_and_slide()
	sprite.flip_h = verso < 0


# ------------------------------------------------------------------ percezione

func _vede(g: Giocatore) -> bool:
	# Niente vista attraverso i muri.
	var da := global_position + (Vector2.ZERO if tipo == "pipistrello" else Vector2(0, -30))
	var a := g.global_position + Vector2(0, -22)
	var domanda := PhysicsRayQueryParameters2D.create(da, a, Effetti.S_MONDO)
	return get_world_2d().direct_space_state.intersect_ray(domanda).is_empty()


func _sente(g: Giocatore, dx: float, dy: float) -> bool:
	# Colpi, rotoli, scatti e scavalchi fanno rumore.
	var rumore := g.stato in [Giocatore.Stato.ATTACCO, Giocatore.Stato.ROTOLATA, Giocatore.Stato.SCHIVATA, Giocatore.Stato.SCAVALCO, Giocatore.Stato.TIRO]
	return rumore and absf(dx) < UDITO and absf(dy) < 90.0


func _osserva_giocatore(g: Giocatore) -> void:
	# Appena finisce un rotolo o uno scatto, chi gioca è scoperto per un attimo.
	var ora := int(g.stato)
	if _stato_giocatore_prima in [Giocatore.Stato.ROTOLATA, Giocatore.Stato.SCHIVATA] and ora == Giocatore.Stato.NORMALE:
		_t_finestra = 0.4
	_stato_giocatore_prima = ora


func _annuncia() -> void:
	annunciato = true
	var testo := Memoria.incontro(nemesi)
	if testo != "":
		get_tree().call_group("hud", "messaggio", testo, 4.0)


func _lezione() -> String:
	return nemesi.get("lezione", "") if not nemesi.is_empty() else Memoria.lezione_attuale()


func _schiva_tiri() -> bool:
	# Chi ha imparato che colpisci da lontano scansa i tuoi tiri (il bestione no: si fida della corazza).
	if tipo == "bestione" or _t_schiva > 0.0 or _lezione() != "schiva_tiri":
		return false
	for t: Node in get_tree().get_nodes_in_group("tiri_eroe"):
		var tiro := t as Proiettile
		var d := global_position + Vector2(0, -16) - tiro.global_position
		if d.length() < 80.0 and d.dot(tiro.velocita) > 0.0 and absf(d.y) < 40.0:
			_t_schiva = 1.2
			var via := signf(d.x) if d.x != 0.0 else float(-verso)
			if tipo == "pipistrello":
				velocity = Vector2(via * 60.0, -170.0)
			elif is_on_floor():
				velocity = Vector2(via * 120.0, -230.0)
			else:
				return false
			Rapporto.conta("tiri_schivati_dai_nemici")
			return true
	return false


# ------------------------------------------------------------------ comportamenti

func _risvegliati() -> void:
	_cambia(Stato.RISVEGLIO)
	sprite.riproduci("risveglio", true)
	Rapporto.evento("risveglio", {"x": roundi(global_position.x), "tipo": tipo})


func _pattuglia(allerta: bool) -> void:
	velocity.x = verso * float(_dati["passo"])
	sprite.riproduci("cammina")
	if is_on_floor() and (is_on_wall() or _vuoto_davanti()):
		verso = -verso
		velocity.x = verso * float(_dati["passo"])
	if allerta:
		_cambia(Stato.FERMO if tipo in TIRATORI else Stato.INSEGUE)


func _scegli_tattica() -> void:
	var prima := tattica
	var lezione := _lezione()
	for i in 3:
		tattica = Memoria.scegli_tattica(tipo, lezione, _caso)
		if tattica != prima or _mancati < 2:
			break
	_mancati = 0
	_t_tattica = 0.0


func _insegui(g: Giocatore, delta: float, dx: float, dy: float, visto: bool) -> void:
	if tattica == "":
		_scegli_tattica()
	if not visto:
		# Non ti vede: va a cercarti dove ti ha visto (o sentito) l'ultima volta, poi si arrende.
		_t_senza_vista += delta
		if not _ha_ricordo or _t_senza_vista > RICERCA_MASSIMA:
			_ha_ricordo = false
			_t_senza_vista = 0.0
			_cambia(Stato.PATTUGLIA)
			return
		var verso_ricordo := _ultimo_visto.x - global_position.x
		if absf(verso_ricordo) < 10.0:
			_ha_ricordo = false
		else:
			verso = 1 if verso_ricordo > 0.0 else -1
		_cammina(float(_dati["passo"]) * 1.3)
		return
	_t_senza_vista = 0.0
	if _t_balzo > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		return
	if absf(dx) > 4.0 and not _carica:
		var voluto := 1 if dx > 0.0 else -1
		if tipo == "bestione" and voluto != verso:
			# Pesante: ci mette un attimo a girarsi, e alle spalle lo si può colpire.
			_t_giro += delta
			if _t_giro >= GIRO_BESTIONE:
				verso = voluto
				_t_giro = 0.0
		else:
			verso = voluto
			_t_giro = 0.0
	var distanza := absf(dx)
	var portata := float(_dati["portata"])
	var stessa_quota := absf(dy) < 44.0

	# Carica del bestione: corre dritto finché non ti raggiunge, sbatte o passa il tempo.
	if _carica:
		_colpisci_a_contatto(g, 1, 260.0)
		velocity.x = verso * 165.0
		sprite.riproduci("cammina", false, 2.2)
		if _t_tattica > 0.9 or is_on_wall() or _vuoto_davanti() or _colpo_dato:
			_carica = false
			_t_pausa = 0.5        # dopo la carica resta scoperto un attimo
			_verifica_attacco()
		return

	# Difesa: se attacchi da vicino, a volte balza indietro (di più se ha imparato che attacchi per primo).
	if tipo == "scheletro" and g.stato == Giocatore.Stato.ATTACCO and float(g.get("_t_stato")) < 0.12 and distanza < 46.0 \
			and is_on_floor() and _t_ricarica <= 0.0 and _t_pausa <= 0.0:
		var p := 0.12 + 0.12 * potere + (0.3 if nemesi.get("lezione", "") == "arretra" else 0.0)
		if _caso.randf() < p:
			velocity = Vector2(-verso * 150.0, -110.0)
			_t_balzo = 0.3
			_t_ricarica = 0.35
			Rapporto.conta("balzi_nemici")
			return

	if _t_pausa > 0.0:
		velocity.x = 0.0
		sprite.riproduci("fermo")
		return

	var pronto := _t_ricarica <= 0.0 and is_on_floor() and stessa_quota
	match tattica:
		"attesa":
			# Resta appena fuori portata e colpisce quando sei scoperto (o dopo un po').
			var voluta := portata + 16.0
			if distanza > voluta + 8.0:
				_cammina(float(_dati["corsa"]))
			elif distanza < portata - 6.0:
				verso = -verso
				_cammina(float(_dati["passo"]))
				verso = -verso
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")
			var scoperto: bool = _t_finestra > 0.0 or (g.stato == Giocatore.Stato.ATTACCO and float(g.get("_t_stato")) > 0.24)
			if pronto and distanza <= portata + 20.0 and (scoperto or _t_tattica > 2.2):
				_inizia_attacco(distanza > portata - 2.0, false)
		"affondo":
			if distanza > portata + 34.0:
				_cammina(float(_dati["corsa"]))
			elif pronto:
				_inizia_attacco(true, false)
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")
		"finta":
			if distanza > portata:
				_cammina(float(_dati["corsa"]))
			elif pronto:
				_inizia_attacco(false, true)
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")
		"carica":
			# Bestione: da lontano carica, da vicino colpisce.
			if pronto and distanza > 80.0 and distanza < 220.0 and _t_tattica > 0.6:
				_carica = true
				_colpo_dato = false
				_forma_colpo.position.x = 20.0 * verso
				_t_tattica = 0.0
				Rapporto.conta("cariche_bestione")
			elif distanza > portata:
				_cammina(float(_dati["corsa"]))
			elif pronto:
				_inizia_attacco(false, false)
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")
		_:
			if distanza > portata or not stessa_quota:
				_cammina(float(_dati["corsa"]))
			elif pronto:
				_inizia_attacco(false, false)
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")


func _cammina(velocita_voluta: float) -> void:
	if is_on_floor() and (is_on_wall() or _vuoto_davanti()):
		velocity.x = 0.0
		sprite.riproduci("fermo")
		return
	velocity.x = verso * velocita_voluta
	sprite.riproduci("cammina", false, 1.6 if velocita_voluta > float(_dati["passo"]) * 1.2 else 1.0)


func _inizia_attacco(affondo: bool, finta: bool) -> void:
	_colpo_dato = false
	_affondo = affondo
	_finta = finta
	_in_balzo = false
	var base := float((_forma_colpo.shape as RectangleShape2D).size.x) * 0.6
	_forma_colpo.position.x = (base + (AFFONDO_PORTATA if affondo else 0.0)) * verso
	_cambia(Stato.ATTACCO)
	sprite.riproduci("attacco", true)


func _attacca(g: Giocatore) -> void:
	var tempi := tempi_attacco()
	velocity.x = 0.0
	if _affondo and _t_stato < float(tempi[1]) and not (is_on_wall() or _vuoto_davanti()):
		velocity.x = verso * AFFONDO_VELOCITA  # passo in avanti mentre carica il colpo
	if _finta and _t_stato >= FINTA_MOMENTO:
		# Finta: interrompe, aspetta che tu reagisca, poi colpisce davvero.
		_finta = false
		_cambia(Stato.INSEGUE)
		_t_pausa = 0.3
		_t_ricarica = 0.0
		_inizia_attacco_dopo_finta()
		return
	if not _colpo_dato and _t_stato >= float(tempi[1]) and _t_stato <= float(tempi[2]):
		for area in _colpo.get_overlapping_areas():
			if area.get_meta("bersaglio", null) == g and g != null:
				_colpo_dato = true
				g.subisci(2 if tipo == "bestione" else 1, global_position, 240.0 if tipo == "bestione" else 190.0, self)
		if tipo == "bestione" and _t_stato - get_physics_process_delta_time() < float(tempi[1]):
			_scossa_ascia()
	if _t_stato >= float(tempi[0]):
		_verifica_attacco()
		_t_ricarica = maxf(0.25, (0.9 if tipo == "bestione" else 0.5) - 0.06 * potere)
		_cambia(Stato.INSEGUE)


func _scossa_ascia() -> void:
	Effetti.scoppio(get_parent(), global_position + Vector2(verso * 30.0, -2.0), Color(0.55, 0.52, 0.5, 0.7), 8, 60.0, 0.4, 200.0, false)
	var g := get_tree().get_first_node_in_group("giocatore") as Giocatore
	if g != null and g.global_position.distance_to(global_position) < 200.0:
		g.scuoti(3.0)


func _colpisci_a_contatto(g: Giocatore, danno: int, spinta: float) -> void:
	if g == null or _colpo_dato:
		return
	for area in _bersaglio_giocatore_vicino():
		if area.get_meta("bersaglio", null) == g:
			_colpo_dato = g.subisci(danno, global_position, spinta, self)
			return


func _bersaglio_giocatore_vicino() -> Array:
	_colpo.monitoring = true
	return _colpo.get_overlapping_areas()


func _inizia_attacco_dopo_finta() -> void:
	tattica = "finta_colpo"  # dopo la pausa colpisce senza altre finte
	await get_tree().create_timer(0.3, false).timeout
	if is_instance_valid(self) and stato == Stato.INSEGUE:
		_inizia_attacco(false, false)
		tattica = "finta"


func _verifica_attacco() -> void:
	# Verifica e ricorda: com'è andata questa tattica?
	var usata := "finta" if tattica == "finta_colpo" else tattica
	Memoria.esito_tattica(tipo, usata, _colpo_dato)
	if _colpo_dato:
		_mancati = 0
	else:
		_mancati += 1
	if _mancati >= 2 or _caso.randf() < 0.25:
		_scegli_tattica()


# ------------------------------------------------------------------ saltatore

func _saltatore(g: Giocatore, delta: float, dx: float, dy: float, visto: bool) -> void:
	# Ti segue saltando; da vicino ti balza addosso.
	if tattica == "":
		_scegli_tattica()
	if not visto:
		_insegui(g, delta, dx, dy, visto)
		return
	if absf(dx) > 4.0:
		verso = 1 if dx > 0.0 else -1
	if not is_on_floor():
		sprite.riproduci("salto")
		return
	var distanza := absf(dx)
	var pronto := _t_ricarica <= 0.0
	# Sei più in alto e vicino: salta su (le piattaforme si attraversano dal basso).
	if dy < -40.0 and distanza < 150.0 and pronto:
		velocity = Vector2(verso * 90.0, -430.0)
		_t_ricarica = 0.6
		Rapporto.conta("salti_saltatore")
		return
	# Sei più in basso: agguato, ti piomba addosso dal bordo.
	if dy > 40.0 and distanza < 120.0 and tattica == "agguato" and pronto:
		_inizia_balzo(g, true)
		return
	match tattica:
		"zig":
			if pronto and distanza < 150.0 and distanza > 40.0:
				if _t_tattica < 0.8:
					velocity = Vector2(-verso * 110.0, -200.0)   # saltello indietro, poi il balzo
					_t_tattica = 0.8
					_t_ricarica = 0.35
				else:
					_inizia_balzo(g, false)
			else:
				_cammina(float(_dati["corsa"]))
		_:
			if pronto and distanza < 140.0 and distanza > 30.0 and absf(dy) < 60.0:
				_inizia_balzo(g, false)
			elif distanza > 30.0:
				_cammina(float(_dati["corsa"]))
			elif pronto:
				_inizia_balzo(g, false)
			else:
				velocity.x = 0.0
				sprite.riproduci("fermo")


func _inizia_balzo(g: Giocatore, dall_alto: bool) -> void:
	_colpo_dato = false
	_in_balzo = true
	_affondo = false
	_finta = false
	var dx := g.global_position.x - global_position.x if g != null else verso * 80.0
	var salto := -200.0 if dall_alto else -310.0
	velocity = Vector2(clampf(dx * 2.0, -260.0, 260.0), salto)
	_forma_colpo.position.x = 12.0 * verso
	_cambia(Stato.ATTACCO)
	sprite.riproduci("balzo", true)
	Rapporto.conta("balzi_saltatore")


func _balzo(g: Giocatore) -> void:
	if _t_stato > 0.08:
		_colpisci_a_contatto(g, 1, 170.0)
	if is_on_floor() and _t_stato > 0.12:
		velocity.x = move_toward(velocity.x, 0.0, 30.0)
	if _t_stato >= BALZO_DURATA and is_on_floor():
		_in_balzo = false
		_verifica_attacco()
		_t_ricarica = maxf(0.3, 0.8 - 0.08 * potere)
		_t_pausa = 0.35   # atterrato: scoperto
		_cambia(Stato.INSEGUE)


# ------------------------------------------------------------------ pipistrello

func _pipistrello(g: Giocatore, delta: float, dx: float, dy: float, allerta: bool) -> void:
	if stato == Stato.DORME:
		velocity = Vector2.ZERO
		if g != null and ((absf(dx) < 110.0 and absf(dy) < 220.0 and _vede(g)) or (allerta and absf(dx) < 160.0)):
			stato = Stato.INSEGUE
			_fase_volo = "giro"
			_bersaglio.set_deferred("monitorable", true)
			_ombra.visible = true
			sprite.riproduci("vola")
			velocity = Vector2(0, 60)
			Rapporto.evento("risveglio", {"x": roundi(global_position.x), "tipo": tipo})
		return
	_t_senza_vista = 0.0 if allerta else _t_senza_vista + delta
	if g == null or (_t_senza_vista > 3.0 and _fase_volo == "giro"):
		# Non ti vede da un po': torna a girare attorno a dove dormiva.
		sprite.riproduci("vola")
		_vola_verso(_casa + Vector2(sin(_t_tattica * 1.3) * 40.0, cos(_t_tattica * 2.1) * 12.0), 60.0, delta)
		return
	stato = Stato.INSEGUE
	if tattica == "":
		_scegli_tattica()
	var corpo := g.global_position + Vector2(0, -22)
	match _fase_volo:
		"scende":
			sprite.riproduci("picchiata")
			velocity = velocity.move_toward((_meta_volo - global_position).normalized() * float(_dati["corsa"]), 900.0 * delta)
			_colpisci_a_contatto(g, 1, 120.0)
			if _t_stato > 0.9 or global_position.distance_to(_meta_volo) < 8.0 or _colpo_dato or is_on_floor() or is_on_wall():
				_fase_volo = "risale"
				_cambia(Stato.INSEGUE)
				_verifica_attacco()
		"risale":
			sprite.riproduci("vola")
			var su := Vector2(global_position.x - verso * 40.0, corpo.y - 80.0)
			_vola_verso(su, 110.0, delta)
			if global_position.y < corpo.y - 70.0 or _t_stato > 1.2:
				_fase_volo = "giro"
				_t_ricarica = maxf(0.6, 1.4 - 0.15 * potere)
				_cambia(Stato.INSEGUE)
		_:
			sprite.riproduci("vola")
			if absf(dx) > 4.0:
				verso = 1 if dx > 0.0 else -1
			# Si tiene sopra di te, un po' di lato; con "aggira" va dalla parte dove non guardi.
			var lato := -g.verso if tattica == "aggira" else (-1 if dx > 0.0 else 1)
			var posto := corpo + Vector2(lato * 46.0, -74.0 + sin(_t_tattica * 3.0) * 6.0)
			_vola_verso(posto, 95.0 * (1.0 + 0.1 * potere), delta)
			var pronto := _t_ricarica <= 0.0 and global_position.distance_to(posto) < 40.0
			var scoperto := _t_finestra > 0.0 or g.stato in [Giocatore.Stato.ATTACCO, Giocatore.Stato.TIRO, Giocatore.Stato.USA]
			if pronto and (tattica != "attesa" or scoperto or _t_tattica > 3.0):
				_fase_volo = "scende"
				_colpo_dato = false
				_meta_volo = corpo + Vector2(g.velocity.x * 0.25, 4.0)
				_cambia(Stato.INSEGUE)
				Rapporto.conta("picchiate_pipistrello")


func _vola_verso(dove: Vector2, velocita_voluta: float, delta: float) -> void:
	var d := dove - global_position
	var voluta := d.normalized() * minf(velocita_voluta, d.length() * 4.0)
	velocity = velocity.move_toward(voluta, 500.0 * delta)


# ------------------------------------------------------------------ tiratori (mago, arciere)

func _tiratore(g: Giocatore, dx: float, dy: float, visto: bool, delta: float) -> void:
	velocity.x = 0.0
	sprite.riproduci("fermo")
	if not visto or g == null:
		_t_senza_vista += delta
		if _t_senza_vista > 2.0:
			_t_senza_vista = 0.0
			_cambia(Stato.PATTUGLIA)
		return
	_t_senza_vista = 0.0
	if absf(dx) > 4.0:
		verso = 1 if dx > 0.0 else -1
	# Tiene le distanze: se ti avvicini troppo sulla sua quota, arretra.
	if absf(dx) < (90.0 if tipo == "arciere" else 70.0) and absf(dy) < 30.0:
		verso = -verso
		_cammina(float(_dati["passo"]) * 1.4)
		verso = -verso
	if _t_ricarica <= 0.0:
		if tattica == "" or _caso.randf() < 0.35:
			_scegli_tattica()
		_lanciato = false
		_secondo = false
		_cambia(Stato.LANCIA)
		sprite.riproduci("lancia", true)


func _lancia(g: Giocatore) -> void:
	velocity.x = 0.0
	if not _lanciato and _t_stato >= LANCIO_MOMENTO:
		_lanciato = true
		_tira(g)
	if tipo == "arciere" and tattica == "doppio" and _lanciato and not _secondo and _t_stato >= LANCIO_MOMENTO + 0.22:
		_secondo = true
		_tira(g)
	if _t_stato >= LANCIO_DURATA:
		var ricarica := RICARICA_MAGO * (1.0 - 0.06 * potere)
		if tipo == "mago" and tattica == "raffica":
			ricarica += 0.8
		elif tipo == "arciere":
			ricarica = 2.1 * (1.0 - 0.06 * potere) + (0.7 if tattica == "doppio" else 0.0)
		_t_ricarica = ricarica
		_cambia(Stato.FERMO)


func _tira(g: Giocatore) -> void:
	var da := global_position + Vector2(verso * 16.0, -30.0 if tipo == "arciere" else -34.0)
	var velocita := (VELOCITA_DARDO if tipo == "arciere" else VELOCITA_SFERA) * (1.0 + 0.05 * potere)
	var mira := da + Vector2(verso * 100.0, 0.0)
	if g != null:
		mira = g.global_position + Vector2(0.0, -22.0)
		if tattica == "anticipo":
			# Mira dove andrai, non dove sei.
			var tempo := da.distance_to(mira) / velocita
			mira += Vector2(g.velocity.x, clampf(g.velocity.y, -200.0, 200.0)) * tempo * 0.85
	var direzione := (mira - da).normalized()
	var angoli := [0.0]
	if tipo == "mago" and tattica == "raffica":
		angoli = [-0.2, 0.0, 0.2]
	for a: float in angoli:
		var colpo := Proiettile.new()
		colpo.tipo = "freccia" if tipo == "arciere" else "sfera"
		colpo.position = da
		colpo.velocita = direzione.rotated(a) * velocita
		colpo.autore = self
		colpo.tattica = tattica
		get_parent().add_child(colpo)
	Rapporto.conta("dardi_nemici" if tipo == "arciere" else "magie_lanciate")


func esito_sfera(tattica_sfera: String, colpito: bool) -> void:
	Memoria.esito_tattica(tipo, tattica_sfera, colpito)


func _vuoto_davanti() -> bool:
	var da := global_position + Vector2(verso * 12.0, -4.0)
	var domanda := PhysicsRayQueryParameters2D.create(da, da + Vector2(0.0, 26.0),
			Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI)
	return get_world_2d().direct_space_state.intersect_ray(domanda).is_empty()


func _cambia(nuovo: Stato) -> void:
	stato = nuovo
	_t_stato = 0.0


# ------------------------------------------------------------------ danni

func esposto() -> bool:
	# Il bestione si può ferire solo quando è scoperto: dopo un suo colpo, dopo una carica, mentre incassa.
	if tipo != "bestione":
		return true
	if stato == Stato.COLPITO or _t_pausa > 0.0:
		return true
	return stato == Stato.ATTACCO and _t_stato >= float(TEMPI_BESTIONE[2])


func subisci(danno: int, da: Vector2, spinta: float, tipo_colpo: String = "") -> bool:
	if stato == Stato.MORTO or stato == Stato.RISVEGLIO:
		return false
	if stato == Stato.DORME:
		if tipo == "pipistrello":
			vita = 0
			_muori(1.0)   # appeso e addormentato: un colpo basta
			return true
		_risvegliati()  # un colpo lo sveglia soltanto
		return false
	# Il bestione para da davanti, se non è scoperto (la magia e le trappole passano la corazza).
	if tipo == "bestione" and tipo_colpo not in ["magia", "trappola"] and not esposto() \
			and signf(da.x - global_position.x) == float(verso):
		sprite.riproduci("parata", true)
		Effetti.scoppio(get_parent(), global_position + Vector2(verso * 14.0, -34.0), Color(1.0, 0.9, 0.6), 8, 90.0, 0.2, 100.0)
		Rapporto.conta("parate_bestione")
		return false
	vita -= danno
	Effetti.lampo(sprite)
	var lato := signf(global_position.x - da.x)
	if lato == 0.0:
		lato = 1.0
	if vita <= 0:
		_muori(lato)
		return true
	_carica = false
	_in_balzo = false
	_cambia(Stato.COLPITO)
	if tipo == "bestione":
		velocity = Vector2(lato * spinta * 0.15, 0.0)   # pesante: quasi non si sposta
	elif tipo == "pipistrello":
		velocity = Vector2(lato * spinta * 0.6, -60.0)
	else:
		velocity = Vector2(lato * spinta * 0.7, -90.0)
	sprite.riproduci("colpito", true)
	return true


func _muori(lato: float) -> void:
	_cambia(Stato.MORTO)
	velocity = Vector2(lato * 60.0, -80.0)
	collision_layer = 0
	if tipo == "pipistrello":
		motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
		collision_mask = Effetti.S_MONDO | Effetti.S_PIATTAFORME
	_bersaglio.set_deferred("monitorable", false)
	_ombra.visible = false
	z_index = 3
	sprite.riproduci("morte", true)
	Rapporto.conta("nemici_uccisi")
	Rapporto.conta("uccisi_" + tipo)
	Rapporto.evento("nemico_ucciso", {"tipo": tipo, "x": roundi(global_position.x), "y": roundi(global_position.y),
			"nemesi": Memoria.nome_completo(nemesi) if not nemesi.is_empty() else ""})
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -22), Color(0.82, 0.8, 0.7, 0.8), 12, 80.0, 0.5, 220.0, false)
	var frase := Memoria.nemico_sconfitto(self)
	if frase != "":
		get_tree().call_group("hud", "messaggio", frase, 3.0)
