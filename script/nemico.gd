class_name Nemico
extends CharacterBody2D
# Nemici di prova, con comportamenti diversi:
#  - "scheletro": guerriero. Può partire addormentato a terra, si risveglia quando ci si avvicina,
#    pattuglia, insegue e colpisce da vicino con un colpo lento ma annunciato.
#  - "mago": resta a distanza e lancia sfere di luce, che si possono schivare o spezzare con la spada.

enum Stato { DORME, RISVEGLIO, FERMO, PATTUGLIA, INSEGUE, ATTACCO, LANCIA, COLPITO, MORTO }

const TIPI := {
	"scheletro": {"foglio": "scheletro", "vita": 3, "passo": 30.0, "corsa": 54.0, "vista": 170.0, "portata": 38.0},
	"mago": {"foglio": "mago", "vita": 2, "passo": 26.0, "corsa": 26.0, "vista": 250.0, "portata": 0.0},
}
const GRAVITA := 1200.0
const ATTACCO_DURATA := 0.86
const ATTACCO_INIZIO := 0.40
const ATTACCO_FINE := 0.56
const LANCIO_DURATA := 0.83
const LANCIO_MOMENTO := 0.45
const RICARICA_MAGO := 2.4
const VELOCITA_SFERA := 115.0

var tipo := "scheletro"
var dorme := false
var stato := Stato.PATTUGLIA
var verso := -1
var vita := 3
var sprite: SpriteAnimato

var _dati := {}
var _t_stato := 0.0
var _t_ricarica := 1.0
var _t_senza_vista := 0.0
var _colpo_dato := false
var _lanciato := false
var _bersaglio: Area2D
var _colpo: Area2D
var _forma_colpo: CollisionShape2D
var _ombra: LightOccluder2D


func _ready() -> void:
	_dati = TIPI.get(tipo, TIPI["scheletro"])
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

	if dorme and sprite.ha("dorme"):
		stato = Stato.DORME
		sprite.riproduci("dorme")
		_bersaglio.monitorable = false
		_ombra.visible = false
	elif tipo == "mago":
		stato = Stato.PATTUGLIA
		sprite.riproduci("cammina")
	else:
		stato = Stato.PATTUGLIA
		sprite.riproduci("cammina")


func _physics_process(delta: float) -> void:
	_t_stato += delta
	_t_ricarica = maxf(0.0, _t_ricarica - delta)
	velocity.y = minf(velocity.y + GRAVITA * delta, 500.0)

	var g := get_tree().get_first_node_in_group("giocatore") as Giocatore
	var dx := 0.0
	var dy := 0.0
	var visto := false
	if g != null and g.stato != Giocatore.Stato.MORTO:
		dx = g.global_position.x - global_position.x
		dy = g.global_position.y - global_position.y
		var quota := 200.0 if tipo == "mago" else 80.0
		visto = absf(dx) < float(_dati["vista"]) and absf(dy) < quota

	match stato:
		Stato.DORME:
			velocity.x = 0.0
			if g != null and absf(dx) < 120.0 and absf(dy) < 70.0:
				_risvegliati()
		Stato.RISVEGLIO:
			velocity.x = 0.0
			if _t_stato >= sprite.durata("risveglio"):
				_bersaglio.set_deferred("monitorable", true)
				_ombra.visible = true
				_cambia(Stato.INSEGUE)
		Stato.PATTUGLIA:
			_pattuglia(visto)
		Stato.FERMO:
			_fermo_mago(g, dx, visto)
		Stato.INSEGUE:
			_insegui(delta, dx, dy, visto)
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


# ------------------------------------------------------------------ comportamenti

func _risvegliati() -> void:
	_cambia(Stato.RISVEGLIO)
	sprite.riproduci("risveglio", true)
	Rapporto.evento("risveglio", {"x": roundi(global_position.x)})


func _pattuglia(visto: bool) -> void:
	velocity.x = verso * float(_dati["passo"])
	sprite.riproduci("cammina")
	if is_on_floor() and (is_on_wall() or _vuoto_davanti()):
		verso = -verso
		velocity.x = verso * float(_dati["passo"])
	if visto:
		_cambia(Stato.FERMO if tipo == "mago" else Stato.INSEGUE)


func _fermo_mago(g: Giocatore, dx: float, visto: bool) -> void:
	velocity.x = 0.0
	sprite.riproduci("fermo")
	if not visto or g == null:
		_t_senza_vista += get_physics_process_delta_time()
		if _t_senza_vista > 2.0:
			_t_senza_vista = 0.0
			_cambia(Stato.PATTUGLIA)
		return
	_t_senza_vista = 0.0
	if absf(dx) > 4.0:
		verso = 1 if dx > 0.0 else -1
	if _t_ricarica <= 0.0:
		_lanciato = false
		_cambia(Stato.LANCIA)
		sprite.riproduci("lancia", true)


func _lancia(g: Giocatore) -> void:
	velocity.x = 0.0
	if not _lanciato and _t_stato >= LANCIO_MOMENTO:
		_lanciato = true
		var da := global_position + Vector2(verso * 16.0, -34.0)
		var direzione := Vector2(verso, 0.0)
		if g != null:
			direzione = (g.global_position + Vector2(0.0, -22.0) - da).normalized()
		var sfera := Proiettile.new()
		sfera.position = da
		sfera.velocita = direzione * VELOCITA_SFERA
		get_parent().add_child(sfera)
		Rapporto.conta("magie_lanciate")
	if _t_stato >= LANCIO_DURATA:
		_t_ricarica = RICARICA_MAGO
		_cambia(Stato.FERMO)


func _insegui(delta: float, dx: float, dy: float, visto: bool) -> void:
	if not visto:
		_t_senza_vista += delta
		if _t_senza_vista > 2.5:
			_t_senza_vista = 0.0
			_cambia(Stato.PATTUGLIA)
			return
	else:
		_t_senza_vista = 0.0
	if absf(dx) > 4.0:
		verso = 1 if dx > 0.0 else -1
	var vicino := absf(dx) < float(_dati["portata"]) and absf(dy) < 44.0
	if vicino and visto:
		velocity.x = 0.0
		if _t_ricarica <= 0.0 and is_on_floor():
			_colpo_dato = false
			_forma_colpo.position.x = 20.0 * verso
			_cambia(Stato.ATTACCO)
			sprite.riproduci("attacco", true)
		else:
			sprite.riproduci("fermo")
	elif not visto or (is_on_floor() and (is_on_wall() or _vuoto_davanti())):
		velocity.x = 0.0
		sprite.riproduci("fermo")
	else:
		velocity.x = verso * float(_dati["corsa"])
		sprite.riproduci("cammina", false, 1.6)


func _attacca(g: Giocatore) -> void:
	velocity.x = 0.0
	if not _colpo_dato and _t_stato >= ATTACCO_INIZIO and _t_stato <= ATTACCO_FINE:
		for area in _colpo.get_overlapping_areas():
			if area.get_meta("bersaglio", null) == g and g != null:
				_colpo_dato = true
				g.subisci(1, global_position, 190.0)
	if _t_stato >= ATTACCO_DURATA:
		_t_ricarica = 0.5
		_cambia(Stato.INSEGUE)


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
	Rapporto.evento("nemico_ucciso", {"tipo": tipo, "x": roundi(global_position.x), "y": roundi(global_position.y)})
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -22), Color(0.82, 0.8, 0.7, 0.8), 12, 80.0, 0.5, 220.0, false)
