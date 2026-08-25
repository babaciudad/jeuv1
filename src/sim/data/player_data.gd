## Réglages d'une classe jouable. Invariant 7.
##
## L'ordre des classes dans NetBootstrap.CLASS_PATHS est celui du menu ET celui
## qui voyage sur le réseau : on n'en réordonne jamais, on n'en retire jamais,
## on n'en ajoute qu'à la fin.
class_name PlayerData
extends Resource

@export_group("Identité")
@export var id: StringName = &""
@export var display_name: String = ""
## Résumé d'une ligne, affiché dans le menu de choix.
@export_multiline var summary: String = ""
@export var color: Color = Color(0.56, 0.75, 0.48)

@export_group("Vitalité")
@export var max_health: int = 100
@export var max_stamina: int = 100
@export var max_poise: int = 40
@export var radius: float = 0.45

@export_group("Locomotion")
@export var move_speed: float = 5.0
## Accélération et freinage, en mètres par seconde carrée.
@export var acceleration: float = 60.0
@export var deceleration: float = 45.0
@export var turn_degrees_per_tick: float = 12.0

@export_group("Roulade")
@export var dodge_speed: float = 9.5
@export var dodge_duration_ticks: int = 24
## Ticks d'invulnérabilité, comptés depuis le début de la roulade.
@export var dodge_invulnerable_from_tick: int = 3
@export var dodge_invulnerable_to_tick: int = 15
@export var dodge_stamina_cost: int = 25
## Profil de vitesse de la roulade. Une roulade à vitesse CONSTANTE puis
## arrêt net est ce qui donnait au jeu sa sensation de patinage : un corps
## qui se jette part fort et finit en freinant. `burst` multiplie la vitesse
## au premier tick, `tail` à la fin, et l'interpolation entre les deux suit
## une courbe qui reste rapide longtemps avant de tomber.
@export var dodge_burst: float = 1.45
@export var dodge_tail: float = 0.16
## Vitesse conservée en sortant de la roulade. Non nulle : couper à zéro fige
## le personnage sur place et casse tout enchaînement.
@export var dodge_exit_speed: float = 2.4

@export_group("Endurance")
## Régénération par tick, en centièmes de point : évite l'arithmétique
## flottante sur une valeur qui doit rester identique sur toutes les machines.
@export var stamina_regen_per_tick_centi: int = 90
## Ticks d'attente après une dépense avant que la régénération reprenne.
@export var stamina_regen_delay_ticks: int = 30

@export_group("Réactions")
@export var stagger_duration_ticks: int = 30
## Ticks avant que la poise cassée ne se reconstitue entièrement.
@export var poise_recovery_ticks: int = 180

@export_group("Armes")
@export var attacks: Array[AttackData] = []
