#!/bin/zsh

# Created by Elliot Isaiah Decaro 03Aug2026 - Updated 10Nov2026

# SPDX-FileCopyrightText: 2026 Elliot Isaiah Decaro
# SPDX-License-Identifier: MIT

# Creates a LaunchAgent that creates the Logic Pro Library bookmark
# in logged-in user's library, if not already present.

#--------------------------------------------
# Parent values
launchType="Agent"
plistName="applesounds.bookmarkcopy"
plistPath="/Library/Launch${launchType}s/com.magepoizon.${plistName}.plist"

scriptName="create_applesounds_bookmark.zsh"
scriptFolder="/Library/Scripts/magepoizon"
scriptPath="${scriptFolder}/${scriptName}"

#--------------------------------------------
# Prerequisites

if (( EUID != 0 )); then
	echo "ERROR: This installer must be run as root."
	exit 1
fi

if ! mkdir -p "$scriptFolder"; then
	echo "ERROR: Could not create Scripts folder at $scriptFolder"
	exit 1
fi

if [[ -f "$scriptPath" ]]; then
	echo "$scriptPath exists...removing. It will be recreated."
	rm -f "$scriptPath"
else
	echo "$scriptPath does not exist. It will be created."
fi

if [[ -f "$plistPath" ]]; then
	echo "$plistPath exists...removing. It will be recreated."
	rm -f "$plistPath"
else
	echo "No previous LaunchAgent version found."
fi

#--------------------------------------------
# Create the LaunchAgent plist

echo "Creating Launch${launchType} plist at $plistPath..."
cat <<EOF > "$plistPath"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.magepoizon.$plistName</string>

	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>$scriptPath</string>
	</array>

	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
EOF

echo "Setting permissions on Launch${launchType}..."
chown root:wheel "$plistPath"
chmod 644 "$plistPath"

#--------------------------------------------
# Create the copy script

echo "Creating script at $scriptPath..."
cat <<'EOF' > "$scriptPath"
#!/bin/zsh

# Created by Elliot Isaiah Decaro 31Jul2026 - Updated 10Nov2026
# Creates a template bookmark for the apple loops sounds.

# SPDX-FileCopyrightText: 2026 Elliot Isaiah Decaro
# SPDX-License-Identifier: MIT

targetPath="/Users/Shared/Logic Pro Library.bundle"
bookmarkDirectory="$HOME/Library/Application Support/com.apple.musicapps.content"
bookmarkPath="$bookmarkDirectory/Logic Pro Library.bookmark"
logLocation="$HOME/Library/Logs/magepoizon"
logFile="${logLocation}/apple_bookmark.log"
timestampFormat='%d-%m-%y--%H:%M:%S'

#===============================================================================
# Logging and exits
#===============================================================================

if ! /bin/mkdir -p "$logLocation"; then
  print -u2 -- "Could not create log directory at $logLocation."
  exit 1
fi

exec >> "$logFile" 2>&1

log() {
  printf '%s %s\n' "$(date +"${timestampFormat}")" "$*"
}

log_error () {
  printf '%s %s\n' "$(date +"${timestampFormat}")" "ERROR: $*"
}

clean_exit () {
    echo "=================END=================="
    exit 0
}

error_exit () {
    echo "=================END WITH ERROR=================="
    exit 1
}

#===============================================================================
# Run
#===============================================================================

echo "=================START=================="

# The shared library must already exist
if [[ ! -d "$targetPath" ]]; then
    log_error "Logic library not found: $targetPath"
    log "Check targetPath variable or"
    log "Create Logic Pro Library.bundle at "$targetPath""
    log "Exiting...."
    error_exit
else
    log "Logic Library found: "$targetPath""
fi

# Do not overwrite a bookmark that Logic may have subsequently refreshed
if [[ -f "$bookmarkPath" ]]; then
    log "Bookmark exists $bookmarkPath"
    log "Exiting..."
    clean_exit
fi

/bin/mkdir -p "$bookmarkDirectory"

/usr/bin/osascript -l JavaScript - "$targetPath" "$bookmarkPath" <<'JXA'
ObjC.import("Foundation")

function run(arguments) {
    var targetPath = arguments[0]
    var bookmarkPath = arguments[1]
    var objcNil = $()

    // Convert the target bundle path into a file URL
    var targetURL =
        $.NSURL.fileURLWithPathIsDirectory(targetPath, true)

    // Encode the file URL as a minimal macOS bookmark
    var bookmarkData =
        targetURL.bookmarkDataWithOptionsIncludingResourceValuesForKeysRelativeToURLError(
            0x200,
            objcNil,
            objcNil,
            objcNil
        )

    // Write the bookmark to the user's Logic content folder
    var written =
        bookmarkData.writeToFileAtomically(bookmarkPath, true)

    if (!written) {
        throw new Error("Could not write bookmark: " + bookmarkPath)
    }
}
JXA

if [[ $? -ne 0 || ! -f "$bookmarkPath" ]]; then
    log_error "Failed to create Logic bookmark"
    error_exit
else
    if ! /bin/chmod 600 "$bookmarkPath"; then
        log_error "Failed to set bookmark permissions: $bookmarkPath"
        error_exit
    fi
    log "Created minimal Logic bookmark: $bookmarkPath"
    clean_exit
fi
EOF

echo "Setting permissions on $scriptPath"
chown root:wheel "$scriptPath"
chmod 755 "$scriptPath"

#--------------------------------------------
# Load the LaunchAgent for the console user

consoleUser=$(/usr/bin/stat -f %Su /dev/console)
if [[ -n "$consoleUser" && "$consoleUser" != "root" && "$consoleUser" != "loginwindow" ]]; then
	consoleUid=$(/usr/bin/id -u "$consoleUser")
	launchDomain="gui/${consoleUid}"
	launchLabel="com.magepoizon.${plistName}"
	launchTarget="${launchDomain}/${launchLabel}"

	if /bin/launchctl print "$launchTarget" &>/dev/null; then
		echo "Booting out existing LaunchAgent: $launchLabel"
		if ! /bin/launchctl bootout "$launchTarget"; then
			echo "ERROR: Could not boot out existing LaunchAgent: $launchLabel"
			exit 1
		fi
	fi

	echo "Bootstrapping LaunchAgent: $launchLabel"
	if ! /bin/launchctl bootstrap "$launchDomain" "$plistPath"; then
		echo "ERROR: Could not bootstrap LaunchAgent: $launchLabel"
		exit 1
	fi
else
	echo "No logged-in user detected. Skipping LaunchAgent bootout/bootstrap."
fi

#--------------------------------------------
# Checks and verification

echo "------------------------------------------"

if [[ -f "$scriptPath" ]]; then
	echo "$scriptPath created successfully"
else
	echo "Error: $scriptPath was not created."
	exit 1
fi

if [[ -f "$plistPath" ]]; then
	echo "$plistPath created successfully"
else
	echo "$plistPath was not created."
	exit 1
fi

echo "=================Finished================="
exit 0
