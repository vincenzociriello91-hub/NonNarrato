class_name Raccoglibile
extends Area2D
# Munizioni da raccogliere passandoci sopra: un fascio di dardi o una faretra di frecce.
# Le lasciano i barili rotti (a volte); dopo un po' svaniscono.

const DURATA := 14.0

var cosa := "dardi"                # "dardi" o "frecce"
var quante := 3

var _t := 0.0
var _sprite: SpriteAnimato


func _ready() -> void:
	collision_layer = 0
	collision_mask = Effetti.S_GIOCATORE
	monitorable = false
	var rett := RectangleShape2D.new()
	rett.size = Vector2(18, 18)
	var forma := CollisionShape2D.new()
	forma.shape = rett
	forma.position = Vector2(0, -9)
	add_child(forma)
	_sprite = SpriteAnimato.new()
	_sprite.carica("munizioni_" + cosa)
	_sprite.light_mask = Effetti.L_DAVANTI
	_sprite.set_process(false)
	add_child(_sprite)
	if Dispositivo.profilo.get("luci_doppie", true):
		var bagliore := Effetti.luce(Color(1.0, 0.82, 0.5), 34.0, 0.8, 14.0)   # si nota anche al buio
		bagliore.position = Vector2(0, -10)
		add_child(bagliore)
	z_index = 3
	body_entered.connect(_su_corpo)
	add_to_group("raccoglibili")


var permanente := false           # quelli messi nella stanza (per esempio sul ripiano di legno) non spariscono


func _process(delta: float) -> void:
	if permanente:
		_t = fmod(_t + delta, 2.0 * PI)
		_sprite.position.y = -2.0 - absf(sin(_t * 3.0)) * 3.0
		return
	_t += delta
	_sprite.position.y = -2.0 - absf(sin(_t * 3.0)) * 3.0   # saltella per farsi notare
	if _t > DURATA - 2.0:
		_sprite.visible = int(_t * 8.0) % 2 == 0
	if _t > DURATA:
		queue_free()


func _su_corpo(corpo: Node2D) -> void:
	if not corpo is Giocatore:
		return
	var prese := (corpo as Giocatore).raccogli(cosa, quante)
	if prese <= 0:
		return   # già piene: restano lì
	Rapporto.conta("munizioni_raccolte", prese)
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -8), Color(0.95, 0.85, 0.6), 8, 50.0, 0.4, -40.0)
	queue_free()
