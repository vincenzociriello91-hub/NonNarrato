extends Node
# Cosa indossa il Non Narrato. Ogni oggetto è un insieme di pezzi del manichino
# (modelli/manichino.scn); ogni posto ha anche un colore. Per ora cambia solo l'aspetto.
# Qui stanno anche i tesori trovati nei forzieri: colori rari e frammenti della storia.
# Salvato in user://equipaggiamento.cfg.

signal cambiato

const PERCORSO := "user://equipaggiamento.cfg"

const POSTI: Array[String] = ["testa", "copricapo", "busto", "braccia", "gambe", "mantello", "arma", "mano_sinistra"]
const NOMI_POSTI := {
	"testa": "Testa", "copricapo": "Copricapo", "busto": "Busto", "braccia": "Braccia",
	"gambe": "Gambe", "mantello": "Mantello", "arma": "Arma", "mano_sinistra": "Mano sinistra",
}

# id -> [posto, nome, pezzi del manichino]
const OGGETTI := {
	"cappuccio_viandante": ["testa", "Cappuccio del viandante", ["Viandante__Rogue_Head_Hooded"]],
	"volto_ladro": ["testa", "Volto del ladro", ["Ladro__Rogue_Head"]],
	"volto_cavaliere": ["testa", "Volto del cavaliere", ["Cavaliere__Knight_Head"]],
	"volto_barbaro": ["testa", "Volto del barbaro", ["Barbaro__Barbarian_Head"]],
	"volto_mago": ["testa", "Volto dell'eremita", ["Mago__Mage_Head"]],

	"nessun_copricapo": ["copricapo", "Nessuno", []],
	"elmo_cavaliere": ["copricapo", "Elmo del cavaliere caduto", ["Cavaliere__Knight_Helmet"]],
	"elmo_cornuto": ["copricapo", "Elmo cornuto", ["Barbaro__Barbarian_Hat"]],
	"cappello_eremita": ["copricapo", "Cappello dell'eremita", ["Mago__Mage_Hat"]],
	"elmo_sepolti": ["copricapo", "Elmo dei sepolti", ["Sepolto__Skeleton_Warrior_Helmet"]],
	"cappuccio_sepolti": ["copricapo", "Cappuccio dei sepolti", ["SepoltoLadro__Skeleton_Rogue_Hood"]],
	"cappello_negromante": ["copricapo", "Cappello del negromante", ["SepoltoMago__Skeleton_Mage_Hat"]],

	"giubba_viandante": ["busto", "Giubba del viandante", ["Viandante__Rogue_Body"]],
	"corazza_cavaliere": ["busto", "Corazza del cavaliere", ["Cavaliere__Knight_Body"]],
	"pelliccia_barbaro": ["busto", "Pelliccia del barbaro", ["Barbaro__Barbarian_Body"]],
	"veste_eremita": ["busto", "Veste dell'eremita", ["Mago__Mage_Body"]],

	"maniche_viandante": ["braccia", "Maniche del viandante", ["Viandante__Rogue_ArmLeft", "Viandante__Rogue_ArmRight"]],
	"bracciali_cavaliere": ["braccia", "Bracciali del cavaliere", ["Cavaliere__Knight_ArmLeft", "Cavaliere__Knight_ArmRight"]],
	"braccia_barbaro": ["braccia", "Braccia del barbaro", ["Barbaro__Barbarian_ArmLeft", "Barbaro__Barbarian_ArmRight"]],
	"maniche_eremita": ["braccia", "Maniche dell'eremita", ["Mago__Mage_ArmLeft", "Mago__Mage_ArmRight"]],

	"brache_viandante": ["gambe", "Brache del viandante", ["Viandante__Rogue_LegLeft", "Viandante__Rogue_LegRight"]],
	"gambali_cavaliere": ["gambe", "Gambali del cavaliere", ["Cavaliere__Knight_LegLeft", "Cavaliere__Knight_LegRight"]],
	"stivali_barbaro": ["gambe", "Stivali del barbaro", ["Barbaro__Barbarian_LegLeft", "Barbaro__Barbarian_LegRight"]],
	"tunica_eremita": ["gambe", "Tunica dell'eremita", ["Mago__Mage_LegLeft", "Mago__Mage_LegRight"]],

	"nessun_mantello": ["mantello", "Nessuno", []],
	"mantello_viandante": ["mantello", "Mantello del viandante", ["Viandante__Rogue_Cape"]],
	"mantello_cavaliere": ["mantello", "Mantello del cavaliere", ["Cavaliere__Knight_Cape"]],
	"mantello_barbaro": ["mantello", "Pelle del barbaro", ["Barbaro__Barbarian_Cape"]],
	"mantello_eremita": ["mantello", "Mantello dell'eremita", ["Mago__Mage_Cape"]],
	"mantello_sepolti": ["mantello", "Sudario dei sepolti", ["SepoltoLadro__Skeleton_Rogue_Cape"]],

	"spada_viandante": ["arma", "Spada del viandante", ["Viandante__Spada"]],
	"spada_cavaliere": ["arma", "Spada del cavaliere", ["Cavaliere__1H_Sword"]],
	"spadone": ["arma", "Spadone", ["Cavaliere__2H_Sword"]],
	"ascia": ["arma", "Ascia", ["Barbaro__1H_Axe"]],
	"bipenne": ["arma", "Ascia bipenne", ["Barbaro__2H_Axe"]],
	"pugnale": ["arma", "Pugnale", ["Viandante__Knife"]],
	"bastone": ["arma", "Bastone dell'eremita", ["Mago__2H_Staff"]],
	"bacchetta": ["arma", "Bacchetta", ["Mago__1H_Wand"]],
	"lama_sepolti": ["arma", "Lama dei sepolti", ["Sepolto__Lama"]],
	"ascia_sepolti": ["arma", "Ascia dei sepolti", ["Sepolto__Ascia"]],
	"bastone_sepolti": ["arma", "Bastone dei sepolti", ["Sepolto__Bastone"]],
	"mani_nude": ["arma", "A mani nude", []],

	"mano_vuota": ["mano_sinistra", "Nulla", []],
	"scudo_tondo": ["mano_sinistra", "Scudo tondo", ["Cavaliere__Round_Shield"]],
	"scudo_stemma": ["mano_sinistra", "Scudo con stemma", ["Cavaliere__Badge_Shield"]],
	"scudo_torre": ["mano_sinistra", "Scudo a torre", ["Cavaliere__Rectangle_Shield"]],
	"scudo_chiodato": ["mano_sinistra", "Scudo chiodato", ["Cavaliere__Spike_Shield"]],
	"scudo_barbaro": ["mano_sinistra", "Scudo del barbaro", ["Barbaro__Barbarian_Round_Shield"]],
	"seconda_spada": ["mano_sinistra", "Seconda spada", ["Cavaliere__1H_Sword_Offhand"]],
	"seconda_ascia": ["mano_sinistra", "Seconda ascia", ["Barbaro__1H_Axe_Offhand"]],
	"secondo_pugnale": ["mano_sinistra", "Secondo pugnale", ["Viandante__Knife_Offhand"]],
	"grimorio": ["mano_sinistra", "Grimorio", ["Mago__Spellbook"]],
}

