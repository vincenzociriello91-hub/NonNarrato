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


class Fiato extends Control:
	# Stamina (barra verde) e respiro (bolle): compaiono solo quando servono.
	var stamina := 1.0
	var respiro := 1.0
	var esausto := false

	func _draw() -> void:
		var y := 0.0
		if stamina < 0.999:
			var colore := Color(0.85, 0.35, 0.3) if esausto else Color(0.45, 0.78, 0.42)
			draw_rect(Rect2(0, y, 120, 8), Color(0.05, 0.04, 0.08, 0.85))
			draw_rect(Rect2(1, y + 1, 118 * stamina, 6), colore)
			draw_rect(Rect2(0, y, 120, 8), Color(0.75, 0.72, 0.82, 0.8), false, 1.0)
			y += 14.0
		if respiro < 0.999:
			var bolle := 10
			for i in bolle:
				var c := Vector2(6.0 + i * 12.0, y + 6.0)
				var piena := respiro * bolle > float(i) + 0.5
				draw_circle(c, 5.0, Color(0.05, 0.06, 0.1, 0.8))
				if piena:
					draw_circle(c, 4.0, Color(0.6, 0.82, 1.0))
					draw_circle(c + Vector2(-1.5, -1.5), 1.2, Color(1, 1, 1, 0.9))
				else:
					draw_arc(c, 4.0, 0.0, TAU, 12, Color(0.6, 0.82, 1.0, 0.35), 1.0)


class Pozioni extends Control:
	# Pozioni in corso: un cerchio del loro colore che si svuota col tempo e la forza (×2 se sommate).
	var voci: Array = []           # [tipo, forza, frazione rimasta]

	func _draw() -> void:
		var x := 0.0
		for v: Array in voci:
			var c := Vector2(x + 11.0, 11.0)
			var colore: Color = Bottino.COLORI_POZIONE.get(v[0], Color.WHITE)
			draw_circle(c, 10.5, Color(0.05, 0.04, 0.08, 0.85))
			draw_arc(c, 8.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(float(v[2]), 0.0, 1.0), 24, colore, 3.0)
			draw_circle(c, 4.5, colore)
			if float(v[1]) >= 2.0:
				draw_string(ThemeDB.fallback_font, Vector2(x + 1.0, 36.0), "×%d" % int(v[1]), HORIZONTAL_ALIGNMENT_LEFT,
						-1, 12, Color(0.96, 0.93, 0.86))
			x += 30.0


const PULSANTI := [
	["attacca", "Colpo", 46.0], ["salta", "Salto", 42.0], ["rotola", "Rotola", 36.0],
	["schiva", "Schiva", 36.0], ["afferra", "Afferra", 34.0], ["tira", "Tira", 34.0],
	["cambia_arma", "Arma", 26.0], ["pausa", "II", 24.0],
]

var _centri := {}
var _stanza: Stanza
var _sogno := 1
var _radice: Control
var _cuori: Cuori
var _etichetta_sogno: Label
var _armi: Label
var _debug: Label
var _messaggio: Label
var _touch: Control
var _leva: VirtualJoystick
var _pulsanti := {}
var _t_debug := 0.0
var _tela := Vector2i(640, 360)
var _scala := 3.0
var _didascalie: VBoxContainer
var _fiato: Fiato
var _pozioni: Pozioni
var _oggetto: Label
var _avviso_oggetto: Tween
var _pausa := false
var _avviso_messaggio: Tween


