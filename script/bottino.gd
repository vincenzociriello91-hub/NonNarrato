class_name Bottino
extends RefCounted
# Cosa lasciano nemici e forzieri (decisione di Vincenzo, 26/11/2026):
#  - i nemici deboli non lasciano niente; quelli forti lasciano consumabili secondo l'arma con cui li hai
#    battuti (dardi o frecce se li hai finiti con balestra o arco, pozioni di mana con la magia) e a volte
#    pozioni di salute, di stamina e, più di rado, di velocità;
#  - i forzieri danno oggetti a caso; alcuni sono mimic che, battuti, lasciano pozioni migliori;
#  - pozioni piccole, medie e grandi.
# Una voce del bottino: {"cosa": "pozione", "tipo": "salute", "taglia": "media"} oppure
# {"cosa": "dardi"/"frecce"/"cura", "quante": 3}. Le pozioni si raccolgono passandoci sopra (Raccoglibile)
# e il loro effetto dura qualche secondo e si somma (Giocatore.bevi).

const TIPI_POZIONE := ["salute", "stamina", "mana", "velocita"]
const NOMI_POZIONE := {"salute": "salute", "stamina": "stamina", "mana": "mana", "velocita": "velocità"}
const COLORI_POZIONE := {
	"salute": Color(0.86, 0.3, 0.28), "stamina": Color(0.5, 0.8, 0.36),
	"mana": Color(0.36, 0.56, 1.0), "velocita": Color(0.95, 0.82, 0.36),
}
const TAGLIE := ["piccola", "media", "grande"]
# Probabilità per un nemico forte: quello dell'arma, poi le pozioni "di scorta".
const PROB_ARMA := 0.8
const PROB_SALUTE := 0.35
const PROB_STAMINA := 0.25
const PROB_VELOCITA := 0.12
const MIMIC_PROBABILITA := 0.35   # per ogni forziere "a caso", a ogni sogno


static func forte(tipo: String, forza: int, nemesi: bool) -> bool:
	# Deboli: scheletri, arcieri, pipistrelli e saltatori finché non sono cresciuti (veterani, ondate).
	return nemesi or tipo in ["bestione", "mago", "mimic"] or forza >= 2


static func grado(tipo: String, forza: int, nemesi: bool) -> int:
	# 0 = forte, 1 = molto forte, 2 = mimic o nemesi: decide quanto sono grandi le pozioni.
	if nemesi or tipo == "mimic":
		return 2
	if tipo == "bestione" or forza >= 4:
		return 1
	return 0


static func taglia_a_caso(grado_bottino: int, caso: RandomNumberGenerator) -> String:
	var pesi: Array = [[0.75, 0.22, 0.03], [0.45, 0.42, 0.13], [0.0, 0.6, 0.4]][clampi(grado_bottino, 0, 2)]
	var r := caso.randf()
	var somma := 0.0
	for i in 3:
		somma += float(pesi[i])
		if r < somma:
			return TAGLIE[i]
	return "grande"


static func pozione(tipo: String, taglia: String) -> Dictionary:
	return {"cosa": "pozione", "tipo": tipo, "taglia": taglia}


static func per_nemico(tipo: String, forza: int, nemesi: bool, arma: String, caso: RandomNumberGenerator) -> Array:
	# arma = con cosa è stato dato l'ultimo colpo: "dardi", "frecce", "magia", "mischia", "trappola".
	var bottino: Array = []
	if not forte(tipo, forza, nemesi):
		return bottino
	var g := grado(tipo, forza, nemesi)
	if tipo == "mimic":
		# Il mimic battuto lascia sempre due pozioni medie o grandi, più il resto.
		for i in 2:
			bottino.append(pozione(TIPI_POZIONE[caso.randi() % TIPI_POZIONE.size()], taglia_a_caso(2, caso)))
	if caso.randf() < PROB_ARMA:
		match arma:
			"dardi":
				bottino.append({"cosa": "dardi", "quante": 2 + caso.randi() % 3 + g})
			"frecce":
				bottino.append({"cosa": "frecce", "quante": 2 + caso.randi() % 2 + g})
			"magia":
				bottino.append(pozione("mana", taglia_a_caso(g, caso)))
	if caso.randf() < PROB_SALUTE:
		bottino.append(pozione("salute", taglia_a_caso(g, caso)))
	if caso.randf() < PROB_STAMINA:
		bottino.append(pozione("stamina", taglia_a_caso(g, caso)))
	if caso.randf() < PROB_VELOCITA:
		bottino.append(pozione("velocita", taglia_a_caso(g, caso)))
	return bottino


