fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac restore_signing

```sh
[bundle exec] fastlane mac restore_signing
```

Rebuild the signing keychains on a fresh build machine. Recovery only, not CI.

### mac build_check

```sh
[bundle exec] fastlane mac build_check
```

PR gate: build and run the unit tests. No signing, no upload.

### mac release

```sh
[bundle exec] fastlane mac release
```

Build, sign and upload a build to App Store Connect. Does not submit for review.

### mac release_dmg

```sh
[bundle exec] fastlane mac release_dmg
```

Build a Developer ID signed, notarized DMG for direct download. Not for the App Store.

### mac attach_latest_build

```sh
[bundle exec] fastlane mac attach_latest_build
```

Attach the newest processed build to the current version.

### mac push_metadata

```sh
[bundle exec] fastlane mac push_metadata
```

Push the store listing text only. No build, no submission.

### mac submission_status

```sh
[bundle exec] fastlane mac submission_status
```

Report which submission requirements are still outstanding.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
