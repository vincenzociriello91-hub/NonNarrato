extends Node
# Aggiornamento dall'app: controlla su GitHub se c'è una versione nuova, la scarica,
# la controlla (impronta SHA-256, stesso pacchetto, stessa firma) e la installa.
# Con il plugin Android (addons/nonnarrato_android.jar) l'installazione passa da una sessione
# di PackageInstaller: da Android 12 in poi un'app che aggiorna sé stessa non deve chiedere conferme.
# Serve solo, la prima volta, il permesso "Installa app sconosciute".
# Senza plugin (computer, versioni vecchie) apre l'installatore di sistema o la pagina delle versioni.

signal cambiato

const API := "https://api.github.com/repos/vincenzociriello91-hub/NonNarrato/releases/latest"
const PAGINA := "https://github.com/vincenzociriello91-hub/NonNarrato/releases/latest"
const APK := "https://github.com/vincenzociriello91-hub/NonNarrato/releases/latest/download/NonNarrato.apk"
const SHA := "https://github.com/vincenzociriello91-hub/NonNarrato/releases/latest/download/NonNarrato.apk.sha256"
const CARTELLA := "user://aggiornamento"
const FILE_APK := "user://aggiornamento/NonNarrato.apk"
const FILE_STATO := "user://aggiornamento/stato.cfg"

# Stati: fermo, controllo, aggiornato, disponibile, scarico, verifica, permesso, installo, conferma, errore, offline
var stato := "fermo"
var messaggio := ""
var versione_attuale := ""
var versione_nuova := ""
var note := ""
var progresso := 0.0
var plugin: Object = null

var _richiesta: HTTPRequest
var _scarica: HTTPRequest
var _sha_atteso := ""
var _fase_richiesta := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	versione_attuale = String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if Engine.has_singleton("NonNarratoAndroid"):
		plugin = Engine.get_singleton("NonNarratoAndroid")
		plugin.connect("stato_installazione", _su_stato_installazione)
	_richiesta = HTTPRequest.new()
	_richiesta.timeout = 10.0
	_richiesta.request_completed.connect(_su_risposta)
	add_child(_richiesta)
	_scarica = HTTPRequest.new()
	_scarica.use_threads = true
	_scarica.timeout = 300.0
	_scarica.request_completed.connect(_su_scaricato)
	add_child(_scarica)
	set_process(false)
	_dopo_un_aggiornamento()


func _dopo_un_aggiornamento() -> void:
	# Se l'ultima volta è partito un aggiornamento, guardo com'è andata e pulisco il file scaricato.
	var cfg := ConfigFile.new()
	if cfg.load(FILE_STATO) != OK:
		return
	var attesa := String(cfg.get_value("aggiornamento", "versione", ""))
	var da := String(cfg.get_value("aggiornamento", "da", ""))
	if attesa != "" and confronta(versione_attuale, attesa) >= 0:
		Rapporto.evento("aggiornamento_riuscito", {"da": da, "a": versione_attuale, "installatore": installatore()})
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE_APK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE_STATO))
	elif attesa != "":
		Rapporto.evento("aggiornamento_non_arrivato", {"atteso": attesa, "attuale": versione_attuale})


func installatore() -> String:
	return String(plugin.call("installatore")) if plugin != null else ""


# ------------------------------------------------------------------ controllo

func controlla() -> void:
	if stato in ["controllo", "scarico", "verifica", "installo"]:
		return
	_imposta("controllo", "Controllo degli aggiornamenti…")
	_fase_richiesta = "api"
	_richiesta.max_redirects = 8
	var errore := _richiesta.request(API, ["Accept: application/vnd.github+json", "X-GitHub-Api-Version: 2022-11-28", "User-Agent: NonNarrato"])
	if errore != OK:
		_ripiego()


func _ripiego() -> void:
	# Le domande senza chiave all'API di GitHub sono 60 all'ora per indirizzo: se finiscono,
	# leggo il numero della versione dal rinvio della pagina "ultima versione".
	_fase_richiesta = "pagina"
	_richiesta.cancel_request()
	_richiesta.max_redirects = 0
	if _richiesta.request(PAGINA, ["User-Agent: NonNarrato"], HTTPClient.METHOD_HEAD) != OK:
		_imposta("offline", "Nessun collegamento per controllare gli aggiornamenti.")