func _ready() -> void:
	layer = 10
	add_to_group("hud")  # i nemici ci scrivono le loro frasi
	_radice = Control.new()
	_radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_radice)

	_cuori = Cuori.new()
	_cuori.size = Vector2(170, 30)
	_cuori.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(_cuori)

	_fiato = Fiato.new()
	_fiato.size = Vector2(130, 32)
	_fiato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(_fiato)
	_pozioni = Pozioni.new()
	_pozioni.size = Vector2(140, 40)
	_pozioni.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(_pozioni)
	_oggetto = _etichetta(15, Color(0.95, 0.9, 0.8))
	_oggetto.modulate.a = 0.0
	_radice.add_child(_oggetto)

	_etichetta_sogno = _etichetta(15, Color(0.72, 0.7, 0.84))
	_radice.add_child(_etichetta_sogno)
	_armi = _etichetta(16, Color(0.86, 0.82, 0.95))
	_radice.add_child(_armi)

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

	# Didascalie dei suoni (accessibilità): in basso al centro, spariscono da sole.
	_didascalie = VBoxContainer.new()
	_didascalie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_didascalie.alignment = BoxContainer.ALIGNMENT_BEGIN
	_radice.add_child(_didascalie)

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
	# "Margini" nelle impostazioni dello schermo: -1 = area sicura del telefono, altrimenti una quota in più.
	var area := get_viewport().get_visible_rect().size
	var extra: float = Impostazioni.leggi("schermo/margini")
	var aggiunta := maxf(0.0, extra) * area.x
	if not OS.has_feature("mobile"):
		return [aggiunta, aggiunta * 0.5, aggiunta, aggiunta * 0.5]
	var finestra := Vector2(get_window().size)
	var sicura := DisplayServer.get_display_safe_area()
	var fattore := finestra.x / maxf(1.0, area.x)
	return [
		maxf(0.0, sicura.position.x) / fattore + aggiunta,
		maxf(0.0, sicura.position.y) / fattore + aggiunta * 0.5,
		maxf(0.0, finestra.x - sicura.end.x) / fattore + aggiunta,
		maxf(0.0, finestra.y - sicura.end.y) / fattore + aggiunta * 0.5,
	]


func _disponi() -> void:
	if _radice == null:
		return
	var area := get_viewport().get_visible_rect().size
	var m := _margini()
	_cuori.position = Vector2(m[0] + 16.0, m[1] + 14.0)
	_fiato.position = Vector2(m[0] + 270.0, m[1] + 16.0)
	_pozioni.position = Vector2(m[0] + 410.0, m[1] + 10.0)
	_oggetto.position = Vector2(m[0] + 410.0, m[1] + 52.0)
	_etichetta_sogno.position = Vector2(m[0] + 20.0, m[1] + 46.0)
	_armi.position = Vector2(m[0] + 20.0, m[1] + 68.0)
	_debug.position = Vector2(m[0] + 16.0, m[1] + 100.0)
	_debug.visible = Impostazioni.leggi("gioco/debug")
	# Le frasi lunghe (per esempio quelle delle nemesi) vanno a capo restando al centro.
	_messaggio.position = Vector2(area.x * 0.12, area.y * 0.26)
	_messaggio.size = Vector2(area.x * 0.76, 170.0)
	_messaggio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var k := Dispositivo.scala_touch()
	var mancino: bool = Impostazioni.leggi("controlli/mancino")
	_touch.modulate.a = Impostazioni.leggi("controlli/opacita_touch")
	_leva.deadzone_ratio = clampf(Impostazioni.leggi("controlli/zona_morta"), 0.05, 0.9)
	# Per chi è mancino la leva va a destra e i tasti a sinistra (disposizione specchiata).
	_leva.position = Vector2(area.x * 0.58 if mancino else m[0], area.y * 0.36)
	_leva.size = Vector2(area.x * 0.42 - (m[2] if mancino else m[0]), area.y * 0.64 - m[3])
	_leva.joystick_size = 150.0 * k
	_leva.tip_size = 64.0 * k
	var bx: float = area.x - m[2]
	var by: float = area.y - m[3]
	var posti := {
		"attacca": Vector2(bx - 96.0 * k, by - 96.0 * k),
		"salta": Vector2(bx - 215.0 * k, by - 78.0 * k),
		"rotola": Vector2(bx - 84.0 * k, by - 212.0 * k),
		"schiva": Vector2(bx - 200.0 * k, by - 186.0 * k),
		"afferra": Vector2(bx - 330.0 * k, by - 90.0 * k),  # compare solo accanto a casse, leve e forzieri
		"tira": Vector2(bx - 318.0 * k, by - 212.0 * k),
		"cambia_arma": Vector2(bx - 112.0 * k, by - 306.0 * k),
		"pausa": Vector2(bx - 44.0, m[1] + 44.0),
	}
	if mancino:
		for azione: String in posti:
			if azione != "pausa":
				var p: Vector2 = posti[azione]
				posti[azione] = Vector2(m[0] + (bx - p.x), p.y)
	# In alto al centro, sotto la riga della vita: non coprono mai il personaggio.
	_didascalie.position = Vector2(area.x * 0.25, m[1] + 12.0)
	_didascalie.size = Vector2(area.x * 0.5, area.y * 0.18)
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


