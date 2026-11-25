extends Node
# Impostazioni del gioco, salvate in user://impostazioni.cfg.
# Il gioco sceglie da solo i valori di partenza; qui restano le scelte fatte a mano.

signal cambiata(chiave: String)

const PERCORSO := "user://impostazioni.cfg"

const PREDEFINITE := {
	"grafica/qualita": "auto",          # auto, bassa, media, alta
	"grafica/limite_fps": 0,            # 0 = consigliato per il dispositivo
	"grafica/palette": true,            # filtro "palette fissa" in pixel art
	"grafica/ombre": true,              # ombre dinamiche delle luci
	"controlli/dimensione_touch": 1.0,
	"controlli/opacita_touch": 0.6,
	"controlli/vibrazione": true,
	"gioco/debug": true,                # schermata con FPS e dati del dispositivo
}

var _valori := {}


func _ready() -> void:
	_valori = PREDEFINITE.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PERCORSO) != OK:
		return
	for chiave: String in PREDEFINITE:
		var parti := chiave.split("/")
		if cfg.has_section_key(parti[0], parti[1]):
			var v: Variant = cfg.get_value(parti[0], parti[1])
			if typeof(v) == typeof(PREDEFINITE[chiave]):
				_valori[chiave] = v


func leggi(chiave: String) -> Variant:
	return _valori.get(chiave, PREDEFINITE.get(chiave))


func scrivi(chiave: String, valore: Variant) -> void:
	if _valori.get(chiave) == valore:
		return
	_valori[chiave] = valore
	_salva()
	cambiata.emit(chiave)


func ripristina() -> void:
	_valori = PREDEFINITE.duplicate()
	_salva()
	for chiave: String in PREDEFINITE:
		cambiata.emit(chiave)


func tutte() -> Dictionary:
	return _valori.duplicate()


func _salva() -> void:
	var cfg := ConfigFile.new()
	for chiave: String in _valori:
		var parti := chiave.split("/")
		cfg.set_value(parti[0], parti[1], _valori[chiave])
	cfg.save(PERCORSO)
