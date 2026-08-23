# Backlog

Tout ce qui est hors du périmètre V1 verrouillé atterrit ici et **n'est pas
implémenté**, quelle que soit sa qualité ou sa rapidité de mise en œuvre.
Ce fichier n'est pas une file d'attente : c'est un endroit où une idée cesse
de coûter de l'attention.

Format : ce que c'est, pourquoi c'est hors périmètre, ce que ça coûterait
réellement — le coût réel étant presque toujours l'argument décisif.

---

## Quatre classes jouables : tank, mage, healer, archer

**Demandé le** 2026-08-23, pendant la session d'amorçage.

**Pourquoi hors périmètre.** Le périmètre V1 est « une arme, une roulade,
combat au corps-à-corps ». Quatre classes, c'est quatre jeux de mouvement,
quatre jeux d'animations, quatre lots d'équilibrage et quatre trajectoires de
progression.

**Ce que ça coûterait, au-delà du contenu.**

- **Le mage et l'archer imposent des projectiles.** Un projectile est une
  entité réseau à part entière : il naît chez l'attaquant, doit être prédit
  côté tireur, interpolé chez les autres, et son impact tombe sous
  l'invariant 6 qui interdit de prédire les dégâts. Rien de cela n'existe et
  rien de cela n'est prévu par le socle actuel.
- **Le healer casse le modèle d'autorité (invariant 5).** L'autorité hybride
  couvre deux cas : dégâts reçus par un joueur, dégâts infligés à un ennemi.
  Un soin est un troisième cas — un joueur modifie favorablement l'état d'un
  autre joueur. Qui en fait autorité ? Le soigneur peut alors mentir sur les
  points de vie d'autrui, ce que le modèle actuel rend impossible par
  construction. Il faudrait rouvrir la décision 5.
- **L'archer impose du ciblage à distance**, donc de la validation de ligne de
  vue côté hôte, donc une notion de géométrie partagée qui n'existe pas.
- **Le tank impose la poise et l'aggro**, donc un modèle de menace côté hôte.

**Conséquence.** Ce n'est pas « quatre personnages en plus », c'est une
révision de l'invariant 5 et l'ajout d'un système de projectiles. Si cette
direction est voulue, elle se décide **avant** d'écrire du gameplay, pas après.

**Décision — 23 août 2026 : LEVÉE.** Le propriétaire du projet a redemandé les
quatre classes après avoir lu le coût ci-dessus. Elles sont implémentées.

Ce que cela a effectivement coûté, pour mémoire :

- un système de projectiles, dont la trajectoire est déduite du tick de départ
  plutôt que diffusée, et dont seule la touche demande une autorité ;
- un **troisième cas d'autorité** dans l'invariant 5, pour le soin : déclaré
  par le soigneur, confirmé par l'hôte. La raison du choix est écrite dans
  `CLAUDE.md` et n'est pas un détail — c'est ce qui empêche un soigneur de
  mentir sur les points de vie d'autrui ;
- un index de classe dans l'instantané réseau, avec la contrainte qui va avec :
  l'ordre des classes ne se réordonne plus jamais.

Le tir allié n'existe pas : un projectile ne touche que le camp d'en face.

---

## Verrouillage de cible

**Rencontré** pendant les essais de la tranche verticale.

**Pourquoi hors périmètre.** Le périmètre V1 énumère du contenu, pas des
systèmes, et n'en mentionne aucun. Le combat est jouable sans : on vise à la
souris, la caméra donne la direction de l'attaque.

**Ce que ça changerait.** Un verrouillage impose une cible sélectionnée dans
l'état de l'acteur, donc dans l'instantané réseau, donc une règle sur ce qui se
passe quand la cible meurt ou sort du champ chez un client mais pas chez
l'hôte. Ce n'est pas une commodité de confort, c'est de l'état partagé de plus.

**Décision.** Reporté. À rouvrir seulement si les essais montrent que viser à
la souris rend le boss illisible.

---

## Équilibrage du boss

**Constat.** Le boss a 400 points de vie et frappe pour 28 ou 40. Ces valeurs
n'ont été mesurées que contre un bot de test, jamais contre un joueur humain.
Le bot atteint le boss et meurt ; un humain qui sait esquiver devrait s'en
tirer, mais personne ne l'a vérifié.

**Ce n'est pas une tâche de code.** Tout est dans
`res://data/actors/warden.tres` et `res://data/attacks/boss_*.tres`. Se règle
dans l'inspecteur, sans recompiler.

---

## Transport Steam (GodotSteam)

**Pourquoi hors périmètre maintenant.** Reporté d'un commun accord pendant la
session d'amorçage : le socle ne pose que l'abstraction `Transport`, ENet est
seul actif. GodotSteam est une extension native qui exige un AppID Steam et
alourdit immédiatement la vérification et les tests.

**Ce qu'il faudra faire le jour venu.** Écrire `SteamTransport` en face de
`EnetTransport`, sous la même interface. Aucune ligne de `src/sim/` ne doit
bouger — si elle bouge, c'est que l'invariant 9 a été violé quelque part.
