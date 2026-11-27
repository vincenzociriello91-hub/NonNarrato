class_name Salvataggio
extends RefCounted
# Scrittura sicura dei salvataggi in user:// (impostazioni, aspetto, memoria del Dormiente, partita in corso).
# Su Android il sistema può chiudere il gioco in qualsiasi momento: un file scritto a metà sarebbe illeggibile
# e si perderebbe tutto. Per questo:
# 1. si scrive su "<file>.tmp" e lo si rilegge per controllare che sia intero;
# 2. il file buono di prima viene copiato in "<file>.bak" (l'originale non si tocca);
# 3. solo alla fine il .tmp prende il posto dell'originale con una rinomina, che è istantanea.
# In lettura, se il file manca o è rovinato si usa il .bak.

static var scritture := 0      # per le prove e il rapporto
static var recuperati := 0     # letture riuscite solo grazie al .bak


static func scrivi_cfg(cfg: ConfigFile, percorso: String) -> bool:
	var tmp := percorso + ".tmp"
	if cfg.save(tmp) != OK:
		push_warning("Salvataggio: impossibile scrivere %s" % tmp)
		return false
	var verifica := ConfigFile.new()
	if verifica.load(tmp) != OK:
		push_warning("Salvataggio: %s scritto male, il file buono resta quello di prima" % tmp)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	var vero := ProjectSettings.globalize_path(percorso)
	if FileAccess.file_exists(percorso):
		DirAccess.copy_absolute(vero, vero + ".bak")
	var esito := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), vero)
	if esito != OK:
		# Alcuni sistemi non rinominano sopra un file che esiste: lo si toglie (il .bak c'è già) e si riprova.
		DirAccess.remove_absolute(vero)
		esito = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), vero)
	if esito == OK:
		scritture += 1
	return esito == OK


static func leggi_cfg(cfg: ConfigFile, percorso: String) -> int:
	# OK se il file (o la sua copia .bak) si legge; altrimenti l'errore del file principale.
	var esito := cfg.load(percorso) if FileAccess.file_exists(percorso) else ERR_FILE_NOT_FOUND
	if esito == OK:
		return OK
	var copia := percorso + ".bak"
	if FileAccess.file_exists(copia):
		cfg.clear()
		if cfg.load(copia) == OK:
			recuperati += 1
			if esito != ERR_FILE_NOT_FOUND:
				push_warning("Salvataggio: %s rovinato, ripreso dalla copia" % percorso)
			return OK
	cfg.clear()
	return esito


static func cancella(percorso: String) -> void:
	for p: String in [percorso, percorso + ".bak", percorso + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
