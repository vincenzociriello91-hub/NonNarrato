class_name SpriteAnimato
extends Sprite2D
# Sprite nato da un modello 3D: foglio dei colori, foglio delle normali (per le luci)
# ed elenco delle animazioni. I tre file li crea strumenti/render_sprite.gd.

signal finita(nome: String)
signal densita_cambiata          # passato all'altra definizione (chi ha materiali legati ai pixel li rifà)

static var _fogli := {}
# Figure in doppia definizione (0.1.37): con 2 i fogli che hanno la variante "_x2" (il doppio dei pixel)
# si disegnano a metà grandezza in un mondo disegnato al doppio. La decide Principale (Dispositivo.densita_figure).
static var densita_figure := 1
const SUFFISSO_DOPPIA := "_x2"
const GRUPPO_DENSE := "figure_dense"

var animazione := ""
var fotogramma := 0          # posizione dentro l'animazione in corso
var velocita := 1.0
var in_corso := false

var _dati := {}
var _anim := {}
var _cella := Vector2i(16, 16)
var _colonne := 1
var _tempo := 0.0
var densita_px := 1               # pixel del foglio per pixel di gioco (1 o 2)
var scala_base := Vector2.ONE    # 1 / densita_px: schiacciamenti e slanci la moltiplicano, non la sostituiscono
var _nome := ""
var _fotogrammi: Array = []      # fogli ritagliati: [x, y, largo, alto, da_x, da_y] per fotogramma


static func densita(fotogrammi: int, fps: float, fps_minimo: float) -> int:
	# Movimenti fluidi (0.1.33): un'animazione sotto fps_minimo prende k volte i fotogrammi e k volte gli fps.
	# La durata (fotogrammi / fps) resta identica: i tempi di gioco non cambiano.
	if fotogrammi <= 1 or fps <= 0.0 or fps >= fps_minimo:
		return 1
	return ceili(fps_minimo / fps)


static func foglio(nome: String) -> Dictionary:
	if _fogli.has(nome):
		return _fogli[nome]
	var base := "res://arte/sprite/" + nome
	var dati: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if typeof(dati) != TYPE_DICTIONARY:
		push_error("Foglio sprite non valido: " + nome)
		dati = {"cella": [16, 16], "piedi": [8, 16], "colonne": 1, "animazioni": {}}
	var tex := CanvasTexture.new()
	tex.diffuse_texture = load(base + ".png")
	tex.normal_texture = load(base + "_n.png")
	var voce := {"texture": tex, "dati": dati}
	_fogli[nome] = voce
	return voce


static func ha_doppia(nome: String) -> bool:
	return FileAccess.file_exists("res://arte/sprite/%s%s.json" % [nome, SUFFISSO_DOPPIA])


func carica(nome: String) -> void:
	_nome = nome
	var doppia := ha_doppia(nome)
	if doppia and not is_in_group(GRUPPO_DENSE):
		add_to_group(GRUPPO_DENSE)
	var voce := foglio(nome + SUFFISSO_DOPPIA if doppia and densita_figure >= 2 else nome)
	_dati = voce["dati"]
	texture = voce["texture"]
	_cella = Vector2i(int(_dati["cella"][0]), int(_dati["cella"][1]))
	_colonne = maxi(1, int(_dati.get("colonne", 1)))
	_fotogrammi = _dati.get("fotogrammi", [])
	var prima := scala_base
	densita_px = maxi(1, int(_dati.get("densita", 1)))
	scala_base = Vector2.ONE / float(densita_px)
	scale = scale / prima * scala_base   # uno schiacciamento in corso resta
	centered = false
	offset = -Vector2(float(_dati["piedi"][0]), float(_dati["piedi"][1]))
	region_enabled = true
	_mostra(0)


