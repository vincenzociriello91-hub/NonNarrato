extends Node
# Il Dormiente ricorda. Tre memorie, salvate fra un sogno e l'altro in user://memoria.cfg:
#  - le NEMESI: chi ti uccide torna più forte e superbo, con un titolo; chi batti può tornare
#    sfregiato e in cerca di vendetta. Ognuna ricorda com'è finita l'ultima volta e lo dice.
#  - le ABITUDINI di chi gioca (rotola spesso? scatta indietro? salta?): i nemici le studiano.
#  - le TATTICHE: ogni tipo di nemico tiene il conto di quali tattiche vanno a segno contro di te
#    (osserva, decide, agisce, verifica, ricorda) e usa più spesso quelle che funzionano.
#  - l'ARMA preferita di chi gioca: contro le armi lente i nemici arretrano e rispondono, contro
#    quelle rapide parano di più.
#  - i VETERANI: ogni posto della stanza ha un nemico che accumula esperienza a ogni morte e a ogni
#    ondata; sale di livello piano piano (in mesi di gioco) e diventa più forte e più furbo.
# Le nemesi, a ogni ritorno, guadagnano una capacità nuova e resistono all'arma che le ha battute.
# Idea nata dal bot di Minecraft (ciclo osserva-decidi-agisci-verifica, non ripetere gli errori)
# e dalle nemesi delle Cronache dei Varchi; scritto da zero per questo gioco.

signal cambiata

const PERCORSO := "user://memoria.cfg"
const MAX_NEMESI := 3
const POTERE_MAX := 4
const SCONFITTE_PER_RIPOSARE := 3
const PROBABILITA_VENDETTA := 0.3        # un nemico normale battuto può tornare come nemesi
const ESPLORAZIONE := 0.2                # ogni tanto si prova una tattica diversa dalla migliore
const DECADIMENTO := 0.85                # a ogni nuovo sogno le abitudini vecchie pesano meno
const XP_PER_LIVELLO := 12.0             # livello = radice(xp / 12): livello 1 a 12, 5 a 300, 10 a 1200 (mesi)
const LIVELLO_MAX := 10
const CAPACITA := ["parata", "combo", "rinforzi", "pelle_dura", "furia"]
const SPIEGA_CAPACITA := {
	"parata": "Ha imparato a parare.",
	"combo": "Ora colpisce due volte di fila.",
	"rinforzi": "Non viene più da solo.",
	"pelle_dura": "La sua pelle si è indurita.",
	"furia": "Ferito, diventa furioso.",
}
const LEZIONI_ARMA := {"lente": "punisce_lente", "rapide": "para_rapide"}
const SPIEGA_LEZIONE_ARMA := {
	"punisce_lente": "Conosce le armi pesanti: arretra quando carichi e risponde subito.",
	"para_rapide": "Conosce le armi rapide: para più spesso.",
}

const TITOLI_VINCITORE := ["il Trionfante", "il Tiranno", "l'Invitto", "il Flagello"]
const TITOLI_VINTO := ["lo Sfregiato", "il Redivivo", "il Rancoroso", "l'Implacabile"]
const NOMI_A := ["Ossa", "Cenere", "Lume", "Sale", "Ruggine", "Silenzio", "Brace", "Polvere", "Vespro", "Calce"]
const NOMI_B := ["di Fossa", "Spenta", "del Pozzo", "senza Nome", "di Cripta", "Muta", "del Sonno", "Antica"]