func _su_risposta(esito: int, codice: int, intestazioni: PackedStringArray, corpo: PackedByteArray) -> void:
	if _fase_richiesta == "api":
		if esito != HTTPRequest.RESULT_SUCCESS or codice != 200:
			Rapporto.evento("aggiornamento_api", {"esito": esito, "codice": codice})
			_ripiego()
			return
		var dati: Variant = JSON.parse_string(corpo.get_string_from_utf8())
		if typeof(dati) != TYPE_DICTIONARY:
			_ripiego()
			return
		note = String(dati.get("body", "")).strip_edges()
		_versione_trovata(String(dati.get("tag_name", "")))
	elif _fase_richiesta == "pagina":
		var tag := ""
		for riga in intestazioni:
			if riga.to_lower().begins_with("location:"):
				tag = riga.get_slice("/tag/", 1).strip_edges()
		if tag == "":
			_imposta("offline", "Nessun collegamento per controllare gli aggiornamenti.")
			return
		note = ""
		_versione_trovata(tag)
	elif _fase_richiesta == "sha":
		_sha_atteso = ""
		if esito == HTTPRequest.RESULT_SUCCESS and codice == 200:
			_sha_atteso = corpo.get_string_from_utf8().strip_edges().get_slice(" ", 0).to_lower()
		_avvia_scaricamento()


func _versione_trovata(tag: String) -> void:
	var ultima := tag.trim_prefix("prova-").trim_prefix("v")
	if ultima == "":
		_imposta("offline", "Risposta di GitHub non valida.")
		return
	if confronta(ultima, versione_attuale) > 0:
		versione_nuova = ultima
		_imposta("disponibile", "C'è la versione %s (hai la %s)." % [ultima, versione_attuale])
		Rapporto.evento("aggiornamento_disponibile", {"versione": ultima})
	else:
		versione_nuova = ""
		_imposta("aggiornato", "Hai l'ultima versione (%s)." % versione_attuale)


static func confronta(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var na := pa[i].to_int() if i < pa.size() else 0
		var nb := pb[i].to_int() if i < pb.size() else 0
		if na != nb:
			return 1 if na > nb else -1
	return 0


# ------------------------------------------------------------------ aggiornamento

func aggiorna() -> void:
	# Il tasto "Aggiorna": da qui in poi fa tutto da solo.
	if versione_nuova == "":
		controlla()
		return
	if OS.get_name() != "Android":
		OS.shell_open(PAGINA)
		return
	if stato in ["scarico", "verifica", "installo"]:
		return
	if FileAccess.file_exists(FILE_APK) and _versione_salvata() == versione_nuova:
		_verifica_e_installa()  # già scaricato (per esempio prima di dare il permesso)
		return
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	_imposta("scarico", "Scarico la versione %s…" % versione_nuova)
	_fase_richiesta = "sha"
	_richiesta.cancel_request()
	_richiesta.max_redirects = 8
	if _richiesta.request(SHA, ["User-Agent: NonNarrato"]) != OK:
		_sha_atteso = ""
		_avvia_scaricamento()


func _avvia_scaricamento() -> void:
	progresso = 0.0
	_scarica.cancel_request()
	_scarica.download_file = FILE_APK
	if _scarica.request(APK, ["User-Agent: NonNarrato"]) != OK:
		_imposta("errore", "Scaricamento non partito.")
		return
	set_process(true)


func _process(_delta: float) -> void:
	var totale := _scarica.get_body_size()
	if totale > 0:
		var nuovo := clampf(float(_scarica.get_downloaded_bytes()) / float(totale), 0.0, 1.0)
		if absf(nuovo - progresso) >= 0.01:
			progresso = nuovo
			messaggio = "Scarico la versione %s… %d%%" % [versione_nuova, roundi(progresso * 100.0)]
			cambiato.emit()


func _su_scaricato(esito: int, codice: int, _intestazioni: PackedStringArray, _corpo: PackedByteArray) -> void:
	set_process(false)
	if esito != HTTPRequest.RESULT_SUCCESS or codice != 200:
		_imposta("errore", "Scaricamento non riuscito (%d/%d). Riprova." % [esito, codice])
		Rapporto.evento("aggiornamento_errore", {"fase": "scarico", "esito": esito, "codice": codice})
		return
	progresso = 1.0
	var cfg := ConfigFile.new()
	cfg.set_value("aggiornamento", "scaricata", versione_nuova)
	cfg.save(FILE_STATO)
	_verifica_e_installa()


func _versione_salvata() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(FILE_STATO) != OK:
		return ""
	return String(cfg.get_value("aggiornamento", "scaricata", ""))


static func impronta_valida(percorso: String, attesa: String) -> bool:
	# Senza impronta pubblicata (versioni vecchie) mi fido dei controlli del plugin e di Android.
	if attesa == "":
		return FileAccess.file_exists(percorso)
	return FileAccess.get_sha256(percorso).to_lower() == attesa.to_lower()


func _verifica_e_installa() -> void:
	_imposta("verifica", "Controllo il file scaricato…")
	if not impronta_valida(FILE_APK, _sha_atteso):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE_APK))
		_imposta("errore", "Il file scaricato è rovinato: l'ho cancellato. Riprova.")
		Rapporto.evento("aggiornamento_errore", {"fase": "impronta"})
		return
	var percorso := ProjectSettings.globalize_path(FILE_APK)
	if plugin == null:
		# Versione senza plugin: Android mostra la sua finestra di installazione.
		Rapporto.evento("aggiornamento_installo", {"modo": "finestra_android", "versione": versione_nuova})
		_segna_attesa()
		OS.request_permission("android.permission.REQUEST_INSTALL_PACKAGES")
		OS.shell_open(percorso)
		_imposta("conferma", "Conferma l'installazione nella finestra di Android.")
		return
	var errore := String(plugin.call("verificaApk", percorso))
	if errore != "":
		_imposta("errore", "Aggiornamento rifiutato (%s)." % errore)
		Rapporto.evento("aggiornamento_errore", {"fase": "verifica", "motivo": errore})
		return
	if not bool(plugin.call("puoInstallare")):
		# Unica domanda di Android, solo la prima volta: al ritorno nel gioco riparto da solo.
		_imposta("permesso", "Android chiede una sola volta il permesso: attiva \"Consenti da questa fonte\" per NonNarrato e torna nel gioco.")
		Rapporto.evento("aggiornamento_permesso")
		plugin.call("apriPermessoInstallazione")
		return
	_installa()


