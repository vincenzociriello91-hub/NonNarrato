#!/usr/bin/env bash
# Compila il plugin Android (android_plugin/src) in addons/nonnarrato_android.jar.
# La compilazione Gradle di Godot prende da sola i .jar che stanno in res://addons.
# Uso: strumenti/compila_plugin.sh <android.jar> <classes.jar di godot-lib>
set -euo pipefail
android_jar="$1"
godot_jar="$2"
cartella="$(cd "$(dirname "$0")/.." && pwd)"
lavoro="$(mktemp -d)"
trap 'rm -rf "${lavoro}"' EXIT
mapfile -t sorgenti < <(find "${cartella}/android_plugin/src" -name "*.java")
javac -nowarn -Xlint:-options -source 11 -target 11 -encoding UTF-8 \
	-cp "${android_jar}:${godot_jar}" -d "${lavoro}/classi" "${sorgenti[@]}"
mkdir -p "${cartella}/addons"
(cd "${lavoro}/classi" && jar cf "${cartella}/addons/nonnarrato_android.jar" .)
echo "plugin compilato: ${cartella}/addons/nonnarrato_android.jar"
