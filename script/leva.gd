class_name Leva
extends Node2D
# Una leva di pietra e ferro: col tasto "afferra" (accanto) si tira e si rilascia.
# Apre e chiude ciò che comanda (di solito una Porta).

var nome := ""
var bersaglio: Node              # ha apri() e chiudi()
var accesa := false
var sprite: SpriteAnimato


func _ready() -> void:
	sprite = SpriteAnimato.new()
	sprite.carica("leva")
	sprite.light_mask = Effetti.L_DAVANTI
	add_child(sprite)
	sprite.riproduci("spenta")
	z_index = -2
	add_to_group("interagibili")


func puo_interagire() -> bool:
	return true


func etichetta() -> String:
	return "Leva"


func interagisci(_g: Node) -> void:
	accesa = not accesa
	sprite.riproduci("tira" if accesa else "rilascia", true)
	Rapporto.conta("leve_tirate")
	Rapporto.evento("leva", {"nome": nome, "accesa": accesa})
	Suoni.suona("leva", global_position)
	Controlli.vibra(0.3, 0.06)
	if bersaglio != null:
		if accesa:
			bersaglio.apri()
		else:
			bersaglio.chiudi()
