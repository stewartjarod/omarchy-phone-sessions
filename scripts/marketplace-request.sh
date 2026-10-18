#!/usr/bin/env bash
# Prints the exact GitHub issue the Omarchy plugin marketplace expects, and the `gh` command to open it.
# It NEVER creates the issue: that is a public action under your account. Review, then run it yourself.
#
#   scripts/marketplace-request.sh submit --category Widgets --tags bar,media [--notes "text"]
#   scripts/marketplace-request.sh update          # verify + publish the current HEAD after you pushed a release
#
# `submit` lists a new plugin; `update` promotes a newer commit of an already-listed plugin (verification
# is bound to ONE exact commit: any later commit shows "Update unverified" until promoted).
# Forms: SUBMISSION.md and VERIFICATION.md in https://github.com/omacom/omarchy-plugin-marketplace
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
REPO=omacom/omarchy-plugin-marketplace
CATEGORIES="Appearance|Desktop|Developer Tools|Hardware|Kids|Productivity|System|Widgets|Other"
TAGS="ai bar education games hyprland kids launcher media power-management quickshell security system vpn workspaces"

mode=${1:-}; shift || true
category=""; tags=""; notes="_No response_"
while [ $# -gt 0 ]; do
  case $1 in
    --category) category=${2:?}; shift ;;
    --tags) tags=${2:?}; shift ;;
    --notes) notes=${2:?}; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

id=$(jq -r .id manifest.json)
name=$(jq -r .name manifest.json)
origin=$(git remote get-url origin 2>/dev/null || true)
url=$(printf '%s' "$origin" | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##; s#/$##')
[[ $url =~ ^https://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "set a GitHub 'origin' remote first (got: '${origin}')" >&2; exit 1; }
sha=$(git rev-parse HEAD)
git diff --quiet && git diff --cached --quiet || echo "warning: uncommitted changes; the marketplace verifies the pushed commit $sha" >&2
git branch -r --contains "$sha" 2>/dev/null | grep -q . || echo "warning: $sha is not on any pushed branch yet; push it first" >&2

case $mode in
  submit)
    printf '%s\n' "${CATEGORIES//|/$'\n'}" | grep -qxF -- "$category" || { echo "--category must be one of: ${CATEGORIES//|/, }" >&2; exit 2; }
    [ -n "$tags" ] || { echo "--tags needs 1-3 of: $TAGS" >&2; exit 2; }
    n=0
    for t in ${tags//,/ }; do
      n=$((n + 1))
      [[ " $TAGS " == *" $t "* ]] || { echo "unknown tag '$t' (allowed: $TAGS)" >&2; exit 2; }
    done
    [ "$n" -le 3 ] || { echo "at most 3 tags" >&2; exit 2; }
    title="[Plugin]: $name"
    body=$(cat <<EOF
### Repository URL

$url

### Category

$category

### Tags

${tags//,/, }

### Suggest a missing tag

_No response_

### Maintainer notes

$notes

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
EOF
) ;;
  update)
    title="[Verify]: $id"
    body=$(cat <<EOF
### Verification action

Verify and publish a newer upstream commit

### Plugin ID

$id

### Repository URL

$url

### Target commit

$sha

### Verification acknowledgment

- [x] I understand that only the exact target commit can become a verified marketplace snapshot and that verification is not a security audit.

### Standard installation acknowledgment

- [ ] I confirm that this listed root plugin supports the standard Omarchy installation path and does not require manual setup.
EOF
) ;;
  *) echo "usage: scripts/marketplace-request.sh submit|update [options]" >&2; exit 2 ;;
esac

printf '# Title: %s\n\n%s\n\n' "$title" "$body"
echo "# The checked boxes are statements YOU confirm (ownership, licence, no config overwrite). Make sure they are true."
echo "# To open it:"
printf "gh issue create --repo %s --title %q --body-file <(cat <<'BODY'\n%s\nBODY\n)\n" "$REPO" "$title" "$body"
