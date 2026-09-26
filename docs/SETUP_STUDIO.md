# Installer le projet sur ton PC et le lancer dans Roblox Studio

À faire une seule fois (sauf l'étape 6, à refaire à chaque session de travail).
Le principe : **le code vit dans ce dépôt GitHub**. Rojo l'envoie en direct dans Studio.
Studio sert à tester et à construire la map, pas à écrire les scripts.

---

## 1. Les logiciels

| Logiciel | À quoi il sert | Où le trouver |
|---|---|---|
| **Roblox Studio** | Tester le jeu, construire la map | https://create.roblox.com |
| **GitHub Desktop** (ou Git) | Récupérer le code que Claude a poussé | https://desktop.github.com |
| **Rokit** | Installe Rojo et Lune aux bonnes versions | https://github.com/rojo-rbx/rokit/releases |
| **VS Code** (recommandé) | Lire et modifier le code | https://code.visualstudio.com |

**Installer Rokit (Windows)** : télécharge `rokit-…-windows-x86_64.zip` dans les *Releases*, dézippe-le,
double-clique sur `rokit.exe` (ou lance `.\rokit.exe self-install` dans PowerShell), puis **ferme et rouvre** le terminal.
Sur Mac/Linux : `curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`.

Dans VS Code, installe les extensions **Rojo** (evaera) et **Luau Language Server** (JohnnyMorganz).

## 2. Récupérer le code

Dans GitHub Desktop : *File → Clone repository → `noeslim/roblox-game`*, choisis un dossier.
Puis, en haut, *Current branch* → choisis la branche où Claude a travaillé
(ex. `claude/busy-franklin-57kc17`), ou `main` une fois la pull request fusionnée.

## 3. Installer Rojo et Lune

Ouvre un terminal **dans le dossier du projet** (dans VS Code : *Terminal → New Terminal*) :

```bash
rokit install        # réponds "oui" quand il demande de faire confiance aux outils
rojo --version       # doit afficher 7.7.0
lune --version       # doit afficher 0.10.5
lune run tests/run   # doit finir par "... passed, 0 failed"
```

## 4. Installer le plugin Rojo dans Studio

```bash
rojo plugin install
```

Redémarre Studio : un bouton **Rojo** apparaît dans l'onglet *Plugins*.

## 5. Créer le jeu dans Studio (une seule fois)

1. Studio → **New → Baseplate**. Tu peux aussi ouvrir ton `BlackMarket_phase0.rbxl`, ça marche pareil.
2. **File → Publish to Roblox** : crée une nouvelle expérience, nom « Black Market », en **privé**.
   *Sans publication, la sauvegarde (DataStore) ne marche pas.*
3. **Home → Game Settings → Security** : active **Enable Studio Access to API Services**, puis *Save*.
4. **View** : ouvre **Output** et **Command Bar** (on s'en sert pour tester).

## 6. Travailler (à chaque session)

1. Dans le terminal, dans le dossier du projet :
   ```bash
   rojo serve
   ```
   Laisse ce terminal ouvert.
2. Dans Studio : **Plugins → Rojo → Connect**. Les scripts apparaissent dans
   `ReplicatedStorage.Shared`, `ServerScriptService.Server` et `StarterPlayerScripts.Client`.
3. Appuie sur **Play** (F5).

⚠️ **Ne modifie pas les scripts dans Studio** : Rojo les écrase à la prochaine synchro. Modifie-les dans VS Code (ou laisse Claude le faire).
La map, les modèles et les décors que tu construis dans Workspace ne sont **pas** touchés par Rojo. Sauvegarde-les avec *File → Publish* ou *Save*.

## 7. Ce que tu dois voir (état actuel : étape 1.1)

- En haut au centre : **☀️ JOUR 9:59** qui défile (cycle jour/nuit).
- En haut à droite : **$ 500** (ton argent, chargé depuis ta sauvegarde).
- Dans **Output** :
  ```
  [ProfileStore]: Roblox API services available - data will be saved
  [Server] started 2 services: DataService, WorldService
  [DataService] loaded TonPseudo ($500, v1)
  ```

### Tester la sauvegarde

1. Pendant le Play, dans l'onglet **Test**, clique sur **Current: Client** pour passer en **Server**.
2. Dans la **Command Bar**, tape (remplace `TonPseudo`) :
   ```lua
   game.Players.TonPseudo:SetAttribute("DebugGrant", 250)
   ```
   Le compteur passe à **$ 750**. (Cette commande ne marche que dans Studio.)
3. **Stop**, puis **Play** à nouveau : tu dois retrouver **$ 750**. ✅ La sauvegarde marche.

## 8. Récupérer le travail de Claude

1. Claude pousse sur une branche `claude/...`. Sur GitHub, fusionne la pull request (ou reste sur la branche).
2. GitHub Desktop → **Fetch origin** → **Pull**.
3. Si `rojo serve` tourne déjà, Studio se met à jour tout seul. Sinon, refais l'étape 6.
4. Teste. Si ça marche, passe à l'étape suivante de `docs/ROADMAP.md`.

## Problèmes fréquents

| Symptôme | Solution |
|---|---|
| `rokit` / `rojo` : commande introuvable | Ferme et rouvre le terminal (ou redémarre le PC) après avoir installé Rokit. |
| Rojo : *Connect* ne fait rien | Vérifie que `rojo serve` tourne et que le port affiché est `34872`. |
| Output : `Roblox API services unavailable - data will not be saved` | Étape 5 : le jeu doit être publié ET l'accès aux API activé. |
| Tu es kick : « Impossible de charger tes données » | Coupure DataStore : relance Play. Si ça revient, copie la ligne `[DataService]` d'Output à Claude. |
| Le compteur reste sur `...` | Le profil ne s'est pas chargé : regarde les erreurs rouges dans Output. |
| Tu veux tester sans toucher aux vraies sauvegardes | Dans `src/shared/Config/Data.luau`, mets `UseMockInStudio = true`. |
