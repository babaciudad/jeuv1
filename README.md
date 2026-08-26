# souls-like — build Windows v5

Cette branche ne contient **que le jeu compilé**. Elle n'a aucune histoire
commune avec le code : elle ne sera jamais fusionnée, et elle n'alourdit pas
les clones du code source.

## Télécharger

Clique sur `souls-like-windows-v5.zip`, puis sur le bouton **Download**
(l'icône de téléchargement en haut à droite du fichier).

Décompresse, puis double-clique sur `souls-like.exe`.
Windows dira « éditeur inconnu » — le binaire n'est pas signé :
*Informations complémentaires* → *Exécuter quand même*.

## Vérifier le fichier

```powershell
Get-FileHash souls-like-windows-v5.zip -Algorithm SHA256
```

Doit donner :

```
ba7cf22137f8b089aa2a9dc2e82289ec7089f914906a7488cb1fc658ef2e7868
```

## Ce qu'il y a dedans

Voir `LISEZMOI.txt`. Quatre bugs corrigés, pas des réglages :

1. **La barre noire qui traversait chaque plan n'était pas de l'éclairage.**
   Sous l'horizon le sol est vu par la tranche, le décroché de profondeur
   sature, et la passe d'encre remplissait toute la bande en noir plein.
   Preuve : en passant l'ambiante en rouge vif, toute la scène rougit et la
   bande reste parfaitement noire.
2. **Le gardien et le boss n'avaient aucune animation de marche** depuis leur
   import : leur clip était nommé sans son préfixe de bibliothèque, et jouer
   une animation inexistante ne lève rien dans Godot.
3. **Le sol était du papier millimétré** : le joint de mortier était creusé
   dans la géométrie, une dalle par mètre, et l'encre détourait chaque face.
4. **Les personnages portaient la livrée orange du mannequin d'atelier**
   fournie avec le corps importé, et leur redingote était montée à l'envers.

Build produit depuis le commit `d0347c7` de la branche
`claude/souls-like-godot-foundation-tibo8e`, avec Godot 4.7.2 en Forward+.

Vérifié en construisant le jumeau Linux du paquet et en le démarrant : il
héberge et charge le niveau complet (762 pièces de décor, 77 lots) sans une
seule erreur de script. La **fluidité n'a pas pu être mesurée** : la machine
de développement n'a pas de carte graphique et plafonne à quelques images par
seconde.

Une carte graphique compatible Vulkan est nécessaire.

Les branches `builds/windows-v3` et `builds/windows-v4` sont périmées.
