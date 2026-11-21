#!/usr/bin/env bash
# Transition endpoints: every transition in tests/transitions must show exactly the old
# shot at the instant it starts and exactly the new shot at the instant it ends.
#
#   xvfb-run -a .github/transition-endpoints.sh [out-dir]   (Linux without a display)
#   .github/transition-endpoints.sh [out-dir]               (with a display / on Windows)
#
# Two strips of the same film, one row per transition (cols 2):
#   expected.png   each pair of shots on its own, away from any transition:
#                  old shot (t<n-1>+1.5), new shot (t<n>+1.5)
#   endpoints.png  the transition into shot t<n> at progress 0 (t<n>+0) and at the
#                  last instant before the cut (t<n>+0.99999, progress 0.99999: the
#                  timeline shows the plain new shot from t<n>+1, so progress 1 itself is
#                  never drawn by a transition)
# compared with zero tolerance: any pixel off by 1/255 fails. The scenes are still
# pictures, so the time each is rendered at doesn't matter. On a failure,
# <out-dir>/endpoints.diff.png marks the differing pixels in magenta; row n is the
# transition into shot t<n> (its line in movie.toml).
set -euo pipefail
film=tests/transitions
out=${1:-transition-endpoints}
size=320x180
mkdir -p "$out"

n=$(grep -c '^\[\[shot\]\]' "$film/movie.toml")
expected="" endpoints=""
for ((i = 1; i < n; i++)); do
    expected+="t$((i - 1))+1.5,t$i+1.5,"
    endpoints+="t$i+0,t$i+0.99999,"
done

shotglass strip "$film" --at "$expected" --cols 2 --size "$size" --out "$out/expected.png"
if ! shotglass strip "$film" --at "$endpoints" --cols 2 --size "$size" --out "$out/endpoints.png" \
    --compare "$out/expected.png" --tolerance 0 --budget 0 --max-mean 0; then
    echo "::error file=$film/movie.toml::a transition doesn't start exactly on the old shot or end exactly on the new one (row n of $out/endpoints.diff.png = the transition into shot t<n>; left = start, right = end)"
    exit 1
fi
echo "$((n - 1)) transitions start on the old shot and end on the new one"
