class_name Titolo
extends CanvasLayer
# Schermata iniziale: il nome del gioco sopra la stanza in penombra (il gioco è in pausa dietro).
# Continua (solo se c'è un sogno da riprendere), Nuovo sogno, Impostazioni, Fai giocare il bot, Esci (solo computer).
# Con un controller si scorre con la croce o la leva; il tasto Indietro di Android, premuto due volte, chiude il gioco.

signal continua
signal nuovo_sogno
signal impostazioni
signal bot
signal esci

const VOLTE_INDIETRO_S := 2.0

var tasti := {}                 # nome -> Button (li usano le prove)
var _fondo: Control
var _colonna: VBoxContainer
var _descrizione: Label
var _conferma: PanelContainer
var _avviso: Label
var _versione: Label
var _t_indietro := -100.0


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_costruisci()
	visible = false


func _costruisci() -> void:
	_fondo = Control.new()
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP   # sotto ci sono i tasti a schermo: non devono ricevere tocchi
	add_child(_fondo)
	var tema := Theme.new()
	tema.default_font_size = 26
	_fondo.theme = tema

	# Penombra più scura in basso e ai lati: il nome resta leggibile sopra la stanza.
	var sfuma := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.02, 0.015, 0.04, 0.15), Color(0.02, 0.015, 0.04, 0.55), Color(0.02, 0.015, 0.04, 0.92)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.35)
	tex.fill_to = Vector2(1.1, 1.1)
	sfuma.texture = tex
	sfuma.set_anchors_preset(Control.PRESET_FULL_RECT)
	sfuma.stretch_mode = TextureRect.STRETCH_SCALE
	sfuma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondo.add_child(sfuma)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondo.add_child(centro)
	_colonna = VBoxContainer.new()
	_colonna.custom_minimum_size = Vector2(460, 0)
	_colonna.add_theme_constant_override("separation", 12)
	centro.add_child(_colonna)

	var nome := Label.new()
	nome.text = "NON NARRATO"
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 76)
	nome.add_theme_color_override("font_color", Color(0.86, 0.8, 0.97))
	nome.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.1))
	nome.add_theme_constant_override("outline_size", 10)
	nome.add_theme_color_override("font_shadow_color", Color(0.45, 0.2, 0.75, 0.55))
	nome.add_theme_constant_override("shadow_offset_y", 4)
	_colonna.add_child(nome)
	var motto := Label.new()
	motto.text = "l'ultima leggenda mai finita"
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	motto.add_theme_font_size_override("font_size", 24)
	motto.add_theme_color_override("font_color", Color(0.64, 0.6, 0.74))
	_colonna.add_child(motto)
	var spazio := Control.new()
	spazio.custom_minimum_size = Vector2(0, 26)
	_colonna.add_child(spazio)

	tasti["continua"] = _tasto("Continua", continua)
	_descrizione = Label.new()
	_descrizione.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_descrizione.add_theme_font_size_override("font_size", 19)
	_descrizione.add_theme_color_override("font_color", Color(0.7, 0.66, 0.8))
	_colonna.add_child(_descrizione)
	tasti["nuovo"] = _tasto("Nuovo sogno", _chiedi_nuovo)
	tasti["impostazioni"] = _tasto("Impostazioni", impostazioni)
	tasti["bot"] = _tasto("Fai giocare il bot", bot)
	tasti["esci"] = _tasto("Esci", esci)
	tasti["esci"].visible = not OS.has_feature("mobile")   # su Android si esce col tasto Indietro

	_avviso = Label.new()
	_avviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avviso.add_theme_font_size_override("font_size", 20)
	_avviso.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	_avviso.modulate.a = 0.0
	_colonna.add_child(_avviso)

	_versione = Label.new()
	_versione.anchor_left = 1.0
	_versione.anchor_top = 1.0
	_versione.anchor_right = 1.0
	_versione.anchor_bottom = 1.0
	_versione.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_versione.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_versione.offset_right = -22.0
	_versione.offset_bottom = -14.0
	_versione.add_theme_font_size_override("font_size", 16)
	_versione.add_theme_color_override("font_color", Color(0.5, 0.47, 0.58))
	_fondo.add_child(_versione)

	_costruisci_conferma()


