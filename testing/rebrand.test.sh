#!/usr/bin/env bash
# THE REBRAND WRITES EACH VALUE ONCE, AND WHAT IT WROTE STAYS WRITTEN.
#
# Drives the real tooling/rebrand/rebrand.mjs over one-file trees and compares
# the file. Each case is a shape this baseline's identity actually takes in the
# tree — a source link, the site-name seam, the Worker name in wrangler.jsonc
# and the component, the intent's environment URLs, the placeholder domain, the
# WordPress secret ref, and the upstream template's own name, which is its
# credit and must NOT be renamed — and each can run through several passes (a re-run of a phase
# re-runs the rebrand over everything already placed, and 02-docs's heal runs
# it again), so a value written by one pass must survive every later one.
#
# The identity is PINNED (fixtures/baseline-identity.cms-wordpress.json) rather than
# read from .baseline/identity.json: what this tests is the engine, and its
# fixtures spell the identity out literally.
#
# Needs: node, git. No network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
rebrand="$here/../tooling/rebrand/rebrand.mjs"
identity="$here/fixtures/baseline-identity.cms-wordpress.json"

fail=0
# check NAME VALUES-JSON FILE CONTENT WANT [PASSES]
check() {
  local name="$1" values="$2" file="$3" content="$4" want="$5" passes="${6:-1}"
  local tmp got out i
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  for ((i = 1; i <= passes; i++)); do
    git -C "$tmp" add -A
    if ! out="$(cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty 2>&1)"; then
      echo "   ✕  $name: rebrand pass $i failed:" >&2
      printf '%s\n' "$out" | sed 's/^/        /' >&2
      fail=1
      rm -rf "$tmp"
      return
    fi
  done
  got="$(cat "$tmp/$file")"
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then
    echo "   ok  $name"
  else
    echo "   ✕  $name:" >&2
    echo "        got:  $got" >&2
    echo "        want: $want" >&2
    fail=1
  fi
}

acme='{"reponame":"acme-notes","productname":"Acme Notes","productdomain":"acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'

echo "── rebrand: the site's own identity"
check "a source link names the product's owner and repository" \
  "$acme" README.md \
  'See https://github.com/sourceplane/cms-wordpress for the source.' \
  'See https://github.com/acme-inc/acme-notes for the source.'
check "the site-name seam takes the product's name" \
  "$acme" apps/web/site.config.ts 'export const SITE_NAME = "next-wp";' \
  'export const SITE_NAME = "Acme Notes";'
check "…and stays a valid string for a name with an apostrophe and an ampersand" \
  '{"reponame":"sams-notes","productname":"Sam'"'"'s Notes & Links","productdomain":"sam.dev"}' \
  apps/web/site.config.ts 'export const SITE_NAME = "next-wp";' \
  'export const SITE_NAME = "Sam'"'"'s Notes & Links";'
check "the template's name elsewhere is its credit, and is left alone" \
  "$acme" apps/web/app/page.tsx 'This is <a href="https://github.com/9d8dev/next-wp">next-wp</a>,' \
  'This is <a href="https://github.com/9d8dev/next-wp">next-wp</a>,'
check "the Worker name in wrangler.jsonc is re-prefixed" \
  "$acme" apps/web/wrangler.jsonc '  "name": "cms-wordpress-web",' \
  '  "name": "acme-notes-web",'
check "the component's worker name is re-prefixed, the environment suffix kept" \
  "$acme" apps/web/component.yaml '    workerName: cms-wordpress-web' \
  '    workerName: acme-notes-web'
check "the workers.dev subdomain in the component" \
  "$acme" apps/web/component.yaml '    workersDevSubdomain: your-workers-subdomain' \
  '    workersDevSubdomain: acme'
check "an environment URL in the intent" \
  "$acme" intent.yaml '    url: https://cms-wordpress-web-prod.your-workers-subdomain.workers.dev' \
  '    url: https://acme-notes-web-prod.acme.workers.dev'
