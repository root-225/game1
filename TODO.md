# ABIDJAN RUNNER — état : ✅ TERMINÉ

## Assets (pipeline pur-Python glTF, sans Blender GUI) — ✅
- [x] gltf_builder.py — writer glTF/glb (meshes, matériaux, skin, animations)
- [x] gen_characters.py — 4 skins riggés + animés (run/jump/roll/hit/idle, 11 os)
- [x] gen_env.py — bâtiments, kiosque, taxi wôrô-wôrô, pont, palmiers, route, sol
- [x] gen_items.py — 9 obstacles, 5 collectibles, 3 power-ups
- [x] gen_textures.py — icône appli + 13 icônes UI
- [x] gen_audio.py — 7 SFX + boucle musicale
- [x] 30 .glb (528K) validés (accessors, skins, anims) + importés dans Godot

## Projet Godot — ✅
- [x] project.godot (autoloads, input map clavier, GL Compatibility mobile)
- [x] global.gd (sauvegarde JSON, pièces, record, skins, missions quotidiennes)
- [x] audio.gd (SFX + musique bouclée)
- [x] data.gd, player.gd, game.gd, chunk_manager.gd, spawnable.gd, main.gd, ui.gd
- [x] Génération procédurale infinie + pooling (0 lag)
- [x] UI complète : menu, HUD tactile, pause, game over, boutique
- [x] Smoke test headless : joueur court, chunks streament, 56 pickups, anim run ✅

## Livrables — ✅
- [x] Export Windows (.exe autonome, PCK embarqué)
- [x] Export Linux (.x86_64 autonome)
- [x] APK Android signée (apksigner v1+v2+v3 ✅, installable)
- [x] export_presets.cfg + tools/build.sh
- [x] README.md complet
- [x] Commits + push branche claude/eloquent-ramanujan-7i3pbf

## v2 — Assets téléchargés & embellissement — ✅
- [x] Personnages KayKit (CC0) riggés, 12 animations, recolorés en 4 tenues ivoiriennes
- [x] Rue KayKit (CC0) : immeubles, taxi orange, wôrô-wôrô vert, benne, lampadaires, mobilier
- [x] Kenney (CC0) : pièce, nuages, sons ; police Lilita One (OFL)
- [x] Route texturée (asphalte, pavés), bordures rouge/blanc, palmiers, tours du Plateau
- [x] Biome lagune : pont, garde-corps, eau animée (shader), skyline du Plateau
- [x] Particules (poussière, atterrissage, étincelles), bulle de bouclier, halos power-ups
- [x] Éclairage/brouillard corrigés (scène n'est plus délavée), couleurs glTF en linéaire
- [x] UI refaite (menu transparent sur la scène 3D, boutique avec aperçu 3D + portraits)
- [x] Bugs corrigés : HUD power-ups figé, monitorable modifié pendant un signal
- [x] Perf : 606 → ~270 draw calls, pools pré-remplis, test de 2 min sans fuite
- [x] CREDITS.md + captures dans docs/

## v3 — Retours joueur — ✅
- [x] Image trop claire : Filmic + contraste/saturation, ambiante réduite et moins bleue, ciel plus profond, brouillard plus loin, pas de glow
- [x] Obstacles plus visibles : contours toon, ombres de contact, +10 à 30 % de taille
- [x] Coureur trop gros : humanoïde 1,66 m (Mannequiny CC-BY) au lieu du chibi, caméra plus haute/reculée
- [x] Nouvelle glissade (slide) créée à la main, animations KayKit retargetées
- [x] Qualité : MSAA 4x, anisotrope, ombres 2 cascades haute résolution

## v4 — Personnages Quaternius en tenues africaines — ✅
- [x] Universal Base Characters (CC0, fournis par l'utilisateur) : 2 garçons + 2 filles
- [x] Tenues : chemise wax + jean, grand boubou bazin brodé + kufi, maillot Éléphants, robe pagne + gele
- [x] Coiffes moulées sur le crâne, cheveux, chignon ; peau foncée ; mains en poing
- [x] Animations KayKit retargetées + glissade
