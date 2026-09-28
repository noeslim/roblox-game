# Assets gratuits : tous les liens

Tout est en **CC0** (gratuit, usage commercial, redistribution libre) sauf mention contraire. Détails, licences et
sources à éviter : `reports/Assets gratuits ville criminelle.md`.

## Le plus simple : le script

Dans PowerShell (pas cmd), à la racine du dépôt :

```powershell
powershell -ExecutionPolicy Bypass -File tools\download_assets.ps1
git add assets/incoming
git commit -m "Add CC0 assets"
git push
```

Il télécharge les parties 1 à 3 ci-dessous dans `assets/incoming/` au bon format (JPG 1K, 2K pour l'asphalte et la
brique principale, normal maps OpenGL, glTF 1K pour les modèles) avec un `SOURCE.txt` par asset. Relançable : ce qui
est déjà là est sauté. À la fin il liste ce qui a échoué (identifiant inconnu, site indisponible) avec le lien, à
prendre à la main ou à ignorer. Les parties 4 à 6 sont à la main.

Si tu télécharges à la main sur Poly Haven : format **JPG**, cartes **Diffuse**, **Normal (GL)**, **Rough** (+ **Metal**
pour les métaux), jamais `nor_dx` ni `arm`. Modèles : **glTF**, 1K.

## 1. Textures photo (Poly Haven) → `assets/incoming/polyhaven_textures/<id>/`