check "the placeholder domain is the product's domain, not a renamed slug" \
  "$acme" intent.yaml '      BASE_DOMAIN: cms-wordpress.example.com' \
  '      BASE_DOMAIN: acme.dev'
check "no domain given: the reserved placeholder, for an owner to replace later" \
  '{"reponame":"acme-notes","productname":"Acme Notes","githuborg":"acme-inc","subdomain":"acme"}' \
  intent.yaml '      BASE_DOMAIN: cms-wordpress.example.com' \
  '      BASE_DOMAIN: acme-notes.example.com'
check "an empty domain is no domain" \
  '{"reponame":"acme-notes","productname":"Acme Notes","productdomain":""}' \
  intent.yaml '      BASE_DOMAIN: cms-wordpress.example.com' \
  '      BASE_DOMAIN: acme-notes.example.com'
check "the repo slug" \
  "$acme" package.json '  "name": "cms-wordpress",' \
  '  "name": "acme-notes",'
check "the WordPress secret ref names the product's workspace and project, the environment kept" \
  "$acme" apps/web/component.yaml \
  '    WORDPRESS_URL: "secret://cms-wordpress/cms-wordpress/{{ .environment }}/WORDPRESS_URL"' \
  '    WORDPRESS_URL: "secret://ws_79BDXAZQ/acme-notes/{{ .environment }}/WORDPRESS_URL"'
check "the WordPress variable names are the template's, and are left alone" \
  "$acme" apps/web/.env.example 'WORDPRESS_URL=' \
  'WORDPRESS_URL='
check "org-owned identity is not renamed" \
  "$acme" intent.yaml 'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai' \
  'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai'
check "without githuborg a source link keeps the baseline's owner" \
  '{"reponame":"acme-notes","productname":"Acme Notes","productdomain":"acme.dev"}' \
  README.md 'https://github.com/sourceplane/cms-wordpress' \
  'https://github.com/sourceplane/acme-notes'

echo "── rebrand: a written value is not rewritten, in any later pass"
contains='{"reponame":"cms-wordpress-2","productname":"next-wp 2","productdomain":"cms-wordpress.example.com.au","githuborg":"sourceplane","subdomain":"your-workers-subdomain-2"}'
check "a repo slug containing the baseline's slug survives three passes" \
  "$contains" package.json '  "name": "cms-wordpress",' \
  '  "name": "cms-wordpress-2",' 3
check "a Worker name built on it survives three passes" \
  "$contains" apps/web/wrangler.jsonc '  "name": "cms-wordpress-web",' \
  '  "name": "cms-wordpress-2-web",' 3
check "a domain containing the baseline's domain survives three passes" \
  "$contains" intent.yaml 'BASE_DOMAIN: cms-wordpress.example.com' \
  'BASE_DOMAIN: cms-wordpress.example.com.au' 3
check "a subdomain containing the placeholder survives three passes" \
  "$contains" intent.yaml '    url: https://cms-wordpress-web-stage.your-workers-subdomain.workers.dev' \
  '    url: https://cms-wordpress-2-web-stage.your-workers-subdomain-2.workers.dev' 3
check "a site name containing the baseline's name survives three passes" \
  "$contains" apps/web/site.config.ts 'export const SITE_NAME = "next-wp";' \
  'export const SITE_NAME = "next-wp 2";' 3
check "the template's credit survives three passes of a slug and a name that contain the baseline's" \
  "$contains" apps/web/app/page.tsx 'This is <a href="https://github.com/9d8dev/next-wp">next-wp</a>,' \
  'This is <a href="https://github.com/9d8dev/next-wp">next-wp</a>,' 3
# The fixture the placement and end-to-end gates build with: a slug that ENDS
# in the baseline's, so its Worker is `<…>-cms-wordpress-web`.
suffixed='{"reponame":"acme-cms-wordpress","productname":"Acme","productdomain":"www.acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'
check "a repo slug ending in the baseline's slug survives three passes" \
  "$suffixed" package.json '  "name": "cms-wordpress",' \
  '  "name": "acme-cms-wordpress",' 3
