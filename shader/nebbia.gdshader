shader_type canvas_item;
render_mode unshaded, blend_add;
// Nebbia che scorre lenta: due strati della stessa nuvola che si muovono in versi opposti.

uniform sampler2D rumore : repeat_enable, filter_linear;
uniform vec4 colore : source_color = vec4(0.30, 0.36, 0.58, 1.0);
uniform float densita = 0.22;
uniform vec2 ripetizioni = vec2(6.0, 2.0);
uniform vec2 scorrimento = vec2(0.012, 0.002);
uniform float verso_il_basso = 1.0;

void fragment() {
	vec2 uv = UV * ripetizioni;
	float a = texture(rumore, uv + TIME * scorrimento).r;
	float b = texture(rumore, uv * 0.55 - TIME * scorrimento * 0.7 + vec2(0.37, 0.11)).r;
	float n = smoothstep(0.25, 0.95, a * b * 2.2);
	float altezza = mix(1.0, UV.y * UV.y, verso_il_basso);
	// Sfuma ai bordi del rettangolo, così non si vede dove finisce.
	float bordo = smoothstep(0.0, 0.08, UV.y) * smoothstep(0.0, 0.03, UV.x) * smoothstep(0.0, 0.03, 1.0 - UV.x);
	COLOR = vec4(colore.rgb, n * densita * altezza * bordo);
}
