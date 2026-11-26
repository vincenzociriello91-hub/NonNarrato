@tool
extends EditorPlugin
# Mette nel manifest dell'APK la riga che fa trovare a Godot il plugin Android
# (addons/nonnarrato_android.jar, compilato da strumenti/compila_plugin.sh).
# Funziona solo con la compilazione Gradle (gradle_build/use_gradle_build=true).

var _esporta: Esportazione


func _enter_tree() -> void:
	_esporta = Esportazione.new()
	add_export_plugin(_esporta)


func _exit_tree() -> void:
	remove_export_plugin(_esporta)
	_esporta = null


class Esportazione extends EditorExportPlugin:
	func _get_name() -> String:
		return "NonNarratoAndroid"

	func _supports_platform(piattaforma: EditorExportPlatform) -> bool:
		return piattaforma is EditorExportPlatformAndroid

	func _get_android_manifest_application_element_contents(_piattaforma: EditorExportPlatform, _debug: bool) -> String:
		if not FileAccess.file_exists("res://addons/nonnarrato_android.jar"):
			return ""
		return "\n        <meta-data android:name=\"org.godotengine.plugin.v2.NonNarratoAndroid\" android:value=\"com.vincenzo.nonnarrato.NonNarratoAndroid\" />\n"
