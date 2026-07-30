# Windbar runbook

Operational notes for the build and release pipeline. For the app itself see `README.md`.

> **This file is public.** Never add a password, key, token, internal hostname or IP address to it.
> Point at where the secret lives instead.

## How a release happens

Merge to `main` on **Gitea** (`<gitea-host>/lucidfabrics/dreo-menubar`, which is `origin`).

```
ci  ──>  cd-appstore  ──>  cd-github-source
```

- `ci` builds and runs the 59 tests. Gates everything.
- `cd-appstore` builds, signs, packages and uploads to App Store Connect, pushes the store listing
  from `fastlane/metadata/`, and attaches the new build to the version.
- `cd-github-source` pushes source to GitHub, **only if the upload succeeded**.

**No binary is ever published to GitHub.** The job refuses to run if any `.dmg/.pkg/.ipa/.app/
.xcarchive` is tracked in git. Distribution is the Mac App Store, full stop.

Submitting for review is never automatic. Run `bundle exec fastlane mac submission_status` to see
what is still outstanding.

## The build machine

A dedicated macOS VM on the internal Proxmox cluster. Its address and credentials are in the
team notes, not here.
It is the only Mac builder and beeside's iOS pipeline shares it, so concurrent runs queue.

> The `hackintosh` entry in `~/.ssh/config` is stale. Use the current address from the
> team notes, not that alias.

**Two act_runner installs live on it**, each with its own registration and LaunchAgent:

| Directory | Gitea runner | Scope |
|---|---|---|
| `~/gitea-runner/` | id 5 `beeside-hackintosh-ios` | beeside repo only |
| `~/gitea-runner-lucidfabrics/` | id 8 `lucidfabrics-hackintosh-ios` | whole org, **this is the one Windbar needs** |

Both advertise the label `hackintosh-ios`, so the label tells you nothing about which will take a job.

### Jobs stuck in "waiting" forever

Almost always the org-scoped runner is down. Check:

```bash
curl -s -H "Authorization: token $GITEA_TOKEN" \
  http://<gitea-host>/api/v1/orgs/lucidfabrics/actions/runners
```

Restart it:

```bash
ssh -i ~/.ssh/id_ed25519 cicd@<build-vm> \
  'launchctl bootout gui/$(id -u)/gitea-runner.lucidfabrics 2>/dev/null;
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/gitea-runner-lucidfabrics.plist'
```

**Do not "simplify" that LaunchAgent to exec act_runner directly.** macOS 26 Local Network Privacy
blocks a LaunchAgent-spawned binary from reaching the Gitea server and it fails with
`no route to host`, while curl from a shell on the same box works fine. Both runners deliberately
launch inside Terminal.app via `osascript`, because Terminal holds the local-network grant and its
children inherit it.

### Reading job logs

The API endpoint 404s on Gitea 1.27. Go to disk on the Gitea VM:

```bash
ssh root@<gitea-host> \
  'zstdcat /var/lib/gitea/data/data/actions_log/lucidfabrics/dreo-menubar/<xx>/<task_id>.log.zst'
```

Job status codes in `action_run_job`: 1 success, 2 failure, 3 cancelled, 4 skipped, 5 waiting,
6 running, 7 blocked.

## Signing

Two identities, in **persistent** keychains on the build machine. CI only *unlocks* them; it never
imports certificates at build time.

| Keychain | Holds |
|---|---|
| `~/gitea-runner/ci-signing.keychain-db` | Apple Distribution (beeside owns this file) |
| `~/gitea-runner/windbar-signing.keychain-db` | 3rd Party Mac Developer Installer, Developer ID Application |

Their unlock passwords are in the macOS Keychain on the maintainer's machine, and in the
team password store. **They are deliberately not written here: this file is public.**

Both must be unlocked: the `.app` is signed from the first, the `.pkg` from the second.

Why not import per run: on macOS 26 the security daemon **asynchronously SIGKILLs any process that
calls `security set-key-partition-list`**. Importing once into a persistent keychain sidesteps it.

