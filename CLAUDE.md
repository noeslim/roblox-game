# CLAUDE.md — Black Market (jeu Roblox)

Lis ce fichier en entier avant de coder. Le design est dans `docs/GAME_DESIGN.md`, le plan dans `docs/ROADMAP.md`.
Les auteurs parlent français : réponds en français, mais le code, les noms et les commentaires sont en anglais.
**Le jeu est en anglais** : tout texte visible par les joueurs (UI, PNJ, erreurs, panneaux) est en anglais. Les messages d'erreur et répliques des PNJ sont dans `src/shared/Config/Messages.luau`.

## Le jeu en bref
Jeu de dealer d'armes (univers fictif, armes stylisées, pas de sang) avec ambiance ville criminelle nocturne façon Criminality. Construction libre de sa planque, fabrication d'armes à sa marque, vente à des PNJ et aux joueurs de deux camps en guerre, descentes d'inspecteurs, marché noir de nuit.

## Stack
- **Rojo** (`default.project.json`) : le code vit dans `src/`, synchronisé vers Studio sur le PC des auteurs.
- **Luau** avec `--!strict` en tête de chaque fichier.
- **Lune** pour exécuter les tests dans le cloud (pas de Roblox Studio ici).
- Sauvegarde : ProfileStore (vendored dans `src/server/Packages/ProfileStore.luau`, licence dans `docs/licenses/`).

## Arborescence
```
src/
  shared/            -> ReplicatedStorage.Shared
    Config/          économie, rareté, pièces, réglages (AUCUN chiffre en dur ailleurs)
    Logic/           modules PURS : pas de game, workspace, Instance, task, tick(), os.clock()
  server/            -> ServerScriptService.Server
    Services/        services serveur (DataService, BuildService, SaleService...)
  client/            -> StarterPlayer.StarterPlayerScripts.Client
    Controllers/     UI, caméra, construction, effets (démarrés automatiquement, méthode :Start())
    UI.luau, Effects.luau, State.luau, Notify.luau   modules client partagés
  shared/Visual/     ModelFactory (modèles 3D procéduraux), PlotUtil (coordonnées de terrain)
  shared/Net.luau    liste des Remotes (créés par server/Lib/ServerNet, avec rate-limit)
  server/Lib/        ServerNet, NpcMover (modules serveur qui ne sont pas des services)
tests/
  run.luau           lanceur : `lune run tests/run`
  specs/*.spec.luau  un fichier de test par module de Logic
docs/
```

## Règles d'architecture (non négociables)
1. **Le serveur fait autorité** sur tout ce qui a de la valeur (argent, pièces, armes, placement, ventes, chaleur). Le client envoie des *intentions* (`RequestPlace`, `RequestSell`...), le serveur valide tout (type, bornes, distance, cooldown, argent) et répond.
2. **Logique pure dans `src/shared/Logic`** : fonctions déterministes, testables avec Lune. Le temps et l'aléatoire sont **injectés** (paramètre `now: number`, objet `rng` avec `:NextNumber()`), jamais lus directement.
3. Les modules de `Logic` ne `require` rien de Roblox. S'ils ont besoin de config, ils la reçoivent en paramètre ou requièrent `Config` par chemin relatif (`require("../Config/Economy")`).
4. **Aucune valeur d'équilibrage en dur** : tout dans `src/shared/Config`.
5. Animations et effets **côté client uniquement**, déclenchés par un Remote après validation serveur.
6. Remotes : un seul dossier `ReplicatedStorage.Remotes`, noms en PascalCase, rate-limit côté serveur sur chaque Remote.
7. Budget mobile : max 400 objets par planque (800 avec extension), particules légères, pas de boucle `while true` sans `task.wait`.

## Conformité Roblox
- Pas d'objets aléatoires payants (ni Robux, ni monnaie achetée avec des Robux) sans afficher les probabilités et vérifier `ArePaidRandomItemsRestricted`. Au lancement : les caisses ne s'achètent qu'avec l'argent gagné en jeu, qui ne s'achète pas en Robux.
- Pas de pari simulé. Pas d'échange argent du jeu ↔ Robux entre joueurs.
- Texte saisi par les joueurs (nom de marque, enseigne) → toujours filtré avec `TextService:FilterStringAsync`.

