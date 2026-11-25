class_name Nemico
extends CharacterBody2D
# Nemici di prova, con un piccolo cervello: osservano, decidono, agiscono, verificano e ricordano.
#  - "scheletro": guerriero. Può partire addormentato, si risveglia se ti avvicini o se fai rumore,
#    pattuglia, ti insegue, ti cerca dove ti ha visto l'ultima volta e colpisce da vicino con un colpo
#    lento ma annunciato. Sceglie una tattica (diretto, attesa, affondo, finta) secondo quello che ha
#    funzionato contro di te finora, e a volte fa un balzo indietro quando attacchi.
#  - "mago": tiene le distanze e lancia sfere di luce (dritte, anticipate dove andrai, o a raffica).
# Una nemesi (vedi Memoria) è lo stesso nemico, ma più forte, con un nome, un titolo e una frase.

enum Stato { DORME, RISVEGLIO, FERMO, PATTUGLIA, INSEGUE, ATTACCO, LANCIA, COLPITO, MORTO }

const TIPI := {
	"scheletro": {"foglio": "scheletro", "vita": 3, "passo": 30.0, "corsa": 54.0, "vista": 170.0, "portata": 38.0},
	"mago": {"foglio": "mago", "vita": 2, "passo": 26.0, "corsa": 26.0, "vista": 250.0, "portata": 0.0},
}
const GRAVITA := 1200.0
const ATTACCO_DURATA := 0.86
const ATTACCO_INIZIO := 0.40
const ATTACCO_FINE := 0.56
const FINTA_MOMENTO := 0.22
const AFFONDO_VELOCITA := 95.0
const AFFONDO_PORTATA := 14.0
const LANCIO_DURATA := 0.83
const LANCIO_MOMENTO := 0.45
const RICARICA_MAGO := 2.4
const VELOCITA_SFERA := 115.0
const UDITO := 150.0
const RICERCA_MASSIMA := 3.5

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
var _colpo_dato := false
var _lanciato := false
var _affondo := false
var _finta := false
var _mancati := 0
var _ultimo_visto := Vector2.ZERO
var _ha_ricordo := false
var _stato_giocatore_prima := -1
var _caso := RandomNumberGenerator.new()
var _bersaglio: Area2D
var _colpo: Area2D
var _forma_colpo: CollisionShape2D
var _ombra: LightOccluder2D


func _ready() -> void:
	_dati = (TIPI.get(tipo, TIPI["scheletro"]) as Dictionary).duplicate()
	_caso.seed = hash(Vector2i(position)) + int(Memoria.sogni) * 7919
	if not nemesi.is_empty():
		potere = int(nemesi.get("potere", 1))
		_dati["vita"] = int(_dati["vita"]) + potere
		_dati["corsa"] = float(_dati["corsa"]) * (1.0 + 0.1 * potere)
		_dati["vista"] = float(_dati["vista"]) + 30.0 * potere
	vita = _dati["vita"]
	collision_layer = Effetti.S_NEMICI
	collision_mask = Effetti.S_MONDO | Effetti.S_PIATTAFORME | Effetti.S_OGGETTI
	floor_snap_length = 4.0
	z_index = 5

	var rett := RectangleShape2D.new()
	rett.size = Vector2(14, 40)
	var forma := CollisionShape2D.new()
	forma.shape = rett
	forma.position = Vector2(0, -20)
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
	rett_b.size = Vector2(18, 40)
	var forma_b := CollisionShape2D.new()
	forma_b.shape = rett_b
	forma_b.position = Vector2(0, -20)
	_bersaglio.add_child(forma_b)
	add_child(_bersaglio)

	_colpo = Area2D.new()
	_colpo.collision_layer = Effetti.S_COLPI_NEMICI
	_colpo.collision_mask = Effetti.S_BERSAGLIO_GIOCATORE
	_colpo.monitorable = false
	var rett_c := RectangleShape2D.new()
	rett_c.size = Vector2(34, 42)
	_forma_colpo = CollisionShape2D.new()
	_forma_colpo.shape = rett_c
	_forma_colpo.position = Vector2(20, -21)
	_colpo.add_child(_forma_colpo)
	add_child(_colpo)

	_ombra = Effetti.occlusore(self, Rect2(-5, -38, 10, 36))
	if not nemesi.is_empty():
		_aspetto_nemesi()

	if dorme and sprite.ha("dorme"):
		stato = Stato.DORME
		sprite.riproduci("dorme")
		_bersaglio.monitorable = false
		_ombra.visible = false
	else:
		stato = Stato.PATTUGLIA
		sprite.riproduci("cammina")