The installer certificate does **not** appear under `security find-identity -p codesigning`, only
under plain `security find-identity`. That is normal, it is a product-signing certificate.

### Rebuilding a lost build machine

```bash
export MATCH_PASSWORD=...                    # see fastlane/.env of lucidpal-ios
export MATCH_GIT_BASIC_AUTHORIZATION=$(printf 'x-access-token:%s' "$(gh auth token)" | base64)
bundle exec fastlane mac restore_signing
```

That pulls both certificates and the provisioning profile from the `windbar` branch of
`lucid-fabrics/lucidpal-certs` and rebuilds the keychain. Verified working: it installs
`Apple Distribution` and `3rd Party Mac Developer Installer` plus the `Windbar MAS` profile.

Also needed on a fresh machine: XcodeGen (already at `~/.local/xcodegen/bin`, **not** on PATH, and
`~/.local/bin` is root-owned so you cannot symlink into it), and rbenv Ruby 3.3.11.

> **Never run `match nuke`, and never port beeside's certificate-prune step into this repo.** It
> keeps only the newest Distribution certificate and revokes the rest, which would break beeside,
> lucidpal and medclear. They all share team KRPUAN3FFA.

## Store metadata

`fastlane/metadata/` is the source of truth. Anything typed into the App Store Connect website is
overwritten on the next release. Edit the files, then:

```bash
bundle exec fastlane mac push_metadata     # listing text only, no build
```

Keyword research method and measured data: `design/ASO.md`. Icon generator: `design/`.

### Traps already paid for

- **Never commit the App Review contact or demo Dreo account.** This repo is published to GitHub on
  every green CD run, so a committed `demo_password.txt` is a live password on the public internet.
  They are Gitea secrets; `write_review_information` in the Fastfile writes
  `fastlane/metadata/review_information/` (gitignored) just before deliver reads it, and
  `cd-github-source` refuses to publish if that path is ever tracked again.

  Set all six in the repo's Gitea secrets (Settings -> Actions -> Secrets), or from the API with
  `printf '%s'` so no newline is appended:

  ```bash
  curl -sS -X PUT -H "Authorization: token $GITEA_TOKEN" -H 'Content-Type: application/json' \
    "http://<gitea-host>/api/v1/repos/lucidfabrics/dreo-menubar/actions/secrets/ASC_REVIEW_PHONE" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"data": sys.argv[1]}))' '+15145550123')"
  ```

  The demo Dreo account needs a fan actually bound to it, or the reviewer sees an empty list.
- **A half-filled `review_information/` is worse than none.** Its mere existence makes deliver write
  the contact record, and Apple then demands the complete set, failing CD with
  `You must provide a value for the attribute 'contactPhone'`. Hence all six or nothing.
- Uploading a build and **selecting** it for a version are different operations. `release` calls
  `attach_latest_build` for this; without it a version sits there unsubmittable with no warning.
- Gitea rejects any secret name starting with `GITHUB_`.
- **Never set a Gitea secret with a here-string (`<<<`).** It appends a newline, which corrupts the
  value *and* defeats Gitea's log masking. That leaked a live token into a job log once.
- macOS App Store profiles live at `profiles/appstore/AppStore_*.provisionprofile` in match storage,
  not `profiles/macappstore/MacAppStore_*`.
- **`deliver` APPENDS screenshots, it does not replace them.** Two `push_metadata` runs left ten
  screenshots on the listing, including the superseded ones, while reporting
  "Successfully uploaded all screenshots". Always verify the count afterwards:

  ```bash
  ./design/verify_screenshots.sh
  ```

  And when cleaning up, **do not trust the screenshot-set listing**. It is cached and keeps
  returning rows that are already deleted, so a naive delete loop spins forever re-deleting ghosts
  and the count never moves. Confirm each screenshot with
  `GET /v1/appScreenshots/{id}` individually; a 404 means it is genuinely gone. That is what the
  verify script does.
