# Roadmap — Black Market

Chaque étape = **une session Claude courte et ciblée**. Le prompt à copier est donné.
Règle : on ne passe à l'étape suivante que quand les tests sont verts ET que ça marche dans Studio.
Commit après chaque étape.

Légende coût : 🟢 petit · 🟡 moyen · 🔴 gros (mérite Opus)

---

## Phase 0 — Socle ✅ (fait)
- Structure Rojo, config de l'économie, modules `Ledger`, `WeaponCrafting`, `Heat`, `Customer`, `ComboTracker`, `Grid`, tests Lune.

## Phase 1 — Jouable minimal (la planque qui vend)

**1.1 🟡 Profils et sauvegarde** ✅
> Lis CLAUDE.md. Ajoute ProfileStore dans `src/server/Packages`, crée `src/server/Services/DataService.luau` qui charge/sauvegarde le profil (argent, inventaire de pièces, armes, niveau, planque sérialisée). Branche `Ledger` dessus. Tests Lune pour le schéma et la migration de version du profil.

**1.2 🔴 Construction libre (serveur)** ✅ (à valider dans Studio)
> Lis CLAUDE.md et GAME_DESIGN §5. Crée `src/shared/Config/Buildables.luau` (20 objets de départ) et `src/server/Services/BuildService.luau` : placer, déplacer, pivoter, supprimer, avec validation serveur via `Logic/Grid` (limites du terrain, collisions, limite d'objets, argent). Sérialisation compacte de la planque. Tests Lune pour la sérialisation.

**1.3 🟡 Construction libre (client)** ✅ (à valider dans Studio)
> Crée `src/client/Controllers/BuildController.luau` : mode construction, caméra aérienne, fantôme vert/rouge, rotation, raccourcis PC + boutons mobile. Le client envoie seulement des intentions au serveur.

**1.4 🟡 Établi** ✅ (à valider dans Studio)
> Branche `Logic/WeaponCrafting` : `CraftService` serveur + UI de l'établi (5 emplacements). Animation de fabrication côté client via `Effects`.

**1.5 🔴 Clients PNJ et vente** ✅ (à valider dans Studio)
> `CustomerService` : spawn des PNJ, file d'attente, pathfinding jusqu'au comptoir, décision d'achat via `Logic/Customer`, patience. `SaleService` valide la vente avec `Ledger` + `ComboTracker`. Remote vers le client pour jouer l'animation de deal.

**1.6 🟢 Module d'effets** ✅ (à valider dans Studio)
> `src/client/Effects.luau` : pop, rebond, billets qui volent vers le compteur, secousse caméra, texte flottant. Tous les réglages en paramètres. (Ensuite, régler les valeurs à la main dans Studio.)

👉 **Fin de phase 1 : premier test avec des potes.**

## Phase 2 — La vibe criminelle
- 2.1 🟡 Cycle jour/nuit (`Logic/DayNight`) + éclairage, pluie, néons.
- 2.2 🔴 Chaleur et descentes (`Logic/Heat` déjà prêt) : `RaidService`, compte à rebours, fouille, objets secrets.
- 2.3 🟡 Marché noir de nuit avec prix dynamiques (`Logic/Market`).
- 2.4 🟢 Musique et ambiance sonore par zone.

## Phase 3 — La guerre
- 3.1 🔴 Système d'armes (partir d'un kit FPS open source, l'adapter aux stats de `WeaponCrafting`).
- 3.2 🟡 Zone de guerre, camps, points de contrôle, manches.
- 3.3 🟡 Boutique joueur (ViewportFrame), stand de tir d'essai.
- 3.4 🟢 Kill feed avec marque + commissions.
- 3.5 🟡 Réputation par camp, krach de fin de manche.

## Phase 4 — Approvisionnement
- 4.1 🟡 Fournisseur légal + stock.
- 4.2 🔴 Missions de contrebande en camionnette + checkpoints.
- 4.3 🟡 Caisses de récupération, convois.

## Phase 5 — Social
- 5.1 🔴 Rôle Inspecteur joueur.
- 5.2 🟡 Crews + planque partagée.
- 5.3 🔴 Territoires et classement hebdo.
- 5.4 🟡 Événements serveur (enchère, embargo, offensive, VIP).

## Phase 6 — Rétention et lancement
- Progression, prestige, codex, saisons, classements, gamepasses, tutoriel guidé, optimisation mobile, miniature et icône.

---

## Répartition conseillée entre associés
- **Associé A (code)** : pilote les sessions Claude, relit, teste, commit.
- **Associé B (visuel)** : map de la ville, modèles des objets et des pièces d'armes, animations de personnages (Animation Editor / Moon Animator), réglage des effets dans Studio, UI.
