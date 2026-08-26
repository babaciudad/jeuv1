# souls-like — build Windows v4

Cette branche ne contient **que le jeu compilé**. Elle n'a aucune histoire
commune avec le code : elle ne sera jamais fusionnée, et elle n'alourdit pas
les clones du code source.

## Télécharger

Clique sur `souls-like-windows-v4.zip`, puis sur le bouton **Download**
(l'icône de téléchargement en haut à droite du fichier).

Décompresse, puis double-clique sur `souls-like.exe`.
Windows dira « éditeur inconnu » — le binaire n'est pas signé :
*Informations complémentaires* → *Exécuter quand même*.

## Vérifier le fichier

```powershell
Get-FileHash souls-like-windows-v4.zip -Algorithm SHA256
```

Doit donner :

```
ad63ea7c94bb288cd75866ca97bb6f349955a0cd111613945d14af056a753cd3
```

## Ce qu'il y a dedans

Voir `LISEZMOI.txt`. Deux changements de fond depuis la v3 : les personnages
reposent sur un vrai corps skinné à proportions humaines avec 162 animations
authentiques, et le niveau passe de 60 × 80 m entièrement couvert à
68 × 184 m dont la moitié à ciel ouvert.

Build produit depuis le commit `a63eb88` de la branche
`claude/souls-like-godot-foundation-tibo8e`, avec Godot 4.7.2 en Forward+.

Une carte graphique compatible Vulkan est nécessaire.

La branche `builds/windows-v3` est périmée : elle porte l'ancien squelette
chibi et l'ancien niveau exigu.
