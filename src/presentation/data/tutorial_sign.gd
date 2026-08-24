## Une rune gravée dans le sol, qui enseigne une chose et une seule.
##
## Invariant 2 : présentation pure. Une rune n'ouvre pas de porte, ne bloque
## pas le joueur, ne modifie aucune règle. Le jeu se termine exactement pareil
## si on les ignore toutes — et on peut toutes les désactiver d'un argument.
##
## Le principe : on n'apprend pas en lisant une liste de consignes en haut de
## l'écran, on apprend en croisant la bonne phrase à l'endroit où elle sert.
## Une rune s'allume quand on s'en approche, et s'ÉTEINT quand on a fait la
## chose. C'est le monde qui garde la trace de ce qu'on sait, pas un compteur.
class_name TutorialSign
extends Resource

## Ce qui éteint la rune.
enum Condition {
	## S'éteint toute seule après lecture. Pour ce qui s'annonce sans se
	## pratiquer : un avertissement, un lieu.
	READ,
	## Le joueur a tourné la caméra.
	LOOK,
	## Le joueur s'est éloigné de la rune.
	MOVE,
	## Une roulade.
	DODGE,
	## Une attaque principale.
	ATTACK,
	## L'attaque secondaire, ou le soin selon la classe.
	SECOND,
	## Un coup porté à un adversaire, quel qu'il soit.
	HIT,
	## Un repos au feu.
	REST,
	## Un ennemi tué.
	KILL,
	## Le raccourci ouvert.
	SHORTCUT,
}

@export var id: StringName = &""
## Position au sol, dans le plan XZ de la simulation.
@export var position: Vector2 = Vector2.ZERO
## Distance à laquelle la rune s'allume et se lit.
@export var radius: float = 3.4

## La phrase. Une seule idée : deux idées dans une rune, et aucune ne passe.
@export_multiline var line: String = ""
## La touche, ou le détail. Affiché plus petit, sous la phrase.
@export var hint: String = ""

@export var condition: Condition = Condition.READ
## Secondes de lecture avant qu'une rune `READ` ne s'éteigne.
@export var read_seconds: float = 3.5
@export var tone: Color = Color(1.0, 0.72, 0.30)
