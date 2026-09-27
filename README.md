# 🏃🏾 ABIDJAN RUNNER

Un **endless runner 3D** inspiré d'Abidjan : cours dans le Plateau, esquive les taxis
*wôrô-wôrô*, saute les nids-de-poule, roule sous les banderoles et ramasse des pièces
CFA, de l'alloco, du coco et de l'akpakpa. Vitesse progressive, score, meilleur score
sauvegardé, missions quotidiennes et 4 skins à débloquer.

Moteur : **Godot 4.4** (GDScript, renderer GL Compatibility, optimisé mobile 60 FPS).
Tous les assets 3D/2D/audio sont **générés procéduralement** (aucune dépendance, aucun
placeholder manquant).

---

## 🎮 Gameplay

- **3 couloirs** (gauche / centre / droite)
- **Sauter** par-dessus les obstacles bas (barrière, nid-de-poule, pneu, cône, fût)
- **Rouler** sous les obstacles hauts (banderole / barre de toit)
- **Changer de voie** pour éviter les blocs (taxi garé, charrette, kiosque)
- **Power-ups** : 🧲 aimant à objets · 🛡️ bouclier (encaisse un choc) · ✖️2 multiplicateur
- **Collectibles** : pièces CFA (monnaie), coco, alloco, akpakpa, smartphone (bonus)
- **Vitesse** qui augmente avec la distance
- **Génération procédurale infinie** par chunks recyclés + **pooling** des obstacles (zéro
  instanciation en cours de partie → pas de lag)
- **Missions quotidiennes** (pièces / distance / parties) avec récompenses
- **Boutique** : 4 skins (Urbain, Traditionnel, Footballeur, Businessman)
- **Menu / Pause / Game Over**, UI tactile mobile + support clavier

### Contrôles

| Action        | Clavier                | Tactile                    |
|---------------|------------------------|----------------------------|
| Gauche/Droite | ← → ou A / D           | Swipe horizontal / boutons |
| Sauter        | ↑ / W / Espace         | Swipe haut / bouton        |
| Rouler        | ↓ / S                  | Swipe bas / bouton         |
| Pause         | Échap                  | Bouton pause               |

---

## ▶️ Lancer le jeu

1. Installer **Godot 4.4.x** (branche standard, GDScript) : <https://godotengine.org/download>
2. Ouvrir le projet : `Godot → Import → sélectionner project.godot`
3. Appuyer sur **F5** (ou le bouton ▶). Godot ré-importe les assets au premier lancement.

En ligne de commande :

```bash
godot --path . scenes/Main.tscn
```

---

## 📁 Structure

```
game1/
├── project.godot            # config moteur, autoloads, input map
├── export_presets.cfg       # presets Windows / Linux / Android
├── icon.png
├── scenes/
│   └── Main.tscn            # scène principale (bootstrap)
├── scripts/
│   ├── global.gd           # autoload: sauvegarde, pièces, record, skins, missions
│   ├── audio.gd            # autoload: SFX + musique
│   ├── data.gd             # constantes & tables (obstacles, collectibles, skins…)
│   ├── main.gd             # orchestrateur (états, routing signaux)
│   ├── game.gd             # monde 3D, caméra, score, power-ups
│   ├── player.gd           # CharacterBody3D: voies, saut, roulade, hitbox
│   ├── chunk_manager.gd    # génération procédurale + pooling
│   ├── spawnable.gd        # obstacle / collectible / power-up poolé
│   └── ui.gd               # menus, HUD, pause, game over, boutique
├── assets/
│   ├── models/             # 30 .glb low-poly (perso riggés + anims, décor, objets)
│   ├── ui/                 # icônes PNG
│   └── audio/              # SFX + boucle musicale (.wav)
└── tools/                  # générateurs Python des assets (voir ci-dessous)
```

---

## 🛠️ Régénérer les assets (optionnel)

Les assets sont déjà commités. Pour les régénérer :

