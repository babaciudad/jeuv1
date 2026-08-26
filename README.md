# souls-like — build Windows v3

Cette branche ne contient **que le jeu compilé**. Elle n'a aucune histoire
commune avec le code : elle ne sera jamais fusionnée, et elle n'alourdit pas
les clones du code source.

## Télécharger

Clique sur `souls-like-windows-v3.zip`, puis sur le bouton **Download**
(l'icône de téléchargement en haut à droite du fichier).

Décompresse, puis double-clique sur `souls-like.exe`.
Windows dira « éditeur inconnu » — le binaire n'est pas signé :
*Informations complémentaires* → *Exécuter quand même*.

## Vérifier le fichier

    Get-FileHash souls-like-windows-v3.zip -Algorithm SHA256

Doit donner :

    B6B4222F5059A2A3F6B6CB0B4AC4496A80E4CF8800EFC6B9B4697593C58DE534

## Ce qu'il y a dedans

Voir `LISEZMOI.txt`. Build produit depuis le commit `d93c5a6` de la branche
`claude/souls-like-godot-foundation-tibo8e`, avec Godot 4.7.2 en Forward+.

Une carte graphique compatible Vulkan est nécessaire.