func _aspetto_nemesi() -> void:
	# Si riconosce subito: tinta di sangue se ti ha battuto, di cenere se torna per vendetta, occhi accesi.
	sprite.modulate = Color(0.8, 0.82, 1.0) if nemesi.get("cicatrice", false) else Color(1.0, 0.7, 0.62)
	if Dispositivo.profilo.get("luci_doppie", true):
		var occhi := Effetti.luce(Color(1.0, 0.25, 0.2), 26.0, 0.9, 12.0)
		occhi.position = Vector2(0, -34)
		add_child(occhi)


func _physics_process(delta: float) -> void:
	_t_stato += delta
	_t_tattica += delta
	_t_ricarica = maxf(0.0, _t_ricarica - delta)
	_t_pausa = maxf(0.0, _t_pausa - delta)
	_t_balzo = maxf(0.0, _t_balzo - delta)
	_t_finestra = maxf(0.0, _t_finestra - delta)
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
		var quota := 200.0 if tipo == "mago" else 80.0
		visto = absf(dx) < float(_dati["vista"]) and absf(dy) < quota and _vede(g)
		sentito = _sente(g, dx, dy)
		_osserva_giocatore(g)
		if visto or sentito:
			_ultimo_visto = g.global_position
			_ha_ricordo = true
		if visto and not annunciato and not nemesi.is_empty() and stato != Stato.DORME:
			_annuncia()

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
			_mago(g, dx, dy, visto, delta)
		Stato.INSEGUE:
			_insegui(g, delta, dx, dy, visto)
		Stato.ATTACCO:
			_attacca(g)
		Stato.LANCIA:
			_lancia(g)
		Stato.COLPITO:
			velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
			if _t_stato >= 0.3:
				_cambia(Stato.FERMO if tipo == "mago" else Stato.INSEGUE)
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
	var da := global_position + Vector2(0, -30)
	var a := g.global_position + Vector2(0, -22)
	var domanda := PhysicsRayQueryParameters2D.create(da, a, Effetti.S_MONDO)
	return get_world_2d().direct_space_state.intersect_ray(domanda).is_empty()


func _sente(g: Giocatore, dx: float, dy: float) -> bool:
	# Colpi, rotoli, scatti e scavalchi fanno rumore.
	var rumore := g.stato in [Giocatore.Stato.ATTACCO, Giocatore.Stato.ROTOLATA, Giocatore.Stato.SCHIVATA, Giocatore.Stato.SCAVALCO]
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


# ------------------------------------------------------------------ comportamenti

func _risvegliati() -> void:
	_cambia(Stato.RISVEGLIO)
	sprite.riproduci("risveglio", true)
	Rapporto.evento("risveglio", {"x": roundi(global_position.x)})


func _pattuglia(allerta: bool) -> void:
	velocity.x = verso * float(_dati["passo"])
	sprite.riproduci("cammina")
	if is_on_floor() and (is_on_wall() or _vuoto_davanti()):
		verso = -verso
		velocity.x = verso * float(_dati["passo"])
	if allerta:
		_cambia(Stato.FERMO if tipo == "mago" else Stato.INSEGUE)


func _scegli_tattica() -> void:
	var prima := tattica
	var lezione: String = nemesi.get("lezione", "") if not nemesi.is_empty() else Memoria.lezione_attuale()
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
	if absf(dx) > 4.0:
		verso = 1 if dx > 0.0 else -1
	var distanza := absf(dx)
	var portata := float(_dati["portata"])
	var stessa_quota := absf(dy) < 44.0

	# Difesa: se attacchi da vicino, a volte balza indietro (di più se ha imparato che attacchi per primo).
	if g.stato == Giocatore.Stato.ATTACCO and float(g.get("_t_stato")) < 0.12 and distanza < 46.0 and is_on_floor() \
			and _t_ricarica <= 0.0 and _t_pausa <= 0.0:
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
	_forma_colpo.position.x = (20.0 + (AFFONDO_PORTATA if affondo else 0.0)) * verso
	_cambia(Stato.ATTACCO)
	sprite.riproduci("attacco", true)


