## Réglages d'un ennemi. Invariant 7.
##
## Le comportement lui-même est simulé exclusivement par l'hôte (invariant 5) ;
## seules ses constantes sont ici.
class_name EnemyData
extends Resource

@export var id: StringName = &""
@export var is_boss: bool = false

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
@export var stagger_duration_ticks: int = 36
@export var poise_recovery_ticks: int = 240

@export_group("Attaques")
@export var attacks: Array[AttackData] = []
## Fraction de vie en dessous de laquelle le boss change de phase.
## Ignoré si is_boss est faux.
@export var phase_two_health_ratio: float = 0.5
## Multiplicateur de cadence en phase deux, en pourcentage.
@export var phase_two_speed_percent: int = 130
