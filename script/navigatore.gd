class_name Navigatore
extends RefCounted
# La mappa della stanza per il bot: superfici su cui stare in piedi e i modi per passare dall'una
# all'altra (camminare, saltare, aggrapparsi a un bordo, scendere da un bordo, attraversare una
# piattaforma con giù + salto, rotolare nel cunicolo, passare una grata aperta, prendere il
# montacarichi). Alcuni passaggi esistono solo a certe condizioni (grata aperta, lastra non
# crollata): le chiede alla stanza con "condizione". Trova il percorso più comodo e tiene
# l'esperienza: un passaggio fallito costa di più la volta dopo e il punto di stacco viene corretto,
# così lo stesso errore non si ripete (come il bot di Minecraft). Salvata in user://bot_esperienza.cfg.

const PERCORSO := "user://bot_esperienza.cfg"
const SALTO_PIENO := 76.0        # dislivello superabile con un salto normale
const SALTO_CON_PRESA := 135.0   # aggrappandosi al bordo
const DISTANZA_SALTO := 90.0

var superfici := {}              # id -> {x0, x1, y, passante, isolata?, fragile?, condizione?}
var archi: Array = []            # {da, a, tipo, stacco, verso, altezza, meta?, condizione?}
var condizione: Callable         # nome -> bool (se non c'è, tutto è sempre possibile)
var _speciali: Array = []
var _vietati := {}
var esperienza := {}             # chiave arco -> {prove, riuscite, scarto, errori_di_fila}
var errori_ripetuti := 0
var lezioni: Array = []


func _init(elenco: Array, speciali: Array = []) -> void:
	for s: Dictionary in elenco:
		superfici[s["id"]] = s
	_speciali = speciali
	_costruisci()
	_carica()


func _costruisci() -> void:
	archi.clear()
	_vietati.clear()
	for sp: Dictionary in _speciali:
		if sp.get("tipo", "") == "vietato":
			_vietati["%s>%s" % [sp["da"], sp["a"]]] = true
			continue
		var arco := sp.duplicate()
		arco["altezza"] = float(superfici[sp["da"]]["y"]) - float(superfici[sp["a"]]["y"])
		archi.append(arco)
	for id_a: String in superfici:
		for id_b: String in superfici:
			if id_a != id_b and not _vietati.has("%s>%s" % [id_a, id_b]):
				var arco := _arco(superfici[id_a], superfici[id_b])
				if not arco.is_empty():
					archi.append(arco)


