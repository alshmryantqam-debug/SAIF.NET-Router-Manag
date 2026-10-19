#!/usr/bin/env bash
set -euo pipefail
flutter pub get
flutter build apk --release --no-tree-shake-icons