check "…and its Worker name" \
  "$suffixed" apps/web/wrangler.jsonc '  "name": "cms-wordpress-web",' \
  '  "name": "acme-cms-wordpress-web",' 3
check "…and its secret ref" \
  "$suffixed" apps/web/component.yaml '    WORDPRESS_URL: "secret://cms-wordpress/cms-wordpress/{{ .environment }}/WORDPRESS_URL"' \
  '    WORDPRESS_URL: "secret://ws_79BDXAZQ/acme-cms-wordpress/{{ .environment }}/WORDPRESS_URL"' 3
# The placement fixture carries no domain (a console build asks for none), and
# its slug's placeholder CONTAINS the baseline's: acme-cms-wordpress.example.com.
nodomain='{"reponame":"acme-cms-wordpress","productname":"Acme","productdomain":"","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'
check "…and, with no domain, its placeholder survives three passes" \
  "$nodomain" intent.yaml '      BASE_DOMAIN: cms-wordpress.example.com' \
  '      BASE_DOMAIN: acme-cms-wordpress.example.com' 3

# --verify runs in every phase. Without the product's values it cannot tell
# the product's own identity from a leftover; with them it can. A real
# leftover must fail it either way.
verify() { # NAME VALUES FILE CONTENT WANT(pass|fail) [--values]
  local name="$1" values="$2" file="$3" content="$4" want="$5" withvalues="${6:-}" tmp got
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  git -C "$tmp" add -A
  if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --verify ${withvalues:+--values .rebrand/values.json} >/dev/null 2>&1); then got=pass; else got=fail; fi
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then echo "   ok  $name"; else echo "   ✕  $name: --verify ${got}ed, want $want" >&2; fail=1; fi
}
echo "── rebrand --verify: the product's own identity is not residue"
verify "given the values, a slug containing the baseline's passes" \
  "$contains" package.json '"name": "cms-wordpress-2"' pass --values
verify "without them it cannot know, and fails" \
  "$contains" package.json '"name": "cms-wordpress-2"' fail
verify "given the values, a slug ending in the baseline's passes" \
  "$suffixed" apps/web/wrangler.jsonc '"name": "acme-cms-wordpress-web"' pass --values
verify "given the values, a placeholder domain containing the baseline's passes" \
  "$nodomain" intent.yaml 'BASE_DOMAIN: acme-cms-wordpress.example.com' pass --values
verify "the upstream template's link is not residue" \
  "$acme" apps/web/app/page.tsx 'href="https://github.com/9d8dev/next-wp/blob/main/README.md"' pass --values
verify "given the values, a real leftover still fails" \
  "$acme" package.json '"name": "cms-wordpress"' fail --values
verify "a leftover Worker name fails" \
  "$acme" apps/web/wrangler.jsonc '"name": "cms-wordpress-web"' fail --values
verify "a leftover link to another repository named like it fails" \
  "$acme" README.md 'https://github.com/acme-inc/cms-wordpress' fail --values
verify "a leftover code identifier fails (no rule renames it — so nothing may spell it)" \
  "$acme" apps/web/x.ts 'export class CmsWordpress {}' fail --values
verify "a clean product passes" \
  "$acme" package.json '"name": "acme-notes"' pass --values

echo "── rebrand: a residue it cannot rename fails the rebrand itself"
tmp="$(mktemp -d)"; git -C "$tmp" init -q; mkdir -p "$tmp/.rebrand" "$tmp/apps/web"
printf '%s\n' "$acme" > "$tmp/.rebrand/values.json"
printf 'const x = "CMS_WORDPRESS_TOKEN"\n' > "$tmp/apps/web/x.ts"
git -C "$tmp" add -A
if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty >/dev/null 2>&1); then
  echo "   ✕  an unrenamable env-var prefix passed the rebrand" >&2; fail=1
else
  echo "   ok  an unrenamable env-var prefix fails the rebrand, naming the file"
fi
rm -rf "$tmp"

[ "$fail" -eq 0 ] || exit 1
echo "rebrand.test.sh: ok"
