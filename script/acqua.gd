class_name Acqua
extends Node2D
# Acqua ferma (la vasca del sotterraneo): un velo blu trasparente con la superficie che ondeggia,
# un riflesso chiaro sul pelo dell'acqua e una luce fredda. Chi ci entra nuota (vedi Giocatore):
# le regole stanno in Stanza.ACQUE, qui c'è solo l'aspetto.

const SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 colore_alto : source_color = vec4(0.16, 0.3, 0.4, 0.3);
uniform vec4 colore_basso : source_color = vec4(0.04, 0.08, 0.16, 0.6);
uniform vec2 misura = vec2(100.0, 100.0);
void fragment() {
	vec2 p = UV * misura;
	float onda = 3.0 + sin(p.x * 0.09 + TIME * 2.0) * 1.2 + sin(p.x * 0.23 - TIME * 1.3) * 0.6;
	if (p.y < onda) {
		discard;
	}
	vec4 c = mix(colore_alto, colore_basso, clamp(p.y / misura.y, 0.0, 1.0));
	float bordo = 1.0 - clamp((p.y - onda) / 2.5, 0.0, 1.0);
	c.rgb += vec3(0.32, 0.42, 0.46) * bordo;
	c.a = max(c.a, bordo * 0.75);
	float luce = sin(p.x * 0.05 + p.y * 0.08 + TIME) * sin(p.x * 0.07 - p.y * 0.05 - TIME * 0.7);
	c.rgb += vec3(0.03, 0.05, 0.06) * max(luce, 0.0);
	COLOR = c;
}
"""

var rett := Rect2()                # da superficie (in alto) al fondo


func _ready() -> void:
	z_index = 15
	var s := Shader.new()
	s.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = s
	var velo := ColorRect.new()
	velo.position = rett.position - Vector2(0, 3)
	velo.size = rett.size + Vector2(0, 3)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.material = m
	m.set_shader_parameter("misura", velo.size)
	add_child(velo)
	var luce := Effetti.luce(Color(0.45, 0.7, 0.85), rett.size.x * 0.6, 0.6, 30.0)
	luce.position = rett.get_center()
	luce.range_item_cull_mask = Effetti.L_SFONDO | Effetti.L_DAVANTI
	add_child(luce)
	add_to_group("acque")
