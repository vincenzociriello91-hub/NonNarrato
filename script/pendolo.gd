class_name Pendolo
extends Node2D
# Una sega dentata appesa a una catena che oscilla. Ferisce chi gioca e i nemici.
# Rotolando ci si passa sotto; in piedi bisogna aspettare che sia lontana (il bot usa sicura_per()).
# La posizione del nodo è il perno in alto.

const LUNGHEZZA := 128.0
const AMPIEZZA := 1.05             # radianti (circa 60 gradi)
const PERIODO := 2.8
const RAGGIO := 14.0

var fase := 0.0
var pavimento := 480.0             # quota dei piedi sotto il pendolo (per zona e sicurezza)

var _t := 0.0
var _catena: Line2D
var _sega: SpriteAnimato
var _colpo: Area2D
var _colpiti := {}


func _ready() -> void:
	_catena = Line2D.new()
	_catena.width = 2.0
	_catena.default_color = Color(0.3, 0.3, 0.36)
	_catena.light_mask = Effetti.L_DAVANTI
	_catena.points = PackedVector2Array([Vector2.ZERO, Vector2(0, LUNGHEZZA)])
	add_child(_catena)
	var attacco := Polygon2D.new()
	attacco.polygon = PackedVector2Array([Vector2(-7, -4), Vector2(7, -4), Vector2(4, 3), Vector2(-4, 3)])
	attacco.color = Color(0.25, 0.24, 0.3)
	attacco.light_mask = Effetti.L_DAVANTI
	add_child(attacco)
	_sega = SpriteAnimato.new()
	_sega.carica("sega")
	_sega.light_mask = Effetti.L_DAVANTI
	add_child(_sega)
	_sega.riproduci("gira")
	_colpo = Area2D.new()
	_colpo.collision_layer = 0
	_colpo.collision_mask = Effetti.S_BERSAGLIO_GIOCATORE | Effetti.S_BERSAGLI
	_colpo.monitorable = false
	var cerchio := CircleShape2D.new()
	cerchio.radius = RAGGIO
	var forma := CollisionShape2D.new()
	forma.shape = cerchio
	_colpo.add_child(forma)
	add_child(_colpo)
	z_index = 4
	_t = fase
	_aggiorna()
	add_to_group("trappole")


func angolo_a(t: float) -> float:
	return AMPIEZZA * sin(TAU * t / PERIODO)


func _punta(angolo: float) -> Vector2:
	return Vector2(sin(angolo), cos(angolo)) * LUNGHEZZA


func _physics_process(delta: float) -> void:
	_t += delta
	_aggiorna()
	for area in _colpo.get_overlapping_areas():
		Spuntoni.ferisci(area.get_meta("bersaglio", null), global_position + _punta(angolo_a(_t)) + Vector2(0, -20), _colpiti, _t, "pendolo")


func _aggiorna() -> void:
	var punta := _punta(angolo_a(_t))
	_catena.set_point_position(1, punta)
	_colpo.position = punta
	# Nel modello il centro della ruota sta 0,9 unità (21,6 px) sopra i piedi dello sprite.
	_sega.position = punta + Vector2(0, 21.6)


func _bassa(t: float) -> bool:
	# La sega arriva all'altezza di chi sta in piedi?
	var punta := global_position + _punta(angolo_a(t))
	return punta.y + RAGGIO > pavimento - 44.0


func pericolosa() -> bool:
	return _bassa(_t)


func zona() -> Rect2:
	var mezza := LUNGHEZZA * sin(acos(clampf((pavimento - 44.0 - RAGGIO - global_position.y) / LUNGHEZZA, -1.0, 1.0))) + RAGGIO
	return Rect2(Vector2(global_position.x - mezza, pavimento - 44.0), Vector2(mezza * 2.0, 44.0))


func sicura_per(secondi: float) -> bool:
	var t := 0.0
	while t <= secondi:
		if _bassa(_t + t):
			return false
		t += 0.03
	return true


func attraversabile(x: float, verso: int, velocita: float, ritardo: float = 0.0) -> bool:
	# Si prova il passaggio più lento (parte in ritardo) e il più veloce (subito a piena velocità):
	# devono andare bene tutti e due.
	return _passaggio(x, verso, velocita, ritardo) and _passaggio(x, verso, Giocatore.VELOCITA, 0.0)


func _passaggio(x: float, verso: int, velocita: float, ritardo: float) -> bool:
	# Chi parte ora da x camminando a quella velocità passa senza che la sega lo tocchi?
	# Si simula il passaggio: dove sarà il corpo (in piedi) e dove sarà la sega, istante per istante.
	var z := zona()
	var fine := z.end.x + 10.0 if verso > 0 else z.position.x - 10.0
	var t := 0.0
	var px := x
	while (fine - px) * verso > 0.0 and t < 4.0:
		var punta := global_position + _punta(angolo_a(_t + t))
		if absf(punta.x - px) < RAGGIO + 9.0 and punta.y + RAGGIO > pavimento - 46.0:
			return false
		t += 0.02
		if t > ritardo:
			px += verso * velocita * 0.02
	return true