## Commandes
```bash
lune run tests/run            # tous les tests
lune run tests/run Ledger     # seulement les specs dont le nom contient "Ledger"
lune run tests/syntax         # compile tous les fichiers de src/ (erreurs de syntaxe)
rojo build -o build.rbxl      # vérifie que le projet Rojo se construit
# vérification des types --!strict (optionnel, nécessite luau-lsp + globalTypes.d.luau de luau-lsp) :
rojo sourcemap -o sourcemap.json && luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --ignore="src/server/Packages/**" src
# modèles 3D (Blender en module Python : pip install bpy==4.2.0 numpy, Python 3.11) :
python3 tools/meshgen/build.py            # régénère assets/BlackMarketMeshes.fbx + Config/MeshLibrary.luau
python3 tools/meshgen/build.py --render   # + aperçus Cycles dans assets/previews/ (~3 min)
lune run tools/dump_city                  # plan de la ville -> tools/meshgen/city_layout.json (requis par build.py)
python3 tools/meshgen/city_preview.py     # rendu de toute la ville -> docs/img/city_*.png (~3 min)
```
Avant de terminer une session : `tests/run` ET `tests/syntax` doivent passer.
Si Lune n'est pas installé : `cargo install lune --locked` (ou via Rokit/Aftman sur le PC).

## Écrire un test
```lua
local Ledger = require("../../src/shared/Logic/Ledger")
return function(t)
	t.test("deposit adds money", function()
		local l = Ledger.new(100)
		l:Deposit(50, "sale")
		t.eq(l:GetBalance(), 150)
	end)
end
```
Assertions disponibles : `t.eq`, `t.near`, `t.truthy`, `t.falsy`, `t.throws`.

## Méthode de travail (pour économiser les crédits)
- Une session = une étape de `docs/ROADMAP.md`. Ne pas déborder.
- D'abord la logique pure + tests, ensuite le service serveur, ensuite le client.
- Lancer les tests avant de dire "fini". Ne jamais laisser un test rouge.
- Tu ne vois pas le rendu : pour le visuel, expose des paramètres (durée, taille, couleur) plutôt que d'itérer sur le "beau". Les auteurs règlent dans Studio.
- Mettre à jour la section "État" ci-dessous à la fin de chaque session.

