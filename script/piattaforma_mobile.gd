class_name PiattaformaMobile
extends AnimatableBody2D
# Montacarichi: un piano di assi appeso a due catene che sale e scende da solo, con una sosta
# in basso e una in alto. Ci si sale sopra (anche saltando da sotto: si attraversa).

const LARGHEZZA := 64.0
const SOSTA := 1.4
const VIAGGIO := 3.0

var basso := 480.0                 # quota del piano (piedi di chi ci sta sopra) alla sosta in basso
var alto := 120.0
var carrucola := 60.0              # quota da cui scendono le catene
var fase := 0.0

var _t := 0.0
var _catene: Array = []


func _ready() -> void:
	collision_layer = Effetti.S_PIATTAFORME
	collision_mask = 0
	sync_to_physics = true
	var rett := RectangleShape2D.new()
	rett.size = Vector2(LARGHEZZA, 8.0)
	var forma := CollisionShape2D.new()
	forma.shape = rett
	forma.position = Vector2(0, 4)
	forma.one_way_collision = true
	forma.one_way_collision_margin = 4.0
	add_child(forma)
	var s := SpriteAnimato.new()
	s.carica("montacarichi")
	s.light_mask = Effetti.L_DAVANTI
	s.set_process(false)
	s.position = Vector2(0, 2)
	add_child(s)
	for x in [-26.0, 26.0]:
		var catena := Line2D.new()
		catena.width = 1.0
		catena.default_color = Color(0.32, 0.32, 0.38)
		catena.light_mask = Effetti.L_DAVANTI
		catena.points = PackedVector2Array([Vector2(x, 0), Vector2(x, -10)])
		catena.z_index = -1
		add_child(catena)
		_catene.append(catena)
	Effetti.occlusore(self, Rect2(-LARGHEZZA * 0.5, 0, LARGHEZZA, 6))
	_t = fase
	position.y = quota_a(_t)
	_catene_a_posto()
	add_to_group("montacarichi")


func _ciclo() -> float:
	return 2.0 * (SOSTA + VIAGGIO)


func quota_a(t: float) -> float:
	var u := fposmod(t, _ciclo())
	if u < SOSTA:
		return basso
	u -= SOSTA
	if u < VIAGGIO:
		return lerpf(basso, alto, _dolce(u / VIAGGIO))
	u -= VIAGGIO
	if u < SOSTA:
		return alto
	u -= SOSTA
	return lerpf(alto, basso, _dolce(u / VIAGGIO))


func _dolce(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


func _physics_process(delta: float) -> void:
	_t += delta
	position.y = quota_a(_t)
	_catene_a_posto()


func _catene_a_posto() -> void:
	for c: Line2D in _catene:
		c.set_point_position(1, Vector2(c.get_point_position(0).x, carrucola - position.y))


func fermo_in_basso(per_almeno: float = 0.0) -> bool:
	# In sosta in basso, e ci resterà ancora per almeno questo tempo.
	var u := fposmod(_t, _ciclo())
	return u < SOSTA - per_almeno


func fermo_in_alto() -> bool:
	var u := fposmod(_t, _ciclo())
	return u >= SOSTA + VIAGGIO and u < 2.0 * SOSTA + VIAGGIO
