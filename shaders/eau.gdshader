// L'eau d'un marais salant.
//
// Ce n'est ni une mer ni un lac : c'est une nappe de quelques centimètres sur
// de l'argile, immobile, et c'est le sujet visuel du jeu. « La beauté est dans
// l'eau et la lumière, pas dans l'architecture. Un marais salant au couchant
// est un miroir horizontal de plusieurs kilomètres carrés. »
//
// Trois choses, donc, et rien d'autre :
//   — elle REFLÈTE, d'autant plus qu'on la regarde de loin (Fresnel) ;
//   — elle laisse voir le FOND, d'autant plus qu'elle est peu profonde, et ce
//     fond est l'argile grise qui donne sa couleur au gros sel ;
//   — elle BLANCHIT à mesure qu'elle se sature, jusqu'à la pellicule de fleur.
//
// Le vent d'est n'est pas un décor : il ride la surface, et c'est ce
// frémissement qui annonce au joueur que la fleur va prendre.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// Couleur de l'eau en faible épaisseur, quand on voit surtout l'argile.
uniform vec3 teinte_fond : source_color = vec3(0.336, 0.318, 0.268);
// Couleur de l'eau quand elle a de la profondeur.
uniform vec3 teinte_profonde : source_color = vec3(0.113, 0.147, 0.150);
// Blanc de la saumure saturée. Ce n'est pas un blanc pur : c'est laiteux.
uniform vec3 teinte_saumure : source_color = vec3(0.735, 0.750, 0.720);

// Profondeur, en mètres, au-delà de laquelle on ne voit plus le fond.
uniform float profondeur_opaque : hint_range(0.02, 2.0) = 0.34;
// Épaisseur réelle de la nappe, en mètres, telle que la simulation la connaît.
//
// Elle sert de BORNE au trajet lu dans le tampon de profondeur. Sans elle, une
// nappe de trois centimètres regardée en rasant donne un trajet optique de
// plusieurs mètres — le tampon mesure la distance jusqu'au fond LE LONG DU
// REGARD, pas l'épaisseur d'eau — et le bassin se remplit d'une bande noire
// tout du long de son bord lointain. C'était le défaut le plus visible du
// premier jet, et il n'avait rien à voir avec les ombres.
uniform float profondeur_nappe : hint_range(0.0, 4.0) = 0.05;
// Saturation en sel, de 0 à 1. À 1, la surface est prête à cristalliser.
uniform float salinite : hint_range(0.0, 1.0) = 0.0;
// Force du vent d'est, de 0 à 1. Zéro : l'eau est un miroir parfait.
uniform float vent : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D bruit : hint_default_black, repeat_enable, filter_linear;
// Même piège que pour l'argile : trop fines, les rides disparaissent dans le
// mipmapping dès qu'on regarde la nappe autrement que d'aplomb.
uniform float echelle_rides : hint_range(0.01, 4.0) = 0.28;
uniform float force_rides : hint_range(0.0, 1.0) = 0.34;
uniform float vitesse_rides : hint_range(0.0, 1.0) = 0.045;

// Pellicule de fleur de sel : une croûte fragile qui se forme en surface les
// soirs de vent d'est. Elle n'est pas peinte partout — elle prend par plaques.
uniform float fleur : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D profondeur_ecran : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D image_ecran : hint_screen_texture, filter_linear_mipmap;

varying vec3 monde;
// Débogage : affiche la normale du monde au lieu de la matière. Une face
// retournée saute alors aux yeux, là où une image finie ne montre qu'un noir
// dont on ne sait pas s'il vient de la lumière, de la matière ou du maillage.
uniform bool debug_normales = false;
uniform bool debug_albedo = false;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Épaisseur d'eau réellement traversée par le regard, en mètres, lue dans le
// tampon de profondeur. C'est ce qui fait qu'un bord de bassin s'éclaircit
// tout seul, sans qu'on ait à peindre une seule ligne de rive.
float epaisseur(vec2 ecran, vec3 vue, mat4 inv_projection) {
	float brut = texture(profondeur_ecran, ecran).r;
	vec3 ndc = vec3(ecran * 2.0 - 1.0, brut);
	vec4 derriere = inv_projection * vec4(ndc, 1.0);
	derriere.xyz /= derriere.w;
	return max(0.0, -derriere.z + vue.z);
}

