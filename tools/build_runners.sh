#!/usr/bin/env bash
# Runner pipeline:
#  1. KayKit clips (CC0) -> retargeted onto a T-pose humanoid rig + authored slide (runner_base.glb)
#  2. Quaternius Universal Base Characters (CC0) dressed in African outfits, clips retargeted onto them
set -e
cd "$(dirname "$0")"
python3 retarget.py source_models/kaykit_mage.glb source_models/mannequiny.glb source_models/runner_base.glb
python3 ubc_runners.py