func _arco(a: Dictionary, b: Dictionary) -> Dictionary:
	var ida: String = a["id"]
	var idb: String = b["id"]
	if a.get("isolata", false) or b.get("isolata", false):
		return {}  # ci si entra e se ne esce solo dai passaggi speciali (cunicolo, grate)
	var dy: float = float(a["y"]) - float(b["y"])            # > 0: b è più in alto
	var sovrapposti := minf(a["x1"], b["x1"]) - maxf(a["x0"], b["x0"])
	var verso_b := 1 if (float(b["x0"]) + float(b["x1"])) * 0.5 > (float(a["x0"]) + float(a["x1"])) * 0.5 else -1
	if dy > 4.0:
		if dy > SALTO_CON_PRESA:
			return {}
		if b["passante"] and sovrapposti > 24.0:
			# Da sotto, attraverso la piattaforma.
			var centro := (maxf(a["x0"], b["x0"]) + minf(a["x1"], b["x1"])) * 0.5
			return {"da": ida, "a": idb, "tipo": "salto_su", "stacco": centro, "verso": verso_b, "altezza": dy}
		# Di lato: stacco sul bordo di a più vicino a b.
		var stacco := 0.0
		var distanza := 0.0
		if verso_b < 0:
			stacco = clampf(float(b["x1"]) + 16.0, float(a["x0"]) + 4.0, float(a["x1"]) - 4.0)
			distanza = stacco - float(b["x1"])
		else:
			stacco = clampf(float(b["x0"]) - 16.0, float(a["x0"]) + 4.0, float(a["x1"]) - 4.0)
			distanza = float(b["x0"]) - stacco
		if distanza > DISTANZA_SALTO or distanza < -40.0:
			return {}
		return {"da": ida, "a": idb, "tipo": "salto", "stacco": stacco, "verso": verso_b, "altezza": dy}
	if dy < -4.0:
		if a["passante"] and sovrapposti > 24.0:
			var centro := (maxf(a["x0"], b["x0"]) + minf(a["x1"], b["x1"])) * 0.5
			return {"da": ida, "a": idb, "tipo": "attraversa", "stacco": centro, "verso": verso_b, "altezza": dy}
		# Scendere da un bordo: sotto deve esserci b, e niente in mezzo.
		if float(b["x0"]) <= float(a["x0"]) - 12.0 and float(b["x1"]) >= float(a["x0"]) - 12.0 \
				and not _in_mezzo(float(a["x0"]) - 10.0, float(a["y"]), float(b["y"]), [ida, idb]):
			return {"da": ida, "a": idb, "tipo": "caduta", "stacco": float(a["x0"]) + 3.0, "verso": -1, "altezza": dy}
		if float(b["x1"]) >= float(a["x1"]) + 12.0 and float(b["x0"]) <= float(a["x1"]) + 12.0 \
				and not _in_mezzo(float(a["x1"]) + 10.0, float(a["y"]), float(b["y"]), [ida, idb]):
			return {"da": ida, "a": idb, "tipo": "caduta", "stacco": float(a["x1"]) - 3.0, "verso": 1, "altezza": dy}
		return {}
	return {}


func _in_mezzo(x: float, y_alto: float, y_basso: float, escluse: Array) -> bool:
	# Cadendo da x, si atterra prima su un'altra superficie?
	for id: String in superfici:
		if escluse.has(id):
			continue
		var s: Dictionary = superfici[id]
		var y := float(s["y"])
		if y > y_alto + 4.0 and y < y_basso - 4.0 and x >= float(s["x0"]) - 8.0 and x <= float(s["x1"]) + 8.0:
			return true
	return false


func possibile(arco: Dictionary) -> bool:
	# Il passaggio si può fare adesso? (grata aperta, lastre al loro posto)
	if not condizione.is_valid():
		return true
	for nome: String in [arco.get("condizione", ""), superfici[arco["da"]].get("condizione", ""), superfici[arco["a"]].get("condizione", "")]:
		if nome != "" and not condizione.call(nome):
			return false
	return true


# ------------------------------------------------------------------ dove sono, dove vado

func superficie_di(piedi: Vector2) -> String:
	# La superficie sotto i piedi ("" se si è su una cassa o in aria).
	for id: String in superfici:
		var s: Dictionary = superfici[id]
		if absf(piedi.y - float(s["y"])) < 5.0 and piedi.x >= float(s["x0"]) - 6.0 and piedi.x <= float(s["x1"]) + 6.0:
			if s.has("condizione") and condizione.is_valid() and not condizione.call(s["condizione"]):
				continue
			return id
	return ""


func superficie_per(punto: Vector2) -> String:
	# La superficie più vicina sotto (o all'altezza di) un punto.
	var scelta := ""
	var migliore := INF
	for id: String in superfici:
		var s: Dictionary = superfici[id]
		var dentro := punto.x >= float(s["x0"]) - 4.0 and punto.x <= float(s["x1"]) + 4.0
		var sotto := float(s["y"]) - punto.y
		if s.has("condizione") and condizione.is_valid() and not condizione.call(s["condizione"]):
			continue
		if dentro and sotto > -8.0 and sotto < migliore:
			migliore = sotto
			scelta = id
	return scelta


