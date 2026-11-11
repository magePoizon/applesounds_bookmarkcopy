#!/bin/zsh

# Created by Elliot Isaiah Decaro 10Nov2026

# SPDX-FileCopyrightText: 2026 Elliot Isaiah Decaro
# SPDX-License-Identifier: MIT

# Removes the Apple Sounds bookmark LaunchAgent and its worker script.
# Per-user log folders are intentionally left in place.
# The generated Logic bookmark is preserved because Logic may have refreshed it.

launchLabel="com.magepoizon.applesounds.bookmarkcopy"
plistPath="/Library/LaunchAgents/${launchLabel}.plist"
scriptFolder="/Library/Scripts/magepoizon"
scriptPath="${scriptFolder}/create_applesounds_bookmark.zsh"

if (( EUID != 0 )); then
	echo "ERROR: This uninstaller must be run as root."
	exit 1
fi

consoleUser=$(/usr/bin/stat -f %Su /dev/console)
if [[ -n "$consoleUser" && "$consoleUser" != "root" && "$consoleUser" != "loginwindow" ]]; then
	consoleUid=$(/usr/bin/id -u "$consoleUser")
	launchTarget="gui/${consoleUid}/${launchLabel}"

	if /bin/launchctl print "$launchTarget" &>/dev/null; then
		echo "Booting out LaunchAgent: $launchLabel"
		if ! /bin/launchctl bootout "$launchTarget"; then
			echo "ERROR: Could not boot out LaunchAgent: $launchLabel"
			exit 1
		fi
	fi
fi

for component in "$plistPath" "$scriptPath"; do
	if [[ -e "$component" ]]; then
		echo "Removing $component"
		if ! /bin/rm -f "$component"; then
			echo "ERROR: Could not remove $component"
			exit 1
		fi
	fi
done

/bin/rmdir "$scriptFolder" 2>/dev/null || true

echo "Uninstall complete."
exit 0
