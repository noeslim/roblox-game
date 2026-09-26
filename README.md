# Black Market — jeu Roblox

Jeu de dealer d'armes dans une ville criminelle de nuit : construis ta planque, fabrique tes armes à ta marque, vends aux deux camps, cache ta contrebande quand les inspecteurs débarquent.

- Design complet : [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md)
- Plan de développement + prompts de session : [`docs/ROADMAP.md`](docs/ROADMAP.md)
- Instructions pour Claude : [`CLAUDE.md`](CLAUDE.md)

## Installation sur ton PC (une seule fois)

👉 Guide détaillé pas à pas : [`docs/SETUP_STUDIO.md`](docs/SETUP_STUDIO.md)

1. Installe **Roblox Studio**.
2. Installe **Rokit** (gestionnaire d'outils Roblox) : https://github.com/rojo-rbx/rokit
3. Dans le dossier du projet : `rokit install` (installe Rojo et Lune aux bonnes versions).
4. Dans Studio : onglet Plugins → installe le plugin **Rojo** (ou `rojo plugin install`).
5. Recommandé : VS Code + extensions **Luau Language Server** et **Rojo**.

## Travailler

```bash
rojo serve                 # puis dans Studio : plugin Rojo -> Connect
lune run tests/run         # tests de la logique
lune run tests/syntax      # vérification de syntaxe
```

Premier test : `rojo serve`, connecte Studio, appuie sur Play. Tu dois voir en haut de l'écran "☀️ JOUR 9:59" qui défile, et le ciel qui change avec le cycle jour/nuit (10 min de jour, 6 min de nuit ; réglable dans `src/shared/Config/Economy.luau`).

## Coder avec Claude en cloud

1. Mets ce dossier dans un repo GitHub (privé).
2. Ouvre une session Claude sur ce repo.
3. Copie le prompt de l'étape suivante depuis `docs/ROADMAP.md`.
4. Récupère (`git pull`) sur ton PC, `rojo serve`, teste dans Studio.