func misure(tela: Vector2i, scala: float) -> void:
	_tela = tela
	_scala = scala


func in_pausa(v: bool) -> void:
	_pausa = v
	_aggiorna_touch()


func centro_tasto(azione: String) -> Vector2:
	# Dove sta il tasto a schermo (in unità dell'interfaccia): serve al bot per "toccarlo".
	return _centri.get(azione, Vector2.ZERO)


func tasto_visibile(azione: String) -> bool:
	return _touch.visible and _pulsanti.has(azione) and (_pulsanti[azione]["nodo"] as TouchScreenButton).visible


func testo_armi() -> String:
	return _armi.text


func testo_tasto(azione: String) -> String:
	if not _pulsanti.has(azione):
		return ""
	return ((_pulsanti[azione]["nodo"] as TouchScreenButton).get_child(0) as Label).text


func tasti_a_schermo_visibili() -> bool:
	return _touch.visible


# ------------------------------------------------------------------ contenuti

func collega(stanza: Stanza, sogno: int) -> void:
	_stanza = stanza
	_sogno = sogno
	var g := stanza.giocatore
	g.vita_cambiata.connect(_su_vita)
	_su_vita(g.vita, Giocatore.VITA_MASSIMA)
	g.armi_cambiate.connect(_su_armi)
	_su_armi()
	_etichetta_sogno.text = "Sogno %d" % sogno


func _su_armi() -> void:
	# Armi a distanza: quella scelta tra parentesi, con i colpi rimasti; rossa per un attimo se è scarica.
	if not is_instance_valid(_stanza) or not is_instance_valid(_stanza.giocatore):
		return
	var g := _stanza.giocatore
	var parti := PackedStringArray()
	for arma: String in Giocatore.ORDINE_ARMI:
		var testo := "%s %d" % [Giocatore.ARMI_DISTANZA[arma]["nome"], g.colpi_rimasti(arma)]
		parti.append("[%s]" % testo if arma == g.arma_distanza else testo)
	_armi.text = "   ".join(parti)
	if _pulsanti.has("cambia_arma"):
		var nome: String = Giocatore.ARMI_DISTANZA[g.arma_distanza]["nome"]
		((_pulsanti["cambia_arma"]["nodo"] as TouchScreenButton).get_child(0) as Label).text = nome.left(5)
	if not g.puo_tirare():
		_armi.modulate = Color(1.0, 0.45, 0.45)
		var tw := create_tween()
		tw.tween_property(_armi, "modulate", Color.WHITE, 0.5)


func _su_vita(vita: int, massima: int) -> void:
	_cuori.vita = vita
	_cuori.massima = massima
	_cuori.queue_redraw()


func didascalia(testo: String, colore: Color = Color(0.95, 0.92, 0.8)) -> void:
	# Scritta per un suono importante (attivabile in Accessibilità). Restano al massimo 3 righe.
	if not Impostazioni.leggi("acc/didascalie") or _didascalie == null:
		return
	for vecchia in _didascalie.get_children():
		if (vecchia as Label).text == testo:
			vecchia.queue_free()
	var e := _etichetta(20, colore)
	e.text = testo
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sfondo := StyleBoxFlat.new()
	sfondo.bg_color = Color(0.02, 0.02, 0.04, 0.55)
	sfondo.set_content_margin_all(4)
	sfondo.set_corner_radius_all(4)
	e.add_theme_stylebox_override("normal", sfondo)
	_didascalie.add_child(e)
	while _didascalie.get_child_count() > 3:
		var prima := _didascalie.get_child(0)
		_didascalie.remove_child(prima)
		prima.queue_free()
	var tw := e.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(e, "modulate:a", 0.0, 0.5)
	tw.tween_callback(e.queue_free)


