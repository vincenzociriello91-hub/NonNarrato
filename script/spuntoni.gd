class_name Spuntoni
extends Node2D
# Punte d'acciaio che escono dal pavimento a tempo: prima tremano (avviso), poi escono e feriscono
# chiunque ci sia sopra, chi gioca e anche i nemici. Il bot chiede sicura_per() per passare al momento giusto.

const DENTRO := 1.6
const AVVISO := 0.45
const FUORI := 1.0
const LARGHEZZA := 96.0

var fase := 0.0                    # sfasamento del ciclo, in secondi
var sprite: SpriteAnimato

var _t := 0.0
var _stato := "dentro"
var _colpo: Area2D
var _colpiti := {}


func _ready() -> void:
	sprite = SpriteAnimato.new()
	sprite.carica("spuntoni")
	sprite.light_mask = Effetti.L_DAVANTI
	sprite.z_index = -10              # dietro le lastre del pavimento: rientrate non si vedono
	sprite.position = Vector2(0, -4)
	add_child(sprite)
	sprite.riproduci("dentro")
	_colpo = Area2D.new()
	_colpo.collision_layer = 0
	_colpo.collision_mask = Effetti.S_BERSAGLIO_GIOCATORE | Effetti.S_BERSAGLI
	_colpo.monitorable = false
	var rett := RectangleShape2D.new()
	rett.size = Vector2(LARGHEZZA - 10.0, 16.0)
	var forma := CollisionShape2D.new()
	forma.shape = rett
	forma.position = Vector2(0, -8)
	_colpo.add_child(forma)
	add_child(_colpo)
	_t = fmod(fase, _ciclo())
	add_to_group("trappole")


func _ciclo() -> float:
	return DENTRO + AVVISO + FUORI


func _stato_a(t: float) -> String:
	var u := fposmod(t, _ciclo())
	if u < DENTRO:
		return "dentro"
	if u < DENTRO + AVVISO:
		return "avviso"
	return "fuori"


func _physics_process(delta: float) -> void:
	_t += delta
	var nuovo := _stato_a(_t)
	if nuovo != _stato:
		match nuovo:
			"avviso":
				sprite.riproduci("avviso")
			"fuori":
				sprite.riproduci("esce", true)
				Suoni.suona("spuntoni", global_position, -6.0)
				Effetti.scoppio(get_parent(), global_position + Vector2(0, -4), Color(0.6, 0.6, 0.66, 0.6), 6, 50.0, 0.3, 120.0, false)
			"dentro":
				sprite.riproduci("rientra", true)
		_stato = nuovo
	if _stato == "fuori":
		for area in _colpo.get_overlapping_areas():
			Spuntoni.ferisci(area.get_meta("bersaglio", null), global_position + Vector2(0, 10), _colpiti, _t, "spuntoni")


static func ferisci(chi: Variant, da: Vector2, colpiti: Dictionary, ora: float, trappola: String) -> void:
	# Una trappola colpisce chi gioca e i nemici, ognuno al massimo una volta ogni 0,8 secondi.
	if not (chi is Giocatore or chi is Nemico) or not is_instance_valid(chi):
		return
	var id := (chi as Node).get_instance_id()
	if ora - float(colpiti.get(id, -10.0)) < 0.8:
		return
	if chi is Giocatore:
		if (chi as Giocatore).subisci(1, da, 120.0, null):
			colpiti[id] = ora
			Rapporto.conta("trappole_subite")
			var g := chi as Giocatore
			Rapporto.evento("trappola", {"cosa": trappola, "x": roundi(g.global_position.x), "stato": Giocatore.Stato.keys()[g.stato]})
	elif (chi as Nemico).subisci(1, da, 80.0):
		colpiti[id] = ora


func pericolosa() -> bool:
	return _stato == "fuori"


func zona() -> Rect2:
	return Rect2(global_position + Vector2(-LARGHEZZA * 0.5, -40.0), Vector2(LARGHEZZA, 40.0))


func attraversabile(x: float, verso: int, velocita: float, ritardo: float = 0.0) -> bool:
	# Si prova il passaggio più lento (parte in ritardo) e il più veloce (subito a piena velocità):
	# devono andare bene tutti e due.
	return _passaggio(x, verso, velocita, ritardo) and _passaggio(x, verso, Giocatore.VELOCITA, 0.0)


func _passaggio(x: float, verso: int, velocita: float, ritardo: float) -> bool:
	# Chi parte ora da x camminando a quella velocità è fuori dalle punte quando escono?
	var z := zona()
	var t := 0.0
	var px := x
	var fine := z.end.x + 12.0 if verso > 0 else z.position.x - 12.0
	while (fine - px) * verso > 0.0 and t < 4.0:
		if px > z.position.x - 12.0 and px < z.end.x + 12.0 and _stato_a(_t + t) == "fuori":
			return false
		t += 0.02
		if t > ritardo:
			px += verso * velocita * 0.02
	return true


func sicura_per(secondi: float) -> bool:
	# Le punte restano sotto (o solo in avviso) per tutto questo tempo?
	var passo := 0.05
	var t := 0.0
	while t <= secondi:
		if _stato_a(_t + t) == "fuori":
			return false
		t += passo
	return true