- [asphalt_02](https://polyhaven.com/a/asphalt_02) (2K)
- [asphalt_01](https://polyhaven.com/a/asphalt_01)
- [asphalt_03](https://polyhaven.com/a/asphalt_03)
- [brick_wall_02](https://polyhaven.com/a/brick_wall_02) (2K)
- [brick_wall_001](https://polyhaven.com/a/brick_wall_001)
- [red_brick_03](https://polyhaven.com/a/red_brick_03)
- [brick_wall_09](https://polyhaven.com/a/brick_wall_09)
- [painted_brick](https://polyhaven.com/a/painted_brick)
- [painted_worn_brick](https://polyhaven.com/a/painted_worn_brick)
- [concrete_wall_007](https://polyhaven.com/a/concrete_wall_007)
- [concrete_wall_005](https://polyhaven.com/a/concrete_wall_005)
- [concrete_brick_wall_001](https://polyhaven.com/a/concrete_brick_wall_001)
- [damaged_plaster](https://polyhaven.com/a/damaged_plaster)
- [worn_plaster_wall](https://polyhaven.com/a/worn_plaster_wall)
- [rough_plaster_broken](https://polyhaven.com/a/rough_plaster_broken)
- [checkered_pavement_tiles](https://polyhaven.com/a/checkered_pavement_tiles)
- [concrete_pavement_02](https://polyhaven.com/a/concrete_pavement_02)
- [cobblestone_05](https://polyhaven.com/a/cobblestone_05)
- [cobblestone_pavement](https://polyhaven.com/a/cobblestone_pavement)
- [rusty_corrugated_iron](https://polyhaven.com/a/rusty_corrugated_iron)
- [corrugated_iron](https://polyhaven.com/a/corrugated_iron)
- [rusty_painted_metal](https://polyhaven.com/a/rusty_painted_metal)
- [rusty_metal_04](https://polyhaven.com/a/rusty_metal_04)
- [rusty_metal_sheet](https://polyhaven.com/a/rusty_metal_sheet)
- [old_wood_floor](https://polyhaven.com/a/old_wood_floor)
- [wood_floor_worn](https://polyhaven.com/a/wood_floor_worn)
- [plywood](https://polyhaven.com/a/plywood)
- [tarred_gravel](https://polyhaven.com/a/tarred_gravel)
- [roof_07](https://polyhaven.com/a/roof_07)
- [rusty_metal_shutter](https://polyhaven.com/a/rusty_metal_shutter)
- [metal_grate_rusty](https://polyhaven.com/a/metal_grate_rusty)
- [dirty_tiles](https://polyhaven.com/a/dirty_tiles)
- [worn_tile_floor](https://polyhaven.com/a/worn_tile_floor)
- [broken_brick_wall](https://polyhaven.com/a/broken_brick_wall)

## 2. Décalques et matériaux (ambientCG) → `assets/incoming/ambientcg/<ID>/`

Zip **1K-JPG** (ou 1K-PNG pour les décalques avec transparence).

- [GraffitiSet001](https://ambientcg.com/view?id=GraffitiSet001)
- [AsphaltDamageSet001](https://ambientcg.com/view?id=AsphaltDamageSet001)
- [RoadLines006](https://ambientcg.com/view?id=RoadLines006)
- [Leaking005](https://ambientcg.com/view?id=Leaking005)
- [Fence006](https://ambientcg.com/view?id=Fence006)
- [PaintedMetal006](https://ambientcg.com/view?id=PaintedMetal006)
- [Sticker001](https://ambientcg.com/view?id=Sticker001)
- [Asphalt025C](https://ambientcg.com/view?id=Asphalt025C) (asphalte mouillé ? à vérifier)
- [Asphalt024C](https://ambientcg.com/view?id=Asphalt024C) (asphalte mouillé ? à vérifier)

## 3. Modèles Poly Haven (glTF 1K)

Rue, façades, épaves, docks → `assets/incoming/polyhaven_hidden_alley/<id>/` :

- [modular_fire_escape](https://polyhaven.com/a/modular_fire_escape)
- [exterior_aircon_unit](https://polyhaven.com/a/exterior_aircon_unit)
- [modular_metal_gutter](https://polyhaven.com/a/modular_metal_gutter)
- [rollershutter_door](https://polyhaven.com/a/rollershutter_door)
- [rollershutter_window_01](https://polyhaven.com/a/rollershutter_window_01)
- [rollershutter_window_02](https://polyhaven.com/a/rollershutter_window_02)
- [rollershutter_window_03](https://polyhaven.com/a/rollershutter_window_03)
- [security_camera_01](https://polyhaven.com/a/security_camera_01)
- [security_light](https://polyhaven.com/a/security_light)
- [metal_trash_can](https://polyhaven.com/a/metal_trash_can)
- [utility_box_01](https://polyhaven.com/a/utility_box_01)
- [utility_box_02](https://polyhaven.com/a/utility_box_02)
- [water_manhole_cover](https://polyhaven.com/a/water_manhole_cover)
- [fire_hydrant](https://polyhaven.com/a/fire_hydrant)
- [modular_chainlink_fence](https://polyhaven.com/a/modular_chainlink_fence)
- [large_iron_gate](https://polyhaven.com/a/large_iron_gate)
- [street_lamp_02](https://polyhaven.com/a/street_lamp_02)
- [barrel_stove](https://polyhaven.com/a/barrel_stove)
- [Barrel_01](https://polyhaven.com/a/Barrel_01)
- [Barrel_02](https://polyhaven.com/a/Barrel_02)
- [barrel_03](https://polyhaven.com/a/barrel_03)
- [cardboard_box_01](https://polyhaven.com/a/cardboard_box_01)
- [wooden_crate_01](https://polyhaven.com/a/wooden_crate_01)
- [wooden_crate_02](https://polyhaven.com/a/wooden_crate_02)
- [covered_car](https://polyhaven.com/a/covered_car)
- [old_tyre](https://polyhaven.com/a/old_tyre)
- [rusted_wheel_rim_01](https://polyhaven.com/a/rusted_wheel_rim_01)
- [rusted_wheel_rim_02](https://polyhaven.com/a/rusted_wheel_rim_02)
- [concrete_road_barrier_02](https://polyhaven.com/a/concrete_road_barrier_02)
- [modular_wooden_pier](https://polyhaven.com/a/modular_wooden_pier)
- [lateral_sea_marker](https://polyhaven.com/a/lateral_sea_marker)

Planque et établi → `assets/incoming/polyhaven_shed/<id>/` :

- [Sofa_01](https://polyhaven.com/a/Sofa_01)
- [sofa_02](https://polyhaven.com/a/sofa_02)
- [ArmChair_01](https://polyhaven.com/a/ArmChair_01)
- [plastic_monobloc_chair_01](https://polyhaven.com/a/plastic_monobloc_chair_01)
- [steel_frame_shelves_01](https://polyhaven.com/a/steel_frame_shelves_01)
- [steel_frame_shelves_02](https://polyhaven.com/a/steel_frame_shelves_02)
- [wooden_bookshelf_worn](https://polyhaven.com/a/wooden_bookshelf_worn)
- [Television_01](https://polyhaven.com/a/Television_01)
- [CashRegister_01](https://polyhaven.com/a/CashRegister_01)
- [pull_chain_light_socket](https://polyhaven.com/a/pull_chain_light_socket)
- [lightbulb_01](https://polyhaven.com/a/lightbulb_01)
- [caged_hanging_light](https://polyhaven.com/a/caged_hanging_light)
- [mounted_fluorescent_lights](https://polyhaven.com/a/mounted_fluorescent_lights)
- [portable_generator](https://polyhaven.com/a/portable_generator)
- [propane_tank](https://polyhaven.com/a/propane_tank)
- [bench_vice_01](https://polyhaven.com/a/bench_vice_01)
- [metal_tool_chest](https://polyhaven.com/a/metal_tool_chest)
- [crowbar_01](https://polyhaven.com/a/crowbar_01)
- [pipe_wrench](https://polyhaven.com/a/pipe_wrench)
- [ratchet_wrench](https://polyhaven.com/a/ratchet_wrench)
- [Drill_01](https://polyhaven.com/a/Drill_01)
- [bolt_cutters_01](https://polyhaven.com/a/bolt_cutters_01)
- [spray_paint_bottles](https://polyhaven.com/a/spray_paint_bottles)

Pour fouiller : [tous les modèles Poly Haven](https://polyhaven.com/models) (collections « Hidden Alley » et « The Shed »).

## 4. Mobilier urbain américain (itch.io, CC0, à la main)

- [City Environment Pack](https://3dmodelscc0.itch.io/city-environment-pack) → `assets/incoming/3dmodelscc0_city1/` (GLB)
- [City Environment Pack #2](https://3dmodelscc0.itch.io/free-cc0-city-environment-pack-2) → `assets/incoming/3dmodelscc0_city2/` (GLB)
- [Container (OpenGameArt, CC0)](https://opengameart.org/content/container-0) → `assets/incoming/oga_container/`
- [Collection 3D CC0 d'OpenGameArt](https://opengameart.org/content/3d-assets-cc0) : Simple Sandbags, Concrete Barrier PBR (War Zone)

## 5. Sketchfab (à la main, compte gratuit)

Vérifie la licence sur chaque page : **CC0** ou **CC Attribution** seulement (jamais NC, ND, Editorial ni « Standard »).
Format glTF, dossier `assets/incoming/sketchfab_<auteur>_<modele>/`, et note l'auteur (crédit obligatoire en CC-BY).

- [Abandoned factory (Pasha)](https://sketchfab.com/3d-models/abandoned-factory-c08537c06acd46bba24ad8251bcdf941)
- [Abandoned town (Pasha)](https://sketchfab.com/3d-models/abandoned-town-game-ready-1fa127527711428a8fc95c4b85428217)
- [Abandoned house (Pasha)](https://sketchfab.com/3d-models/abandoned-house-game-ready-7570dba83d68486abcd8dee6e8564173)
- [City Props Collection vol. 2 (TampaJoey)](https://sketchfab.com/3d-models/city-props-collection-volume-2-2f52ea53c58e455f9b69d11f58763c96)
- [Modular Urban Fence Pack avec graffitis (TampaJoey)](https://sketchfab.com/3d-models/modular-urban-fence-pack-w-graffiti-textures-1cf3690327bd449881ba6857d8fe7caf)
- [HD Shipping Container (OCTbuilds)](https://sketchfab.com/3d-models/hd-shipping-container-game-ready-7009265c015e4694817b35a14a89ec8c)
- [Shipping containers (SpatialNeglect)](https://sketchfab.com/3d-models/shipping-containers-cc3f7136710f4905905eae1d10ac50b7)
- Voitures réalistes : [recherche Sketchfab](https://sketchfab.com/search?features=downloadable&q=car&type=models) (coche la licence CC0 ou CC Attribution dans les filtres ; éviter les voitures avec logo de marque)

## 6. Kits officiels Roblox (dans Studio, Toolbox, pas sur GitHub)

- [Modern City Materials Pack](https://create.roblox.com/store/asset/13168345645) (asset 13168345645)
- [Modular Building Kit – Modern City](https://create.roblox.com/store/asset/13168370735) (asset 13168370735)
- [City People Cars – SLIM Template](https://www.roblox.com/games/135885449743134) (voitures réalistes)
- [The Mystery of Duvall Drive](https://www.roblox.com/games/7902470429) (intérieurs délabrés)

Les `.rbxm` exportés ne vont **pas** dans `assets/incoming/` (licence Roblox limitée) : envoie-les dans le chat.
Évite le modèle « Map for criminality » du Creator Store (copie d'une carte existante).