func aggiorna_densita() -> void:
	# Cambiata la densità delle figure (impostazioni o calore): stesso foglio nell'altra definizione,
	# stessa animazione allo stesso punto.
	if _nome == "" or densita_px == (2 if densita_figure >= 2 else 1):
		return
	var anim := animazione
	var f := fotogramma
	var t := _tempo
	var andava := in_corso
	carica(_nome)
	var tutte: Dictionary = _dati.get("animazioni", {})
	if anim != "" and tutte.has(anim):
		animazione = anim
		_anim = tutte[anim]
		fotogramma = clampi(f, 0, (_anim["frame"] as Array).size() - 1)
		_tempo = t
		in_corso = andava
		_mostra(int(_anim["frame"][fotogramma]))
	densita_cambiata.emit()


func dimensione() -> Vector2i:
	# In pixel di gioco (con la doppia definizione il foglio ne ha il doppio).
	return _cella / densita_px


func piedi() -> Vector2:
	return Vector2(float(_dati["piedi"][0]), float(_dati["piedi"][1])) / float(densita_px)


func ha(nome: String) -> bool:
	return (_dati.get("animazioni", {}) as Dictionary).has(nome)


func durata(nome: String) -> float:
	var tutte: Dictionary = _dati.get("animazioni", {})
	if not tutte.has(nome):
		return 0.0
	return float((tutte[nome]["frame"] as Array).size()) / float(tutte[nome]["fps"])


func riproduci(nome: String, ricomincia: bool = false, nuova_velocita: float = 1.0) -> void:
	velocita = nuova_velocita
	if nome == animazione and not ricomincia:
		return  # un'animazione finita resta sull'ultimo fotogramma finché non se ne chiede un'altra
	var tutte: Dictionary = _dati.get("animazioni", {})
	if not tutte.has(nome):
		return
	animazione = nome
	_anim = tutte[nome]
	fotogramma = 0
	_tempo = 0.0
	in_corso = true
	_mostra(int(_anim["frame"][0]))


func posa(nome: String, frazione: float) -> void:
	# Fotogramma scelto dal gioco, non dal tempo (0.1.33): per esempio l'arco del salto secondo la velocità.
	var tutte: Dictionary = _dati.get("animazioni", {})
	if not tutte.has(nome):
		return
	if animazione != nome:
		animazione = nome
		_anim = tutte[nome]
	in_corso = false
	var elenco: Array = _anim["frame"]
	if _anim.get("ciclo", false):
		fotogramma = int(fposmod(frazione, 1.0) * float(elenco.size())) % elenco.size()   # giro: 1 torna a 0
	else:
		fotogramma = clampi(roundi(clampf(frazione, 0.0, 1.0) * float(elenco.size() - 1)), 0, elenco.size() - 1)
	_mostra(int(elenco[fotogramma]))


func _process(delta: float) -> void:
	if not in_corso or _anim.is_empty():
		return
	_tempo += delta * velocita
	var fps: float = _anim["fps"]
	var elenco: Array = _anim["frame"]
	var indice := int(_tempo * fps)
	if indice >= elenco.size():
		if _anim.get("ciclo", false):
			indice = indice % elenco.size()
			_tempo = fmod(_tempo, float(elenco.size()) / fps)
		else:
			in_corso = false
			fotogramma = elenco.size() - 1
			_mostra(int(elenco[fotogramma]))
			finita.emit(animazione)
			return
	if indice != fotogramma:
		fotogramma = indice
		_mostra(int(elenco[indice]))


func _mostra(i: int) -> void:
	if not _fotogrammi.is_empty():
		# Foglio ritagliato: ogni fotogramma ha il suo rettangolo e il suo posto rispetto ai piedi.
		var r: Array = _fotogrammi[clampi(i, 0, _fotogrammi.size() - 1)]
		region_rect = Rect2(r[0], r[1], r[2], r[3])
		var px := float(_dati["piedi"][0])
		var py := float(_dati["piedi"][1])
		# Il rettangolo è largo uguale ai due lati dei piedi: girato (flip_h) resta al suo posto.
		offset = Vector2(float(r[4]) - px, float(r[5]) - py)
		return
	@warning_ignore("integer_division")
	var riga := i / _colonne
	region_rect = Rect2((i % _colonne) * _cella.x, riga * _cella.y, _cella.x, _cella.y)