const TATTICHE := {
	"scheletro": ["diretto", "attesa", "affondo", "finta"],
	"mago": ["dritto", "anticipo", "raffica"],
	"arciere": ["dritto", "anticipo", "doppio"],
	"pipistrello": ["picchiata", "aggira", "attesa"],
	"bestione": ["diretto", "carica", "attesa"],
	"saltatore": ["balzo", "zig", "agguato"],
}
# Abitudine di chi gioca -> cosa impara il nemico.
const LEZIONI := {
	"rotolate": "aspetta", "scatti_indietro": "affondo", "salti": "anticipa",
	"attacchi": "arretra", "scatti_avanti": "arretra", "tiri": "schiva_tiri",
}
const LEZIONE_TATTICA := {
	"scheletro": {"aspetta": "attesa", "affondo": "affondo", "anticipa": "attesa", "arretra": "finta", "schiva_tiri": "affondo"},
	"mago": {"aspetta": "anticipo", "affondo": "raffica", "anticipa": "anticipo", "arretra": "raffica", "schiva_tiri": "raffica"},
	"arciere": {"aspetta": "anticipo", "affondo": "doppio", "anticipa": "anticipo", "arretra": "doppio", "schiva_tiri": "dritto"},
	"pipistrello": {"aspetta": "attesa", "affondo": "picchiata", "anticipa": "aggira", "arretra": "aggira", "schiva_tiri": "aggira"},
	"bestione": {"aspetta": "attesa", "affondo": "carica", "anticipa": "attesa", "arretra": "carica", "schiva_tiri": "carica"},
	"saltatore": {"aspetta": "agguato", "affondo": "balzo", "anticipa": "zig", "arretra": "zig", "schiva_tiri": "zig"},
}
const SPIEGA_LEZIONE := {
	"aspetta": "Ha imparato che rotoli spesso: aspetterà che tu finisca.",
	"affondo": "Ha imparato che scatti all'indietro: ti raggiungerà più lontano.",
	"anticipa": "Ha imparato che salti spesso: mirerà dove atterrerai.",
	"arretra": "Ha imparato che attacchi per primo: farà un passo indietro e risponderà.",
	"schiva_tiri": "Ha imparato che colpisci da lontano: schiverà i tuoi tiri.",
}
# Pesi: gli attacchi sono sempre tanti, contano meno nel capire "che tipo di giocatore sei".
const PESI := {"attacchi": 0.3, "rotolate": 1.0, "scatti_indietro": 1.2, "scatti_avanti": 0.8, "salti": 0.5, "tiri": 0.7}

const FRASI := {
	"vittoria": {
		"scheletro": ["Ancora tu? L'ultima volta sei finito nella polvere ai miei piedi.",
			"Ti ho già spezzato una volta. Il sogno lo ricorda.", "Torni a cadere, Non Narrato?"],
		"mago": ["La mia luce ti ha già spento una volta.", "Il Dormiente sogna la tua fine, e io la scrivo.",
			"Sei tornato a farti bruciare."],
		"arciere": ["Il mio dardo ti ha già trovato una volta.", "Da lontano, come sempre. Come l'ultima volta.",
			"Ti vedo anche nel buio, Non Narrato."],
		"pipistrello": ["Squittii nel buio: si ricorda del tuo sangue.", "Ali sopra di te, come quando sei caduto.",
			"Torna dall'alto, e ti ricorda."],
		"bestione": ["Ti ho schiacciato una volta. Il sogno ne ha voglia ancora.", "Il ferro non dimentica.",
			"Pesante come la tua ultima caduta."],
		"saltatore": ["Ricordi il mio balzo? È l'ultima cosa che hai visto.", "Più in alto di te, più veloce di te.",
			"Ti sono già piombato addosso."],
	},
	"sconfitta": {
		"scheletro": ["Mi hai lasciato questa crepa nelle ossa. Oggi te la restituisco.",
			"Dalla polvere si torna. Io sono tornato per te.", "Il sogno mi ha ricomposto per la vendetta."],
		"mago": ["Mi hai spento una volta. Il buio mi ha insegnato.", "Ricordo la tua lama. Ricordo tutto.",
			"Sono tornato dal fondo del sogno, per te."],
		"arciere": ["Mi hai spezzato l'arco. Ne ho trovato un altro.", "Questa volta non mancherò.",
			"Il sogno mi ha ridato la mira."],
		"pipistrello": ["Ali strappate, ricucite dal sogno.", "Torna a cercarti, più affamato.",
			"Il buio l'ha rimandato indietro."],
		"bestione": ["Mi hai aperto la corazza. L'ho chiusa con il rancore.", "Ricordo dove mi hai colpito.",
			"Il ferro torna, più spesso."],
		"saltatore": ["Mi hai fermato a metà balzo. Non succederà più.", "Ho imparato ad atterrarti addosso.",
			"Il sogno mi ha dato gambe nuove."],
	},
}