void fragment() {
	if (debug_normales) {
		vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		ALBEDO = vec3(0.0);
		EMISSION = vec3(1.0, 0.0, 1.0) * (n.y * 0.5 + 0.5);
		ALPHA = 1.0;
		return;
	}
	if (debug_albedo) {
		ALBEDO = vec3(0.10, 0.55, 0.75);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		ALPHA = 1.0;
		return;
	}
	// Deux couches de bruit qui dérivent en sens contraire : une seule donnerait
	// un défilement visible, et un marais ne défile pas.
	vec2 uv = monde.xz * echelle_rides;
	float t = TIME * vitesse_rides;
	vec3 n1 = texture(bruit, uv * 0.7 + vec2(t, t * 0.6)).rgb;
	vec3 n2 = texture(bruit, uv * 1.9 - vec2(t * 0.8, t * 1.3)).rgb;
	vec3 ride = normalize(vec3((n1.r - 0.5) + (n2.r - 0.5), 1.0,
			(n1.g - 0.5) + (n2.g - 0.5)));
	// Au repos, la surface est un miroir : le vent seul la ride.
	float amplitude = force_rides * (0.12 + 0.88 * vent);
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(ride, 0.0)).xyz, amplitude));

	// Trajet optique réel : l'épaisseur de la nappe divisée par l'inclinaison
	// du regard. À la verticale, on traverse l'épaisseur ; en rasant, on en
	// traverse davantage — mais jamais plus que ce plafond-là.
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	vec3 regard = normalize(monde - camera);
	float trajet_max = profondeur_nappe / max(abs(regard.y), 0.05);
	float e = min(epaisseur(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX), trajet_max);
	float opacite = clamp(e / profondeur_opaque, 0.0, 1.0);

	// Le grain de l'argile, vu À TRAVERS l'eau. C'est le shader d'eau qui le
	// porte, et non le sol : il faut que la nappe soit assez opaque pour garder
	// son reflet, et une nappe opaque cacherait le fond si elle n'en montrait
	// pas elle-même quelque chose.
	float fond_grain = texture(bruit, monde.xz * 0.21).g;
	vec3 argile = teinte_fond * (0.80 + 0.42 * fond_grain);
	vec3 couleur = mix(argile, teinte_profonde, opacite);
	couleur = mix(couleur, teinte_saumure, salinite * 0.55);

	// La fleur ne se pose qu'en surface, par plaques, et seulement là où l'eau
	// est calme et peu profonde. C'est la règle du lore, écrite en shader :
	// « ce qui remonte à la surface est pur, ce qui reste au fond est souillé ».
	float plaques = smoothstep(0.52, 0.78,
			texture(bruit, monde.xz * 0.055 + vec2(TIME * 0.004, 0.0)).b);
	float voile = fleur * plaques * (1.0 - 0.6 * opacite);

	ALBEDO = mix(couleur, vec3(0.94, 0.945, 0.93), voile);
	// Une eau salée peu profonde reste très lisse : c'est ce qui la rend
	// miroir. La fleur, elle, est mate — c'est un solide.
	ROUGHNESS = mix(mix(0.028, 0.15, vent), 0.72, voile);
	METALLIC = 0.0;
	SPECULAR = mix(0.72, 0.2, voile);

	// OPACITÉ DE FRESNEL, et ce n'est pas un raffinement : c'est ce qui fait
	// qu'on voit de l'eau.
	//
	// En mélange alpha, Godot multiplie TOUT le fragment par ALPHA — la
	// réflexion spéculaire comprise. Une nappe de trois centimètres, rendue
	// fidèlement transparente, perdait donc du même coup le reflet qui est la
	// seule chose qui la signale à l'œil : il ne restait que l'argile du fond,
	// et le marais n'avait plus une goutte d'eau dessus.
	//
	// Le remède est aussi la physique : une surface d'eau est transparente
	// quand on la regarde d'aplomb et devient un miroir quand on la rase. On
	// pilote donc l'opacité par Fresnel, et le reflet revient précisément là
	// où il doit être — sur toute l'étendue vue de loin.
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)),
			0.0, 1.0), 4.0);
	// Assez opaque pour garder le reflet, jamais assez pour nier le fond.
	float base = mix(0.68, 0.97, opacite);
	ALPHA = mix(mix(base, 1.0, fresnel), 1.0, voile);
}
