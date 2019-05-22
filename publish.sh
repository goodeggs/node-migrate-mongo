#!/usr/bin/env bash
set -e
set -o pipefail

[ -f package.json ] || { echo 'no package.json file found'; exit 1; }
[ -n "$NPM_AUTH" ] || { echo 'NPM_AUTH should be set'; exit 1; }
[ -n "$NPM_EMAIL" ] || { echo 'NPM_EMAIL should be set'; exit 1; }
[ "$(jq -r 'has("publishConfig")' < package.json)" = "true" ] || { echo 'please set an explicit publishConfig in your package.json'; exit 1; }

lastVersion="$(git show HEAD^:package.json | jq -r '.version')"
thisVersion="$(git show HEAD:package.json | jq -r '.version')"
echo "package.json version was $lastVersion, now $thisVersion"
[ "$lastVersion" = "$thisVersion" ] && { echo 'no version change detected, skipping deploy...'; exit 0; }

yarn run dist

# we still use npm to publish as yarn requires you to version at the same time you publish.

cat <<EOD > .npmrc
_auth = "\${NPM_AUTH}"
email = "\${NPM_EMAIL}"
always_auth = true
EOD

npm publish
