extends Node
# Rapporto di sessione: racconta "vita, morte e miracoli" dell'ultimo utilizzo.
# Viene salvato ogni 30 secondi, quando il gioco va in secondo piano e alla chiusura,
# così resta anche se il gioco si chiude per errore. Non contiene dati personali.

const CARTELLA := "user://rapporti"
const SEGNO_SESSIONE := "user://ultima_sessione.txt"
const CARTELLA_DOWNLOAD := "NonNarrato_report"
const MASSIMO_EVENTI := 1500       # partite più lunghe (ondate): il rapporto deve restare completo
const MASSIMO_FILE := 20


class RegistroMotore extends Logger:
	# Raccoglie errori e avvisi del motore, per ritrovarli nel rapporto.
	const MASSIMO := 200
	const TIPI: Array[String] = ["ERRORE", "AVVISO", "SCRIPT", "SHADER"]
	var righe: PackedStringArray = []
	var totale := 0
	var _blocco := Mutex.new()

	func _log_message(message: String, error: bool) -> void:
		if error:
			_aggiungi("STDERR " + message.strip_edges().left(300))

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var tipo := TIPI[clampi(error_type, 0, TIPI.size() - 1)]
		var testo := rationale if rationale != "" else code
		_aggiungi("%s %s:%d (%s) %s" % [tipo, file.get_file(), line, function, testo.left(300)])

	func _aggiungi(riga: String) -> void:
		_blocco.lock()
		totale += 1
		if righe.size() < MASSIMO:
			righe.append(riga)
		_blocco.unlock()

	func copia() -> Array:
		_blocco.lock()
		var c := Array(righe)
		_blocco.unlock()
		return c


var ultimo_percorso := ""
var percorso_download := ""
var esito_download := "non ancora provato"

var _registro := RegistroMotore.new()
var _inizio := ""
var _nome_file := ""
var _precedente := ""
var _tempo := 0.0
var _eventi: Array = []
var _eventi_scartati := 0
var _contatori := {}
var _grafica := {}
var _sezioni := {}
var _letture_termiche: Array = []
var _termico_massimo := -1

var _fps_serie := PackedInt32Array()
var _acc_tempo := 0.0
var _acc_fotogrammi := 0
var _fotogrammi := 0
var _scatti := 0
var _peggiore_ms := 0.0
var _scatti_registrati := 0
var _compilazioni_prima := 0

# Chi vuole può dire cosa sta succedendo in partita: finisce accanto a ogni scatto registrato.
var contesto: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.add_logger(_registro)
	_inizio = Time.get_datetime_string_from_system()
	_nome_file = "rapporto_%s.json" % _inizio.replace("-", "").replace(":", "").replace("T", "_")
	_leggi_sessione_precedente()
	_segna_sessione("avvio")
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.autostart = true
	timer.timeout.connect(func() -> void: salva("periodico"))
	add_child(timer)


func _notification(cosa: int) -> void:
	if cosa == NOTIFICATION_APPLICATION_PAUSED:
		salva("secondo_piano")
	elif cosa == NOTIFICATION_WM_CLOSE_REQUEST:
		salva("uscita")


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo < 3.0 or get_tree().paused:
		return
	_fotogrammi += 1
	_acc_tempo += delta
	_acc_fotogrammi += 1
	var compilazioni := compilazioni_shader()
	if delta > 0.05:
		_scatti += 1
		_registra_scatto(delta, compilazioni - _compilazioni_prima)
	_compilazioni_prima = compilazioni
	_peggiore_ms = maxf(_peggiore_ms, delta * 1000.0)
	if _acc_tempo >= 1.0:
		if _fps_serie.size() < 900:
			_fps_serie.append(roundi(float(_acc_fotogrammi) / _acc_tempo))
		_acc_tempo = 0.0
		_acc_fotogrammi = 0


static func compilazioni_shader() -> int:
	# Quante volte il motore ha dovuto preparare un effetto grafico nuovo: è la causa più comune degli scatti.
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))