var nemesi: Array = []          # record: vedi _nuova_nemesi()
var abitudini := {}             # azione -> conteggio (con decadimento)
var tattiche := {}              # tipo -> {tattica: [prove, riuscite]}
var sogni := 0
var armi := {}                  # famiglia d'arma di chi gioca -> quanto la usa (con decadimento)
var veterani := {}              # posto nella stanza -> {xp, morti, uccisioni, ondate}
var sogni_completati := 0       # sogni finiti superando tutte le ondate
var _caso := RandomNumberGenerator.new()
var _contatore_id := 0


func _ready() -> void:
	_caso.seed = 7331
	var cfg := ConfigFile.new()
	if Salvataggio.leggi_cfg(cfg, PERCORSO) != OK:
		return
	nemesi = cfg.get_value("memoria", "nemesi", [])
	abitudini = cfg.get_value("memoria", "abitudini", {})
	tattiche = cfg.get_value("memoria", "tattiche", {})
	sogni = int(cfg.get_value("memoria", "sogni", 0))
	armi = cfg.get_value("memoria", "armi", {})
	veterani = cfg.get_value("memoria", "veterani", {})
	sogni_completati = int(cfg.get_value("memoria", "sogni_completati", 0))
	_contatore_id = int(cfg.get_value("memoria", "contatore", 0))


# ------------------------------------------------------------------ abitudini

func registra(azione: String) -> void:
	if not PESI.has(azione):
		return
	abitudini[azione] = float(abitudini.get(azione, 0.0)) + 1.0


func abitudine_principale() -> String:
	var migliore := ""
	var punti := 0.0
	for azione: String in PESI:
		var p: float = float(abitudini.get(azione, 0.0)) * float(PESI[azione])
		if p > punti:
			punti = p
			migliore = azione
	return migliore if punti >= 3.0 else ""


func lezione_attuale() -> String:
	return LEZIONI.get(abitudine_principale(), "")


func registra_arma(famiglia: String) -> void:
	armi[famiglia] = float(armi.get(famiglia, 0.0)) + 1.0


func arma_preferita() -> String:
	var migliore := ""
	var punti := 4.0   # servono un po' di colpi prima che i nemici se ne accorgano
	for f: String in armi:
		if float(armi[f]) > punti:
			punti = float(armi[f])
			migliore = f
	return migliore


func lezione_arma() -> String:
	var f := arma_preferita()
	if Armi.LENTE.has(f):
		return LEZIONI_ARMA["lente"]
	if Armi.RAPIDE.has(f):
		return LEZIONI_ARMA["rapide"]
	return ""


func nuovo_sogno() -> void:
	sogni += 1
	for azione: String in abitudini.keys():
		abitudini[azione] = float(abitudini[azione]) * DECADIMENTO
	for f: String in armi.keys():
		armi[f] = float(armi[f]) * DECADIMENTO
	_salva()


# ------------------------------------------------------------------ tattiche

func scegli_tattica(tipo: String, lezione: String, caso: RandomNumberGenerator) -> String:
	# Osserva (cosa ha funzionato finora), decide (la migliore, a volte una nuova), agisce.
	var elenco: Array = TATTICHE.get(tipo, ["diretto"])
	var da_lezione: String = (LEZIONE_TATTICA.get(tipo, {}) as Dictionary).get(lezione, "")
	var conti_lezione: Array = (tattiche.get(tipo, {}) as Dictionary).get(da_lezione, [0, 0])
	# Una lezione che non funziona mai (almeno 4 prove, meno di 1 su 6 riuscite) viene messa da parte.
	var lezione_fallita := int(conti_lezione[0]) >= 4 and float(conti_lezione[1]) / float(conti_lezione[0]) < 0.17
	if da_lezione != "" and not lezione_fallita and caso.randf() < 0.5:
		return da_lezione
	if caso.randf() < ESPLORAZIONE:
		return elenco[caso.randi() % elenco.size()]
	var migliore: String = elenco[0]
	var punti := -1.0
	var conti: Dictionary = tattiche.get(tipo, {})
	for t: String in elenco:
		var c: Array = conti.get(t, [0, 0])
		var p := (1.0 + float(c[1])) / (2.0 + float(c[0]))   # chi non è mai stata provata parte da metà
		if p > punti:
			punti = p
			migliore = t
	return migliore


