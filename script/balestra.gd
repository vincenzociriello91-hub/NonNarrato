class_name Balestra
extends Node2D
# Balestra murata: quando una piastra la fa scattare, tira una freccia dritta davanti a sé.

const VELOCITA_FRECCIA := 220.0
const RICARICA := 1.2

var verso := -1                    # da che parte tira
var _t_ricarica := 0.0
var _sprite: SpriteAnimato


func _ready() -> void:
	_sprite = SpriteAnimato.new()
	_sprite.carica("balestra")
	_sprite.light_mask = Effetti.L_DAVANTI
	_sprite.set_process(false)
	_sprite.flip_h = verso > 0
	_sprite.position = Vector2(0, 7)
	add_child(_sprite)
	z_index = 3


func _physics_process(delta: float) -> void:
	_t_ricarica = maxf(0.0, _t_ricarica - delta)


func scatta() -> void:
	if _t_ricarica > 0.0:
		return
	_t_ricarica = RICARICA
	# Il clic del meccanismo, un attimo per reagire, poi la freccia.
	Effetti.scoppio(get_parent(), position + Vector2(verso * 8.0, -6.0), Color(1.0, 0.8, 0.5), 4, 30.0, 0.2, 0.0)
	await get_tree().create_timer(0.25, false).timeout
	if not is_instance_valid(self):
		return
	var freccia := Proiettile.new()
	freccia.tipo = "freccia"
	freccia.velocita = Vector2(verso * VELOCITA_FRECCIA, 0.0)
	freccia.position = position + Vector2(verso * 14.0, 0.0)
	get_parent().add_child(freccia)
	Rapporto.conta("frecce_scoccate")
	Effetti.scoppio(get_parent(), position + Vector2(verso * 12.0, 0.0), Color(0.6, 0.55, 0.5, 0.6), 5, 40.0, 0.25, 0.0, false)
