#!/usr/bin/env bash
# TIER 2 — the site a bootstrap produces builds, deploys (dry) and serves,
# with NO WordPress behind it.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will — on the
# day it is built, when its owner has not connected a WordPress site yet:
#
#   1. at the 01-product landing (the commit its one pull request merges), the
#      landing's own checks — install with the lockfile the product ships,
#      render fixtures and check the committed config is the render,
#      typecheck, lint, test, build. The bootstrap's landings are checked in
#      the box with `orun validate` and `orun plan` alone (`checks: local`;
#      their PR's CI on an `orun/BASE-…` branch is `plan` alone), and a
#      product's later pull requests build and dry-deploy it through ci.yml's
#      lanes, so THIS is where a product those steps refuse is caught: before
#      the tag, not after a build has merged it. Then the same at the 02-docs
#      landing, the finished site;
#   2. the stage lane's own steps, read out of `orun plan` in the product for
#      a pull request (the verify profile: the deploy profile has no dry run)
#      — EVERY `run:` step of the job, in order, exactly as planned: the
#      install, `verify-app-structure` (the committed `package.json` and
#      `wrangler.jsonc`, checked BEFORE any build), `build-app` (TypeGen,
#      `next build` on Turbopack, the OpenNext bundle), `verify-build-output`
#      and `deploy-dry-run` (`wrangler deploy --dry-run --name
#      <reponame>-web-stage`). They run IN THE TREE THE RUNNER STAGES for the
#      job (testing/lib/stage-job.py), with no build output in it and the
#      dependency layout the pinned composition produces: if its install step
#      is `scope: lane`, the top-level node_modules is a symlink to the source
#      checkout's (which Turbopack refuses); if not, the job's own install
#      step runs inside the staged tree. The job's WordPress ref is
#      optional, and a fresh product has stored none, so the lane runs with
#      no WORDPRESS_URL — as here;
#   3. serve the built Worker with `wrangler dev` and run the component's OWN
#      `smokeCommand` against it, verbatim and then inside the deploy
#      profile's planned `smoke` step (its retry loop and all — only its
#      workers.dev URL swapped for the local one) — the check the real deploy
#      ends with; then read every route the site promises: the home page,
#      the posts page with its count, filters and search, the three sample
#      posts under the "no WordPress site is connected" notice, the sample
#      page, the category, tag and author lists, carrying the site's name and
#      its stage origin in every absolute link, 404s for an unknown post, page
#      and path, the sitemap, the Open Graph image, the static assets — and
#      the webhook only the Worker's server code answers: /api/revalidate,
#      refusing a request without the secret with 401.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare token, deploy for real and probe workers.dev — nor
# WordPress's: a connected site reading real posts needs a WordPress. That is
# a bootstrap against a workspace (BOOTSTRAP.md); everything short of it is
# here.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, setsid, and the
# network for `pnpm install` and the build's Google Font (or a warm store).
# Several minutes: three installs and three Next.js builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl setsid; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
cleanup() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
sub="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['subdomain'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NEXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1
# NO WORDPRESS, whatever the caller's shell holds: this is the site its owner
# gets before connecting one.
unset WORDPRESS_URL WORDPRESS_HOSTNAME WORDPRESS_WEBHOOK_SECRET SITE_URL NEXT_PUBLIC_SITE_URL
free_port() { python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()"; }

# The landing's own checks, step for step, run here at once on the whole
# tree. A pull request in the product builds and dry-deploys the site
# through ci.yml's lanes; the lint and the tests run here, and by hand before
# a push.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "git diff --exit-code"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
s00="$(git -C "$tree" rev-parse HEAD~2)"; s01="$(git -C "$tree" rev-parse HEAD~1)"
echo "   2 phases placed and landed on orun's Initial commit"

# ── 1. each landing's own checks ───────────────────────────────────────────
echo "── 01-product's landing: install, the fixture render, typecheck, lint, test, build"
git -C "$tree" worktree add -q "$scratch/at-01" "$s01"
checks "$scratch/at-01" "$scratch/checks-01.log"
# Its tree is not needed again, and the disk is shared.
git -C "$tree" worktree remove --force "$scratch/at-01"

echo "── 02-docs's landing (the finished site): the same checks"
checks "$tree" "$scratch/checks-site.log"
grep -q '(Turbopack)' "$scratch/checks-site.log" \
  || { echo "FAIL: the landing's build did not run on Turbopack" >&2; exit 1; }

# ── 2. the stage lane, as a pull request plans it ──────────────────────────
echo "── the stage lane: every run step the PR plan gives web@stage, in a staged job tree"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan-pr.json") > "$scratch/plan-pr.log" 2>&1 \
  || { echo "FAIL: orun plan (pull request)" >&2; tail -15 "$scratch/plan-pr.log" >&2; exit 1; }
python3 - "$scratch/plan-pr.json" "$scratch/steps" "$tree" "$values" <<'PY'
import json, pathlib, sys
import yaml
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
tree, values = pathlib.Path(sys.argv[3]), json.load(open(sys.argv[4]))
repo, ws = values["reponame"], values["orunWorkspace"]
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
params = yaml.safe_load((tree / "apps/web/component.yaml").read_text())["spec"]["parameters"]
order, uses = [], []
for s in job["steps"]:
    if "use" in s:
        uses.append(f"{s['id']}\t{s['use']}\t{json.dumps(s.get('with') or {})}")
        continue
    order.append(s["id"])
    (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    (out / f"{s['id']}.wd").write_text(s.get("working-directory") or ".")
    if s.get("scope"):
        (out / f"{s['id']}.scope").write_text(s["scope"])
(out / "order").write_text("\n".join(order) + "\n")
(out / "uses").write_text("\n".join(uses) + "\n")
(out / "path").write_text(job.get("path") or "apps/web")
(out / "profile").write_text(job["profile"])
(out / "node").write_text(params["nodeVersion"])
(out / "pnpm").write_text(params["pnpmVersion"])
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
# What the platform resolves into the job before its first step. The
# WordPress URL's ref is OPTIONAL: on a product nobody has connected, nothing
# is stored under it, so nothing is exported — which is what this lane replays.
refs = {r["asEnv"]: r for r in job.get("secretRefs") or []}
for key in ("WORDPRESS_URL",):
    r = refs.get(key)
    if not r or r.get("optional") is not True or f"/{repo}/stage/" not in r.get("ref", ""):
        sys.exit(f"FAIL: the stage lane resolves {key} as {r} — want an optional ref to the product's stage secret")
required = sorted(k for k, r in refs.items() if not r.get("optional"))
if required:
    sys.exit(f"FAIL: the verify lane requires secrets {required}; a pull request's lane needs none")
PY
order="$(tr '\n' ' ' < "$scratch/steps/order")"
echo "   $(cat "$scratch/steps/profile"): $order"
for need in install-workspace-dependencies verify-app-structure build-app verify-build-output deploy-dry-run; do
  grep -qx "$need" "$scratch/steps/order" || { echo "FAIL: the stage lane plans no $need step" >&2; exit 1; }
done
[ "$(grep -n -x verify-app-structure "$scratch/steps/order" | cut -d: -f1)" -lt "$(grep -n -x build-app "$scratch/steps/order" | cut -d: -f1)" ] \
  || { echo "FAIL: the structure check is planned after the build" >&2; exit 1; }
# The `use:` steps set up the runner's toolchain; here it is this machine's,
# so it must be the one the component asks for.
node_major="$(node -p 'process.versions.node.split(".")[0]')"
[ "$node_major" = "$(cat "$scratch/steps/node")" ] || { echo "FAIL: node $node_major here, the lane sets up $(cat "$scratch/steps/node")" >&2; exit 1; }
[ "$(pnpm --version)" = "$(cat "$scratch/steps/pnpm")" ] || { echo "FAIL: pnpm $(pnpm --version) here, the lane sets up $(cat "$scratch/steps/pnpm")" >&2; exit 1; }
echo "   setup-node $node_major and setup-pnpm $(pnpm --version) stand in for the lane's \`use:\` steps"
echo "   the WordPress URL's ref is optional and unstored: the lane builds with none"

# The job's private tree, staged as orun stages it, from a source checkout
# with no build output (a CI checkout has none, so step 1's is removed rather
# than copied in) and the dependencies the pinned composition says: a
# lane-scoped install ran once in the source tree (step 1 ran the same
# command) and is linked in, or the job installs its own.
rm -rf "$tree/apps/web/.next" "$tree/apps/web/.open-next" "$tree/apps/web/.wrangler" "$tree/tests/web/coverage"
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
install_scope="$(cat "$scratch/steps/install-workspace-dependencies.scope" 2>/dev/null || echo job)"
if [ "$install_scope" = lane ]; then
  python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
  [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; exit 1; }
else
  python3 "$here/lib/stage-job.py" "$tree" "$work"
  [ ! -e "$work/node_modules" ] || { echo "FAIL: the staged tree carries node_modules it should install" >&2; exit 1; }
fi
for built in apps/web/.next apps/web/.open-next apps/web/.wrangler; do
  [ ! -e "$work/$built" ] || { echo "FAIL: the staged tree carries build output ($built)" >&2; exit 1; }
done
echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: $install_scope; no build output"

while IFS= read -r step; do
  [ -n "$step" ] || continue
  if [ "$step" = install-workspace-dependencies ] && [ "$install_scope" = lane ]; then
    echo "   · $step (lane-scoped: ran once in the source tree)"; continue
  fi
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`) and ORUN_ENVIRONMENT; the step runs in the component's directory.
  if ! (cd "$work/$(cat "$scratch/steps/path")/$(cat "$scratch/steps/$step.wd")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the stage lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done < "$scratch/steps/order"
[ "$install_scope" = lane ] || { [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ]; } \
  || { echo "FAIL: the job's install did not land inside its own tree" >&2; exit 1; }
# The build this site is verified with: Turbopack (a webpack build would get
# past an out-of-tree symlink and is not the build that deploys).
grep -q '(Turbopack)' "$scratch/build-app.log" \
  || { echo "FAIL: the staged build did not run on Turbopack" >&2; grep -m3 'Next.js' "$scratch/build-app.log" >&2; exit 1; }
grep -q -- "--name \"\${EFFECTIVE_WORKER_NAME}\"" "$scratch/steps/deploy-dry-run.sh" && grep -q "$repo-web-stage" "$scratch/steps/deploy-dry-run.sh" \
  || { echo "FAIL: the dry run does not name the Worker $repo-web-stage" >&2; exit 1; }
grep -q 'Total Upload' "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run bundled nothing" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
echo "   the staged build ran on Turbopack; the dry run bundled $repo-web-stage ($(grep -m1 -o 'Total Upload: .*' "$scratch/deploy-dry-run.log"))"

# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
echo "── wrangler dev over the staged Worker, no WordPress, no webhook secret"
port="$(free_port)"; iport="$(free_port)"
# setsid without its own fork: the subshell is not a group leader, so the
# pid recorded IS the new process group's.
(cd "$work/apps/web" && exec setsid pnpm exec wrangler dev --config wrangler.jsonc --name "$repo-web-stage" \
   --ip 127.0.0.1 --port "$port" --inspector-port "$iport" --show-interactive-dev-session=false) \
   > "$scratch/dev.log" 2>&1 < /dev/null &
dev_pid=$!
url="http://127.0.0.1:$port"
for _ in $(seq 1 120); do
  curl -s -o /dev/null "$url/favicon.ico" && break
  kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
  sleep 1
done
curl -s -o /dev/null "$url/favicon.ico" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }

smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
echo "   ▸ the component's own smokeCommand, verbatim, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the site" >&2; exit 1; }
if DEPLOYED_URL="$url/no-such-site" bash -c "$smoke" 2>/dev/null; then
  echo "FAIL: the smoke passed against a path that is not the site — it checks nothing" >&2; exit 1
fi
echo "   ▸ …and it refuses what is not the site"

(cd "$tree" && orun plan --intent intent.yaml --trigger github-push-main --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan-push.json") > "$scratch/plan-push.log" 2>&1 \
  || { echo "FAIL: orun plan (push to main)" >&2; tail -15 "$scratch/plan-push.log" >&2; exit 1; }
python3 - "$scratch/plan-push.json" "$scratch/smoke-step.sh" "https://$repo-web-stage.$sub.workers.dev" <<'PY'
import json, sys
plan, out, origin = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3]
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
assert job["profile"].endswith(".deploy"), job["profile"]
run = next(s for s in job["steps"] if s["id"] == "smoke")["run"]
# The one thing offline cannot reach is workers.dev: the step derives its URL
# from the Worker's name and the account's subdomain, so that line — and only
# that line — is pointed at the local Worker, after checking it is this site's.
line = 'export DEPLOYED_URL="https://${EFFECTIVE_WORKER_NAME}.${WORKERS_DEV_SUBDOMAIN}.workers.dev"'
if line not in run or 'EFFECTIVE_WORKER_NAME="' + origin.split("//")[1].split(".")[0] + '"' not in run:
    sys.exit(f"FAIL: the planned smoke step does not derive {origin}:\n{run}")
open(out, "w").write(run.replace(line, 'export DEPLOYED_URL="${E2E_LOCAL_URL}"'))
PY
echo "   ▸ the deploy profile's planned smoke step (its retry loop around the same command), on the local Worker"
(E2E_LOCAL_URL="$url" bash "$scratch/smoke-step.sh") > "$scratch/smoke-step.log" 2>&1 \
  || { echo "FAIL: the planned smoke step refused the site" >&2; tail -20 "$scratch/smoke-step.log" >&2; exit 1; }

echo "   ▸ every route the site promises"
python3 - "$url" "$values" <<'PY'
import html, json, re, sys, urllib.error, urllib.request
base, values = sys.argv[1], json.load(open(sys.argv[2]))
name = values["productname"]
# The staged lane built for stage: every absolute link is the stage Worker's.
origin = f"https://{values['reponame']}-web-stage.{values['subdomain']}.workers.dev"
problems = []
def bad(m): problems.append(m)
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None
opener = urllib.request.build_opener(NoRedirect)
def get(path, method="GET", data=None, headers=None):
    req = urllib.request.Request(base + path, data=data, method=method, headers=headers or {})
    try:
        with opener.open(req, timeout=60) as r:
            return r.status, r.headers.get("content-type", ""), r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("content-type", ""), e.read()
def text(fragment):
    return " ".join(html.unescape(re.sub(r"<!-- -->|<[^>]+>", "", fragment)).split())
def title(page):
    m = re.search(r"<title>(.*?)</title>", page, re.S)
    return html.unescape(m.group(1)) if m else None
def page_of(path):
    s, ctype, body = get(path)
    if s != 200 or not ctype.startswith("text/html"):
        bad(f"{path} answered {s} {ctype}")
    return body.decode()
def body_of(page):
    # The page without the notice, which links the first sample post from
    # every page: what remains is what the page itself lists.
    return re.sub(r'<div[^>]*data-wordpress="unconnected".*?</div>', "", page, flags=re.S)
def count(page):
    m = re.search(r"(\d+)(?:<!-- -->)?\s*(?:<!-- -->)?posts?(?:<!-- -->)? found", page)
    return int(m.group(1)) if m else None
NOTICE = 'data-wordpress="unconnected"'
POSTS = {"connect-your-wordpress-site": "Connect your WordPress site",
         "how-the-site-reads-wordpress": "How the site reads WordPress",
         "hello-world": "Hello world!"}

# The home page: the site's own name, the notice, and the template's credit.
page = page_of("/")
if title(page) != name:
    bad(f"the home page's <title> is {title(page)!r}, not {name!r}")
nav = re.search(r'<h2 class="text-sm">(.*?)</h2>', page, re.S)
if not nav or text(nav.group(1)) != name:
    bad(f"the nav names the site {nav and text(nav.group(1))!r}, not {name!r}")
if NOTICE not in page or 'href="/posts/connect-your-wordpress-site"' not in page:
    bad("the home page does not say the site is unconnected, or where to connect it")
if 'href="https://github.com/9d8dev/next-wp"' not in page:
    bad("the home page's credit to the upstream template is gone or rewritten")

# The posts page: the count, every sample post, the filters and the search,
# answered as the REST API would answer them.
page = page_of("/posts")
if count(page) != 3:
    bad(f"/posts counts {count(page)} posts, not the 3 samples")
links = set(re.findall(r'href="/posts/([^"/?]+)"', body_of(page)))
if not set(POSTS) <= links:
    bad(f"/posts links {sorted(links)}, missing samples {sorted(set(POSTS) - links)}")
if NOTICE not in page:
    bad("/posts does not carry the unconnected notice")
for query, want, slugs in (("?category=2", 1, {"how-the-site-reads-wordpress"}),
                           ("?tag=3", 2, {"connect-your-wordpress-site", "hello-world"}),
                           ("?author=1", 3, set(POSTS)),
                           ("?search=hello", 1, {"hello-world"})):
    p = page_of("/posts" + query)
    shown = set(re.findall(r'href="/posts/([^"/?]+)"', body_of(p))) & set(POSTS)
    if count(p) != want or shown != slugs:
        bad(f"/posts{query} shows {count(p)} post(s) {sorted(shown)}, want {want} {sorted(slugs)}")
if "matching your search" not in text(page_of("/posts?search=hello")):
    bad("/posts?search= does not say it is a search")

# Each sample post, with the notice and absolute links for the stage origin.
for slug, post_title in POSTS.items():
    p = page_of(f"/posts/{slug}")
    h1 = re.search(r"<h1[^>]*>(.*?)</h1>", p, re.S)
    if not h1 or text(h1.group(1)) != post_title:
        bad(f"/posts/{slug}'s heading is {h1 and text(h1.group(1))!r}, not {post_title!r}")
    if title(p) != post_title:
        bad(f"/posts/{slug}'s <title> is {title(p)!r}, not {post_title!r}")
    if NOTICE not in p:
        bad(f"/posts/{slug} does not carry the unconnected notice")
    if f'content="{origin}/api/og?title=' not in p or f'content="{origin}/posts/{slug}"' not in p:
        bad(f"/posts/{slug}'s Open Graph links are not the stage origin's ({origin})")
p = page_of("/posts/connect-your-wordpress-site")
for words in ("WORDPRESS_URL", "WORDPRESS_WEBHOOK_SECRET", "/api/revalidate", "orun secrets set"):
    if words not in p:
        bad(f"the connect post does not mention {words}")

# The sample page, and the archive lists.
if 'href="/pages/about"' not in page_of("/pages"):
    bad("/pages does not list the sample page")
p = page_of("/pages/about")
if not re.search(r"<h2[^>]*>About</h2>", p):
    bad("/pages/about does not render the sample page")
for path, words in (("/posts/categories", ("Getting started", "Guides", 'href="/posts?category=1"')),
                    ("/posts/tags", ("WordPress", "Next.js", "Cloudflare")),
                    ("/posts/authors", ("The editor",))):
    p = page_of(path)
    for w in words:
        if w not in p:
            bad(f"{path} does not list {w}")

# Not there: an unknown post, page and path — and /admin, which redirects to
# wp-admin only once a WordPress is connected.
for path in ("/posts/no-such-post", "/pages/no-such-page", "/no-such-page", "/admin"):
    s, _, _ = get(path)
    if s != 404:
        bad(f"{path} answered {s}, want 404")

# The sitemap and robots, per request; the Open Graph image, rendered by the Worker.
s, ctype, body = get("/sitemap.xml")
if s != 200 or "xml" not in ctype or f"<loc>{origin}/posts/hello-world</loc>" not in body.decode():
    bad(f"/sitemap.xml answered {s} {ctype} without the sample posts under {origin}")
s, ctype, _ = get("/robots.txt")
if s != 200 or not ctype.startswith("text/plain"):
    bad(f"/robots.txt answered {s} {ctype}")
s, ctype, body = get("/api/og?title=Hello&description=World")
if s != 200 or ctype != "image/png" or not body.startswith(b"\x89PNG"):
    bad(f"/api/og answered {s} {ctype} — not a PNG")

# Static assets, served by the Worker's ASSETS binding.
s, ctype, _ = get("/favicon.ico")
if s != 200 or not ctype.startswith("image/"):
    bad(f"/favicon.ico answered {s} {ctype}")
chunk = re.search(r'src="(/_next/static/[^"]+\.js)"', page_of("/"))
if not chunk:
    bad("the home page loads no script from /_next/static")
else:
    s, ctype, _ = get(chunk.group(1))
    if s != 200 or "javascript" not in ctype:
        bad(f"{chunk.group(1)} answered {s} {ctype}")

# THE ROUTE ONLY THE WORKER ANSWERS: the revalidation webhook. With no
# secret set, every request is refused — never a 500, never a revalidation.
for hdrs in ({}, {"x-webhook-secret": "guess"}):
    s, _, body = get("/api/revalidate", "POST", json.dumps({"contentType": "post"}).encode(),
                     {"content-type": "application/json", **hdrs})
    if s != 401 or b"Invalid webhook secret" not in body:
        bad(f"/api/revalidate with {hdrs or 'no secret'} answered {s} {body[:80]!r}, want 401")
s, _, _ = get("/api/revalidate")
if s != 405:
    bad(f"GET /api/revalidate answered {s}, want 405")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   /, /posts (its count, filters and search), the three sample posts, /pages and the sample page,")
print(f"   the category, tag and author lists, four 404s, the sitemap, the OG image, the static assets")
print(f"   and the webhook's 401 — the site's own, named {name!r}, on {origin}, unconnected and saying so")
PY

echo "e2e.test.sh: ok"
