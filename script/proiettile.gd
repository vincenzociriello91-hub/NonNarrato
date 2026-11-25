class_name Proiettile
extends Area2D
# Sfera di luce lanciata dal mago. Si spegne contro i muri, ferisce il giocatore,
# e si può spezzare con un colpo di spada.

const COLORE := Color(0.42, 0.86, 1.0)

var velocita := Vector2.ZERO
var _vita := 3.5
var _spenta := false


func _ready() -> void:
	collision_layer = Effetti.S_BERSAGLI
	collision_mask = Effetti.S_MONDO | Effetti.S_BERSAGLIO_GIOCATORE
	set_meta("bersaglio", self)
	z_index = 12

	var cerchio := CircleShape2D.new()
	cerchio.radius = 4.0
	var forma := CollisionShape2D.new()
	forma.shape = cerchio
	add_child(forma)

	var alone := Polygon2D.new()
	alone.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(0, -4), Vector2(4, 0), Vector2(0, 4)])
	alone.color = COLORE
	alone.material = Effetti.materiale_luminoso()
	alone.light_mask = 0
	add_child(alone)
	var cuore := Polygon2D.new()
	cuore.polygon = PackedVector2Array([Vector2(-2, 0), Vector2(0, -2), Vector2(2, 0), Vector2(0, 2)])
	cuore.color = Color(1, 1, 1)
	cuore.material = Effetti.materiale_luminoso()
	cuore.light_mask = 0
	add_child(cuore)

	var scia := CPUParticles2D.new()
	scia.amount = Effetti.quantita(10)
	scia.lifetime = 0.35
	scia.local_coords = false
	scia.spread = 180.0
	scia.initial_velocity_min = 2.0
	scia.initial_velocity_max = 10.0
	scia.gravity = Vector2.ZERO
	scia.color = COLORE
	scia.color_ramp = Effetti.sfumatura()
	scia.material = Effetti.materiale_luminoso()
	scia.light_mask = 0
	add_child(scia)

	if Dispositivo.livello != "bassa":
		add_child(Effetti.luce(COLORE, 62.0, 0.9, 20.0))

	body_entered.connect(func(_corpo: Node2D) -> void: _svanisci())
	area_entered.connect(_su_area)


func _physics_process(delta: float) -> void:
	position += velocita * delta
	_vita -= delta
	if _vita <= 0.0:
		_svanisci()


func _su_area(area: Area2D) -> void:
	var chi: Variant = area.get_meta("bersaglio", null)
	if chi is Giocatore and (chi as Giocatore).subisci(1, global_position, 150.0):
		_svanisci()


func subisci(_danno: int, _da: Vector2, _spinta: float) -> bool:
	Rapporto.conta("magie_spezzate")
	_svanisci()
	return true


func _svanisci() -> void:
	if _spenta:
		return
	_spenta = true
	Effetti.scoppio(get_parent(), global_position, COLORE, 8, 70.0, 0.3, 0.0)
	queue_free()
