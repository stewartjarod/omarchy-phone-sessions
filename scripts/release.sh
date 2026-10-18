#!/usr/bin/env bash
# Cut a release from Conventional Commits.
#
#   scripts/release.sh [--dry-run] [--as X.Y.Z]
#
# 1. Reads the commits since the last v* tag.
# 2. Picks the bump:  breaking -> major (minor while 0.x) · feat -> minor · fix/perf/refactor -> patch.
#    The very first release (version 0.0.0, no tag) is 0.1.0. Only docs/test/ci/chore/style/build
#    since the last tag means nothing to release.
# 3. Writes the new version into manifest.json (the only copy) and a dated section into CHANGELOG.md.
#    Hand-written entries under [Unreleased] win; if it is empty, entries are generated from commits.
# 4. Commits "chore(release): X.Y.Z" and tags vX.Y.Z. It never pushes.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

dry=0; forced=""
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) dry=1 ;;
    --as) forced=${2:?--as needs a version}; shift ;;
    *) echo "usage: scripts/release.sh [--dry-run] [--as X.Y.Z]" >&2; exit 2 ;;
  esac
  shift
done

current=$(jq -r .version manifest.json)
last_tag=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)
range=${last_tag:+$last_tag..}HEAD

if [ "$dry" -eq 0 ]; then
  git diff --quiet && git diff --cached --quiet || { echo "release: the working tree has uncommitted changes" >&2; exit 1; }
  [ -z "$(git ls-files --others --exclude-standard)" ] || { echo "release: untracked files present" >&2; exit 1; }
fi

cc_re='^([a-z]+)(\(([^)]+)\))?(!)?: (.+)$'
semver_re='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$'
level=none
added=""; changed=""; fixed=""
while IFS= read -r sha; do
  subject=$(git log -1 --format=%s "$sha")
  body=$(git log -1 --format=%b "$sha")
  [[ $subject == "chore(release):"* ]] && continue
  if [[ $subject =~ $cc_re ]]; then
    type=${BASH_REMATCH[1]}; scope=${BASH_REMATCH[3]}; bang=${BASH_REMATCH[4]}; text=${BASH_REMATCH[5]}
  else
    continue
  fi
  breaking=0
  [ -n "$bang" ] && breaking=1
  grep -qE '^BREAKING[ -]CHANGE:' <<<"$body" && breaking=1
  entry="- ${scope:+**$scope:** }$text"
  [ "$breaking" -eq 1 ] && entry="$entry (**breaking**)"
  case $type in
    feat) added+="$entry"$'\n'; rank=minor ;;
    fix) fixed+="$entry"$'\n'; rank=patch ;;
    perf|refactor|revert) changed+="$entry"$'\n'; rank=patch ;;
    *) rank=none ;;
  esac
  [ "$breaking" -eq 1 ] && rank=major
  case "$level:$rank" in
    major:*|*:none) ;;
    *:major) level=major ;;
    minor:*) ;;
    *:minor) level=minor ;;
    none:patch) level=patch ;;
  esac
done < <(git rev-list --reverse --no-merges "$range")

IFS=. read -r maj min pat <<<"${current%%[-+]*}"
if [ -n "$forced" ]; then
  next=$forced
elif [ "$current" = "0.0.0" ] && [ -z "$last_tag" ]; then
  next=0.1.0
elif [ "$level" = none ]; then
  echo "release: nothing to release since ${last_tag:-the start} (no feat/fix/perf/refactor commits)"
  exit 0
else
  # While 0.x a breaking change bumps the minor number; from 1.0.0 it bumps the major.
  [ "$level" = major ] && [ "$maj" -eq 0 ] && level=minor
  case $level in
    major) next="$((maj + 1)).0.0" ;;
    minor) next="$maj.$((min + 1)).0" ;;
    patch) next="$maj.$min.$((pat + 1))" ;;
  esac
fi
[[ $next =~ $semver_re ]] || { echo "release: '$next' is not SemVer" >&2; exit 1; }
if [ "$(printf '%s\n%s\n' "$current" "$next" | sort -V | tail -n1)" != "$next" ] || [ "$current" = "$next" ]; then
  [ "$current" = "0.0.0" ] || { echo "release: $next is not newer than $current" >&2; exit 1; }
fi
git rev-parse -q --verify "refs/tags/v$next" >/dev/null && { echo "release: tag v$next already exists" >&2; exit 1; }

repo_url=$(sed -nE 's|^\[Unreleased\]: (https://[^/]+/[^/]+/[^/]+).*|\1|p' CHANGELOG.md | head -n1)
[ -n "$repo_url" ] || { echo "release: CHANGELOG.md has no [Unreleased]: link line" >&2; exit 1; }

# [Unreleased] body: hand-written wins.
unreleased=$(awk '/^## \[Unreleased\]/{f=1; next} /^## \[/{f=0} /^\[[^]]+\]: https:/{f=0} f' CHANGELOG.md | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
if [ -n "$(printf '%s' "$unreleased" | tr -d '[:space:]')" ]; then
  notes=$unreleased
else
  notes=""
  [ -n "$added" ] && notes+=$'### Added\n'"$added"$'\n'
  [ -n "$changed" ] && notes+=$'### Changed\n'"$changed"$'\n'
  [ -n "$fixed" ] && notes+=$'### Fixed\n'"$fixed"$'\n'
  [ -n "$notes" ] || notes=$'### Changed\n- Initial release\n'
fi

today=$(date +%F)
why=$level; [ -n "$forced" ] && why=forced
printf 'release: %s -> %s (%s)\n\n## [%s] - %s\n\n%s\n' "$current" "$next" "$why" "$next" "$today" "$notes"
[ "$dry" -eq 1 ] && exit 0

# Rebuild CHANGELOG.md: header, Unreleased (now empty), the new section, older sections, link refs.
sections=$(awk '/^## \[Unreleased\]/{f=1; next} /^## \[[0-9]/{f=2} /^\[[^]]+\]: https:/{f=0} f==2' CHANGELOG.md)
refs=$(grep -E '^\[[0-9][^]]*\]: https://' CHANGELOG.md || true)
header=$(awk '/^## \[Unreleased\]/{exit} {print}' CHANGELOG.md)
if [ -n "$last_tag" ]; then
  newref="[$next]: $repo_url/compare/$last_tag...v$next"
else
  newref="[$next]: $repo_url/releases/tag/v$next"
fi
{
  printf '%s\n\n' "$header"
  printf '## [Unreleased]\n\n## [%s] - %s\n\n%s\n' "$next" "$today" "$notes"
  if [ -n "$sections" ]; then printf '\n%s\n' "$sections"; fi
  printf '\n[Unreleased]: %s/compare/v%s...HEAD\n%s\n' "$repo_url" "$next" "$newref"
  if [ -n "$refs" ]; then printf '%s\n' "$refs"; fi
} | cat -s > CHANGELOG.md.new
mv CHANGELOG.md.new CHANGELOG.md

sed -i -E '0,/"version": *"[^"]*"/s//"version": "'"$next"'"/' manifest.json
[ "$(jq -r .version manifest.json)" = "$next" ] || { echo "release: failed to update manifest.json" >&2; exit 1; }

git add manifest.json CHANGELOG.md
git commit -q -m "chore(release): $next"
git tag -a "v$next" -m "v$next"
echo "release: committed and tagged v$next. Push with:  git push origin HEAD v$next"
