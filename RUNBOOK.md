# Windbar runbook

Operational notes for the build and release pipeline. For the app itself see `README.md`.

> **This file is public.** Never add a password, key, token, internal hostname or IP address to it.
> Point at where the secret lives instead.

## How a release happens

Merge to `main` on **Gitea** (`<gitea-host>/lucidfabrics/windbar`, which is `origin`).

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
  'zstdcat /var/lib/gitea/data/data/actions_log/lucidfabrics/windbar/<xx>/<task_id>.log.zst'
```

Job status codes in `action_run_job`: 1 success, 2 failure, 3 cancelled, 4 skipped, 5 waiting,
6 running, 7 blocked.

## Signing

Two identities, in **persistent** keychains on the build machine. CI only *unlocks* them; it never
imports certificates at build time.

| Keychain | Unlock password from | Holds |
|---|---|---|
| `~/gitea-runner/ci-signing.keychain-db` | `SIGNING_KEYCHAIN_PASSWORD_SHARED` | Apple Distribution (beeside owns this file) |
| `~/gitea-runner/windbar-signing.keychain-db` | `SIGNING_KEYCHAIN_PASSWORD_WINDBAR` | 3rd Party Mac Developer Installer, Developer ID Application |

Both are Gitea repo secrets, read by `unlock_signing_keychains`. **Never write either value
into this file or the Fastfile: both are published to GitHub.** They were, until 2026-07-30;
the Windbar one has been rotated since, and the `security unlock-keychain` calls now run with
`log: false` so the value cannot reach a job log either.

> The shared keychain's password is still the pre-rotation value, because beeside's Fastfile
> hardcodes the same string in a different repo. Rotating it means changing both at once.

Both must be unlocked: the `.app` is signed from the first, the `.pkg` from the second.

Why not import per run: on macOS 26 the security daemon **asynchronously SIGKILLs any process that
calls `security set-key-partition-list`**. Importing once into a persistent keychain sidesteps it.

The installer certificate does **not** appear under `security find-identity -p codesigning`, only
under plain `security find-identity`. That is normal, it is a product-signing certificate.

### Rebuilding a lost build machine

Copy `fastlane/.env.example` to `fastlane/.env` and fill in `MATCH_GIT_URL`, `MATCH_PASSWORD` and
`MATCH_GIT_BASIC_AUTHORIZATION` (fastlane loads `.env` automatically), or export them directly:

```bash
export MATCH_GIT_URL=http://<gitea-host>/lucidfabrics/apple-certs   # bare LAN IP, ask the team
export MATCH_PASSWORD=...                    # see fastlane/.env of lucidpal-ios
export MATCH_GIT_BASIC_AUTHORIZATION=$(printf 'lucidfabrics:%s' "$(security find-generic-password -s gitea-lucidfabrics-token -w)" | base64)
bundle exec fastlane mac restore_signing
```

That pulls both certificates and the provisioning profile from the `windbar` branch of the certs
repo (self-hosted Gitea, moved from GitHub 2026-07-31) and rebuilds the keychain.
`fastlane/Matchfile` deliberately does not hardcode `MATCH_GIT_URL`: this repo is public on GitHub
and the Gitea host is a bare IP with no DNS name, so there is no reason to publish it. Verified
working: it installs `Apple Distribution` and `3rd Party Mac Developer Installer` plus the
`Windbar MAS` profile.

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

### Cutting a release

`main` is always shippable. A release is a deliberate version bump, because **every
marketing version costs an App Store review cycle**, and Apple caps build uploads
per app per day (we burned 21 in one day on an unchanged 1.0.0 and hit a hard
`Upload limit reached. Please wait 1 day`).

So merging to main publishes source and the DMG, but only a **change to
`MARKETING_VERSION` in `project.yml`** uploads a build to App Store Connect.

```bash
bundle exec fastlane mac bump version:1.0.1   # edits project.yml, refuses to go backwards
$EDITOR fastlane/metadata/en-US/release_notes.txt
# PR titled "chore(release): 1.0.1" -> merge -> CD uploads and attaches the build
```

To rebuild a binary for a version that already has one (a fix before first release,
say), do not bump. Run the workflow by hand with `force_appstore`:

```bash
curl -sS -X POST -H "Authorization: token $GITEA_TOKEN" -H 'Content-Type: application/json' \
  "http://<gitea-host>/api/v1/repos/lucidfabrics/windbar/actions/workflows/ci-cd.yml/dispatches" \
  -d '{"ref":"main","inputs":{"force_appstore":"true"}}'
```

Submitting stays manual in App Store Connect. The pipeline never presses Submit.

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
    "http://<gitea-host>/api/v1/repos/lucidfabrics/windbar/actions/secrets/ASC_REVIEW_PHONE" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"data": sys.argv[1]}))' '+15145550123')"
  ```

  The demo Dreo account needs a fan actually bound to it, or the reviewer sees an empty list.
- **A half-filled `review_information/` is worse than none.** Its mere existence makes deliver write
  the contact record, and Apple then demands the complete set, failing CD with
  `You must provide a value for the attribute 'contactPhone'`. Hence all six or nothing.
- Uploading a build and **selecting** it for a version are different operations. `release` calls
  `attach_latest_build` for this; without it a version sits there unsubmittable with no warning.
- **Rotating a signing keychain password needs the build VM rebooted.** `security
  set-keychain-password` over ssh rewrites the file, and ssh can immediately unlock it with the new
  password - but the GUI login session where the runners live keeps the old keychain open, and from
  there `security unlock-keychain` then fails for **every** password, new and old, with the
  misleading `The user name or passphrase you entered is not correct` (exit 51). Same file, same
  inode. Killing and relaunching the runner does not help, and `killall securityd` as `cicd` is a
  no-op because it is root-owned. `sudo shutdown -r now` fixes it; auto-login is on and both runners
  come back by themselves. Verify with a `workflow_dispatch` before assuming the secret is wrong.
- **`workflow_dispatch` on a branch publishes that branch to GitHub.** `cd-github-source` pushes
  `HEAD:refs/heads/main`, so dispatching a debug branch put debug commits on the public repo and it
  took a force push to undo. Dispatch on `main` only.
- **Apple caps build uploads per app per day**, somewhere around 20. The error is
  `Validation failed (409) Upload limit reached`. It is not a TestFlight limit, it applies to any
  build upload. This is why cd-appstore is gated on a version change rather than running on every
  merge, and why the GitHub jobs no longer sit behind it: an Apple quota has nothing to do with
  whether the source can be published.
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
