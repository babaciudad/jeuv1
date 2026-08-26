## Réglages d'un ennemi. Invariant 7.
##
## Le comportement lui-même est simulé exclusivement par l'hôte (invariant 5) ;
## seules ses constantes sont ici.
class_name EnemyData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var is_boss: bool = false
## Mannequin d'entraînement : il ne poursuit personne, ne frappe personne, et
## ne meurt jamais tout à fait — il se relève au bout de quelques secondes.
##
## C'est le seul endroit du jeu où l'on peut se tromper sans conséquence, et
## c'est exactement ce qu'il faut pour apprendre le rythme d'une arme.
@export var is_training_dummy: bool = false
## Ticks après lesquels un mannequin abattu se relève à pleine vie.
@export var dummy_revive_ticks: int = 180
@export var color: Color = Color(0.71, 0.34, 0.31)

@export_group("Vitalité")
@export var max_health: int = 60
@export var max_poise: int = 30
@export var radius: float = 0.5

@export_group("Locomotion")
@export var move_speed: float = 3.0
@export var acceleration: float = 25.0
@export var turn_degrees_per_tick: float = 5.0

@export_group("Comportement")
## Distance à laquelle l'ennemi remarque un joueur.
@export var aggro_radius: float = 12.0
## Distance à laquelle il abandonne la poursuite.
@export var leash_radius: float = 26.0
## Distance à laquelle il déclenche une attaque.
@export var attack_range: float = 2.4
## Ticks entre deux attaques.
@export var attack_cooldown_ticks: int = 90
## Ticks pendant lesquels l'ennemi recule après avoir frappé. Sans ce recul,
## il reste collé au joueur et le combat n'offre plus aucune fenêtre : on ne
## peut ni riposter ni s'écarter.
@export var recover_ticks: int = 26
## Multiplicateur de la portée en deçà duquel l'ennemi tourne autour de sa
## cible au lieu de foncer dessus.
@export var circle_band: float = 1.4
## Ticks d'ARRÊT avant de frapper. L'ennemi se plante face au joueur, cesse
## d'avancer, et frappe seulement après ce délai.
##
## C'est le tell, et sans lui il n'y a pas de combat : un ennemi qui frappe à
## l'instant même où il entre en portée ne donne rien à lire, et le joueur ne
## peut que subir. La marque d'un souls-like est qu'on VOIT le coup venir assez
## tôt pour rouler, et assez tard pour que ce soit un choix.
@export var tell_ticks: int = 22
## Part du délai d'attaque qui saute quand la cible est en train de frapper.
## Un ennemi doit punir un coup manqué : c'est ce qui apprend au joueur à ne
## pas frapper au hasard.
@export var punish_percent: int = 55
@export var stagger_duration_ticks: int = 36
@export var poise_recovery_ticks: int = 240

@export_group("Attaques")
@export var attacks: Array[AttackData] = []
## Fraction de vie en dessous de laquelle le boss change de phase.
## Ignoré si is_boss est faux.
@export var phase_two_health_ratio: float = 0.5
## Multiplicateur de cadence en phase deux, en pourcentage.
@export var phase_two_speed_percent: int = 130
