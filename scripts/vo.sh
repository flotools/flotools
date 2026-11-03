#!/bin/bash
# VoiceOver helpers for live tests, through VoiceOver's AppleScript dictionary
# (`sdef /System/Library/CoreServices/VoiceOver.app`). Text arguments reach
# AppleScript as `argv`, never as script source, so any text is safe.
#
# Usage: scripts/vo.sh <command> [arguments]
#   cursor                 text under the VoiceOver cursor
#   bounds                 VoiceOver cursor bounds: left, top, right, bottom
#   focus                  text under the keyboard cursor
#   phrase                 the last phrase VoiceOver spoke
#   move <where>           move the VoiceOver cursor, then print the text under it.
#                          <where>: left right up down in out first last
#                          dock desktop menubar status spotlight linked
#   walk <where> [n]       move n times (default 5), printing each item
#   seek <text> [where] [n]
#                          move (default right, at most n = 40 times) until the
#                          text under the cursor contains <text>; fails if not found
#   action                 VO+Space on the VoiceOver cursor
#   select                 VO+Cmd+Space (select the item)
#   click [1|2|3] [left|right]
#                          click the mouse where it is
#   mouse                  print the mouse position
#   mouse <x> <y>          move the mouse
#   say <text>             speak text
#   spell <text> [phonetic]
#   open <menu>            commands, items, windows, apps, help, context, web,
#                          utility, history, window-overview, workspace-overview
#   close-menu             close open VoiceOver menus
#   run <command name>     run any VoiceOver command by its English name, lower
#                          case, for example "move left" or "read all"
#   commands [filter]      list the command names `run` accepts
#   caption on|off         show or hide the caption window

set -euo pipefail

COMMAND_MAP=/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Resources/SCRStringsToCommandsMap.scrconfig

# Runs AppleScript source with the remaining arguments as argv.
vo() {
    local source=$1
    shift
    osascript - "$@" <<<"on run argv
tell application \"VoiceOver\"
$source
end tell
end run"
}

cursor_text() { vo 'return text under cursor of vo cursor'; }

# The AppleScript form of a move target; only these fixed words reach the script source.
move_source() {
    case $1 in
        left | right | up | down) echo "tell vo cursor to move $1" ;;
        in) echo 'tell vo cursor to move into item' ;;
        out) echo 'tell vo cursor to move out of item' ;;
        first) echo 'tell vo cursor to move to first item' ;;
        last) echo 'tell vo cursor to move to last item' ;;
        dock | desktop | menubar | spotlight) echo "tell vo cursor to move to $1" ;;
        status) echo 'tell vo cursor to move to status menu' ;;
        linked) echo 'tell vo cursor to move to linked item' ;;
        *) echo "unknown move target: $1" >&2; return 2 ;;
    esac
}

move_once() {
    local source
    source=$(move_source "$1")
    vo "$source" >/dev/null
    sleep 0.3
}

case ${1:-} in
    cursor) cursor_text ;;
    bounds) vo 'return bounds of vo cursor' ;;
    focus) vo 'return text under cursor of keyboard cursor' ;;
    phrase) vo 'return content of last phrase' ;;
    move)
        move_once "${2:?move needs a target}"
        cursor_text
        ;;
    walk)
        where=${2:?walk needs a target}
        for _ in $(seq "${3:-5}"); do
            move_once "$where"
            cursor_text
        done
        ;;
    seek)
        text=${2:?seek needs text}
        where=${3:-right}
        for _ in $(seq "${4:-40}"); do
            current=$(cursor_text)
            if [[ $current == *"$text"* ]]; then echo "$current"; exit 0; fi
            move_once "$where"
        done
        current=$(cursor_text)
        if [[ $current == *"$text"* ]]; then echo "$current"; exit 0; fi
        echo "not found: $text (cursor on: $current)" >&2
        exit 1
        ;;
    action) vo 'tell vo cursor to perform action' ;;
    select) vo 'tell vo cursor to select' ;;
    click)
        case ${2:-1} in 1) count=once ;; 2) count=twice ;; 3) count=thrice ;; *) echo "click count: 1, 2 or 3" >&2; exit 2 ;; esac
        case ${3:-left} in left) button='left button' ;; right) button='right button' ;; *) echo "click button: left or right" >&2; exit 2 ;; esac
        vo "tell mouse cursor to click $count with $button"
        ;;
    mouse)
        if [[ $# -ge 3 ]]; then
            vo 'set position of mouse cursor to {(item 1 of argv) as number, (item 2 of argv) as number}' "$2" "$3"
        else
            vo 'return position of mouse cursor'
        fi
        ;;
    say) vo 'output (item 1 of argv)' "${2:?say needs text}" ;;
    spell)
        case ${3:-alphabetic} in alphabetic) kind='alphabetic spelling' ;; phonetic) kind='phonetic spelling' ;; *) echo "spell: alphabetic or phonetic" >&2; exit 2 ;; esac
        vo "output (item 1 of argv) with $kind" "${2:?spell needs text}"
        ;;
    open)
        case ${2:?open needs a menu} in
            commands) target='commands menu' ;;
            items) target='item chooser' ;;
            windows) target='windows menu' ;;
            apps) target='applications menu' ;;
            help) target='help menu' ;;
            context) target='contextual menu' ;;
            web) target='web menu' ;;
            utility) target='utility' ;;
            history) target='announcement history' ;;
            window-overview) target='window overview' ;;
            workspace-overview) target='workspace overview' ;;
            *) echo "unknown menu: $2" >&2; exit 2 ;;
        esac
        vo "open $target"
        ;;
    close-menu) vo 'close menu' ;;
    run) vo 'tell commander to perform command (item 1 of argv)' "${2:?run needs a command name}" ;;
    commands)
        plutil -convert json -o - "$COMMAND_MAP" | /usr/bin/python3 -c 'import json, sys; print("\n".join(sorted(json.load(sys.stdin))))' | grep -i -- "${2:-}"
        ;;
    caption)
        case ${2:-} in on) value=true ;; off) value=false ;; *) echo "caption: on or off" >&2; exit 2 ;; esac
        vo "set enabled of caption window to $value"
        ;;
    *)
        sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
