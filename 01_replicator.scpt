#!/usr/bin/osascript
on run argv
  set BASEDIR to item 1 of argv as string
  tell application "iTerm2"
    # open first terminal start connect
    tell current session of current tab of current window
        write text "cd " & BASEDIR
        write text "bash ./01-1_startconnect.sh"
        split horizontally with default profile
        split vertically with default profile
    end tell
    # open second terminal and start replicator and consume
    tell second session of current tab of current window
        write text "cd " & BASEDIR
        write text "bash ./01-2_startreplicator.sh"
        split vertically with default profile
    end tell
    # open third terminal and consume
    tell third session of current tab of current window
        write text "cd " & BASEDIR
        write text "bash ./01-3_consumeTarget.sh"
    end tell
    # open forth terminal produce to source
    tell fourth session of current tab of current window
        write text "cd " & BASEDIR
        write text "bash ./01-4_produceSource.sh"
    end tell
  end tell
end run