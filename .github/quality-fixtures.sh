#!/usr/bin/env bash
# The quality/ metrics' fixtures (CONTRIBUTING.md, "Adding a quality metric"): every
# tests/quality/<metric>/pass film must pass `shotglass quality`, and every
# tests/quality/<metric>/fail film must fail it on its limits, not on an error (the
# metric ran, measured no NaN/Inf, and a limit was broken). So a metric that goes blind
# (measures 0 everywhere) or over-reports turns CI red.
#
#   .github/quality-fixtures.sh [out-dir]     (CI: under xvfb-run -a; Git Bash on Windows)
#
# Reports and heatmaps land in out-dir (default quality-fixtures/), one folder per film.
set -u
out=${1:-quality-fixtures}
py=$(command -v python3 || command -v python)
status=0
for film in tests/quality/*/pass tests/quality/*/fail; do
  metric=$(basename "$(dirname "$film")")
  case=$(basename "$film")
  dir="$out/$metric-$case"
  log=$(shotglass quality "$film" --out "$dir" 2>&1)
  code=$?
  if [ "$case" = pass ]; then
    if [ $code -ne 0 ]; then
      echo "::error file=$film/quality.toml::quality/$metric must pass on $film but failed:"
      echo "$log"
      status=1
    else
      echo "ok    $film passes"
    fi
    continue
  fi
  # A fail film: shotglass must exit non-zero, and the report must show the metric
  # measured and broke a limit (not a compile error, a missing file or NaN/Inf).
  if [ $code -eq 0 ]; then
    echo "::error file=$film/quality.toml::quality/$metric must fail on $film but passed (has the metric gone blind?):"
    echo "$log"
    status=1
    continue
  fi
  if ! "$py" - "$dir/quality.json" <<'PY'
import json, sys
try:
    q = json.load(open(sys.argv[1]))
except OSError:
    sys.exit("no quality.json: shotglass stopped before measuring")
ms = q["metrics"] + (q.get("sound") or {}).get("metrics", [])
broken = [m for m in ms if m["failures"] and m["total"]["invalid"] == 0]
if not broken:
    sys.exit("no metric broke a limit with valid measures")
PY
  then
    echo "::error file=$film/quality.toml::quality/$metric failed on $film, but not on its limits:"
    echo "$log"
    status=1
  else
    echo "ok    $film fails, as it must"
  fi
done
exit $status