# Colori: tingono la texture nello shader della figura. id -> [nome, colore, saturazione, luminosità]
const COLORI := {
	"naturale": ["Naturale", Color(1, 1, 1), 1.0, 1.0],
	"cenere": ["Cenere", Color(0.92, 0.92, 1.0), 0.15, 1.1],
	"ossidiana": ["Ossidiana", Color(0.62, 0.58, 0.78), 0.4, 0.75],
	"sangue": ["Sangue", Color(1.0, 0.55, 0.55), 1.2, 0.95],
	"notte": ["Notte", Color(0.66, 0.6, 1.0), 1.1, 0.9],
	"oro_antico": ["Oro antico", Color(1.0, 0.85, 0.55), 1.1, 1.15],
	"muschio": ["Muschio", Color(0.72, 0.9, 0.66), 0.9, 0.9],
	"ossa": ["Ossa", Color(1.0, 0.95, 0.82), 0.5, 1.25],
	"brace": ["Brace", Color(1.0, 0.5, 0.32), 1.35, 1.05],
	"abisso": ["Abisso", Color(0.45, 0.62, 0.9), 0.9, 0.72],
	"argento_lunare": ["Argento lunare", Color(0.9, 0.95, 1.05), 0.2, 1.32],
}
# Colori che si ottengono solo dai forzieri d'oro, in quest'ordine.
const DA_TROVARE: Array[String] = ["brace", "abisso", "argento_lunare"]