func _attacca(g: Giocatore) -> void:
	velocity.x = 0.0
	if _affondo and _t_stato < ATTACCO_INIZIO and not (is_on_wall() or _vuoto_davanti()):
		velocity.x = verso * AFFONDO_VELOCITA  # passo in avanti mentre carica il colpo
	if _finta and _t_stato >= FINTA_MOMENTO:
		# Finta: interrompe, aspetta che tu reagisca, poi colpisce davvero.
		_finta = false
		_cambia(Stato.INSEGUE)
		_t_pausa = 0.3
		_t_ricarica = 0.0
		_inizia_attacco_dopo_finta()
		return
	if not _colpo_dato and _t_stato >= ATTACCO_INIZIO and _t_stato <= ATTACCO_FINE:
		for area in _colpo.get_overlapping_areas():
			if area.get_meta("bersaglio", null) == g and g != null:
				_colpo_dato = true
				g.subisci(1, global_position, 190.0, self)
	if _t_stato >= ATTACCO_DURATA:
		_verifica_attacco()
		_t_ricarica = maxf(0.25, 0.5 - 0.06 * potere)
		_cambia(Stato.INSEGUE)


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


# ------------------------------------------------------------------ mago

func _mago(g: Giocatore, dx: float, dy: float, visto: bool, delta: float) -> void:
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
	if absf(dx) < 70.0 and absf(dy) < 30.0:
		verso = -verso
		_cammina(float(_dati["passo"]) * 1.4)
		verso = -verso
	if _t_ricarica <= 0.0:
		if tattica == "" or _caso.randf() < 0.35:
			_scegli_tattica()
		_lanciato = false
		_cambia(Stato.LANCIA)
		sprite.riproduci("lancia", true)


func _lancia(g: Giocatore) -> void:
	velocity.x = 0.0
	if not _lanciato and _t_stato >= LANCIO_MOMENTO:
		_lanciato = true
		var da := global_position + Vector2(verso * 16.0, -34.0)
		var velocita := VELOCITA_SFERA * (1.0 + 0.05 * potere)
		var mira := da + Vector2(verso * 100.0, 0.0)
		if g != null:
			mira = g.global_position + Vector2(0.0, -22.0)
			if tattica == "anticipo":
				# Mira dove andrai, non dove sei.
				var tempo := da.distance_to(mira) / velocita
				mira += Vector2(g.velocity.x, clampf(g.velocity.y, -200.0, 200.0)) * tempo * 0.85
		var direzione := (mira - da).normalized()
		var angoli := [0.0]
		if tattica == "raffica":
			angoli = [-0.2, 0.0, 0.2]
		for a: float in angoli:
			var sfera := Proiettile.new()
			sfera.position = da
			sfera.velocita = direzione.rotated(a) * velocita
			sfera.autore = self
			sfera.tattica = tattica
			get_parent().add_child(sfera)
		Rapporto.conta("magie_lanciate")
	if _t_stato >= LANCIO_DURATA:
		_t_ricarica = RICARICA_MAGO * (1.0 - 0.06 * potere) + (0.8 if tattica == "raffica" else 0.0)
		_cambia(Stato.FERMO)


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

func subisci(danno: int, da: Vector2, spinta: float) -> bool:
	if stato == Stato.MORTO or stato == Stato.RISVEGLIO:
		return false
	if stato == Stato.DORME:
		_risvegliati()  # un colpo lo sveglia soltanto
		return false
	vita -= danno
	Effetti.lampo(sprite)
	var lato := signf(global_position.x - da.x)
	if lato == 0.0:
		lato = 1.0
	if vita <= 0:
		_muori(lato)
		return true
	_cambia(Stato.COLPITO)
	velocity = Vector2(lato * spinta * 0.7, -90.0)
	sprite.riproduci("colpito", true)
	return true


func _muori(lato: float) -> void:
	_cambia(Stato.MORTO)
	velocity = Vector2(lato * 60.0, -80.0)
	collision_layer = 0
	_bersaglio.set_deferred("monitorable", false)
	_ombra.visible = false
	z_index = 3
	sprite.riproduci("morte", true)
	Rapporto.conta("nemici_uccisi")
	Rapporto.evento("nemico_ucciso", {"tipo": tipo, "x": roundi(global_position.x), "y": roundi(global_position.y),
			"nemesi": Memoria.nome_completo(nemesi) if not nemesi.is_empty() else ""})
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -22), Color(0.82, 0.8, 0.7, 0.8), 12, 80.0, 0.5, 220.0, false)
	var frase := Memoria.nemico_sconfitto(self)
	if frase != "":
		get_tree().call_group("hud", "messaggio", frase, 3.0)
