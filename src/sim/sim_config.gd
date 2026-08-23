## Constantes de la simulation, partagées par toutes les machines.
##
## Ces valeurs définissent le contrat temporel du jeu : ce ne sont pas des
## réglages de gameplay et elles n'ont donc pas leur place dans res://data/.
## Les changer change la signification de tous les ticks déjà échangés.
class_name SimConfig
extends RefCounted

## Invariant 1 : pas fixe à 60 Hz. Doit rester égal à
## physics/common/physics_ticks_per_second dans project.godot.
const TICK_RATE: int = 60

## Durée d'un tick en microsecondes (16 666,67 µs à 60 Hz). En flottant pour
## que les conversions durée <-> ticks ne perdent pas de précision ; les ticks
## eux-mêmes restent toujours des entiers.
const TICK_DURATION_USEC: float = 1_000_000.0 / float(TICK_RATE)

## Invariant 4 : l'hôte est un joueur et porte toujours le peer id 1.
const HOST_PEER_ID: int = 1

## Nombre maximal de joueurs simultanés, hôte compris.
const MAX_PLAYERS: int = 4

## Invariant 4 : tampon d'interpolation des entités distantes.
const INTERPOLATION_BUFFER_MSEC: int = 100

## Marge de sécurité ajoutée à l'avance du client sur l'hôte, en ticks.
## Absorbe la gigue résiduelle : sans elle, une commande émise juste avant un
## pic de latence arriverait après que l'hôte a simulé le tick concerné.
const CLIENT_LEAD_SAFETY_TICKS: int = 2

## Durée en microsecondes -> nombre de ticks, arrondi au plus proche.
static func usec_to_ticks(usec: int) -> int:
	return roundi(float(usec) / TICK_DURATION_USEC)

## Durée en microsecondes -> nombre de ticks entiers écoulés, arrondi vers le
## bas. C'est la conversion à utiliser pour projeter une ancre temporelle :
## on ne compte que les ticks révolus.
static func usec_to_elapsed_ticks(usec: int) -> int:
	return floori(float(usec) / TICK_DURATION_USEC)

## Nombre de ticks -> durée en microsecondes.
static func ticks_to_usec(ticks: int) -> int:
	return roundi(float(ticks) * TICK_DURATION_USEC)