# Frammenti della storia del Dormiente, uno per forziere, in quest'ordine.
const FRAMMENTI: Array[String] = [
	"«Le leggende non nacquero per essere raccontate, ma per essere ripetute. Ogni ripetizione è un punto di sutura sulle palpebre del Dormiente.»",
	"«Chi scavò questa cripta non seppelliva i morti. Seppelliva le storie che avevano smesso di funzionare.»",
	"«Le torce non scacciano il buio. Gli ricordano soltanto dove finisce il sogno.»",
	"«Una leggenda incompiuta non muore: resta sulla soglia. E la soglia, col tempo, impara a camminare.»",
	"«Il Dormiente non sogna noi. Sogna di non svegliarsi, e noi siamo il modo in cui ci riesce.»",
	"«Le ossa che si rialzano non portano rancore. Portano memoria. È peggio.»",
	"«Quando l'ultima storia sarà finita, qualcuno dovrà decidere se raccontarla o lasciarla dormire.»",
]

# Gruppi di mosse: cambiano le animazioni (per ora solo l'aspetto, i tempi di gioco restano uguali).
const MOSSE := {
	"una_mano": "Una mano", "affondi": "Affondi", "due_mani": "Due mani", "doppia": "Doppia arma",
	"scudo": "Scudo", "magia": "Magia", "mani_nude": "A mani nude",
}
# Con "automatiche" decide l'arma; per armi normali conta anche la mano sinistra.
const MOSSE_ARMA := {
	"spadone": "due_mani", "bipenne": "due_mani", "bastone": "magia", "bacchetta": "magia",
	"bastone_sepolti": "magia", "mani_nude": "mani_nude",
}
const MOSSE_MANO := {
	"scudo_tondo": "scudo", "scudo_stemma": "scudo", "scudo_torre": "scudo", "scudo_chiodato": "scudo",
	"scudo_barbaro": "scudo", "seconda_spada": "doppia", "seconda_ascia": "doppia", "secondo_pugnale": "doppia",
}
const MOSSE_ARMA_LEGGERA := {"pugnale": "affondi"}

const PREDEFINITO := {
	"testa": "cappuccio_viandante", "copricapo": "nessun_copricapo", "busto": "giubba_viandante",
	"braccia": "maniche_viandante", "gambe": "brache_viandante", "mantello": "mantello_viandante",
	"arma": "spada_viandante", "mano_sinistra": "mano_vuota",
}

var indossati := {}
var colori := {}
var mosse_scelte := "auto"       # "auto" oppure un gruppo di MOSSE
var trovati: Array = []          # colori rari trovati nei forzieri
var frammenti: Array = []        # indici dei frammenti già letti


func _ready() -> void:
	_predefiniti()
	var cfg := ConfigFile.new()
	if cfg.load(PERCORSO) != OK:
		return
	for posto in POSTI:
		var id: String = str(cfg.get_value("oggetti", posto, ""))
		if OGGETTI.has(id) and OGGETTI[id][0] == posto:
			indossati[posto] = id
		var colore: String = str(cfg.get_value("colori", posto, ""))
		if COLORI.has(colore):
			colori[posto] = colore
	var scelta: String = str(cfg.get_value("mosse", "scelta", "auto"))
	if scelta == "auto" or MOSSE.has(scelta):
		mosse_scelte = scelta
	_leggi_tesori(cfg.get_value("tesori", "colori", []), cfg.get_value("tesori", "frammenti", []))
	for posto in POSTI:
		if not disponibile(colori[posto]):
			colori[posto] = "naturale"


func _leggi_tesori(colori_trovati: Variant, letti: Variant) -> void:
	trovati.clear()
	frammenti.clear()
	if typeof(colori_trovati) == TYPE_ARRAY:
		for c in colori_trovati:
			if DA_TROVARE.has(str(c)) and not trovati.has(str(c)):
				trovati.append(str(c))
	if typeof(letti) == TYPE_ARRAY:
		for i in letti:
			if int(i) >= 0 and int(i) < FRAMMENTI.size() and not frammenti.has(int(i)):
				frammenti.append(int(i))


func _predefiniti() -> void:
	indossati = PREDEFINITO.duplicate()
	mosse_scelte = "auto"
	colori = {}
	for posto in POSTI:
		colori[posto] = "naturale"


func oggetti_del_posto(posto: String) -> Array:
	var elenco: Array = []
	for id: String in OGGETTI:
		if OGGETTI[id][0] == posto:
			elenco.append(id)
	return elenco


func nome(id: String) -> String:
	return OGGETTI[id][1] if OGGETTI.has(id) else id


func pezzi(id: String) -> Array:
	return OGGETTI[id][2] if OGGETTI.has(id) else []


func tutti_i_pezzi() -> Array:
	var elenco: Array = []
	for id: String in OGGETTI:
		elenco.append_array(OGGETTI[id][2])
	return elenco