```bash
pip install pillow numpy
cd tools
python3 gen_characters.py   # 4 persos riggés + animations (run/jump/roll/hit/idle)
python3 gen_env.py          # bâtiments, kiosque, taxi wôrô-wôrô, pont, palmiers, route
python3 gen_items.py        # 9 obstacles, 5 collectibles, 3 power-ups
python3 gen_textures.py     # icône appli + icônes UI
python3 gen_audio.py        # SFX + musique
```

Le pipeline écrit directement des `.glb` glTF 2.0 (maillages *flat-shaded* low-poly,
squelettes + skinning rigide + animations par images-clés) via `tools/gltf_builder.py`,
**sans Blender**.

---

## 📦 Export (Windows / Linux / Android)

Le script `tools/build.sh` gère l'export. Il faut les *export templates* Godot 4.4.1
(installés automatiquement par le script s'ils manquent).

```bash
# Windows .exe + Linux binaire
tools/build.sh windows
tools/build.sh linux

# APK Android (nécessite le SDK Android + JDK 17 — voir plus bas)
tools/build.sh android
```

Ou directement :

```bash
godot --headless --path . --export-release "Windows Desktop" builds/windows/AbidjanRunner.exe
godot --headless --path . --export-release "Linux"          builds/linux/AbidjanRunner.x86_64
godot --headless --path . --export-release "Android"        builds/android/AbidjanRunner.apk
```

### Prérequis Android (APK)

1. **JDK 17** (`apt install openjdk-17-jdk`)
2. **Android SDK** (cmdline-tools) avec `platform-tools`, `build-tools;34.0.0`,
   `platforms;android-34`
3. Dans Godot : *Editor → Editor Settings → Export → Android* → renseigner le chemin du
   SDK et de la debug keystore (Godot peut générer une debug keystore :
   `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999`)
4. `tools/build.sh android` exporte alors `builds/android/AbidjanRunner.apk`.

> En mode headless/CI, renseigner les chemins via
> `~/.config/godot/editor_settings-4.4.tres` (clés `export/android/android_sdk_path` et
> `export/android/debug_keystore`).

#### Astuce : sans le SDK Google (Debian/Ubuntu)

Si `dl.google.com` est bloqué, les seuls outils requis pour signer une APK
(`apksigner`, `zipalign`, `adb`) s'installent via apt, puis on fabrique une
arborescence SDK minimale :

```bash
sudo apt-get install -y apksigner zipalign adb openjdk-17-jdk
SDK=$HOME/android-sdk
mkdir -p "$SDK/platform-tools" "$SDK/build-tools/34.0.0"
ln -sf "$(which adb)"       "$SDK/platform-tools/adb"
ln -sf "$(which apksigner)" "$SDK/build-tools/34.0.0/apksigner"
ln -sf "$(which zipalign)"  "$SDK/build-tools/34.0.0/zipalign"
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
  -keystore "$HOME/debug.keystore" -storepass android \
  -dname "CN=Android Debug,O=Android,C=US" -validity 9999
# Dans ~/.config/godot/editor_settings-4.4.tres :
#   export/android/android_sdk_path = "<...>/android-sdk"
#   export/android/debug_keystore   = "<...>/debug.keystore"
godot --headless --path . --export-debug "Android" builds/android/AbidjanRunner.apk
```

> C'est exactement la méthode utilisée pour produire l'APK signé
> (`apksigner verify` → schémas v1 + v2 + v3 ✅).

---

## ⚙️ Détails techniques

- **CharacterBody3D** joueur, détection par `Area3D` (hitbox qui monte au saut / descend
  à la roulade) → l'esquive dépend réellement de la pose.
- **Chunks** de 12 m recyclés (8 actifs) : quand un chunk passe derrière le joueur, il est
  repositionné devant et repeuplé. Les obstacles/objets sont **poolés** par type.
- **Difficulté** progressive (nombre de voies bloquées / rangées) — au moins une voie
  toujours franchissable.
- **Brouillard** de distance pour masquer l'apparition des chunks lointains.
- Sauvegarde locale JSON dans `user://abidjan_runner_save.json`.

---

## 📜 Licence / crédits

Code, assets et audio générés pour ce projet. Style cartoon low-poly, thème Abidjan 🇨🇮.
