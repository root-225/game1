# Crédits & licences des assets

Tous les assets tiers sont sous licences libres permettant l'usage commercial.
Les fichiers de licence d'origine sont copiés à côté des assets.

| Asset | Auteur | Source | Licence | Utilisation dans le jeu |
|---|---|---|---|---|
| **Mannequiny 0.3.0** (godot-3d-mannequin) | GDQuest and contributors (gdquest.com) | github.com/GDQuest/godot-3d-mannequin | **CC-BY 4.0** — attribution obligatoire | Corps humanoïde et squelette des 4 coureurs. **Modifié** : habillé (couleurs par sommet, cheveux, visage, casquette, kufi, bandeau, lunettes), animations d'origine remplacées |
| **KayKit Adventurers Character Pack 1.0** | Kay Lousberg | github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 | CC0 1.0 | Animations (course, saut, idle, choc, chute, célébration) **retargetées** sur Mannequiny |
| **KayKit City Builder Bits 1.0** | Kay Lousberg | github.com/KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0 | CC0 1.0 | Immeubles de rue, taxi (recoloré orange), berline wôrô-wôrô (recolorée verte), benne, lampadaires, feux, bancs, bouches d'incendie, poubelles |
| **Kenney Starter Kit 3D Platformer** | Kenney | github.com/KenneyNL/Starter-Kit-3D-Platformer | CC0 1.0 (modèles, sons) | Pièce, nuages, sons (pièce, saut, atterrissage, casse) |
| **Kenney Starter Kit City Builder** | Kenney | github.com/KenneyNL/Starter-Kit-City-Builder | CC0 1.0 (modèles, sons) | Ambiance sonore de ville |
| **Lilita One** (police) | Juan Montoreano | via les Starter Kits Kenney / Google Fonts | SIL Open Font License 1.1 | Toute l'interface |

Emplacements :

- `assets/thirdparty/gdquest/runner_*.glb` (+ `LICENSE.txt`) — coureurs générés par `tools/build_runners.sh`
  (sources dans `tools/source_models/`, non exportées)
- `assets/thirdparty/kaykit/city/` (+ `LICENSE.txt`)
- `assets/thirdparty/kenney/` (+ `LICENSE.txt`)
- `assets/audio/kenney/`
- `assets/fonts/LilitaOne-Regular.ttf` (+ `OFL-LilitaOne.txt`)

L'attribution CC-BY de Mannequiny est aussi affichée dans le jeu (écran Boutique).

Merci à **GDQuest**, **Kay Lousberg** (kaylousberg.com) et **Kenney** (kenney.nl) pour leurs assets
libres — le crédit n'est pas obligatoire pour du CC0, mais il est mérité.

## Assets originaux du projet

Générés par les scripts de `tools/` (code du projet) : route à bordures rouge/blanc,
tours vitrées du Plateau, palmiers, kiosques, garde-corps du pont de la lagune,
9 obstacles (dont stand de nourriture à parasol et pousse-pousse de bananes plantain),
collectibles (coco, alloco, akpakpa, smartphone), power-ups, textures (asphalte,
pavés, latérite), icônes UI, SFX de roulade/choc/power-up/clic et boucle musicale,
animation de glissade (slide) des coureurs, shader de contour (outline) et d'eau.