func esito_tattica(tipo: String, tattica: String, riuscita: bool) -> void:
	# Verifica e ricorda: la prossima volta la scelta terrà conto di com'è andata.
	if not tattiche.has(tipo):
		tattiche[tipo] = {}
	var c: Array = (tattiche[tipo] as Dictionary).get(tattica, [0, 0])
	c = [int(c[0]) + 1, int(c[1]) + (1 if riuscita else 0)]
	tattiche[tipo][tattica] = c


# ------------------------------------------------------------------ nemesi

func nemesi_per(tipo: String) -> Array:
	return nemesi.filter(func(n: Dictionary) -> bool: return n["tipo"] == tipo)


func nemico_ha_ucciso(n: Node) -> void:
	# Chi ti uccide se lo ricorda: diventa (o resta) una nemesi, più forte.
	if n == null or not is_instance_valid(n) or not ("tipo" in n) or Nemico.SENZA_NEMESI.has(n.get("tipo")):
		return
	var rec: Dictionary = n.get("nemesi")
	if not rec.is_empty():
		rec = _trova(rec["id"])
	if rec.is_empty():
		rec = _nuova_nemesi(n.get("tipo"))
		_metti(rec)
		Rapporto.evento("nemesi_nasce", {"nome": nome_completo(rec), "motivo": "vittoria"})
	rec["vittorie"] = int(rec["vittorie"]) + 1
	rec["potere"] = mini(POTERE_MAX, int(rec["potere"]) + (1 if int(rec["vittorie"]) > 1 else 0))
	rec["titolo"] = TITOLI_VINCITORE[clampi(int(rec["vittorie"]) - 1, 0, TITOLI_VINCITORE.size() - 1)]
	rec["esito"] = "vittoria"
	rec["lezione"] = lezione_attuale()
	if int(rec["vittorie"]) > 1:
		_nuova_capacita(rec)
	Rapporto.evento("nemesi_vince", {"nome": nome_completo(rec), "potere": rec["potere"], "capacita": rec.get("capacita", [])})
	var posto: String = String(n.get("id_posto")) if "id_posto" in n else ""
	if posto != "":
		var v := veterano(posto)
		v["uccisioni"] = int(v["uccisioni"]) + 1
		v["xp"] = float(v["xp"]) + 4.0
		veterani[posto] = v
	_salva()


func nemico_sconfitto(n: Node, famiglia_arma: String = "") -> String:
	# Restituisce una frase da mostrare, se c'è qualcosa da dire. famiglia_arma = con che cosa l'hai battuto
	# (la nemesi impara a difendersene).
	if n == null or not ("tipo" in n) or Nemico.SENZA_NEMESI.has(n.get("tipo")):
		return ""
	var rec: Dictionary = n.get("nemesi")
	if not rec.is_empty():
		rec = _trova(rec["id"])
		if rec.is_empty():
			return ""
		rec["sconfitte"] = int(rec["sconfitte"]) + 1
		if int(rec["sconfitte"]) >= SCONFITTE_PER_RIPOSARE:
			nemesi.erase(rec)
			Rapporto.evento("nemesi_riposa", {"nome": nome_completo(rec)})
			_salva()
			return "%s non tornerà più nel sogno." % nome_completo(rec)
		rec["esito"] = "sconfitta"
		rec["cicatrice"] = true
		rec["potere"] = mini(POTERE_MAX, int(rec["potere"]) + 1)
		rec["titolo"] = TITOLI_VINTO[clampi(int(rec["sconfitte"]) - 1, 0, TITOLI_VINTO.size() - 1)]
		rec["lezione"] = lezione_attuale()
		if famiglia_arma != "":
			rec["arma_nemica"] = famiglia_arma
		_nuova_capacita(rec)
		Rapporto.evento("nemesi_sconfitta", {"nome": nome_completo(rec), "capacita": rec.get("capacita", []),
				"resiste_a": rec.get("arma_nemica", "")})
		_salva()
		return "%s si dissolve... ma il sogno lo ricorda." % nome_completo(rec)
	if _caso.randf() < PROBABILITA_VENDETTA:
		var nuova := _nuova_nemesi(n.get("tipo"))
		nuova["esito"] = "sconfitta"
		nuova["cicatrice"] = true
		nuova["titolo"] = TITOLI_VINTO[0]
		nuova["lezione"] = lezione_attuale()
		if famiglia_arma != "":
			nuova["arma_nemica"] = famiglia_arma
		_metti(nuova)
		Rapporto.evento("nemesi_nasce", {"nome": nome_completo(nuova), "motivo": "vendetta"})
		_salva()
		# Con il nome: la stessa frase ripetuta a ogni vendetta stancava (controllo da giocatore, 0.1.23).
		return "Qualcosa giura vendetta. Tornerà come %s." % nome_completo(nuova).strip_edges()
	return ""


