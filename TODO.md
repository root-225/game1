# ABIDJAN RUNNER — TODO / progress

## Assets (pure-Python glTF generator, no Blender GUI needed)
- [ ] gltf_builder.py — reusable glTF/glb writer (meshes, vertex materials, skin, animations)
- [ ] gen_characters.py — 3 rigged+animated skins (run/jump/roll/hit/idle)
- [ ] gen_env.py — buildings, kiosk, taxi, bridge, palm, road, ground
- [ ] gen_obstacles.py — 8 obstacles
- [ ] gen_collectibles.py — coins + 4 items + powerups
- [ ] gen_textures.py — road/sky/ui icons (PIL)
- [ ] gen_audio.py — sfx + music loop (numpy wav)

## Godot project
- [ ] project.godot, input map, autoloads
- [ ] Global.gd (save/load, coins, best, skins, daily missions)
- [ ] Player.gd (3 lanes, jump, roll, swipe+keys, anims)
- [ ] Game.gd (loop, speed ramp, score, states)
- [ ] ChunkManager.gd + Chunk.gd (procedural infinite + pooling)
- [ ] ObjectPool.gd, Obstacle.gd, Collectible.gd, PowerUp.gd
- [ ] UI: MainMenu, HUD, Pause, GameOver, Shop
- [ ] Scenes wired

## Ship
- [ ] godot --headless --import (0 errors)
- [ ] export_presets.cfg (Windows + Android)
- [ ] README.md
- [ ] git commits + push
