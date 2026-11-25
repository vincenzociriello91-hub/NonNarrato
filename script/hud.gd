class_name Hud
extends CanvasLayer
# Interfaccia sopra il gioco: vita, tasti a schermo (solo se si gioca col tocco),
# messaggi e la schermata di debug con FPS e dati del dispositivo.

signal pausa_richiesta


class Cuori extends Control:
	# La vita, disegnata come rombi.
	var vita := 5
	var massima := 5

	func _draw() -> void:
		for i in massima:
			var c := Vector2(14.0 + i * 30.0, 14.0)
			draw_colored_polygon(_rombo(c, 12.0), Color(0.05, 0.04, 0.08, 0.85))
			if i < vita:
				draw_colored_polygon(_rombo(c, 8.0), Color(0.78, 0.16, 0.2))
			var bordo := _rombo(c, 12.0)
			bordo.append(bordo[0])
			draw_polyline(bordo, Color(0.75, 0.72, 0.82, 0.9), 1.5)

	func _rombo(c: Vector2, r: float) -> PackedVector2Array:
		return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


const PULSANTI := [
	["attacca", "Colpo", 46.0], ["salta", "Salto", 42.0], ["rotola", "Rotola", 36.0],
	["schiva", "Schiva", 36.0], ["pausa", "II", 24.0],
]

var _centri := {}
var _stanza: Stanza
var _sogno := 1
var _radice: Control
var _cuori: Cuori
var _etichetta_sogno: Label
var _debug: Label
var _messaggio: Label
var _touch: Control
var _leva: VirtualJoystick
var _pulsanti := {}
var _t_debug := 0.0
var _tela := Vector2i(640, 360)
var _scala := 3
var _pausa := false
var _avviso_messaggio: Tween


func _ready() -> void:
	layer = 10
	_radice = Control.new()
	_radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_radice)

	_cuori = Cuori.new()
	_cuori.size = Vector2(170, 30)
	_cuori.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(_cuori)

	_etichetta_sogno = _etichetta(15, Color(0.72, 0.7, 0.84))
	_radice.add_child(_etichetta_sogno)

	_debug = _etichetta(14, Color(0.86, 0.9, 0.86))
	var sfondo := StyleBoxFlat.new()
	sfondo.bg_color = Color(0.02, 0.02, 0.04, 0.6)
	sfondo.set_content_margin_all(8)
	sfondo.set_corner_radius_all(6)
	_debug.add_theme_stylebox_override("normal", sfondo)
	_radice.add_child(_debug)

	_messaggio = _etichetta(34, Color(0.9, 0.88, 0.96))
	_messaggio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_messaggio.modulate.a = 0.0
	_radice.add_child(_messaggio)

	_crea_touch()
	get_viewport().size_changed.connect(_disponi)
	Controlli.modo_cambiato.connect(func(_tocco: bool) -> void: _aggiorna_touch())
	Impostazioni.cambiata.connect(func(_chiave: String) -> void: _disponi())
	_disponi()


func _etichetta(grandezza: int, colore: Color) -> Label:
	var e := Label.new()
	e.add_theme_font_size_override("font_size", grandezza)
	e.add_theme_color_override("font_color", colore)
	e.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	e.add_theme_constant_override("outline_size", 4)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


func _crea_touch() -> void:
	_touch = Control.new()
	_touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(_touch)

	# Leva virtuale: compare dove si appoggia il pollice, nella metà sinistra dello schermo.
	_leva = VirtualJoystick.new()
	_leva.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC
	_leva.visibility_mode = VirtualJoystick.VISIBILITY_ALWAYS
	_leva.action_left = &"sinistra"
	_leva.action_right = &"destra"
	_leva.action_up = &"su"
	_leva.action_down = &"giu"
	_touch.add_child(_leva)

	var normale := _cerchio(0.16)
	var premuto := _cerchio(0.45)
	for dati: Array in PULSANTI:
		var p := TouchScreenButton.new()
		p.texture_normal = normale
		p.texture_pressed = premuto
		var forma := CircleShape2D.new()
		forma.radius = 64.0
		p.shape = forma
		p.shape_centered = true
		p.action = dati[0]
		var scritta := Label.new()
		scritta.text = dati[1]
		scritta.size = Vector2(128, 128)
		scritta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scritta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		scritta.add_theme_font_size_override("font_size", 30)
		scritta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(scritta)
		_touch.add_child(p)
		_pulsanti[dati[0]] = {"nodo": p, "raggio": dati[2]}


func _cerchio(pieno: float) -> ImageTexture:
	var lato := 128
	var img := Image.create(lato, lato, false, Image.FORMAT_RGBA8)
	var centro := Vector2(63.5, 63.5)
	for y in lato:
		for x in lato:
			var d := Vector2(x, y).distance_to(centro)
			var a := 0.0
			if d <= 62.0:
				a = 0.85 if d >= 56.0 else pieno
				if d > 61.0:
					a *= 62.0 - d
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ disposizione

