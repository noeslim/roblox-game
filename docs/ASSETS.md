# Répertoire de modèles 3D : quoi télécharger et comment l'envoyer

Le cloud ne peut pas télécharger lui-même (seul GitHub est accessible). Les auteurs téléchargent les packs,
les poussent dans `assets/incoming/`, et le pipeline Blender (`tools/meshgen`) les intègre à la bibliothèque
comme le Downtown City MegaKit.

## Règles pour que ça passe

- **Licence** : CC0 de préférence (aucune obligation). CC-BY accepté (on met le crédit dans `docs/licenses/`).
  Jamais « personnel uniquement », « éditorial » ou sans licence.
- **Style** : réaliste ou semi-réaliste, ville la nuit, sale, usée. Pas de cartoon (Kenney, low-poly pastel).
- **Format** : glTF / GLB en priorité, sinon FBX. Un seul format par pack : ne pousse pas les dossiers
  Unity / Unreal / Godot en double.
- **Taille** : GitHub refuse les fichiers de plus de 100 Mo. Textures en **2K** max (1K suffit pour les petits objets).
  Ne pousse jamais le `.zip` : décompresse et garde seulement le format choisi.
- **Rangement** : un dossier par pack, `assets/incoming/<nom_du_pack>/`, avec le fichier de licence du pack
  (ou une ligne dans `LICENSE.txt` : site, auteur, licence, lien).
- Pour un gros pack, pousse en plusieurs commits (un par dossier) si le push échoue.

## 1. Textures photo (le plus gros gain, tout de suite)

Toutes nos façades, rues et trottoirs utilisent des textures générées par code. Des vraies photos CC0 changent tout
d'un coup. Sites : **ambientcg.com** et **polyhaven.com/textures** (tout est CC0).
Prendre la version **2K PNG**, cartes Color, Normal (**GL**), Roughness (+ Metalness s'il y en a).
Dossier : `assets/incoming/textures/<nom>/`.

| Pour | Chercher |
| --- | --- |
| façades | brique rouge sale, brique peinte, brique claire, crépi / plâtre abîmé, béton taché, parpaing |
| rues | asphalte usé (avec fissures), asphalte mouillé, pavés, plaque d'égout |
| trottoirs | dalles de béton, bordure en granit |
| toits | goudron / membrane de toit, gravier, tôle ondulée |
| métal | métal rouillé, tôle peinte écaillée, grillage, acier galvanisé |
| intérieurs / planques | carrelage sale, lino, parquet usé, plâtre fissuré, contreplaqué |

Une quinzaine suffit pour commencer (2-3 par ligne).

## 2. Objets de rue (props)

Sites : **polyhaven.com/models** (CC0, photoréaliste), **sketchfab.com** (filtre *Downloadable* +
licence *CC0* ou *CC Attribution*), **quaternius.com** (CC0, même style que le MegaKit).

- lampadaires, feux tricolores, panneaux (stop, sens interdit, noms de rues)
- bennes, poubelles, sacs poubelle, cartons, palettes, caisses, bidons / fûts
- bouches d'incendie, parcmètres, bancs, abribus, cabines, distributeurs de journaux
- grillages, barrières de chantier, plots, blocs béton (jersey), échafaudages
- escaliers de secours, climatiseurs, antennes, réservoirs d'eau de toit
- voitures (berline, van, pick-up, épaves), scooters
- matelas, canapés défoncés, caddies, pneus, graffitis (en décalques PNG)

## 3. Bâtiments et quartiers

- **Quaternius** : d'autres kits modulaires de ville ou de zone en ruine, pour la War Zone.
- **Sketchfab CC0 / CC-BY** : « modular building », « brownstone », « warehouse », « gas station »,
  « container », « docks / pier », « chain link fence », « trailer ».
- Docks (prochaine zone) : conteneurs, grues, bittes d'amarrage, quais en bois, hangars.

## Ce que je fais quand un pack arrive

1. Planche d'aperçu de tous les modèles du pack, pour choisir ensemble ce qu'on garde.
2. Tri par emplacement de la ville (façade, prop de rue, toit, planque, War Zone, docks).
3. Intégration dans `tools/meshgen` (textures redimensionnées, échelle, pivot, limite de 20 000 triangles
   par mesh), nouvelles variantes dans la bibliothèque, rendus au niveau de la rue.
4. Crédits dans `docs/licenses/`.
