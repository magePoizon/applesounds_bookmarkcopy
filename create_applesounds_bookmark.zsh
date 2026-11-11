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
