#!/usr/bin/env bash
# Runner pipeline: KayKit clips -> retarget onto Mannequiny (+ authored slide) -> dress 4 skins.
set -e
cd "$(dirname "$0")"
python3 retarget.py source_models/kaykit_mage.glb source_models/mannequiny.glb source_models/runner_base.glb
python3 dress_runner.py source_models/runner_base.glb ../assets/thirdparty/gdquest
