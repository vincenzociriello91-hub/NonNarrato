class_name PiattaformaFragile
extends StaticBody2D
# Lastra crepata attraversabile dal basso: poco dopo che ci si sale sopra trema e crolla,
# poi dopo qualche secondo torna al suo posto.

const LARGHEZZA := 50.0
const ATTESA := 0.9
const RITORNO := 3.0

var nome := ""
var presente := true

var _t := -1.0                      # conto alla rovescia del crollo (o del ritorno)
var _crollata := false
var _forma: CollisionShape2D
var _sprite: SpriteAnimato
var _sopra: Area2D


func _ready() -> void:
	collision_layer = Effetti.S_PIATTAFORME
	collision_mask = 0
	var rett := RectangleShape2D.new()
	rett.size = Vector2(LARGHEZZA, 8.0)
	_forma = CollisionShape2D.new()
	_forma.shape = rett
	_forma.position = Vector2(0, 4)
	_forma.one_way_collision = true
	_forma.one_way_collision_margin = 4.0
	add_child(_forma)
	_sprite = SpriteAnimato.new()
	_sprite.carica("lastra_crepata")
	_sprite.light_mask = Effetti.L_DAVANTI
	_sprite.set_process(false)
	_sprite.position = Vector2(0, 3)
	add_child(_sprite)
	_sopra = Area2D.new()
	_sopra.collision_layer = 0
	_sopra.collision_mask = Effetti.S_GIOCATORE
	_sopra.monitorable = false
	var r2 := RectangleShape2D.new()
	r2.size = Vector2(LARGHEZZA - 4.0, 6.0)
	var f2 := CollisionShape2D.new()
	f2.shape = r2
	f2.position = Vector2(0, -3)
	_sopra.add_child(f2)
	add_child(_sopra)
	Effetti.occlusore(self, Rect2(-LARGHEZZA * 0.5, 0, LARGHEZZA, 8), false)
	add_to_group("fragili")


func _physics_process(delta: float) -> void:
	if _crollata:
		_t -= delta
		if _t <= 0.0 and _sopra.get_overlapping_bodies().is_empty():
			_torna()
		return
	if _t < 0.0:
		for corpo in _sopra.get_overlapping_bodies():
			if corpo is Giocatore and (corpo as Giocatore).is_on_floor():
				_t = ATTESA
				Rapporto.evento("lastra_trema", {"nome": nome})
		return
	_t -= delta
	_sprite.position.x = sin(_t * 70.0) * 1.0   # trema
	if _t <= 0.0:
		_crolla()


func _crolla() -> void:
	_crollata = true
	presente = false
	_t = RITORNO
	_forma.set_deferred("disabled", true)
	_sprite.position.x = 0.0
	Rapporto.conta("piattaforme_crollate")
	Rapporto.evento("crollo", {"nome": nome})
	Suoni.suona("crollo", global_position, -2.0)
	Effetti.scoppio(get_parent(), global_position + Vector2(0, 4), Color(0.5, 0.47, 0.45, 0.8), 14, 60.0, 0.6, 300.0, false)
	var tw := _sprite.create_tween()
	tw.tween_property(_sprite, "position:y", 48.0, 0.45).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.45)


func _torna() -> void:
	_crollata = false
	presente = true
	_t = -1.0
	_forma.set_deferred("disabled", false)
	_sprite.position = Vector2(0, 3)
	var tw := _sprite.create_tween()
	tw.tween_property(_sprite, "modulate:a", 1.0, 0.4)
