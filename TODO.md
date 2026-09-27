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
