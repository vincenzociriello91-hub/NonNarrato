class_name Piastra
extends Area2D
# Piastra a pressione nel pavimento. La abbassano chi gioca, i nemici e le casse.
#  - "tenuta": finché è premuta tiene aperto il bersaglio (una Porta); lasciata, si richiude poco dopo.
#  - "scatto": appena premuta fa scattare il bersaglio (per esempio una balestra nel muro).

signal premuta(da_cassa: bool)

var nome := ""
var modo := "tenuta"
var bersaglio: Node
var ritardo := 0.35               # "tenuta": quanto resta aperta dopo che la si lascia
var giu := false
var da_cassa := false             # chi la tiene premuta adesso è una cassa
var sprite: SpriteAnimato

var _t_lascia := -1.0
var _chi := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = Effetti.S_GIOCATORE | Effetti.S_OGGETTI | Effetti.S_NEMICI
	monitorable = false
	var rett := RectangleShape2D.new()
	rett.size = Vector2(34, 10)
	var forma := CollisionShape2D.new()
	forma.shape = rett
	forma.position = Vector2(0, -5)
	add_child(forma)
	sprite = SpriteAnimato.new()
	sprite.carica("piastra")
	sprite.light_mask = Effetti.L_DAVANTI
	sprite.set_process(false)
	sprite.riproduci("su")
	sprite.z_index = -8
	add_child(sprite)
	add_to_group("piastre")


func _physics_process(delta: float) -> void:
	var corpi := get_overlapping_bodies()
	var premuta_ora := not corpi.is_empty()
	var cassa := false
	var chi := ""
	for c in corpi:
		if c is RigidBody2D:
			cassa = true
		if chi == "":
			chi = "cassa" if c is RigidBody2D else ("giocatore" if c is Giocatore else "nemico")
	_chi = chi
	da_cassa = cassa
	if premuta_ora and not giu:
		_premi(cassa)
	elif premuta_ora:
		_t_lascia = -1.0
	elif giu:
		if _t_lascia < 0.0:
			_t_lascia = ritardo
		_t_lascia -= delta
		if _t_lascia <= 0.0:
			_lascia()


func _premi(cassa: bool) -> void:
	giu = true
	_t_lascia = -1.0
	sprite.riproduci("giu")
	Controlli.vibra(0.15, 0.05)
	Rapporto.evento("piastra", {"nome": nome, "cassa": cassa, "chi": _chi})
	premuta.emit(cassa)
	if bersaglio == null:
		return
	if modo == "scatto":
		bersaglio.scatta()
	else:
		bersaglio.apri()


func _lascia() -> void:
	giu = false
	_t_lascia = -1.0
	sprite.riproduci("su")
	if bersaglio != null and modo == "tenuta":
		bersaglio.chiudi()
