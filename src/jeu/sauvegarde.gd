## La sauvegarde : ce que la saison retient quand on pose l'outil.
##
## Fermer le jeu perdait TOUT — étape, récolte, eau descendue. Pour un jeu
## dont la règle centrale est que « le monde ne se remet pas à zéro », c'était
## une trahison mécanique autant qu'un manque.
##
## Le format est du JSON lisible dans user:// : on doit pouvoir ouvrir sa
## sauvegarde et la comprendre. On n'y met QUE de la simulation — jamais un
## nœud, jamais un réglage d'affichage (invariant 2, jusque dans le disque).
class_name Sauvegarde
extends RefCounted

const CHEMIN: String = "user://saison.json"
const VERSION: int = 1

## Photographie l'état du monde et du tutoriel.
static func extraire(monde: Monde, tutoriel: Tutoriel) -> Dictionary:
	var bassins: Array = []
	for bassin: Marais.Bassin in monde.marais.bassins:
		bassins.append({
			"nom": String(bassin.nom),
			"volume": bassin.volume,
			"salinite": bassin.salinite,
			"fleur": bassin.fleur,
			"gros_sel": bassin.gros_sel,
		})
	var vannes: Array = []
	for vanne: Marais.Vanne in monde.marais.vannes:
		vannes.append({"nom": String(vanne.nom), "ouverte": vanne.ouverte})
	var joueur: Acteur = monde.joueur()
	var donnees: Dictionary = {
		"version": VERSION,
		"etape": int(tutoriel.etape),
		"gros_sel": monde.gros_sel,
		"fleur": monde.fleur,
		"vent_est": monde.vent_est,
		"evaporation": monde.evaporation,
		"ladure": [monde.ladure.x, monde.ladure.y],
		"bassins": bassins,
		"vannes": vannes,
	}
	if joueur != null:
		donnees["joueur"] = {
			"x": joueur.position.x, "y": joueur.position.y,
			"vie": joueur.vie, "endurance": joueur.endurance,
		}
	var ennemi: Acteur = tutoriel.cristallise()
	if ennemi != null:
		donnees["cristallise"] = {
			"x": ennemi.position.x, "y": ennemi.position.y,
			"vie": ennemi.vie, "vivant": ennemi.vivant(),
		}
	return donnees

## Applique une photographie à un monde fraîchement construit. Renvoie faux si
## les données ne sont pas applicables — on repart alors d'une saison neuve
## plutôt que de charger un monde faux.
static func appliquer(donnees: Dictionary, monde: Monde,
		tutoriel: Tutoriel) -> bool:
	if _entier(donnees, "version", -1) != VERSION:
		return false
	tutoriel.etape = _entier(donnees, "etape", 0) as Tutoriel.Etape
	monde.gros_sel = _entier(donnees, "gros_sel", 0)
	monde.fleur = _entier(donnees, "fleur", 0)
	monde.vent_est = _reel(donnees, "vent_est", 0.0)
	monde.evaporation = _reel(donnees, "evaporation", 0.0)
	var ladure: Array = _tableau(donnees, "ladure")
	if ladure.size() == 2 and ladure[0] is float and ladure[1] is float:
		var lx: float = ladure[0]
		var ly: float = ladure[1]
		monde.ladure = Vector2(lx, ly)
	for entree: Variant in _tableau(donnees, "bassins"):
		if not entree is Dictionary:
			continue
		var b: Dictionary = entree
		var i: int = monde.marais.bassin_nomme(
			StringName(_texte(b, "nom", "")))
		if i < 0:
			continue
		monde.marais.bassins[i].volume = _reel(b, "volume", 0.0)
		monde.marais.bassins[i].salinite = _reel(b, "salinite", 0.0)
		monde.marais.bassins[i].fleur = _reel(b, "fleur", 0.0)
		monde.marais.bassins[i].gros_sel = _entier(b, "gros_sel", 0)
	for entree: Variant in _tableau(donnees, "vannes"):
		if not entree is Dictionary:
			continue
		var v: Dictionary = entree
		var i: int = monde.marais.vanne_nommee(
			StringName(_texte(v, "nom", "")))
		if i >= 0:
			monde.marais.vannes[i].ouverte = _booleen(v, "ouverte", false)
	var joueur: Acteur = monde.joueur()
	if joueur != null and donnees.has("joueur") and donnees["joueur"] is Dictionary:
		var j: Dictionary = donnees["joueur"]
		joueur.position = Vector2(_reel(j, "x", 0.0), _reel(j, "y", 0.0))
		joueur.vie = _reel(j, "vie", joueur.vie_max)
		joueur.endurance = _reel(j, "endurance", Reglages.ENDURANCE_MAX)
	if donnees.has("cristallise") and donnees["cristallise"] is Dictionary \
			and tutoriel.etape >= Tutoriel.Etape.LEVEE:
		var c: Dictionary = donnees["cristallise"]
		tutoriel.relever_depuis_sauvegarde(monde,
			Vector2(_reel(c, "x", 0.0), _reel(c, "y", 0.0)),
			_reel(c, "vie", 0.0), _booleen(c, "vivant", false))
	return true

# ---------------------------------------------------------------------------
# Lecture typée d'un dictionnaire JSON.
#
# `Dictionary.get` rend un Variant, et le typage strict — promu en erreurs —
# refuse de le passer à `int()` ou `float()`. C'est le prix du JSON sous
# l'invariant 10, et il s'acquitte ici, une fois, pour tout le fichier.
# ---------------------------------------------------------------------------

static func _reel(d: Dictionary, cle: String, defaut: float) -> float:
	if not d.has(cle):
		return defaut
	var v: Variant = d[cle]
	if v is float:
		var f: float = v
		return f
	if v is int:
		var n: int = v
		return float(n)
	return defaut

static func _entier(d: Dictionary, cle: String, defaut: int) -> int:
	return int(_reel(d, cle, float(defaut)))

static func _booleen(d: Dictionary, cle: String, defaut: bool) -> bool:
	if not d.has(cle):
		return defaut
	var v: Variant = d[cle]
	if v is bool:
		var b: bool = v
		return b
	return defaut

static func _texte(d: Dictionary, cle: String, defaut: String) -> String:
	if not d.has(cle):
		return defaut
	var v: Variant = d[cle]
	if v is String:
		var t: String = v
		return t
	return defaut

static func _tableau(d: Dictionary, cle: String) -> Array:
	if not d.has(cle):
		return []
	var v: Variant = d[cle]
	if v is Array:
		var t: Array = v
		return t
	return []

static func ecrire(monde: Monde, tutoriel: Tutoriel) -> bool:
	var fichier: FileAccess = FileAccess.open(CHEMIN, FileAccess.WRITE)
	if fichier == null:
		push_warning("Sauvegarde impossible : %s" % CHEMIN)
		return false
	fichier.store_string(JSON.stringify(extraire(monde, tutoriel), "  "))
	fichier.close()
	return true

static func lire() -> Dictionary:
	if not FileAccess.file_exists(CHEMIN):
		return {}
	var texte: String = FileAccess.get_file_as_string(CHEMIN)
	var resultat: Variant = JSON.parse_string(texte)
	if resultat is Dictionary:
		return resultat
	return {}

static func existe() -> bool:
	return FileAccess.file_exists(CHEMIN)

static func effacer() -> void:
	if FileAccess.file_exists(CHEMIN):
		DirAccess.remove_absolute(CHEMIN)