static func per_forziere(oro: bool, caso: RandomNumberGenerator) -> Array:
	# Due o tre oggetti a caso, senza doppioni dello stesso genere. Il forziere d'oro dà pozioni più grandi.
	var generi: Array = ["cura", "dardi", "frecce", "pozione", "pozione", "pozione"]
	var quanti := 2 + (1 if caso.randf() < 0.5 else 0)
	var bottino: Array = []
	var usati := {}
	var g := 1 if oro else 0
	for i in 16:
		if bottino.size() >= quanti:
			break
		var genere: String = generi[caso.randi() % generi.size()]
		if genere == "pozione":
			var tipo: String = TIPI_POZIONE[caso.randi() % TIPI_POZIONE.size()]
			if usati.has(tipo):
				continue
			usati[tipo] = true
			bottino.append(pozione(tipo, taglia_a_caso(g, caso)))
		elif not usati.has(genere):
			usati[genere] = true
			match genere:
				"cura":
					bottino.append({"cosa": "cura", "quante": 2 + caso.randi() % 2})
				"dardi":
					bottino.append({"cosa": "dardi", "quante": 3 + caso.randi() % 3})
				"frecce":
					bottino.append({"cosa": "frecce", "quante": 2 + caso.randi() % 3})
	if not bottino.any(func(v: Dictionary) -> bool: return v["cosa"] == "pozione"):
		bottino[bottino.size() - 1] = pozione(TIPI_POZIONE[caso.randi() % TIPI_POZIONE.size()], taglia_a_caso(g, caso))   # almeno una
	return bottino


static func descrizione(voce: Dictionary) -> String:
	if voce.get("cosa", "") == "pozione":
		return "pozione %s di %s" % [voce["taglia"], NOMI_POZIONE.get(voce["tipo"], voce["tipo"])]
	return "%d %s" % [int(voce.get("quante", 0)), voce.get("cosa", "")]


static func lascia(dove: Node, punto: Vector2, bottino: Array, permanente: bool, caso: RandomNumberGenerator) -> Array:
	# Fa saltar fuori pozioni e munizioni attorno a un punto, a ventaglio. Restituisce i Raccoglibili.
	var fuori: Array = []
	if dove == null or not is_instance_valid(dove):
		return fuori
	var da_lanciare := bottino.filter(func(v: Dictionary) -> bool: return v["cosa"] in ["pozione", "dardi", "frecce"])
	for i in da_lanciare.size():
		var voce: Dictionary = da_lanciare[i]
		var r := Raccoglibile.new()
		r.cosa = voce["cosa"]
		r.quante = int(voce.get("quante", 1))
		r.tipo_pozione = voce.get("tipo", "")
		r.taglia = voce.get("taglia", "")
		r.permanente = permanente
		r.position = punto
		var lato := (float(i) - (da_lanciare.size() - 1) * 0.5) * 22.0 + caso.randf_range(-4.0, 4.0)
		r.lancio = Vector2(lato * 2.4, -170.0 - caso.randf_range(0.0, 40.0))
		dove.add_child.call_deferred(r)
		fuori.append(r)
	if not da_lanciare.is_empty():
		Rapporto.conta("bottini_lasciati")
	return fuori
