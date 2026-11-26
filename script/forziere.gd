class_name Forziere
extends Node2D
# Un forziere: col tasto "afferra" (accanto) si apre. Dentro (0.1.19):
#  - oggetti a caso (Bottino.per_forziere): vita, dardi, frecce, pozioni che saltano fuori;
#  - chi è ferito viene curato, chi ha finito dardi o frecce le ritrova;
#  - i forzieri della storia hanno anche un frammento; quello d'oro un colore nuovo per l'aspetto.
# I forzieri "casuale" (senza storia) a volte sono mimic: aperti, si svegliano e mordono.
# Si apre una volta per sogno.

signal aperto_ora(contenuto: Dictionary)
signal mimic_svegliato(nemico: Node)

var nome := ""
var oro := false
var casuale := false              # solo oggetti a caso, niente storia: può essere un mimic
var mimic := false                # deciso dalla stanza a ogni sogno
var aperto := false
var contenuto := {}               # cosa ha dato, per il rapporto e per il bot
var pozioni_uscite: Array = []    # i Raccoglibili saltati fuori
var sprite: SpriteAnimato
var _caso := RandomNumberGenerator.new()


func _ready() -> void:
	sprite = SpriteAnimato.new()
	sprite.carica("forziere_oro" if oro else "forziere")
	sprite.light_mask = Effetti.L_DAVANTI
	add_child(sprite)
	sprite.riproduci("chiuso")
	if oro:
		sprite.modulate = Color(1.12, 1.0, 0.78)
	z_index = -1
	_caso.seed = hash(nome) + int(Memoria.sogni) * 7919
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
	if mimic:
		await _sveglia_mimic()
		return
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
	for voce: Dictionary in contenuto.get("pozioni", []):
		var d := Bottino.descrizione(voce)
		righe.append(d.left(1).to_upper() + d.substr(1))
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
	var giocatore := g as Giocatore
	var cura := 0
	var dardi := 0
	var frecce := 0
	# Un aiuto a chi ne ha bisogno: ferito, o senza dardi o frecce.
	if giocatore != null:
		if giocatore.vita < Giocatore.VITA_MASSIMA and not oro:
			cura = 3
		if int(giocatore.munizioni["frecce"]) == 0:
			frecce = 3
		if int(giocatore.munizioni["dardi"]) == 0:
			dardi = 4
	# Il resto è a caso.
	var pozioni: Array = []
	for voce: Dictionary in Bottino.per_forziere(oro, _caso):
		match String(voce["cosa"]):
			"cura":
				cura += int(voce["quante"])
			"dardi":
				dardi += int(voce["quante"])
			"frecce":
				frecce += int(voce["quante"])
			"pozione":
				pozioni.append(voce)
	if giocatore != null:
		if cura > 0:
			var curati := giocatore.cura(cura)
			if curati > 0:
				dati["vita"] = curati
		var presi_dardi := giocatore.raccogli("dardi", dardi) if dardi > 0 else 0
		var prese_frecce := giocatore.raccogli("frecce", frecce) if frecce > 0 else 0
		if presi_dardi > 0:
			dati["dardi"] = presi_dardi
		if prese_frecce > 0:
			dati["frecce"] = prese_frecce
	if not pozioni.is_empty():
		dati["pozioni"] = pozioni
		pozioni_uscite = Bottino.lascia(get_parent(), global_position + Vector2(0, -18), pozioni, true, _caso)
	if not casuale:
		var frammento := Equipaggiamento.trova_frammento()
		if frammento != "":
			dati["frammento"] = frammento
			Rapporto.conta("frammenti_trovati")
	return dati


func _sveglia_mimic() -> void:
	# Il coperchio trema, si apre di scatto: era un mimic. Il forziere sparisce e al suo posto c'è lui.
	contenuto = {"mimic": true}
	Controlli.vibra(0.6, 0.25)
	Suoni.suona("mimic_ruggito", global_position)
	var tw := create_tween()
	for i in 4:
		tw.tween_property(sprite, "position:x", 2.0 if i % 2 == 0 else -2.0, 0.05)
	tw.tween_property(sprite, "position:x", 0.0, 0.05)
	await tw.finished
	if not is_instance_valid(self):
		return
	Rapporto.conta("mimic_svegliati")
	Rapporto.evento("mimic", {"nome": nome, "x": roundi(global_position.x), "y": roundi(global_position.y)})
	get_tree().call_group("hud", "messaggio", "Era un mimic!", 2.0)
	var nemico: Node = null
	if get_parent().has_method("sveglia_mimic"):
		nemico = get_parent().call("sveglia_mimic", self)
	visible = false
	remove_from_group("interagibili")
	mimic_svegliato.emit(nemico)


func _bagliore() -> void:
	var colore := Color(1.0, 0.85, 0.45) if oro else Color(0.95, 0.8, 0.55)
	Effetti.scoppio(get_parent(), global_position + Vector2(0, -20), colore, 18, 90.0, 0.7, -40.0, true, 1.0, Vector2.UP, 50.0)
	if Dispositivo.livello != "bassa":
		var luce := Effetti.luce(colore, 90.0, 1.6, 30.0)
		luce.position = Vector2(0, -24)
		add_child(luce)
		var tw := luce.create_tween()
		tw.tween_property(luce, "energy", 0.35, 1.4)
