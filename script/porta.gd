class_name Porta
extends AnimatableBody2D
# Qualcosa che si apre e si chiude scorrendo: una grata di ferro, un gradino di pietra che sale
# dal pavimento. È un corpo solido che si muove (spinge chi ci sta sopra) e lo comandano leve,
# piastre ed enigmi con apri() e chiudi(). Si costruisce da codice: vedi Stanza.

signal cambiata(aperta: bool)

var nome := ""
var misura := Vector2(20, 60)        # rettangolo solido, con i piedi (in basso al centro) nella posizione
var spostamento := Vector2(0, 64)    # da chiusa ad aperta
var velocita := 90.0                 # pixel al secondo
var foglio := ""                     # sprite (grata); vuoto = blocco di pietra disegnato
var aperta := false

var _chiusa_in := Vector2.ZERO
var _meta := 0.0                     # 0 chiusa, 1 aperta
var _voluta := 0.0


func _ready() -> void:
	collision_layer = Effetti.S_MONDO
	collision_mask = 0
	sync_to_physics = true
	_chiusa_in = position
	var rett := RectangleShape2D.new()
	rett.size = misura
	var forma := CollisionShape2D.new()
	forma.shape = rett
	forma.position = Vector2(0, -misura.y * 0.5)
	add_child(forma)
	if foglio != "":
		var s := SpriteAnimato.new()
		s.carica(foglio)
		s.light_mask = Effetti.L_DAVANTI
		s.set_process(false)
		add_child(s)
	else:
		_disegna_pietra()
	Effetti.occlusore(self, Rect2(-misura.x * 0.5 + 2.0, -misura.y + 2.0, misura.x - 4.0, misura.y - 4.0), false)   # niente ombra: strisce dalle torce
	add_to_group("porte")


func _disegna_pietra() -> void:
	var voce := SpriteAnimato.foglio("fondamenta")
	var s := Sprite2D.new()
	s.texture = voce["texture"]
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, misura)
	s.position = Vector2(-misura.x * 0.5, -misura.y)
	s.light_mask = Effetti.L_DAVANTI
	add_child(s)
	var lastra := SpriteAnimato.foglio("lastra")
	var sopra := Sprite2D.new()
	sopra.texture = lastra["texture"]
	sopra.centered = false
	sopra.region_enabled = true
	sopra.region_rect = Rect2(0, 0, misura.x + 2.0, 23.0)
	sopra.position = Vector2(-misura.x * 0.5 - 1.0, -misura.y - 9.0)
	sopra.light_mask = Effetti.L_DAVANTI
	add_child(sopra)


func _physics_process(delta: float) -> void:
	if is_equal_approx(_meta, _voluta):
		return
	var passo := velocita * delta / maxf(1.0, spostamento.length())
	_meta = move_toward(_meta, _voluta, passo)
	position = _chiusa_in + spostamento * _meta
	if is_equal_approx(_meta, _voluta) and aperta:
		Effetti.scoppio(get_parent(), global_position + Vector2(0, -2), Color(0.55, 0.52, 0.5, 0.6), 6, 40.0, 0.4, 60.0, false)


func apri() -> void:
	if aperta:
		return
	aperta = true
	_voluta = 1.0
	_scossa()
	Suoni.suona("porta", global_position)
	Rapporto.evento("porta", {"nome": nome, "aperta": true})
	cambiata.emit(true)


func chiudi() -> void:
	if not aperta:
		return
	aperta = false
	_voluta = 0.0
	_scossa()
	Suoni.suona("porta", global_position, 0.0, 0.85)
	Rapporto.evento("porta", {"nome": nome, "aperta": false})
	cambiata.emit(false)


func del_tutto_aperta() -> bool:
	return aperta and _meta >= 0.999


func _scossa() -> void:
	var g := get_tree().get_first_node_in_group("giocatore") as Giocatore
	if g != null and g.global_position.distance_to(global_position) < 360.0:
		g.scuoti(1.5)
		Controlli.vibra(0.25, 0.12)
