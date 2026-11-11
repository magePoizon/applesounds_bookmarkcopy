# Apple Sounds Bookmark Copy

## Overview

This project installs a per-user LaunchAgent that creates the Logic Pro sound-library bookmark for a centrally deployed `Logic Pro Library.bundle`.

The worker currently expects the shared bundle at:

```text
/Users/Shared/Logic Pro Library.bundle
```

It creates the following bookmark for the logged-in user:

```text
~/Library/Application Support/com.apple.musicapps.content/Logic Pro Library.bookmark
```

This project does not download Logic content or create the library bundle. The bundle must already exist at the configured `targetPath` before the worker runs.

## Disclaimers

- This project is independently developed and is not affiliated with, endorsed by, or supported by Apple Inc.
- This project does not provide or make claim to any Apple products.
- The scripts and tools have been verified locally on 5+ devices and on devices managed by Jamf Pro. No other MDMs or deployment methods have been tested.
- The scripts were written manually, but LLMs were used to troubleshoot and sanity-check them.
- The README is 99% AI-generated... I typed the disclaimers... but I have read and verified it!

## Relationship to Loopdown

This project is intended to complement [Loopdown](https://github.com/carlashley/loopdown), but it has no runtime dependency on the Loopdown binary.

Loopdown can deploy supported Logic Pro content to a centralized library. Its documented default destination for modern Logic content is `/Users/Shared/Logic Pro Library.bundle`, which matches this project's current `targetPath`. The expected order is:

1. Install Logic Pro and deploy its required content.
2. Ensure `Logic Pro Library.bundle` exists and is readable at `targetPath`.
3. Run this project's creator script.

See the upstream [Loopdown deployment notes](https://github.com/carlashley/loopdown#deployment-notes) and the [archived post-deployment guidance](https://github.com/carlashley/loopdown/blob/python_archived/README.md#after-deployment-of-logic-pro-12-andor-mainstage-4) for related background.

This implementation is complementary rather than an exact copy of the upstream examples: it creates a minimal per-user bookmark that points to the centralized bundle.

## Requirements

- macOS. Logic Pro is expected for the intended use, but these scripts only verify the bundle path.
- `Logic Pro Library.bundle` already installed at the configured `targetPath`.
- The logged-in user must be able to read the bundle.
- Root privileges to run the creator or uninstaller.
- A logged-in GUI user for immediate LaunchAgent bootstrap. If no user is logged in, the installed LaunchAgent will be picked up at the next login.

## Included Files

| File | Purpose |
| --- | --- |
| `AppleSoundsBookmark_LAandScript_Create.zsh` | Self-contained creator that installs and loads the LaunchAgent and worker. |
| `create_applesounds_bookmark.zsh` | Reference copy of the per-user worker. |
| `com.magepoizon.applesounds.bookmarkcopy.plist` | Reference copy of the LaunchAgent plist. |
| `AppleSoundsBookmark_Uninstall.zsh` | Unloads the LaunchAgent and removes its installed components. |

## Relationship to the Reference Originals

The standalone worker and plist are the reference "originals" for review and maintenance.

The creator does not read or copy those files when it runs. It embeds equivalent plist and worker content in heredocs, then writes the installed copies directly. Any change to either reference original must therefore also be mirrored in the corresponding embedded section of the creator script.

The creator script is the deployment source of truth.

## How It Works

The creator script:

1. Confirms it is running as root.
2. Creates or replaces the installed worker and LaunchAgent plist.
3. Applies the required ownership and permissions.
4. Boots out the current LaunchAgent if it is already loaded.
5. Bootstraps the new plist into the console user's GUI domain.

The LaunchAgent uses `RunAtLoad`, so the worker runs once when bootstrapped or when the user logs in. The worker then:

1. Confirms that `targetPath` exists as a directory.
2. Leaves an existing Logic bookmark unchanged.
3. Creates a minimal macOS bookmark pointing to the shared bundle.
4. Sets the bookmark permissions to `0600`.
5. Records its result in the user's log.

## Installed Components

| Component | Installed location |
| --- | --- |
| LaunchAgent | `/Library/LaunchAgents/com.magepoizon.applesounds.bookmarkcopy.plist` |
| Worker | `/Library/Scripts/magepoizon/create_applesounds_bookmark.zsh` |
| User bookmark | `~/Library/Application Support/com.apple.musicapps.content/Logic Pro Library.bookmark` |
| User log | `~/Library/Logs/magepoizon/apple_bookmark.log` |

## Deployment

### Jamf or another MDM

Run the creator as root after the policy or workflow that installs the shared library bundle. Jamf policies normally already execute scripts as root.

```zsh
/bin/zsh AppleSoundsBookmark_LAandScript_Create.zsh
```

### Local CLI

From this directory, run:

```zsh
sudo /bin/zsh ./AppleSoundsBookmark_LAandScript_Create.zsh
```

To test only the standalone worker, run it as the logged-in user rather than with `sudo`:

```zsh
/bin/zsh ./create_applesounds_bookmark.zsh
```

## Verification

Confirm the shared bundle exists:

```zsh
test -d "/Users/Shared/Logic Pro Library.bundle" && echo "Library bundle found"
```

Check the loaded LaunchAgent for the current user:

```zsh
/bin/launchctl print "gui/$(/usr/bin/id -u)/com.magepoizon.applesounds.bookmarkcopy"
```

Check the bookmark and recent worker log output:

```zsh
test -f "$HOME/Library/Application Support/com.apple.musicapps.content/Logic Pro Library.bookmark"
tail -n 50 "$HOME/Library/Logs/magepoizon/apple_bookmark.log"
```

## Troubleshooting

- The worker redirects its output to the user log, so a manual run may appear silent in Terminal.
- If `targetPath` is absent, the worker logs an error and exits before creating the bookmark.
- `RunAtLoad` provides one attempt per load. If the bundle appears later, reload the LaunchAgent or wait until the next login.
- An existing bookmark is intentionally preserved because Logic may have refreshed it.
- If a different Loopdown `libraryDest` is used, update `targetPath` in both the standalone worker and the embedded worker inside the creator.
- Review Loopdown's current compatibility notes when changing Logic Pro or Loopdown versions.

## Uninstallation

Run the uninstaller as root:

```zsh
sudo /bin/zsh ./AppleSoundsBookmark_Uninstall.zsh
```

The uninstaller boots out the current LaunchAgent, removes the installed plist and worker, and removes the script directory only when it is empty. It intentionally preserves the user's bookmark and log folder.

## License

This project is licensed under the MIT License.

Copyright (c) 2026 Elliot Isaiah Decaro.

You are free to use, modify, distribute, and incorporate this software into your own projects, including commercial projects, provided that the original copyright and license notices are retained.

Logic Pro and macOS are trademarks of Apple Inc.

See the [LICENSE](LICENSE) file for the full license terms.