func _tasto(testo: String, azione: Variant) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(0, 66)
	b.focus_mode = Control.FOCUS_ALL
	var normale := StyleBoxFlat.new()
	normale.bg_color = Color(0.08, 0.06, 0.13, 0.86)
	normale.border_color = Color(0.32, 0.28, 0.44)
	normale.set_border_width_all(2)
	normale.set_corner_radius_all(14)
	var acceso := normale.duplicate() as StyleBoxFlat
	acceso.bg_color = Color(0.22, 0.16, 0.36, 0.95)
	acceso.border_color = Color(0.82, 0.74, 1.0)
	for stato: String in ["normal", "disabled"]:
		b.add_theme_stylebox_override(stato, normale)
	for stato: String in ["hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(stato, acceso)
	b.add_theme_color_override("font_color", Color(0.86, 0.83, 0.94))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.pressed.connect(func() -> void: Suoni.suona("ui_tocco"))
	if azione is Signal:
		b.pressed.connect(func() -> void: (azione as Signal).emit())
	else:
		b.pressed.connect(azione as Callable)
	_colonna.add_child(b)
	return b


func _costruisci_conferma() -> void:
	_conferma = PanelContainer.new()
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(0.06, 0.05, 0.1, 0.98)
	stile.border_color = Color(0.6, 0.5, 0.85)
	stile.set_border_width_all(2)
	stile.set_corner_radius_all(16)
	stile.set_content_margin_all(24)
	_conferma.add_theme_stylebox_override("panel", stile)
	_conferma.set_anchors_preset(Control.PRESET_CENTER)
	_conferma.visible = false
	_fondo.add_child(_conferma)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_conferma.add_child(v)
	var testo := Label.new()
	testo.text = "Il sogno in corso finirà.\nLe nemesi e i caduti ricordano comunque."
	testo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(testo)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(riga)
	var si := Button.new()
	si.text = "Nuovo sogno"
	si.custom_minimum_size = Vector2(220, 60)
	si.pressed.connect(func() -> void:
		Suoni.suona("ui_tocco")
		_conferma.visible = false
		nuovo_sogno.emit())
	riga.add_child(si)
	var no := Button.new()
	no.text = "Annulla"
	no.custom_minimum_size = Vector2(220, 60)
	no.pressed.connect(_chiudi_conferma)
	riga.add_child(no)
	tasti["conferma_si"] = si
	tasti["conferma_no"] = no


func mostra() -> void:
	var c_e := Partita.esiste()
	tasti["continua"].visible = c_e
	_descrizione.visible = c_e
	_descrizione.text = Partita.descrizione()
	_versione.text = "Versione %s" % Aggiornatore.versione_attuale
	_conferma.visible = false
	_avviso.modulate.a = 0.0
	visible = true
	_colonna.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_colonna, "modulate:a", 1.0, 0.8)
	riprendi_focus()


func nascondi() -> void:
	visible = false
	_conferma.visible = false


func riprendi_focus() -> void:
	if not visible:
		return
	var primo: Button = tasti["continua"] if tasti["continua"].visible else tasti["nuovo"]
	primo.grab_focus.call_deferred()


func in_conferma() -> bool:
	return _conferma.visible


func _chiedi_nuovo() -> void:
	if not Partita.esiste():
		nuovo_sogno.emit()
		return
	_conferma.visible = true
	_conferma.reset_size()
	_conferma.position = (_fondo.size - _conferma.size) * 0.5
	(tasti["conferma_no"] as Button).grab_focus.call_deferred()


func _chiudi_conferma() -> void:
	Suoni.suona("ui_indietro")
	_conferma.visible = false
	(tasti["nuovo"] as Button).grab_focus.call_deferred()


func indietro() -> bool:
	# Tasto Indietro di Android sul titolo: chiude la conferma; altrimenti la prima volta avvisa, la seconda esce.
	# Torna true se il gioco deve chiudersi.
	if _conferma.visible:
		_chiudi_conferma()
		return false
	var adesso := Time.get_ticks_msec() / 1000.0
	if adesso - _t_indietro <= VOLTE_INDIETRO_S:
		return true
	_t_indietro = adesso
	_avviso.text = "Premi di nuovo Indietro per uscire"
	_avviso.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_avviso, "modulate:a", 0.0, 0.5)
	return false
