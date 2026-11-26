class_name Armi
extends RefCounted
# Ogni arma da mischia ha i suoi attacchi: quanti colpi nella combinazione, danno, portata, tempi
# (da quando fa male a quando smette), passo in avanti, spinta, e una dote propria.
# La mano sinistra aggiunge qualcosa: lo scudo para, la seconda arma allunga e accelera la combinazione.
# L'aspetto (gruppo di mosse e animazioni) resta in Equipaggiamento; qui ci sono solo i numeri del combattimento.
#
# Un colpo: d = danno, t = durata, da/a = finestra in cui fa male, p = portata, h = altezza della zona,
# passo = slancio in avanti, spinta = quanto sposta il nemico.

const FAMIGLIE := {
	"spada": {
		"nome": "Spada", "dote": "Equilibrata: tre colpi, l'ultimo più forte.",
		"colpi": [
			{"d": 1, "t": 0.34, "da": 0.09, "a": 0.22, "p": 40.0, "h": 48.0, "passo": 80.0, "spinta": 150.0},
			{"d": 1, "t": 0.34, "da": 0.09, "a": 0.22, "p": 40.0, "h": 48.0, "passo": 80.0, "spinta": 150.0},
			{"d": 2, "t": 0.46, "da": 0.15, "a": 0.28, "p": 48.0, "h": 50.0, "passo": 130.0, "spinta": 230.0},
		],
	},
	"ascia": {
		"nome": "Ascia", "dote": "Lenta ma spacca: il secondo colpo rompe le parate.",
		"colpi": [
			{"d": 1, "t": 0.42, "da": 0.16, "a": 0.28, "p": 40.0, "h": 48.0, "passo": 60.0, "spinta": 180.0},
			{"d": 2, "t": 0.52, "da": 0.2, "a": 0.32, "p": 44.0, "h": 52.0, "passo": 90.0, "spinta": 260.0, "rompe": true},
		],
	},
	"pugnale": {
		"nome": "Pugnale", "dote": "Velocissimo, corto: alle spalle fa il doppio del danno.",
		"alle_spalle": 2,
		"colpi": [
			{"d": 1, "t": 0.24, "da": 0.06, "a": 0.14, "p": 30.0, "h": 40.0, "passo": 70.0, "spinta": 80.0},
			{"d": 1, "t": 0.24, "da": 0.06, "a": 0.14, "p": 30.0, "h": 40.0, "passo": 70.0, "spinta": 80.0},
			{"d": 1, "t": 0.24, "da": 0.06, "a": 0.14, "p": 30.0, "h": 40.0, "passo": 70.0, "spinta": 80.0},
			{"d": 1, "t": 0.3, "da": 0.08, "a": 0.18, "p": 34.0, "h": 40.0, "passo": 110.0, "spinta": 140.0},
		],
	},
	"spadone": {
		"nome": "Spadone", "dote": "Ampio e pesante: lunga portata, rompe le parate.",
		"colpi": [
			{"d": 2, "t": 0.58, "da": 0.24, "a": 0.38, "p": 58.0, "h": 60.0, "passo": 90.0, "spinta": 280.0, "rompe": true},
			{"d": 3, "t": 0.66, "da": 0.26, "a": 0.42, "p": 62.0, "h": 62.0, "passo": 140.0, "spinta": 340.0, "rompe": true},
		],
	},
	"bipenne": {
		"nome": "Ascia bipenne", "dote": "La più forte: rompe le parate e fa barcollare.",
		"colpi": [
			{"d": 3, "t": 0.66, "da": 0.3, "a": 0.44, "p": 52.0, "h": 56.0, "passo": 80.0, "spinta": 320.0, "rompe": true},
			{"d": 3, "t": 0.72, "da": 0.3, "a": 0.46, "p": 56.0, "h": 58.0, "passo": 120.0, "spinta": 360.0, "rompe": true,
					"stordisce": 0.7},
		],
	},
	"bastone": {
		"nome": "Bastone", "dote": "Colpi deboli e lunghi; la magia costa meno e torna prima.",
		"magia_costo": 0.6, "magia_ricarica": 1.5,
		"colpi": [
			{"d": 1, "t": 0.36, "da": 0.1, "a": 0.24, "p": 48.0, "h": 52.0, "passo": 60.0, "spinta": 200.0},
			{"d": 1, "t": 0.4, "da": 0.12, "a": 0.26, "p": 52.0, "h": 52.0, "passo": 60.0, "spinta": 240.0},
		],
	},
	"bacchetta": {
		"nome": "Bacchetta", "dote": "Colpi deboli; la magia parte più in fretta e costa meno.",
		"magia_costo": 0.75, "magia_veloce": 0.65,
		"colpi": [
			{"d": 1, "t": 0.3, "da": 0.08, "a": 0.2, "p": 34.0, "h": 44.0, "passo": 60.0, "spinta": 120.0},
			{"d": 1, "t": 0.3, "da": 0.08, "a": 0.2, "p": 34.0, "h": 44.0, "passo": 60.0, "spinta": 120.0},
		],
	},
	"mani_nude": {
		"nome": "Pugni", "dote": "Rapidissimi; l'ultimo colpo stordisce e interrompe gli attacchi.",
		"colpi": [
			{"d": 1, "t": 0.22, "da": 0.06, "a": 0.14, "p": 28.0, "h": 40.0, "passo": 50.0, "spinta": 100.0},
			{"d": 1, "t": 0.22, "da": 0.06, "a": 0.14, "p": 28.0, "h": 40.0, "passo": 50.0, "spinta": 100.0},
			{"d": 1, "t": 0.32, "da": 0.1, "a": 0.2, "p": 32.0, "h": 44.0, "passo": 90.0, "spinta": 200.0, "stordisce": 0.5},
		],
	},
}

