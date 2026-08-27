// L'argile du marais : le sol, les talus, le fond des bassins.
//
// L'argile est ce qui rend le lieu possible — imperméable, elle retient l'eau —
// et c'est elle qui donne au gros sel sa couleur grise, puisqu'il cristallise
// contre elle. Le sol doit donc raconter trois états, et le maillage les porte
// dans sa couleur de sommet :
//
//   COLOR.r  mouillé   0 = talus sec et clair, 1 = fond de bassin détrempé
//   COLOR.g  sel       0 = argile nue, 1 = croûte de sel accumulée
//
// Pas de texture importée ici : tout est tiré d'un bruit. C'est délibéré tant
// que la provenance des textures n'est pas tranchée — un sol procédural qui
// tient debout vaut mieux qu'un sol emprunté dont on ne sait pas la licence.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 argile_seche : source_color = vec3(0.244, 0.220, 0.174);
// Mesuré, pas choisi. À 0,098 de réflectance, l'argile mouillée tombait à
// RGB(8,8,10) partout où elle n'a que l'ambiante pour l'éclairer — c'est-à-dire
// sur toute la paroi est de chaque talus. On a longtemps cru à un défaut
// d'ombre ; un rendu à albédo uniforme a montré que la lumière était là et que
// c'était la matière qui l'avalait.
uniform vec3 argile_mouillee : source_color = vec3(0.118, 0.108, 0.091);
uniform vec3 croute_sel : source_color = vec3(0.775, 0.771, 0.740);
uniform sampler2D bruit : hint_default_black, repeat_enable, filter_linear_mipmap;
// ÉCHELLES, et elles sont mesurées.
//
// À 3,1, le grain se répétait cent quatre-vingt-dix-huit fois sur soixante-
// quatre mètres. Vu en rasant — c'est-à-dire partout, dans un lieu plat — le
// mipmapping moyennait la texture à 0,5 sur toute l'image : le sol devenait
// parfaitement lisse et DEUX CAPTURES À COEFFICIENTS DIFFÉRENTS SORTAIENT
// IDENTIQUES AU BIT PRÈS. C'est ce qui a mis le doigt dessus.
uniform float echelle_grain : hint_range(0.01, 4.0) = 0.34;
uniform float echelle_plaques : hint_range(0.002, 0.5) = 0.031;
// Un maillage sans couleur de sommet — un plan, un prop — arrive ici avec du
// blanc, c'est-à-dire « trempé et couvert de sel ». Quand x est positif, cette
// teinte remplace la couleur de sommet et le maillage sait enfin ce qu'il est.
uniform vec3 teinte_forcee = vec3(-1.0, 0.0, 0.0);

varying vec3 monde;
// Débogage : affiche la normale du monde au lieu de la matière. Une face
// retournée saute alors aux yeux, là où une image finie ne montre qu'un noir
// dont on ne sait pas s'il vient de la lumière, de la matière ou du maillage.
uniform bool debug_normales = false;
// Débogage : albédo uniforme et mat. Ce qui reste à l'image est alors
// exactement la lumière reçue, sans que la matière puisse en être accusée.
uniform bool debug_albedo = false;
varying vec3 teintes;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	teintes = COLOR.rgb;
	if (teinte_forcee.x >= 0.0) {
		teintes = teinte_forcee;
	}
}

void fragment() {
	// PAS DE `return` ICI. Le langage de shader de Godot l'interdit dans
	// `fragment`, et il ne le dit qu'au chargement : le shader ne compile plus
	// du tout, le moteur retombe sur un matériau blanc par défaut, et l'image
	// change juste assez pour qu'on croie à un problème de réglage. Deux heures
	// de captures identiques au bit près sont sorties de cette seule ligne.
	if (debug_albedo) {
		ALBEDO = vec3(0.72);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else if (debug_normales) {
		ALBEDO = vec3(0.0);
		EMISSION = texture(bruit, monde.xz * echelle_plaques).rgb;
	} else {
	// Deux échelles : de grandes plaques qui font la géologie, un grain fin qui
	// casse l'uniformité de près. Une seule donnerait une moquette.
	float plaques = texture(bruit, monde.xz * echelle_plaques).r;
	float grain = texture(bruit, monde.xz * echelle_grain).g;

	float mouille = clamp(teintes.r + (plaques - 0.5) * 0.30, 0.0, 1.0);
	vec3 base = mix(argile_seche, argile_mouillee, mouille);
	base *= 0.84 + 0.30 * grain;

	// Le sel se dépose par plaques, pas en couche uniforme : il faut qu'il y en
	// ait assez pour qu'on le lise, et jamais assez pour que ce soit de la neige.
	float sel = clamp(teintes.g * smoothstep(0.46, 0.86, plaques) * 1.15, 0.0, 1.0);
	ALBEDO = mix(base, croute_sel, sel);

	// L'argile mouillée brille, l'argile sèche non, et le sel est mat et poudreux.
	ROUGHNESS = mix(mix(0.94, 0.42, mouille), 0.88, sel);
	SPECULAR = mix(0.32, 0.12, sel);
	}
}