## État
- Phase 0 terminée : Config (Economy, Parts), Logic (Ledger, WeaponCrafting, Heat, Customer, ComboTracker, Grid, DayNight), 46 tests Lune verts.
- Bootstrap : `src/server/init.server.luau` démarre chaque module de `Services/` (méthode `:Start()`), idem côté client avec `Controllers/`.
- `WorldService` fait tourner le cycle jour/nuit (Lighting.ClockTime + attributs `Phase` / `PhaseSecondsLeft` sur ReplicatedStorage). `PhaseHudController` affiche JOUR/NUIT.
- 1.1 terminée : `Logic/ProfileSchema` (template, migrations versionnées, nettoyage anti-triche, 17 tests), `Config/Data` (nom du store, mock Studio), limites de profil dans `Economy.Profile`. `Ledger:SetChangedCallback` écrit l'argent dans le profil.
- `DataService` : charge le profil à la connexion (ProfileStore, session verrouillée), kick si échec ou profil d'une version future, publie les attributs `Money` / `Level` sur le Player. API : `GetLedger(player)`, `GetData(player)`, `IsLoaded(player)`, signal `PlayerLoaded`. Studio seulement : attribut `DebugGrant` pour ajouter de l'argent. `MoneyHudController` affiche l'argent.
- Pour changer la forme du profil : incrémenter `ProfileSchema.VERSION` + ajouter une migration (voir l'en-tête du module).
- Guide d'installation pour les auteurs : `docs/SETUP_STUDIO.md`.
- Phase 1 (1.2 → 1.6) écrite d'un coup à la demande des auteurs, **pas encore validée dans Studio** :
  - `CityService` génère la rue (Config/World : 8 terrains, bâtiments, néons, lampadaires). Si `workspace.City` existe déjà, rien n'est généré.
  - `PlotService` attribue un terrain (panneau "<Name>'s Shop"), `BuildService` (placer/déplacer/vendre, validé par `Logic/Hideout`), `CraftService` (établi, fournisseur, prix), `CustomerService` (PNJ, file, patience), `SaleService` (vente, contre-offre, combo, pourboire).
  - Client : `BuildController` (touche B, caméra aérienne, fantôme vert/rouge), `WorkbenchController`, `SellController`, `FxController` (animations), `MoneyHudController` (argent + niveau).
  - Profil v2 : planque de départ, prix des armes, stats. 20 objets dans `Config/Buildables` (modèles en pièces simples, remplaçables par `ReplicatedStorage.Assets.Buildables.<id>`).
- Réglages à faire dans Studio : valeurs dans `Effects.Settings`, `UI.Theme`, `Config/World`, `Config/Visual` (sons à remplacer).
- Animations : `Config/Animations` (R15 Roblox pour marche/idle/emotes, poses procédurales jouées par `PoseController` sur tous les clients, slots `Custom` pour des animations publiées). `server/Lib/AnimServer` (NPC, emotes, arme dans la main). Scène du deal : poignée de main → le dealer compte les billets → le client inspecte l'arme et part avec.
- Ambiance : pluie (attribut `Raining` décidé par WorldService), sol mouillé, fumée, bidons en feu, bennes, sacs, flaques, néons qui clignotent (`AmbienceController`), sons à renseigner dans `Config/World.Sounds`.
- Modèles 3D : `tools/meshgen` (Blender bpy) génère `assets/BlackMarketMeshes.fbx`, importé une fois dans Studio sous `ReplicatedStorage.Assets.BlackMarketMeshes` (docs/SETUP_STUDIO.md §9). `ModelFactory` les utilise s'ils sont présents (repère `__origin__` pour position et échelle), sinon garde les blocs. Chaque mesh s'appelle `<id>__<matériau>`, les matériaux Roblox sont dans `Config/MeshLibrary` (généré).
- **Phase M (map)** : `Config/City` + `Logic/CityLayout` (plan pur et testé : 9 quartiers, avenues, 338 bâtiments, 18 trap houses, mobilier, War Zone, POI) + `Logic/CityParts` (pièces exactes : structure de la trap house, sous-sol, escalier, clôtures, bunkers...) + `server/Lib/MapBuilder` (instancie tout, meshes de la bibliothèque, lumières, streaming). À lancer une fois dans Studio (docs/SETUP_STUDIO.md §10) ; sinon CityService la construit au démarrage.
- Trap house : origine du terrain = centre du sol du sous-sol (48×48 constructible, plafond à 14, `PlotMaxHeight` 13), cage d'escalier en +X, porte d'entrée au-dessus. Chaque Plot_N contient `Anchor` (Floor, streaming persistant), `House`, `Sign`, `Waypoints` (Door → StairsTop → StairsBottom, suivis par les clients), `Objects`. Profil v3 (comptoir de départ déplacé).
- MapBuilder accepte des prefabs (`ReplicatedStorage.Assets.Buildings.<archetype>`, `Assets.Props.<kind>`, Model ou Folder de variantes, entrée vers +Z, mis à l'échelle de l'emplacement) et applique automatiquement les `MaterialVariant` de MaterialService par matière de base. Piste de réalisme retenue : kit officiel Roblox « Modular Building Kit - Modern City » + « Modern City Materials Pack » (docs/SETUP_STUDIO.md §12). Les domaines roblox.com sont bloqués depuis le cloud : les auteurs envoient les kits en `.rbxm` (lisibles avec Lune `@lune/roblox`).
- Aperçu 3D de la ville : `lune run tools/dump_city && python3 tools/meshgen/city_preview.py` → `docs/img/city_*.png`.
- Textures PBR : `tools/meshgen/textures.py` génère 12 textures tuilables (numpy, `assets/textures/`), embarquées dans le FBX sur des carrés `__swatch__<nom>` ; `MapBuilder` en fait des MaterialVariant `BM_<nom>` (MaterialService) et les pose via le champ `texture` des PartSpec (`Config/City.Archetypes[*].texture`, `CityParts.SlabLooks`, pièces de la trap house). `Config/MeshLibrary.Textures` = matériau de base + studs par tuile. Marquage au sol (lignes jaunes, pointillés, passages piétons) dans `CityLayout` (slabs `paint`). Mobilier « ville vivante » : poteaux électriques + câbles (`layout.wires`, Beams qui pendent) dans les Blocks, feux tricolores aux carrefours (tag `TrafficSignal`, attributs `Color`/`Axis`, prêts à être animés), panneaux publicitaires sur les toits (`City.BillboardAds`, SurfaceGui via `CityParts.PropExtras`).
- Éclairage : au lancement, `CityService` met de côté le Sky, les Atmosphere et les PostEffect du place qui ne s'appellent pas `BM_*` (ils se cumulaient et teintaient la ville en rouge) et installe `BM_Sky`. Fenêtres allumées la nuit : `World.Lighting.NightWindowColor` (sombre, sinon les façades brillent).
- Pièges Studio corrigés : un `Highlight` sans `Adornee` surligne son parent (le survol du mode construction teintait tout le Workspace en rouge → `setHover` l'active seulement avec une cible) ; `LevelOfDetail = StreamingMesh` déforme les façades (désactivé, `City.Streaming.BuildingLod`) ; les MaterialVariant ne vont que sur des `Part` (les meshes de la bibliothèque n'ont pas d'UV), jamais les `BM_*` en automatique.
- Placement des meshes : `build.py` écrit la boîte englobante de chaque mesh (`MeshLibrary.Parts`, centre relatif à l'origine du modèle + taille, en studs) et met le pivot de chaque objet FBX au centre de sa boîte ; `ModelFactory` place les meshes avec ces données au lieu de se fier à l'import Studio (log : `N repositioned, K reshaped`). Test `MeshLibrary.spec`.
- Studio : `require` dans la Command Bar garde les modules en cache → après une mise à jour, redémarrer Studio avant `MapBuilder.Build()` ; `MapBuilder.VERSION` est affiché à chaque build (le changer quand MapBuilder/ModelFactory changent).
- Ambiance « vie dure » (`Config/Mood`) : `MoodController` (étalonnage sombre jour/nuit, vignette, grain optionnel, effets de blessure), `MovementController` + `Logic/Stamina` (sprint Shift / bouton RUN, épuisement, saut qui coûte, caméra vivante), `BodyController` + `BodyService` (penché en courant, tête qui suit le regard via le remote `LookAt`, `ServerNet.OnEvent` pour les events client → serveur). Clients qui attendent : animations `LookAround`, `CheckPhone`, `ArmsCrossed`, `ShiftWeight` (`Animations.Npc`).
- Intérieurs : chaque archétype a `door` + `interior` (`Config/City`), `CityParts.BuildingShell` (rez-de-chaussée creux) + `CityParts.Interior` (mobilier par type : store, restaurant, lobby, office, warehouse, mansion, squat ; testé : dans les murs, sous le plafond, entrée dégagée). Les battants de porte des façades sont des meshes `door_*` supprimés par MapBuilder et remplacés par des portes `AutoDoor` ouvertes par `DoorController` (client). Nécessite de réimporter le FBX.
- Rétention (`docs/GAME_DESIGN.md` §23) : profil v4 (`Daily`, `Contracts`), `Logic/DailyReward`, `Logic/Contracts`, `GoalsService` (`GoalsService.Record(player, event, amount)` appelé par SaleService / CraftService, remote `RequestClaimDaily`, event `GoalsSync`), `GoalsController` (panneau contrats + carte de série).
- Prochaine étape : valider la ville dans Studio, puis refonte de l'UI style Criminality (téléphone de dealer), puis M.3/M.4 (logique des points d'intérêt et de la War Zone), puis recrutement.