# Arma indossata -> famiglia.
const FAMIGLIA_DI := {
	"spada_viandante": "spada", "spada_cavaliere": "spada", "lama_sepolti": "spada",
	"ascia": "ascia", "ascia_sepolti": "ascia", "pugnale": "pugnale",
	"spadone": "spadone", "bipenne": "bipenne",
	"bastone": "bastone", "bastone_sepolti": "bastone", "bacchetta": "bacchetta",
	"mani_nude": "mani_nude",
}
# Armi lente e veloci: i nemici imparano a riconoscerle.
const LENTE := ["ascia", "spadone", "bipenne"]
const RAPIDE := ["pugnale", "mani_nude"]

# Mano sinistra -> dote.
const MANO := {
	"scudo_tondo": "scudo", "scudo_stemma": "scudo", "scudo_torre": "scudo", "scudo_chiodato": "scudo",
	"scudo_barbaro": "scudo", "seconda_spada": "doppia", "seconda_ascia": "doppia", "secondo_pugnale": "doppia",
}
const PARATA_DURATA := 0.42          # con lo scudo: Schiva senza direzione
const PARATA_FINESTRA := 0.3         # i colpi da davanti in questo tempo sono parati
const PARATA_PAUSA := 0.45
const DOPPIA_VELOCITA := 0.85        # con la seconda arma la combinazione è più svelta...


static func famiglia(arma: String) -> String:
	return FAMIGLIA_DI.get(arma, "spada")


static func dote_mano(mano: String) -> String:
	return MANO.get(mano, "")


static func colpi(fam: String, mano: String) -> Array:
	# ...e ha un colpo in più (lo stesso del primo).
	var lista: Array = (FAMIGLIE[fam]["colpi"] as Array).duplicate(true)
	if dote_mano(mano) == "doppia":
		lista.insert(1, (lista[0] as Dictionary).duplicate())
		for c: Dictionary in lista:
			for chiave: String in ["t", "da", "a"]:
				c[chiave] = float(c[chiave]) * DOPPIA_VELOCITA
	return lista


static func attuali() -> Dictionary:
	# L'arma che si ha in mano adesso, con tutto quello che serve per combattere.
	var arma: String = Equipaggiamento.indossati.get("arma", "spada_viandante")
	var mano: String = Equipaggiamento.indossati.get("mano_sinistra", "mano_vuota")
	var fam := famiglia(arma)
	var dati: Dictionary = (FAMIGLIE[fam] as Dictionary).duplicate()
	dati["famiglia"] = fam
	dati["mano"] = dote_mano(mano)
	dati["colpi"] = colpi(fam, mano)
	return dati


static func descrizione(arma: String, mano: String) -> String:
	var fam := famiglia(arma)
	var testo := "%s — %s" % [FAMIGLIE[fam]["nome"], FAMIGLIE[fam]["dote"]]
	match dote_mano(mano):
		"scudo":
			testo += " Scudo: Schiva da fermo para i colpi da davanti."
		"doppia":
			testo += " Seconda arma: un colpo in più, più veloce."
	return testo