func didascalie_visibili() -> int:
	return _didascalie.get_child_count() if _didascalie != null else 0


func messaggio(testo: String, durata: float, storia: bool = false) -> void:
	if storia and not Impostazioni.leggi("gioco/messaggi"):
		return  # frasi delle nemesi spente; restano i messaggi che servono per giocare
	_messaggio.text = testo
	if _avviso_messaggio != null and _avviso_messaggio.is_valid():
		_avviso_messaggio.kill()
	_avviso_messaggio = create_tween()
	_avviso_messaggio.tween_property(_messaggio, "modulate:a", 1.0, 0.4)
	_avviso_messaggio.tween_interval(durata)
	_avviso_messaggio.tween_property(_messaggio, "modulate:a", 0.0, 0.6)


func didascalia_oggetto(testo: String, colore: Color = Color(0.95, 0.9, 0.8)) -> void:
	# Cosa hai appena preso (una pozione, e se si è sommata a quella in corso).
	if _oggetto == null:
		return
	_oggetto.text = testo
	_oggetto.add_theme_color_override("font_color", colore.lightened(0.25))
	if _avviso_oggetto != null and _avviso_oggetto.is_valid():
		_avviso_oggetto.kill()
	_oggetto.modulate.a = 1.0
	_avviso_oggetto = create_tween()
	_avviso_oggetto.tween_interval(2.2)
	_avviso_oggetto.tween_property(_oggetto, "modulate:a", 0.0, 0.5)


func pozioni_visibili() -> int:
	return _pozioni.voci.size() if _pozioni != null else 0


func fiato_visibile() -> bool:
	return _fiato != null and (_fiato.stamina < 0.999 or _fiato.respiro < 0.999)


func _process(delta: float) -> void:
	if is_instance_valid(_stanza) and is_instance_valid(_stanza.giocatore):
		var g := _stanza.giocatore
		var st := g.stamina / Giocatore.STAMINA_MASSIMA
		var re := g.respiro / Giocatore.RESPIRO_MASSIMO
		if absf(st - _fiato.stamina) > 0.004 or absf(re - _fiato.respiro) > 0.004 or _fiato.esausto != g.get("_esausto"):
			_fiato.stamina = st
			_fiato.respiro = re
			_fiato.esausto = g.get("_esausto")
			_fiato.queue_redraw()
		if not g.effetti.is_empty() or not _pozioni.voci.is_empty():
			var voci: Array = []
			for tipo: String in Bottino.TIPI_POZIONE:
				if g.effetti.has(tipo):
					var e: Dictionary = g.effetti[tipo]
					voci.append([tipo, float(e["forza"]), float(e["tempo"]) / maxf(0.1, float(e["durata"]))])
			_pozioni.voci = voci
			_pozioni.queue_redraw()
	# "Afferra" serve solo accanto a una cassa, a una leva o a un forziere, e dice cosa fa.
	if _pulsanti.has("afferra"):
		var cosa := ""
		if is_instance_valid(_stanza) and is_instance_valid(_stanza.giocatore):
			cosa = _stanza.giocatore.cosa_vicina()
		var tasto := _pulsanti["afferra"]["nodo"] as TouchScreenButton
		tasto.visible = cosa != ""
		if cosa != "":
			(tasto.get_child(0) as Label).text = cosa
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
	righe.append("Tela %dx%d ×%s   torce con ombra: %d" % [_tela.x, _tela.y, str(snappedf(_scala, 0.01)), ombre])
	righe.append("Comandi: %s %s" % [Controlli.nome_modo(), Controlli.controller])
	if is_instance_valid(_stanza) and is_instance_valid(_stanza.giocatore):
		var g := _stanza.giocatore
		righe.append("%s  pos %d,%d  vel %d,%d" % [
			Giocatore.Stato.keys()[g.stato], roundi(g.position.x), roundi(g.position.y), roundi(g.velocity.x), roundi(g.velocity.y)])
	righe.append("Rapporto in Download: %s" % Rapporto.esito_download)
	_debug.text = "\n".join(righe)
