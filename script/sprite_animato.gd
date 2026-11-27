class_name SpriteAnimato
extends Sprite2D
# Sprite nato da un modello 3D: foglio dei colori, foglio delle normali (per le luci)
# ed elenco delle animazioni. I tre file li crea strumenti/render_sprite.gd.

signal finita(nome: String)

static var _fogli := {}

var animazione := ""
var fotogramma := 0          # posizione dentro l'animazione in corso
var velocita := 1.0
var in_corso := false

var _dati := {}
var _anim := {}
var _cella := Vector2i(16, 16)
var _colonne := 1
var _tempo := 0.0


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


func carica(nome: String) -> void:
	var voce := foglio(nome)
	_dati = voce["dati"]
	texture = voce["texture"]
	_cella = Vector2i(int(_dati["cella"][0]), int(_dati["cella"][1]))
	_colonne = maxi(1, int(_dati.get("colonne", 1)))
	centered = false
	offset = -Vector2(float(_dati["piedi"][0]), float(_dati["piedi"][1]))
	region_enabled = true
	_mostra(0)


func dimensione() -> Vector2i:
	return _cella


func piedi() -> Vector2:
	return -offset


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
	@warning_ignore("integer_division")
	var riga := i / _colonne
	region_rect = Rect2((i % _colonne) * _cella.x, riga * _cella.y, _cella.x, _cella.y)