func _registra_scatto(delta: float, compilazioni: int) -> void:
	# Ogni fotogramma lento finisce nel rapporto con ciò che stava succedendo, per capirne la causa.
	if _scatti_registrati >= 40:
		return
	_scatti_registrati += 1
	var dati := {
		"ms": snappedf(delta * 1000.0, 0.1),
		"shader_nuovi": compilazioni,
		"nodi": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"disegni": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
	}
	if contesto.is_valid():
		var extra: Variant = contesto.call()
		if typeof(extra) == TYPE_DICTIONARY:
			dati.merge(extra)
	evento("scatto", dati)


# ------------------------------------------------------------------ raccolta

func evento(tipo: String, dati: Dictionary = {}) -> void:
	if _eventi.size() >= MASSIMO_EVENTI:
		_eventi_scartati += 1
		return
	var voce := {"t": snappedf(_tempo, 0.01), "tipo": tipo}
	voce.merge(dati)
	_eventi.append(voce)
	if Dispositivo.in_prova and tipo in ["trappola", "piastra", "lastra_trema", "crollo", "morte"]:
		print("PROVA evento: ", voce)


func conta(chiave: String, quanto: int = 1) -> void:
	_contatori[chiave] = int(_contatori.get(chiave, 0)) + quanto


func contatore(chiave: String) -> int:
	return int(_contatori.get(chiave, 0))


func sezione(nome: String, dati: Variant) -> void:
	# Una parte in più del rapporto (per esempio l'esito del bot).
	_sezioni[nome] = dati


func grafica(chiave: String, valore: Variant) -> void:
	_grafica[chiave] = valore


func lettura_termica(stato: int, margine: float, carica: int) -> void:
	_termico_massimo = maxi(_termico_massimo, stato)
	if _letture_termiche.size() < 200:
		_letture_termiche.append([snappedf(_tempo, 0.1), stato, snappedf(margine, 0.01), carica])


# ------------------------------------------------------------------ scrittura

func salva(motivo: String) -> String:
	var testo := JSON.stringify(_componi(motivo), "\t")
	_scrivi_nel_gioco(testo)
	if motivo != "periodico":
		var esito_prima := esito_download
		_copia_in_download(testo)
		if esito_download != esito_prima:
			# L'esito della copia fa parte del rapporto: lo riscrivo aggiornato.
			testo = JSON.stringify(_componi(motivo), "\t")
			_scrivi_nel_gioco(testo)
			_copia_in_download(testo)
		_elimina_vecchi()
	_segna_sessione(motivo)
	return testo


func _scrivi_nel_gioco(testo: String) -> void:
	var cartella := DirAccess.open("user://")
	if cartella != null and not cartella.dir_exists("rapporti"):
		cartella.make_dir_recursive("rapporti")
	var percorso := CARTELLA.path_join(_nome_file)
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	if f != null:
		f.store_string(testo)
		f.close()
		ultimo_percorso = ProjectSettings.globalize_path(percorso)


func testo_completo() -> String:
	return JSON.stringify(_componi("richiesta"), "\t")


