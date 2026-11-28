class_name Stordimento
extends Node2D
# Tre stelline che girano in ellisse sopra la testa di un nemico stordito (0.1.43). Si aggiunge come figlio del
# nemico, con la posizione sopra la testa, e si accende con mostra(true). Gialle pallide di norma, rosse quando
# il nemico si può eseguire. Vista di tre quarti: la stellina dietro è più piccola e più scura.

const GIRI_AL_SECONDO := 1.1
const RAGGIO := Vector2(9.0, 3.0)
const COLORE := Color(1.0, 0.93, 0.55)
const COLORE_ROSSO := Color(1.0, 0.3, 0.26)

var _rosse := false
var _fase := 0.0


func _init() -> void:
	z_index = 30
	light_mask = 0
	material = Effetti.materiale_piatto()   # non risente della luce: si vede anche nel buio
	visible = false
	set_process(false)


func mostra(si: bool, rosse: bool = false) -> void:
	_rosse = rosse
	visible = si
	set_process(si)
	queue_redraw()


func _process(delta: float) -> void:
	_fase = fposmod(_fase + delta * GIRI_AL_SECONDO * TAU, TAU)
	queue_redraw()


func _draw() -> void:
	var colore := COLORE_ROSSO if _rosse else COLORE
	# Prima quelle dietro (profondità negativa), poi quelle davanti.
	var stelle: Array = []
	for i in 3:
		var angolo := _fase + float(i) * TAU / 3.0
		stelle.append([sin(angolo), Vector2(cos(angolo) * RAGGIO.x, sin(angolo) * RAGGIO.y)])
	stelle.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for s: Array in stelle:
		var davanti := float(s[0]) >= 0.0
		var c := colore if davanti else Color(colore.r * 0.55, colore.g * 0.55, colore.b * 0.55)
		_stella((s[1] as Vector2).round(), c, 1 if davanti else 0)


func _stella(p: Vector2, c: Color, braccio: int) -> void:
	# Una crocetta di pixel (centro + quattro bracci); davanti ha i bracci lunghi due pixel.
	draw_rect(Rect2(p, Vector2.ONE), c)
	var lungo := float(1 + braccio)
	draw_rect(Rect2(p + Vector2(-lungo, 0.0), Vector2(lungo, 1.0)), c)
	draw_rect(Rect2(p + Vector2(1.0, 0.0), Vector2(lungo, 1.0)), c)
	draw_rect(Rect2(p + Vector2(0.0, -lungo), Vector2(1.0, lungo)), c)
	draw_rect(Rect2(p + Vector2(0.0, 1.0), Vector2(1.0, lungo)), c)
