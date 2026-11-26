class_name Forziere
extends Node2D
# Un forziere: col tasto "afferra" (accanto) si apre. Dentro:
#  - forziere di legno: tre cuori di vita, dardi e frecce, un frammento della storia del Dormiente;
#  - forziere d'oro: un colore nuovo per l'aspetto (resta per sempre), dardi e frecce, un frammento.
# Si apre una volta per sogno.

signal aperto_ora(contenuto: Dictionary)

var nome := ""
var oro := false
var aperto := false
var contenuto := {}               # cosa ha dato, per il rapporto e per il bot
var sprite: SpriteAnimato


func _ready() -> void:
	sprite = SpriteAnimato.new()
	sprite.carica("forziere_oro" if oro else "forziere")
	sprite.light_mask = Effetti.L_DAVANTI
	add_child(sprite)
	sprite.riproduci("chiuso")
	if oro:
		sprite.modulate = Color(1.12, 1.0, 0.78)
	z_index = -1
	Effetti.occlusore(self, Rect2(-14, -26, 28, 24))
	add_to_group("interagibili")
	add_to_group("forzieri")


func puo_interagire() -> bool:
	return not aperto


func etichetta() -> String:
	return "Apri"


func interagisci(g: Node) -> void:
	if aperto:
		return
	aperto = true
	sprite.riproduci("apre", true)
	Controlli.vibra(0.35, 0.1)
	Suoni.suona("forziere", global_position)
	await get_tree().create_timer(0.35, false).timeout
	if not is_instance_valid(self):
		return
	contenuto = _premio(g)
	_bagliore()
	Rapporto.conta("forzieri_aperti")
	Rapporto.evento("forziere", {"nome": nome, "oro": oro, "contenuto": contenuto})
	var righe: Array = []
	if contenuto.has("vita"):
		righe.append("+%d vita" % int(contenuto["vita"]))
	var munizioni := PackedStringArray()
	for cosa: String in ["dardi", "frecce"]:
		if contenuto.has(cosa):
			munizioni.append("+%d %s" % [int(contenuto[cosa]), cosa])
	if not munizioni.is_empty():
		righe.append(", ".join(munizioni))
	if contenuto.has("colore"):
		righe.append("Nuovo colore: %s" % Equipaggiamento.COLORI[contenuto["colore"]][0])
	if contenuto.has("frammento"):
		righe.append(String(contenuto["frammento"]))
	if righe.is_empty():
		righe.append("Il forziere è vuoto. Qualcuno è arrivato prima di te.")
	get_tree().call_group("hud", "messaggio", "\n".join(righe), 5.0)
	aperto_ora.emit(contenuto)


func _premio(g: Node) -> Dictionary:
	var dati := {}
	if oro:
		var colore := Equipaggiamento.trova_colore()
		if colore != "":
			dati["colore"] = colore
			Rapporto.conta("colori_trovati")
	elif g != null and g.has_method("cura"):
		var curati: int = g.cura(3)
		if curati > 0:
			dati["vita"] = curati
	if g != null and g.has_method("raccogli"):
		var dardi: int = g.raccogli("dardi", 4)
		var frecce: int = g.raccogli("frecce", 3)
		if dardi > 0:
			dati["dardi"] = dardi
		if frecce > 0:
			dati["frecce"] = frecce
	var frammento := Equipaggiamento.trova_frammento()
	if frammento != "":
		dati["frammento"] = frammento
		Rapporto.conta("frammenti_trovati")
	return dati


func _bagliore() -> void:
	var colore := Color(1.0, 0.85, 0.45) if oro else Color(0.95, 0.8, 0.55)
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -20), colore, 18, 90.0, 0.7, -40.0, true, 1.0, Vector2.UP, 50.0)
	if Dispositivo.livello != "bassa":
		var luce := Effetti.luce(colore, 90.0, 1.6, 30.0)
		luce.position = Vector2(0, -24)
		add_child(luce)
		var tw := luce.create_tween()
		tw.tween_property(luce, "energy", 0.35, 1.4)
