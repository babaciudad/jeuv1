// La végétation qui plie sous le vent.
//
// Un marais salant est un lieu plat, ouvert, et balayé. Sans mouvement, sa
// végétation devient un décor de maquette — et le vent d'est n'est pas un
// ornement dans ce jeu : c'est lui qui annonce la fleur. Il doit donc se VOIR
// avant qu'on en parle.
//
// Le pli est calculé par sommet, à partir de deux choses :
//   — la hauteur du sommet au-dessus de sa base, pour que la tige plie et que
//     le pied reste planté ;
//   — la position dans le MONDE, pour que deux touffes voisines ne plient pas
//     à l'unisson. C'est ce déphasage-là qui fait la houle sur une prairie.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley;

uniform vec4 teinte : source_color = vec4(0.42, 0.45, 0.30, 1.0);
uniform sampler2D image : source_color, hint_default_white, filter_linear_mipmap;
uniform bool avec_image = false;
uniform float seuil_alpha : hint_range(0.0, 1.0) = 0.35;

// Force du vent, de 0 à 1. Pilotée par la simulation : c'est le même chiffre
// qui décide si la fleur prend.
uniform float vent : hint_range(0.0, 1.0) = 0.25;
uniform vec2 souffle = vec2(0.86, 0.51);
// Amplitude du pli au sommet de la plante, en mètres par unité de hauteur.
uniform float amplitude : hint_range(0.0, 1.0) = 0.16;
uniform float cadence : hint_range(0.0, 6.0) = 1.35;
// Le vent salé décolore : plus une plante est haute, plus elle prend le sel.
uniform vec3 sel : source_color = vec3(0.78, 0.77, 0.70);
uniform float blanchiment : hint_range(0.0, 1.0) = 0.26;

// PALETTE DU MARAIS.
//
// Les modèles libres arrivent dans un vert de jeu d'arcade — menthe, saturé,
// éclatant. Une lande salée de Bretagne n'a pas cette couleur : elle est
// olive, grise, mangée de vent et de sel. Plutôt que de retoucher trente
// fichiers, on désature vers cette teinte-là au moment du rendu. Les modèles
// restent tels que leurs auteurs les ont faits ; c'est le lieu qui les teint.
uniform vec3 palette : source_color = vec3(0.62, 0.66, 0.44);
uniform float ancrage : hint_range(0.0, 1.0) = 0.62;

varying float hauteur;

void vertex() {
	vec3 monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hauteur = max(VERTEX.y, 0.0);
	// Deux fréquences : une houle lente qui traverse tout le marais, et un
	// frémissement court. Une seule donnerait un balancement de métronome.
	float phase = dot(monde.xz, souffle) * 0.55 + TIME * cadence;
	float pli = sin(phase) * 0.7 + sin(phase * 2.37 + 1.7) * 0.3;
	// Le pli suit le carré de la hauteur : la tige se courbe, elle ne bascule
	// pas d'un bloc comme un panneau.
	float bras = hauteur * hauteur * amplitude * (0.25 + 0.75 * vent);
	VERTEX.xz += souffle * pli * bras;
}

void fragment() {
	vec4 couleur = teinte;
	if (avec_image) {
		couleur *= texture(image, UV);
	}
	if (couleur.a < seuil_alpha) {
		discard;
	}
	// On garde la LUMINOSITÉ du modèle — c'est elle qui porte ses volumes — et
	// on lui impose la teinte du marais.
	float valeur = dot(couleur.rgb, vec3(0.299, 0.587, 0.114));
	vec3 teinte_locale = mix(couleur.rgb, palette * (0.45 + 1.25 * valeur), ancrage);
	ALBEDO = mix(teinte_locale, sel, clamp(hauteur * blanchiment, 0.0, 0.42));
	ROUGHNESS = 0.86;
	SPECULAR = 0.18;
	ALPHA = 1.0;
	// Une feuille est fine : elle laisse passer la lumière rasante, et c'est
	// exactement l'heure du jeu.
	BACKLIGHT = vec3(0.34, 0.38, 0.24) * (0.4 + 0.6 * hauteur);
}