func incontro(rec: Dictionary) -> String:
	# La frase con cui una nemesi ti accoglie, più quello che ha imparato.
	rec = _trova(rec.get("id", ""))
	if rec.is_empty():
		return ""
	rec["incontri"] = int(rec["incontri"]) + 1
	var frasi: Array = (FRASI.get(rec["esito"], FRASI["vittoria"]) as Dictionary).get(rec["tipo"], ["..."])
	var frase: String = frasi[(int(rec["incontri"]) - 1) % frasi.size()]
	var testo := "%s: «%s»" % [nome_completo(rec), frase]
	var lezione: String = rec.get("lezione", "")
	if SPIEGA_LEZIONE.has(lezione):
		testo += "\n" + SPIEGA_LEZIONE[lezione]
	var arma_nemica: String = rec.get("arma_nemica", "")
	if Armi.FAMIGLIE.has(arma_nemica):
		testo += "\nHa imparato a difendersi da: %s." % String(Armi.FAMIGLIE[arma_nemica]["nome"]).to_lower()
	var capacita: Array = rec.get("capacita", [])
	if not capacita.is_empty():
		testo += "\n" + String(SPIEGA_CAPACITA.get(capacita[-1], ""))
	Rapporto.evento("nemesi_incontro", {"nome": nome_completo(rec)})
	_salva()
	return testo


func nome_completo(rec: Dictionary) -> String:
	return "%s %s" % [rec.get("nome", "?"), rec.get("titolo", "")]


func _nuova_nemesi(tipo: String) -> Dictionary:
	if nemesi.size() >= MAX_NEMESI:
		# Il posto lo prende chi ha più da raccontare: esce la nemesi più debole.
		var debole: Dictionary = nemesi[0]
		for r: Dictionary in nemesi:
			if int(r["potere"]) < int(debole["potere"]):
				debole = r
		nemesi.erase(debole)
	_contatore_id += 1
	var nome := ""
	for prova in 8:  # niente due nemesi con lo stesso nome
		nome = "%s %s" % [NOMI_A[_caso.randi() % NOMI_A.size()], NOMI_B[_caso.randi() % NOMI_B.size()]]
		if not nemesi.any(func(r: Dictionary) -> bool: return r["nome"] == nome):
			break
	return {"id": "n%d" % _contatore_id, "tipo": tipo, "nome": nome, "titolo": TITOLI_VINCITORE[0], "potere": 1,
			"vittorie": 0, "sconfitte": 0, "esito": "vittoria", "lezione": "", "cicatrice": false, "incontri": 0,
			"capacita": [], "arma_nemica": ""}


func _nuova_capacita(rec: Dictionary) -> void:
	# A ogni ritorno la nemesi impara qualcosa di nuovo (finché ne restano).
	var ha: Array = rec.get("capacita", [])
	var restano := CAPACITA.filter(func(c: String) -> bool: return not ha.has(c))
	if restano.is_empty():
		return
	ha.append(restano[_caso.randi() % restano.size()])
	rec["capacita"] = ha


# ------------------------------------------------------------------ veterani

func veterano(posto: String) -> Dictionary:
	return (veterani.get(posto, {"xp": 0.0, "morti": 0, "uccisioni": 0, "ondate": 0}) as Dictionary).duplicate()