func indossa(posto: String, id: String) -> void:
	if not OGGETTI.has(id) or OGGETTI[id][0] != posto or indossati.get(posto) == id:
		return
	indossati[posto] = id
	_dopo_cambio()


func disponibile(colore: String) -> bool:
	return COLORI.has(colore) and (not DA_TROVARE.has(colore) or trovati.has(colore))


func trova_colore() -> String:
	# Il prossimo colore raro, o "" se si sono già trovati tutti.
	for c in DA_TROVARE:
		if not trovati.has(c):
			trovati.append(c)
			_salva()
			cambiato.emit()
			return c
	return ""


func trova_frammento() -> String:
	# Il prossimo frammento non ancora letto, o "" se si sono già letti tutti.
	for i in FRAMMENTI.size():
		if not frammenti.has(i):
			frammenti.append(i)
			_salva()
			return FRAMMENTI[i]
	return ""


func azzera_tesori() -> void:
	# Per il bot: parte senza tesori, così i forzieri danno sempre qualcosa (alla fine rimette quelli di chi gioca).
	trovati.clear()
	frammenti.clear()
	for posto in POSTI:
		if not disponibile(colori[posto]):
			colori[posto] = "naturale"
	_salva()
	cambiato.emit()


func colora(posto: String, colore: String) -> void:
	if not disponibile(colore) or colori.get(posto) == colore:
		return
	colori[posto] = colore
	_dopo_cambio()


func mosse_automatiche() -> String:
	var arma: String = indossati.get("arma", "")
	if MOSSE_ARMA.has(arma):
		return MOSSE_ARMA[arma]
	var mano: String = indossati.get("mano_sinistra", "")
	if MOSSE_MANO.has(mano):
		return MOSSE_MANO[mano]
	return MOSSE_ARMA_LEGGERA.get(arma, "una_mano")


func mosse_attive() -> String:
	return mosse_automatiche() if mosse_scelte == "auto" else mosse_scelte


func scegli_mosse(id: String) -> void:
	if (id != "auto" and not MOSSE.has(id)) or id == mosse_scelte:
		return
	mosse_scelte = id
	_dopo_cambio()


func stato() -> Dictionary:
	return {"indossati": indossati.duplicate(), "colori": colori.duplicate(), "mosse": mosse_scelte,
			"trovati": trovati.duplicate(), "frammenti": frammenti.duplicate()}


func ripristina_stato(s: Dictionary) -> void:
	# Per il bot: rimette l'aspetto (e i tesori) che aveva chi gioca.
	_predefiniti()
	_leggi_tesori(s.get("trovati", trovati.duplicate()), s.get("frammenti", frammenti.duplicate()))
	for posto in POSTI:
		var id: String = str((s.get("indossati", {}) as Dictionary).get(posto, ""))
		if OGGETTI.has(id) and OGGETTI[id][0] == posto:
			indossati[posto] = id
		var c: String = str((s.get("colori", {}) as Dictionary).get(posto, ""))
		if disponibile(c):
			colori[posto] = c
	var m: String = str(s.get("mosse", "auto"))
	mosse_scelte = m if m == "auto" or MOSSE.has(m) else "auto"
	_dopo_cambio()


func casuale(generatore: RandomNumberGenerator = null) -> void:
	var g := generatore
	if g == null:
		g = RandomNumberGenerator.new()
		g.randomize()
	var nomi_colori := COLORI.keys().filter(disponibile)
	for posto in POSTI:
		var elenco := oggetti_del_posto(posto)
		indossati[posto] = elenco[g.randi() % elenco.size()]
		colori[posto] = "naturale" if g.randf() < 0.5 else nomi_colori[g.randi() % nomi_colori.size()]
	_dopo_cambio()


func ripristina() -> void:
	_predefiniti()
	_dopo_cambio()


func descrizione() -> Dictionary:
	var d := {}
	for posto in POSTI:
		d[posto] = "%s (%s)" % [indossati[posto], colori[posto]]
	d["mosse"] = "%s (%s)" % [mosse_attive(), mosse_scelte]
	return d


func _dopo_cambio() -> void:
	_salva()
	cambiato.emit()
	Rapporto.conta("cambi_aspetto")


func _salva() -> void:
	var cfg := ConfigFile.new()
	for posto in POSTI:
		cfg.set_value("oggetti", posto, indossati[posto])
		cfg.set_value("colori", posto, colori[posto])
	cfg.set_value("mosse", "scelta", mosse_scelte)
	cfg.set_value("tesori", "colori", trovati)
	cfg.set_value("tesori", "frammenti", frammenti)
	cfg.save(PERCORSO)
