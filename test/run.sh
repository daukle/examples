#!/bin/sh
# Every example is run against a real daukle, because an example that is not
# executed is a document claiming daukle works rather than evidence of it.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work="$root/test/.work"

daukle=${DAUKLE:-}
if [ -z "$daukle" ]; then
  for candidate in \
    "$root/.daukle/build/daukle" \
    "$root/.daukle/build/daukle.exe" \
    "$root/.daukle/build/Release/daukle.exe" \
    "$root/.daukle/build/Debug/daukle.exe"
  do
    [ -x "$candidate" ] && daukle=$candidate && break
  done
fi
if [ -z "$daukle" ] || [ ! -x "$daukle" ]; then
  echo "no daukle binary: set DAUKLE, or check out daukle/daukle into .daukle and build it" >&2
  exit 1
fi

# One cache for the whole run rather than one per example. The usual rule is to
# isolate DAUKLE_CACHE_DIR per case, and it is suspended here for the reason the
# rule itself names: two examples provision the same JDK and the same CMake, and
# isolating them would download both twice per runner.
cache="$work/.cache"

# A task case provisions a real toolchain, so by default the tasks run on Linux
# only and one download per CI run is the trade. DAUKLE_EXAMPLES_E2E=1 runs them
# everywhere.
run_tasks=0
case "$(uname -s 2>/dev/null || echo unknown)" in
  Linux) run_tasks=1 ;;
esac
[ "${DAUKLE_EXAMPLES_E2E:-}" = "1" ] && run_tasks=1

passed=0
failed=0
skipped=0

fail() {
  echo "FAIL $1: $2" >&2
  failed=$((failed + 1))
}

pass() {
  echo "ok   $1: $2"
  passed=$((passed + 1))
}

skip() {
  echo "skip $1: $2"
  skipped=$((skipped + 1))
}

stage() {
  rm -rf "$work/$1"
  mkdir -p "$work"
  cp -R "$root/$1" "$work/$1"
}

# Byte comparison rather than a diff of parsed json: what this asserts is the
# formatting daukle.json_set produces, and a parse would agree with itself about
# whitespace it never looked at.
compare_expected() {
  name=$1
  staged=$2
  mismatch=""
  for expected in $(cd "$root/$name/expected" && find . -type f | sed 's|^\./||'); do
    if ! cmp -s "$root/$name/expected/$expected" "$staged/$expected"; then
      mismatch="$expected"
      break
    fi
  done
  echo "$mismatch"
}

for manifest in "$root"/*/daukle.toml; do
  [ -f "$manifest" ] || continue
  name=$(basename "$(dirname "$manifest")")
  staged="$work/$name"
  stage "$name"

  # Sync first, then check. A fresh clone of a generating toolchain is
  # legitimately NOT in sync: cmake has no CMakeLists.txt yet and npm has not
  # written into package.json. So `check` is not a precondition here, it is the
  # assertion that one sync was enough, which is the stronger claim.
  if ! (cd "$staged" && DAUKLE_CACHE_DIR="$cache" "$daukle" sync >"$staged/.sync1.log" 2>&1); then
    fail "$name" "first sync failed: $(tail -n 1 "$staged/.sync1.log")"
    continue
  fi
  if ! (cd "$staged" && DAUKLE_CACHE_DIR="$cache" "$daukle" sync >"$staged/.sync2.log" 2>&1); then
    fail "$name" "second sync failed: $(tail -n 1 "$staged/.sync2.log")"
    continue
  fi
  if ! (cd "$staged" && DAUKLE_CACHE_DIR="$cache" "$daukle" check >"$staged/.check.log" 2>&1); then
    fail "$name" "not in sync after syncing twice: $(tail -n 1 "$staged/.check.log")"
    continue
  fi
  pass "$name" "synced twice and in sync"

  if [ -d "$root/$name/expected" ]; then
    mismatch=$(compare_expected "$name" "$staged")
    if [ -n "$mismatch" ]; then
      fail "$name" "$mismatch does not match expected/"
      continue
    fi
    pass "$name" "matched expected/"
  fi

  if [ ! -f "$root/$name/task.txt" ]; then
    continue
  fi
  task=$(cat "$root/$name/task.txt")
  if [ "$run_tasks" -ne 1 ]; then
    skip "$name" "task $task, which provisions a toolchain; set DAUKLE_EXAMPLES_E2E=1"
    continue
  fi
  if ! (cd "$staged" && DAUKLE_CACHE_DIR="$cache" "$daukle" "$task" >"$staged/.task.log" 2>&1); then
    fail "$name" "task $task failed: $(tail -n 1 "$staged/.task.log")"
    continue
  fi
  clause=$(cat "$root/$name/expect-output.txt")
  if ! grep -q "$clause" "$staged/.task.log"; then
    fail "$name" "task $task printed no \"$clause\""
    continue
  fi
  pass "$name" "task $task printed \"$clause\""
done

echo "pass: $passed, fail: $failed, skip: $skipped"
[ "$failed" -eq 0 ] || exit 1
[ "$passed" -gt 0 ] || { echo "no example ran at all" >&2; exit 1; }