func _margini() -> Array:
	# Spazio da lasciare libero per notch e bordi curvi: sinistra, alto, destra, basso.
	if not OS.has_feature("mobile"):
		return [0.0, 0.0, 0.0, 0.0]
	var finestra := Vector2(get_window().size)
	var sicura := DisplayServer.get_display_safe_area()
	var fattore := finestra.x / maxf(1.0, get_viewport().get_visible_rect().size.x)
	return [
		maxf(0.0, sicura.position.x) / fattore,
		maxf(0.0, sicura.position.y) / fattore,
		maxf(0.0, finestra.x - sicura.end.x) / fattore,
		maxf(0.0, finestra.y - sicura.end.y) / fattore,
	]


func _disponi() -> void:
	if _radice == null:
		return
	var area := get_viewport().get_visible_rect().size
	var m := _margini()
	_cuori.position = Vector2(m[0] + 16.0, m[1] + 14.0)
	_etichetta_sogno.position = Vector2(m[0] + 20.0, m[1] + 46.0)
	_debug.position = Vector2(m[0] + 16.0, m[1] + 78.0)
	_debug.visible = Impostazioni.leggi("gioco/debug")
	_messaggio.position = Vector2(0.0, area.y * 0.3)
	_messaggio.size = Vector2(area.x, 50.0)

	var k := Dispositivo.scala_touch()
	_touch.modulate.a = Impostazioni.leggi("controlli/opacita_touch")
	_leva.position = Vector2(m[0], area.y * 0.36)
	_leva.size = Vector2(area.x * 0.42 - m[0], area.y * 0.64 - m[3])
	_leva.joystick_size = 150.0 * k
	_leva.tip_size = 64.0 * k
	var bx: float = area.x - m[2]
	var by: float = area.y - m[3]
	var posti := {
		"attacca": Vector2(bx - 96.0 * k, by - 96.0 * k),
		"salta": Vector2(bx - 215.0 * k, by - 78.0 * k),
		"rotola": Vector2(bx - 84.0 * k, by - 212.0 * k),
		"schiva": Vector2(bx - 200.0 * k, by - 186.0 * k),
		"pausa": Vector2(bx - 44.0, m[1] + 44.0),
	}
	_centri = posti
	for azione: String in _pulsanti:
		var voce: Dictionary = _pulsanti[azione]
		var nodo: TouchScreenButton = voce["nodo"]
		var raggio: float = float(voce["raggio"]) * (1.0 if azione == "pausa" else k)
		nodo.scale = Vector2.ONE * (raggio / 64.0)
		nodo.position = (posti[azione] as Vector2) - Vector2(64, 64) * nodo.scale
	_aggiorna_touch()


func _aggiorna_touch() -> void:
	_touch.visible = Controlli.touch and not _pausa


func misure(tela: Vector2i, scala: int) -> void:
	_tela = tela
	_scala = scala


func in_pausa(v: bool) -> void:
	_pausa = v
	_aggiorna_touch()


func centro_tasto(azione: String) -> Vector2:
	# Dove sta il tasto a schermo (in unità dell'interfaccia): serve al bot per "toccarlo".
	return _centri.get(azione, Vector2.ZERO)


func tasti_a_schermo_visibili() -> bool:
	return _touch.visible


# ------------------------------------------------------------------ contenuti

func collega(stanza: Stanza, sogno: int) -> void:
	_stanza = stanza
	_sogno = sogno
	var g := stanza.giocatore
	g.vita_cambiata.connect(_su_vita)
	_su_vita(g.vita, Giocatore.VITA_MASSIMA)
	_etichetta_sogno.text = "Sogno %d" % sogno


func _su_vita(vita: int, massima: int) -> void:
	_cuori.vita = vita
	_cuori.massima = massima
	_cuori.queue_redraw()


func messaggio(testo: String, durata: float) -> void:
	_messaggio.text = testo
	if _avviso_messaggio != null and _avviso_messaggio.is_valid():
		_avviso_messaggio.kill()
	_avviso_messaggio = create_tween()
	_avviso_messaggio.tween_property(_messaggio, "modulate:a", 1.0, 0.4)
	_avviso_messaggio.tween_interval(durata)
	_avviso_messaggio.tween_property(_messaggio, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	if not _debug.visible:
		return
	_t_debug -= delta
	if _t_debug > 0.0:
		return
	_t_debug = 0.25
	var fps := Engine.get_frames_per_second()
	var righe := PackedStringArray()
	righe.append("NonNarrato %s   %d FPS (%.1f ms)" % [
		ProjectSettings.get_setting("application/config/version", "?"), fps, 1000.0 / maxf(1.0, fps)])
	righe.append_array(Dispositivo.righe_debug())
	var ombre := 0
	if is_instance_valid(_stanza):
		ombre = _stanza.torce_con_ombra()
	righe.append("Tela %dx%d ×%d   torce con ombra: %d" % [_tela.x, _tela.y, _scala, ombre])
	righe.append("Comandi: %s %s" % [Controlli.nome_modo(), Controlli.controller])
	if is_instance_valid(_stanza) and is_instance_valid(_stanza.giocatore):
		var g := _stanza.giocatore
		righe.append("%s  pos %d,%d  vel %d,%d" % [
			Giocatore.Stato.keys()[g.stato], roundi(g.position.x), roundi(g.position.y), roundi(g.velocity.x), roundi(g.velocity.y)])
	righe.append("Rapporto in Download: %s" % Rapporto.esito_download)
	_debug.text = "\n".join(righe)