func percorso(da: String, a: String) -> Array:
	# Il percorso più comodo (Dijkstra: la stanza è piccola).
	var costi := {da: 0.0}
	var venuto := {}
	var aperti: Array = [da]
	while not aperti.is_empty():
		aperti.sort_custom(func(x: String, y: String) -> bool: return costi[x] < costi[y])
		var ora: String = aperti.pop_front()
		if ora == a:
			break
		for arco: Dictionary in archi:
			if arco["da"] != ora or not possibile(arco):
				continue
			var c: float = costi[ora] + costo(arco)
			if c < float(costi.get(arco["a"], INF)):
				costi[arco["a"]] = c
				venuto[arco["a"]] = arco
				if not aperti.has(arco["a"]):
					aperti.append(arco["a"])
	if not venuto.has(a):
		return []
	var cammino: Array = []
	var passo := a
	while passo != da:
		var arco: Dictionary = venuto[passo]
		cammino.push_front(arco)
		passo = arco["da"]
	return cammino


func costo(arco: Dictionary) -> float:
	var base := {"salto": 0.6, "salto_su": 0.6, "attraversa": 0.4, "caduta": 0.3, "rotola": 0.8, "passa": 0.3, "ascensore": 2.0}
	var c: float = base.get(arco["tipo"], 1.0)
	if float(arco["altezza"]) > SALTO_PIENO:
		c += 0.4  # serve aggrapparsi
	if superfici[arco["a"]].get("fragile", false):
		c += 2.5  # una lastra che crolla: meglio un'altra strada, se c'è
	var e: Dictionary = esperienza.get(chiave(arco), {})
	var falliti := int(e.get("prove", 0)) - int(e.get("riuscite", 0))
	return c + 1.5 * falliti   # i passaggi che hanno fallito costano di più


func stacco(arco: Dictionary) -> float:
	var e: Dictionary = esperienza.get(chiave(arco), {})
	return float(arco["stacco"]) + float(e.get("scarto", 0.0)) * float(arco["verso"])


func chiave(arco: Dictionary) -> String:
	return "%s>%s" % [arco["da"], arco["a"]]


# ------------------------------------------------------------------ esperienza

func esito(arco: Dictionary, riuscito: bool) -> void:
	# Verifica e ricorda: se un passaggio fallisce, la prossima volta si stacca da un punto diverso.
	var k := chiave(arco)
	var e: Dictionary = esperienza.get(k, {"prove": 0, "riuscite": 0, "scarto": 0.0, "errori_di_fila": 0})
	e["prove"] = int(e["prove"]) + 1
	if riuscito:
		e["riuscite"] = int(e["riuscite"]) + 1
		e["errori_di_fila"] = 0
	else:
		if int(e["errori_di_fila"]) > 0:
			errori_ripetuti += 1
		e["errori_di_fila"] = int(e["errori_di_fila"]) + 1
		# Prima più vicino al bordo, poi più lontano, alternando.
		var scarti := [-10.0, 10.0, -18.0, 18.0, 0.0]
		e["scarto"] = scarti[(int(e["prove"]) - int(e["riuscite"]) - 1) % scarti.size()]
		if lezioni.size() < 30:
			lezioni.append("%s (%s): stacco corretto di %+.0f px" % [k, arco["tipo"], float(e["scarto"])])
	esperienza[k] = e
	_salva()


func riassunto() -> Dictionary:
	var provati := 0
	var falliti := 0
	for k: String in esperienza:
		provati += int(esperienza[k]["prove"])
		falliti += int(esperienza[k]["prove"]) - int(esperienza[k]["riuscite"])
	return {"passaggi_provati": provati, "passaggi_falliti": falliti, "errori_ripetuti": errori_ripetuti,
			"lezioni": lezioni, "archi_noti": archi.size()}


func _carica() -> void:
	var cfg := ConfigFile.new()
	if Salvataggio.leggi_cfg(cfg, PERCORSO) == OK:
		esperienza = cfg.get_value("bot", "esperienza", {})


func _salva() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bot", "esperienza", esperienza)
	Salvataggio.scrivi_cfg(cfg, PERCORSO)