func livello_veterano(posto: String) -> int:
	if posto == "":
		return 0
	return mini(LIVELLO_MAX, int(sqrt(float(veterano(posto)["xp"]) / XP_PER_LIVELLO)))


func veterano_morto(posto: String, xp: float, ondata: int) -> void:
	# Ogni morte insegna: più ha fatto (colpi a segno, schivate, quanto ha resistito), più impara.
	if posto == "":
		return
	var v := veterano(posto)
	var prima := livello_veterano(posto)
	v["xp"] = float(v["xp"]) + xp
	v["morti"] = int(v["morti"]) + 1
	v["ondate"] = maxi(int(v["ondate"]), ondata)
	veterani[posto] = v
	var dopo := livello_veterano(posto)
	if dopo > prima:
		Rapporto.evento("veterano_cresce", {"posto": posto, "livello": dopo})
		Rapporto.conta("veterani_saliti")
	_salva()


func sogno_completato() -> void:
	sogni_completati += 1
	_salva()


func _trova(id: String) -> Dictionary:
	for r: Dictionary in nemesi:
		if r["id"] == id:
			return r
	return {}


func _metti(rec: Dictionary) -> void:
	if _trova(rec["id"]).is_empty():
		nemesi.append(rec)


# ------------------------------------------------------------------ stato e salvataggio

func stato() -> Dictionary:
	return {"nemesi": nemesi.duplicate(true), "abitudini": abitudini.duplicate(), "tattiche": tattiche.duplicate(true),
			"sogni": sogni, "contatore": _contatore_id, "armi": armi.duplicate(), "veterani": veterani.duplicate(true),
			"sogni_completati": sogni_completati}


func ripristina_stato(s: Dictionary) -> void:
	nemesi = (s.get("nemesi", []) as Array).duplicate(true)
	abitudini = (s.get("abitudini", {}) as Dictionary).duplicate()
	tattiche = (s.get("tattiche", {}) as Dictionary).duplicate(true)
	sogni = int(s.get("sogni", 0))
	_contatore_id = int(s.get("contatore", 0))
	armi = (s.get("armi", {}) as Dictionary).duplicate()
	veterani = (s.get("veterani", {}) as Dictionary).duplicate(true)
	sogni_completati = int(s.get("sogni_completati", 0))
	_salva()


func descrizione() -> Dictionary:
	var tat := {}
	for tipo: String in tattiche:
		tat[tipo] = {}
		for t: String in tattiche[tipo]:
			var c: Array = tattiche[tipo][t]
			tat[tipo][t] = "%d/%d" % [int(c[1]), int(c[0])]
	return {
		"nemesi": nemesi.map(func(r: Dictionary) -> String:
			return "%s (%s, potere %d, vinte %d, perse %d, lezione %s, capacità %s, resiste a %s)" % [
				nome_completo(r), r["tipo"], r["potere"], r["vittorie"], r["sconfitte"], r.get("lezione", ""),
				",".join(PackedStringArray(r.get("capacita", []))), r.get("arma_nemica", "")]),
		"abitudine": abitudine_principale(),
		"arma_preferita": arma_preferita(),
		"lezione_arma": lezione_arma(),
		"veterani": _riassunto_veterani(),
		"sogni_completati": sogni_completati,
		"tattiche": tat,
		"sogni": sogni,
	}


func _riassunto_veterani() -> Dictionary:
	var livelli := {}
	for posto: String in veterani:
		var v: Dictionary = veterani[posto]
		livelli[posto] = "livello %d (xp %.0f, morti %d, uccisioni %d)" % [livello_veterano(posto), float(v["xp"]),
				int(v["morti"]), int(v["uccisioni"])]
	return livelli


func _salva() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("memoria", "armi", armi)
	cfg.set_value("memoria", "veterani", veterani)
	cfg.set_value("memoria", "sogni_completati", sogni_completati)
	cfg.set_value("memoria", "nemesi", nemesi)
	cfg.set_value("memoria", "abitudini", abitudini)
	cfg.set_value("memoria", "tattiche", tattiche)
	cfg.set_value("memoria", "sogni", sogni)
	cfg.set_value("memoria", "contatore", _contatore_id)
	Salvataggio.scrivi_cfg(cfg, PERCORSO)
	cambiata.emit()