func _componi(motivo: String) -> Dictionary:
	var dispositivo := get_node_or_null("/root/Dispositivo")
	var controlli := get_node_or_null("/root/Controlli")
	var dati := {
		"app": "NonNarrato",
		"formato": 1,
		"versione": String(ProjectSettings.get_setting("application/config/version", "?")),
		"inizio": _inizio,
		"fine": Time.get_datetime_string_from_system(),
		"durata_s": snappedf(_tempo, 0.1),
		"motivo": motivo,
		"sessione_precedente": _precedente,
		"fps": _statistiche_fps(),
		"partita": _contatori,
		"impostazioni": Impostazioni.tutte(),
		"copia_in_download": esito_download,
		"eventi": _eventi,
		"eventi_scartati": _eventi_scartati,
		"errori_motore": _registro.totale,
		"registro_motore": _registro.copia(),
	}
	var grafica_ora := _grafica.duplicate()
	if dispositivo != null:
		dati["dispositivo"] = dispositivo.info
		grafica_ora["livello"] = dispositivo.livello
		grafica_ora["livello_consigliato"] = dispositivo.livello_consigliato
		grafica_ora["fps_obiettivo"] = dispositivo.fps_obiettivo
		grafica_ora["riduzione_caldo"] = dispositivo.riduzione_caldo
		grafica_ora["riduzione_scatti"] = dispositivo.riduzione_scatti
		dati["termico"] = {
			"ultimo": dispositivo.stato_termico,
			"massimo": _termico_massimo,
			"batteria": dispositivo.batteria,
			"letture": _letture_termiche,
		}
	dati["grafica"] = grafica_ora
	dati.merge(_sezioni)
	var memoria := get_node_or_null("/root/Memoria")
	if memoria != null:
		dati["memoria"] = memoria.descrizione()
	var equipaggiamento := get_node_or_null("/root/Equipaggiamento")
	if equipaggiamento != null:
		dati["aspetto"] = equipaggiamento.descrizione()
	var partita := get_node_or_null("/root/Partita")
	if partita != null:
		dati["salvataggi"] = {
			"sogno_salvato": partita.descrizione(), "salvataggi_partita": partita.salvataggi,
			"scritture": Salvataggio.scritture, "ripresi_dalla_copia": Salvataggio.recuperati,
		}
	var suoni := get_node_or_null("/root/Suoni")
	if suoni != null:
		dati["audio"] = suoni.stato()
	if controlli != null:
		dati["comandi"] = {
			"modo": controlli.nome_modo(),
			"cambi_modo": controlli.cambi_modo,
			"controller": controlli.elenco_controller(),
		}
	return dati


func _statistiche_fps() -> Dictionary:
	var serie := Array(_fps_serie)
	if serie.is_empty():
		return {"fotogrammi": _fotogrammi}
	var ordinata := serie.duplicate()
	ordinata.sort()
	var somma := 0
	for v: int in serie:
		somma += v
	return {
		"medio": snappedf(float(somma) / serie.size(), 0.1),
		"minimo": ordinata[0],
		"massimo": ordinata[ordinata.size() - 1],
		"peggior_secondo_su_cento": ordinata[int(ordinata.size() * 0.01)],
		"fotogrammi": _fotogrammi,
		"scatti_oltre_50ms": _scatti,
		"shader_preparati": compilazioni_shader(),
		"fotogramma_peggiore_ms": snappedf(_peggiore_ms, 0.1),
		"serie_al_secondo": serie,
	}


func _copia_in_download(testo: String) -> void:
	# Su Android una copia va in Download/NonNarrato_report, così si può allegare o sincronizzare.
	if OS.get_name() != "Android":
		esito_download = "solo su Android"
		return
	var base := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if base == "":
		esito_download = "cartella Download non trovata"
		return
	var cartella := base.path_join(CARTELLA_DOWNLOAD)
	var percorso := cartella.path_join(_nome_file)
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	if f == null:
		DirAccess.make_dir_recursive_absolute(cartella)
		f = FileAccess.open(percorso, FileAccess.WRITE)
	if f == null:
		esito_download = "non riuscita (errore %d)" % FileAccess.get_open_error()
		return
	f.store_string(testo)
	f.close()
	percorso_download = percorso
	esito_download = "ok"


func _elimina_vecchi() -> void:
	var cartella := DirAccess.open(CARTELLA)
	if cartella == null:
		return
	var nomi: Array = []
	for nome in cartella.get_files():
		if nome.begins_with("rapporto_") and nome.ends_with(".json"):
			nomi.append(nome)
	nomi.sort()
	while nomi.size() > MASSIMO_FILE:
		cartella.remove(nomi.pop_front())


func _leggi_sessione_precedente() -> void:
	if not FileAccess.file_exists(SEGNO_SESSIONE):
		_precedente = "nessuna"
		return
	var parti := FileAccess.get_file_as_string(SEGNO_SESSIONE).strip_edges().split("|")
	var motivo := parti[1] if parti.size() > 1 else "?"
	if motivo == "avvio" or motivo == "periodico":
		_precedente = "interrotta senza chiusura (%s)" % parti[0]
	else:
		_precedente = "chiusa bene (%s)" % motivo


func _segna_sessione(motivo: String) -> void:
	var f := FileAccess.open(SEGNO_SESSIONE, FileAccess.WRITE)
	if f != null:
		f.store_string("%s|%s" % [_nome_file, motivo])
		f.close()