func _installa() -> void:
	_imposta("installo", "Installo la versione %s: il gioco si chiuderà da solo, poi riaprilo." % versione_nuova)
	# Prima di chiudersi salvo tutto: rapporto (aspetto, memoria e impostazioni si salvano già a ogni cambio).
	Rapporto.evento("aggiornamento_installo", {"modo": "sessione", "versione": versione_nuova, "installatore": installatore(), "api": plugin.call("livelloApi")})
	Rapporto.salva("aggiornamento")
	_segna_attesa()
	plugin.call("installaApk", ProjectSettings.globalize_path(FILE_APK))


func _segna_attesa() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE_STATO)
	cfg.set_value("aggiornamento", "versione", versione_nuova)
	cfg.set_value("aggiornamento", "da", versione_attuale)
	cfg.save(FILE_STATO)


func _su_stato_installazione(codice: int, testo: String) -> void:
	# Codici di PackageInstaller: 0 riuscito, -1 serve una conferma, 1-7 errori.
	Rapporto.evento("aggiornamento_stato", {"codice": codice, "testo": testo.left(200)})
	match codice:
		0:
			_imposta("aggiornato", "Aggiornamento installato.")
		-1:
			_imposta("conferma", "Android chiede una conferma: premi \"Aggiorna\" nella sua finestra.")
		3:
			_imposta("disponibile", "Installazione annullata. Premi di nuovo \"Aggiorna\" quando vuoi.")
		_:
			_imposta("errore", "Installazione non riuscita (%d). %s" % [codice, testo.left(120)])


func _notification(cosa: int) -> void:
	if cosa == NOTIFICATION_APPLICATION_RESUMED and stato == "permesso" and plugin != null:
		if bool(plugin.call("puoInstallare")):
			_installa.call_deferred()
		else:
			_imposta("disponibile", "Senza il permesso l'aggiornamento non si può installare. Premi \"Aggiorna\" per riprovare.")


func _imposta(nuovo: String, testo: String) -> void:
	stato = nuovo
	messaggio = testo
	cambiato.emit()


func testo_pulsante() -> String:
	match stato:
		"disponibile", "errore", "conferma":
			return "Aggiorna alla %s" % versione_nuova if versione_nuova != "" else "Cerca aggiornamenti"
		"scarico":
			return "Scarico… %d%%" % roundi(progresso * 100.0)
		"verifica", "installo":
			return "Installo…"
		"permesso":
			return "Aspetto il permesso…"
		"controllo":
			return "Controllo…"
	return "Cerca aggiornamenti"
