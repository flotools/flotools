---
layout: page
title: Getting Started
permalink: /Flo Tools/
---

<script src="/js/audio.js"></script>
<audio controls id="audioFloTools1.0" onPlaying="playing(this)" onPause="pauseing(this)" onEnded="ending(this)">
<source src="/media/Flo Tools 1.0.m4a" type="audio/mp4">
Your browser does not support html5 audio.
</audio>

Music by [Frank Senior](http://www.franksenior.com/)

## Welcome to Flo Tools!

This open source product is a series of UI scripts for VoiceOver designed to enhance the accessibility of Pro Tools for visually-impaired users   by streamlining and automating tasks to dramatically improve workflows.

This Read Me file is divided into headings for easier screen reader navigation. Read on to get started.

## Acknowledgements

Flo Tools was first developed as a concept by Chi Kim and Rocco Fiorentino, in the [Assistive Music Technology Lab](http://berklee.edu/amtlab) at Berklee College of Music. After the initial project at Berklee was completed, Slau Halatyn joined the team, and the group worked together to continue developing the scripts outside of the classroom. Many thanks to Chi Kim for his countless hours of creative scripting, to Rocco Fiorentino for his scripting contributions and writing of documentation, and to Slau Halatyn, for his invaluable feedback and expert knowledge in Pro Tools. We sincerely hope Flo Tools will enhance the work flow of Pro Tools users with visual impairments!

## Disclaimer and License

Support is only available through a volunteer based community.

Flo Tools  
Copyright (C) 2016 Chi Kim  
Copyright (C) 2016 Rocco Fiorentino  
Copyright (C) 2016 Slau Halatyn

Flo Tools is free software. You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your discretion) any later version.

Flo Tools is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY, expressed or implied, of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the [GNU General Public License](http://www.gnu.org/licenses/) for more details.

## Table of Contents

* [Download](#download)
* [System REquirements](#systemrequirements)
* [Installation](#installation)
* [Using Flo Tools](#usingflotools)
* [Misc](#misc)
* [Change Log](#changelog)

<div id='download'/>
## Download

You can [download Flo Tools](http://flotools.org/download/) from flotools.org.

Once downloaded, this  zip file, referenced in this read me, will automatically decompress itself into a folder on Mac OS. Please refer to this downloaded folder, called "Flo Tools Master", when reading this document.

<div id='systemrequirements'/>
## System Requirements

Flo Tools supports Mac OS version 10.10 or later, and Pro Tools version 12.3 or later. Pro Tools First has limited support at this time from version 12.8.2 or higher. Earlier versions of Mac OS, Pro Tools, and Pro Tools First may provide limited functionality with Flo Tools, but have not been tested and are not guaranteed to function correctly.

<div id='installation'/>
## Installation
Flo Tools relies on a third party program called Keyboard Maestro to perform its functions. Download instructions for Keyboard Maestro are below.

### Keyboard Maestro Installation

1. Go to the Keyboard Maestro homepage by clicking [here](https://www.keyboardmaestro.com/) and download the Keyboard Maestro application from the website.

2. Copy the Keyboard Maestro application from the downloads folder to the applications folder. From there, open Keyboard Maestro.

If using Keyboard Maestro for the first time, please check the boxes for both Keyboard Maestro and Keyboard Maestro Engine in system preferences, under "Security and Privacy", "Accessibility." These must be enabled for Flo Tools to function correctly.


### Important Notes about Keyboard Maestro

Keyboard Maestro contains some default macro groups that conflict with common Mac OS keyboard shortcuts. These are found in the switcher group, and clipboard group, which are disabled by default after installing FloTools. If you choose to reenable them, you can do so by selecting each group and pressing the enable button.

Keyboard Maestro is limited by a 30-day trial period. After this time, a purchase of a one-time license is required to continue using the program, and subsequently, Flo Tools.

More information about purchasing a license can be found [here.](https://wiki.keyboardmaestro.com/manual/Purchase)Keyboard Maestro occasionally provides spoken notifications to alert you to tasks it's performing in the background. If these become bothersome, you can turn them off by going to system preferences, notifications, and choosing Keyboard Maestro Engine from the table. Then select "none" under Alert Style.

### Flo Tools Installation

To install Flo Tools, go to the provided zip file, and open the application called "Flo Tools Installer". Follow the on-screen prompts to guide you through installation.

For the scripts to run properly, open Keyboard Maestro Preferences, and under the general tab, check the box labeled, "Start Keyboard Maestro Engine at log-in." Note that the Keyboard Maestro window does not need to be open for the scripts to run.

### Optimizing Pro Tools for Flo Tools

For all functions of Flo Tools to work as expected, it is recommended to apply the following settings and window configurations  in Pro Tools:

1. The checkbox labeled "Allow VoiceOver to be controlled with AppleScript" in the General pane of VoiceOver Utility should be checked.
2. The Mix and Edit windows should both be open at all times.
3. The "Track List Table" in the mix window should always be shown.
4. Within the Display tab of the Pro Tools Preferences dialog,  the check boxes labeled "function" and "details" under basics, tooltips, should be checked.
5. Track Heights should be set to "medium" for optimal Flo Tools performance.
6. In the toolbar menu of the edit window, the "Transport", "midi Controls", and "expanded transport" settings should be checked.
7. If the default keyboard is not set to "US" in System Preferences, Keyboards, input sources, please add it to the list of input sources, and switch to it when using Flo Tools.


Pro Tools includes a Keyboard Focus mode, within which commands are issued through single letter keystrokes. When Keyboard Focus mode is not active, these same commands can be issued by adding the Control key as a modifier. Since certain Flo Tools commands are issued with single letter taps and double-taps, it is recommended that users avoid the Keyboard Focus mode in Pro Tools. Although Flo Tools will function as expected in Keyboard Focus mode, users may inadvertently press a keystroke not used by Flo Tools and pass unwanted commands through to Pro Tools, yielding unexpected results. To allow use of the  Control modifier instead of keyboard focus mode for Pro Tools, and make single letter commands available for Flo Tools, move VoiceOver focus either on the Clips list by pressing Command-Option-2, or the Groups List by pressing Command-Option-3 while in the edit window.


<div id='usingflotools'/>
## Using Flo Tools

### Auditory Feedback

Flo Tools uses 2 distinct sounds to provide auditory feedback when it is performing a task. The first is [This Sound](Tink.aiff), which tells a user that something has been toggled, such as solo on or off.

The second is [This Sound](Pop.aiff), which signals that something is in process and the user needs to wait for Flo Tools to complete a task. An example of this would be deselecting all tracks in a large session.


### Commands

Flo Tools is organized into 22 macro groups inside of Keyboard Maestro. Below is a list of Flo Tools commands, and their associated functions, separated by their respective groups.

#### Flo Tools

The Flo Tools group of commands is always active while Pro Tools is the application in focus, and applies to the entire session.

Where two actions are listed, double-tapping the key will perform the second action.

* Speak/Edit selection start: Command+f1
* Speak/Edit Selection End: Command+f2
* Speak/Edit Selection Length: Command+f3
* Speak/Edit main counter: Command+f4
* Select main counter:	Command+Option+f4
* Speak/Edit Sub Counter:	Command+f6
* Select Sub Counter:	Command+Option+f6
* Speak/Edit Nudge Value:	Command+f7
* Select Nudge Value:	Command+Option+f7
* Speak Grid Value:	Command+f8
* Select Grid Value:	Command+Option+f8
* Speak/Edit Pre-Roll Amount:	Command+f9
* Speak/Edit Post-Roll Amount:	Command+f10
* Speak/Edit Tempo:	Command+f11
* Close All Floating Windows: Command+Option+w
* Speak Shown Tracks, Show Track List Pop-up Menu:	Option+Shift+w
* List Shown Tracks:	Control+Shift+w
* Speak Hidden Tracks, Show Track List Pop-up Menu:	Option+Shift+h
* List Hidden Tracks:	Control+Shift+h
* Speak Selected Tracks, Deselect All Tracks: Option+Shift+t
* List Selected Tracks, List Unselected Tracks:	Control+Shift+t
* Speak Input Monitor-Enabled Tracks, Disable Input Monitor On All Tracks: Option+Shift+k
* List Input Monitor-Enabled Tracks, List Input Monitor-Disabled  Tracks:	Control+Shift+k
* Beta: Speak Record-Enabled Tracks, Disarm All Record Enabled Tracks: Option+Shift+r
* Beta: List Record-Enabled Tracks, List Record-Disabled Tracks:	Control+Shift+r
* Speak Soloed Tracks, UnSolo All Tracks: Option+Shift+s
* List Soloed Tracks, List Unsoloed Tracks:	Control+Shift+s
* Speak Muted Tracks, UnMute All Tracks: Option+Shift+m
* List Muted Tracks, List Unmuted Tracks:	Control+Shift+m
 * Note that this shortcut overrides one of the Pro Tools shortcuts for "Nudge the Selected Clip Gain Back." Use either Control+Shift+minus or Control+Shift+comma instead
* Speak Record Safe Tracks: Command+Option+Shift+r
* Speak Solo Safe Tracks: Command+Option+Shift+s
* Speak tracks who’s level is greater then or equal to 0DB: Option+Shift+0
* Speak and select Previous Playlist: Shift + Up Arrow
* Speak and select Next Playlist: Shift+Down Arrow
* Speak and Select Previous Track: Control+P
* Speak and select Next Track: Control+; (semicolon)
* Speak and add Previous Track to Selection: Control+Shift+P
* Speak and add Next Track to Selection: Control+Shift+;(semicolon)
* Speak and retract Selection from Top Track: Control+Option+P (must be passed through)
*Speak and retract Selection from Bottom Track: Control+Option+; (semicolon) (must be passed through)
* Speak/Toggle Metronome:	Option+num pad 7
* Speak/Toggle Count In:	Option+num pad8
* Speak/Toggle Midi Merge:	Option+num pad 9
* Speak/Toggle Link Timeline and Edit Selection: Shift+/
* Speak/Toggle Tab to Transients:	Command+Option+Tab
* Speak/Toggle Insertion Follows Playback:	Control+n
* Speak/select shufflemode:	f1
* Speak/Select Slip Mode:	f2
* Speak/Select Spot Mode:	f3
* Speak/Select Grid Mode (and Toggle Absolute/Relative Grid Mode):	f4
* Speak/toggle quickpunch:	Command+Shift+p
* Speak/Toggle loop playback:	Command+Shift+l
* Speak/Toggle Loop Record:	Option+l
* Speak/Toggle Pre/Post-Roll:	Command+K
* Select Clip Keyboard Focus: Command+Option+2
* Select Group Keyboard Focus: Command+Option+3
* Select Timeline Keyboard Focus: Command+Option+1
* Toggle Input Monitor: Option+K
* Mark clip to drag:	Command+Option+Shift+, (comma)
* Drag clip:	Command+Option+Shift+. (period)
* Resize track list Table:	Command+Control+Shift+t
* Resize clip list table:	Command+Control+Shift+c
* Speak Selected Clips:	Option+Shift+p


#### Flo Tools Global

The Flo Tools Global group is mentioned here only for reference purposes, and contains various macros for Flo Tools to function correctly.

This group also contains a macro that allows Flo Tools to run only while the VoiceOver screenreader is active. This is to avoid possible conflicts with other sighted users of the computer.

#### Flo Tools Inspector

The Flo Tools Inspector group of commands is inactive by default, but can be toggled on and off. Inspector commands only apply to the track on which VoiceOver is currently focused . This means the track name must be under the VoiceOver cursor, and the user should not be interacting with anything inside the track.

Note: The inspector must be disabled to use first-letter navigation in any pop-up menus, menu bars, or the doc while Pro Tools is running.

Where 2 actions are listed, double tapping the key will perform the second action.

* Toggle Inspector on or off: /
* Speak Track Name, Select Track Pop-Up Menu: t
* Speak/Open Inserts A through J:	1 through 0 on the numbers row
* Assign Inserts A through J:	Command+1 through 0 on the numbers row
 * Note that Command+1 through 5 are also shortcuts for selecting Pro Tools presets. Turn off the inspector to access these shortcuts. See the Pro Tools Keyboard Shortcuts pdf for more details.
 * Note that, when the Flo Tools Inspector is on,  the macro for assigning Insert J (Command+0) overrides the Pro Tools shortcut for "Quantize Clip to Nearest Grid." Use the Clip menu or turn off the Flo Tools Inspector to pass through the shortcut.
* Speak/Open Sends A through J:	Control+1 through 0 on the numbers row
* Assign Sends A through J:	Command+Control+1 through 0 on the numbers row
* Speak/Select Track Input: i
* Speak/Select Instrument Input: Option+i
* Speak/Select Track Output: o
* Speak/Select Instrument Output: Option+o
* Beta: Speak/Select Automation Mode: a
* Speak/Select Group: g
* Speak/Reset Pan: n
* Adjust pan value for mono track: Command+Control+left-or-right-arrows
* Adjust pan value for stereo Track: Command+Control+left-or-right-arrows for left pan, add shift to adjust right pan
* Speak/Toggle Input Monitor: k
* Speak/Toggle Record State: r
* Speak/Toggle Solo: s
* Speak/Toggle Mute: m
* Speak/Toggle Instrument Mute: Option+m
* Speak/Reset Volume Fader: v
* Speak/Reset Instrument Volume Fader: Option+v
* Adjust Volume Fader: Command+Control+up-or-down-arrows
* Adjust Instrument Volume Fader: Command+Option+up-or-down-arrows
* Speak Level Meter, Toggle Level Meter Monitor:	l
* Speak/Reset Peak Meter: p
* Speak Gain Reduction Meter, Toggle Gain Reduction Meter Monitor:	semicolon
* Speak Gain Reduction Meter Maximum:	Shift+semicolon
* Speak/Edit Comments: c
* Track Options Menu: h
* Speak/Select Playlist: \
* Beta: Speak/Select Track View: w
* Speak/Toggle Freeze Status: f
* Speak/Select Timebase: b
* Beta: Speak/Select Elastic Audio Plugin: e

#### Flo Mouse

The Flo Mouse group is global, so these commands will work system-wide when the group is turned on. Note that both the Flo Mouse and Flo Num Pad Macro Groups are no longer automatically installed with Flo Tools, and must be downloaded separately.

* Activate Flo Mouse: Command+Slash
* Option-Click:	Option+` (accent)
* Option+Shift-Click:	Option+Shift+` (accent)
* Command-Click:	Command+` (accent)
* Shift-Click:	Shift+` (accent)
* Control-Click:	Control+` (accent)
* Command+Control-Click:	Command+Control+` (accent)
* Command+Option-Click:	Command+Option+` (accent)
* Command+Option+Control-Click:	Command+Option+Control+` (accent) (must be passed through)
* Command+Shift-Click:	Command+Shift+` (accent)
* Command+Option+Shift-Click:	Command+Option+Shift+` (accent)
* Control+Shift-Click:	Control+Shift+` (accent)
* Control+Option-Click:	Control+Option+` (accent) (must be passed through)
* Control+Option+Shift-Click:	Control+Option+Shift+` (accent) (must be passed through)
* Control+Option+Command+Shift-Click:	Control+Option+Command+Shift+` (accent) (must be passed through)* Command+Control+Shift-Click:	Command+Control+Shift+` (accent) (must be passed through)
* Copy/Speak Mouse Coordinates Relative to Front Window: Command+Option+Shift+c
* Copy/speak mouse coordinates relative to screen:	Command+Option+Shift+a
* Move mouse up: Command+Option+Shift+up-arrow
* Move mouse down: Command+Option+Shift+down-arrow
* Move mouse left: Command+Option+Shift+left-arrow
* Move mouse right: Command+Option+Shift+right-arrow
* Move Mouse to middle of Current Window: Command+Option+Shift+M
* Move Mouse to Coordinates Relative  to Current Window: Command+Option+Shift+W
* Zoom/Maximize Window: Command+Option+Shift+z

#### Flo Tools Midi Event List

This macro group allows easier navigation and editing of the Midi Event List using Flo Tools, and contains the following commands:

* Speak/Edit Pitch for Selected Note:	Option+p
* Speak/Edit Attack Velocity for Selected Note:	Option+a
* Speak/Edit Release Velocity for Selected Note:	Option+r
* Move to next Column:	Control+right arrow
* Move to previous Column:	Control+left arrow
* Edit Event:	Control+Command+Return


#### Flo Num Pad

Flo Tools provides a key remapping using the keyboard as a standard num pad. This num pad group of remappings can be used system-wide, and can be toggled on and off by pressing Control+/.

Note that the inspector and num pad groups cannot be active at the same time. If the inspector is turned on, the num pad group is automatically turned off, and If the num pad group is turned on, the inspector is automatically turned off.

Below is the list of remapped keyboard keys when using the num pad group.


* m: 0
* j: 1
* k: 2
* l: 3
* u: 4
* i: 5
* o: 6
* 7, 8, 9, and the period key on the qwerty keyboard are mapped to num pad 7, 8, 9 and period.
* Semicolon: *
* apostrophe: /
* Left bracket: minus
* Right Bracket: +
* comma: equals



#### Flo Tools Plugin

These Flo Tools commands are used inside of Pro Tools plugins.

Where 2 actions are listed, double tapping the key will perform the second action.

* Speak/select preset: Option+P
* Load previous preset: left bracket
* Load next preset: right bracket
* Speak/toggle bypass: Option+B
* Plugin Monitor:
 * This  feature of Flo Tools is for  control surface users with Pro Tools. When controlling a plugin's parameters using a control surface, the plugin monitor will speak the value of the parameter as it changes in real time.
 * Activate Plugin Monitor:	Option+/
 * Deactivate Plugin Monitor:	Option+Shift+/
* Plugin Views:
 * Flo Tools provides an alternative means of browsing parameters in the Plug-In window, allowing some inaccessible plugin parameters to be manipulated and controlled. The script relies on user-generated text files to provide Flo Tools with a template for navigating parameters,  with the option to move the mouse pointer to specific coordinates within the Plug-In window.
 * load default view: Command+0
 * Load Views 1 through 9: Command+1 through 9
 * for more information about plugin views, and how to create them, click [here.](/Plug-In Views/)
#### Flo Tools Selected Tab

This group allows Flo Tools to announce the currently selected tab in Pro Tools dialogs, such as preferences and peripherals. Pressing Command+1, Command+2, etc. will trigger this feature.
#### Flo Tools Shortcuts Helper

Flo Tools provides a convenient way to find any Pro Tools Shortcut, called the Shortcuts Helper. While Pro Tools is running, Press Control Shift Command K to launch the Shortcuts Helper. Press keys to hear their functions.

When you're in the Mix or Edit windows, you'll hear the main shortcuts that are available in most windows. When you're in a window or dialog that has its own shortcuts, you'll hear only those shortcuts that are specific to that environment.

For example, Command+f brings up the Fades dialog in the Mix or Edit windows but it brings up the View filter while the MIDI Event List is in focus. Flo Tools Shortcuts Helper recognizes the context and offers the appropriate shortcuts.

Rather than randomly pressing keys to hear their functions, you can also press Control Shift Command H to bring up a palette of all of the available shortcuts. You can even narrow down the list by bringing up the Item Chooser and use first letter navigation to narrow the list to make it easier to find the shortcut you're trying to remember. You can either trigger the macro, which will speak the function as if you had pressed the key combination or you can press the very first button in the palette (which happens to be unlabelled and that will close the palette. To exit Shortcuts Helper, simply press Escape.

<div id='misc'/>
## Misc

### Changing Shortcuts

The shortcuts outlined above are the default assignments for Flo Tools. They may be changed based on personal preference, however, when Flo Tools is updated, the shortcuts will revert back to their default assignments. To  change a shortcut, open Keyboard Maestro and do the following:

1. Go to the view menu, and select "start editing macros."
2. Find the Macro Groups scroll area and interact with it. Inside, find and select the appropriate Flo Tools macro group by pressing VO space on it.
3. Stop interacting with this area and move to the right to the macros scroll area.

  * Interact, and find the script with the desired shortcut  to change. Press VO space to select it, and press tab.

This should move the VoiceOver Cursor  inside the edit screen of the macro. VO right arrow to the  button labeled with the current shortcut for the script.

To change it, simply type the new desired shortcut and then stop interacting with the edit area. Be careful not to press command tab here, as this will assign it self as a new shortcut.

### Reinstalling Flo Tools

The provided zip file contains both an installer and uninstaller for Flo Tools. If  Flo Tools needs to be reinstalled for any reason, simply run the installer and follow the prompts to be guided through installation. All Flo Tools related macros will be automatically replaced with the ones within the installer. Be sure you have the latest version of the installer by downloading it from the Flo Tools website.

You can check the version you’re running, and check for updates by opening Pro Tools, and then navigating to the "Keyboard Maestro Engine" Menu Extra and arrowing through the options until you hear "Flo Tools". Arrow down to hear the version number and the option to check for updates.

### Uninstalling Flo Tools

The uninstaller is only required if you wish to completely remove Flo Tools and its associated files and folders from your computer. To uninstall the Flo Tools scripts and associated plugin views, run the uninstaller application and follow the on-screen prompts to remove Flo Tools.

Please backup any text files in the Plugin Views folder that you’d like to keep, as these will be permanently deleted during Flo Tools removal.

Note that if you wish to uninstall Keyboard Maestro, it must be removed manually. Instructions for uninstalling Keyboard Maestro can be found on the Keyboard Maestro website.


### Known Issues

* Items marked as "Beta" may not function as expected, and should not be used regularly until they are no longer in the beta stage.
* Checking the arm state of tracks does not report consistently. This is due to the way that Pro Tools indicates whether a track is record enabled. To work around this, check the arm state multiple times.


### Reporting Issues

GitHub provides a convenient and reliable way to track and resolve issues. Please click [here,](https://github.com/flotools/flotools/issues) and search for your issue. If you don't find an open issue relating to your problem with Flo Tools, you can create a new one by clicking on "new issue" and filling out the required fields.

Before reporting an issue, please check that the item being queried by Flo Tools is visible on the screen if Flo Tools is not functioning as expected. For example, if 1 is pressed to report insert A of a track, and nothing is spoken, make sure that inserts A through E are checked in the view menu before reporting this as a Flo Tools issue.


### Generating A Report

When troubleshooting a problem, it might occasionally be necessary to have Keyboard Maestro generate a report when a script fails. By default, Flo Tools will ignore errors but, for diagnostic purposes, it might be necessary to provide those results to the Flo Tools team. Follow these steps to generate the error message:

1. In Keyboard Maestro, navigate to the macro that appears to be malfunctioning and click once on the macro.
2. Press Tab once and you'll be placed in the Macro Edit Detail Scroll Area. Use VoiceOver to navigate over to the Execute Java script for Automation Action Group.
3. Interact with the action group and navigate over to the pop-up menu that says, "Ignore Results" and change this option to "Display Results in a Window."
4. Return to Pro Tools and try launching the macro again. If there's an error with the script, Keyboard Maestro will open a new window with the error result. It might look something like this:  
/var/folders/lf/hwjp9syx5ll56brrkhgr818w0000gn/T/Keyboard-Maestro-Script-7640162F-37E6-49B9-AF85-02762D598028:243:339: execution error: Error on line 10: Error: Can't get object. (-1728)
5. With the error message open, press Command-a to select the message and press Command-c to copy it. 

The Flo Tools team will use this information to determine what the problem and solution might be. You might be asked to make a change to your system or session file to troubleshoot further. Once the issue is identified and/or resolved, you can change the results preference in the action group back to "Ignore Results."

<div id='changelog'/>
## ChangeLog

### Flo Tools 2.0:

* Changed "activate inspector" command to toggle. pressing / once will toggle the inspector on and off. Shift+/ is now used for "Speak/Toggle Link Timeline and Edit Selection."
* Added speak/edit tempo. Press Command+f11 to speak the current tempo. Double tap Command+f11 to edit the tempo value.
* Added increase/decrease volume/pan.
 * When the Inspector is on, pressing Command+Control+up/down arrows adjusts the track volume fader.
 * Pressing Command+Control+left/right arrows adjusts the track pan for mono tracks or the left channel pan for stereo tracks. Add the Shift modifier to adjust the right channel pan.
* Created "Flo Tools Global" group. This is used to store commands to trigger the Flo Tools Mouse and num pad groups, and allows Flo Tools to be deactivated when VoiceOver is not running.
* Created "Flo Tools Plugin" group.
 * Added preset, next, previous, bypass for plugins.
 * Press Option+p to speak the current preset (beta).
 * Double tap Option+p to open the Preset pop-up menu.
 * Press ] (right bracket) for next preset and [ (left bracket) for previous preset.
 * Press Option+b to speak the bypass status. Double-tap Option+b to toggle the bypass state.
* Added plugin views feature. See the "Flo Tools Plugin" group of commands for details.
* Created Flo Tools Mouse group, and added mouse movement shortcuts.
 * This group is now global, and works system-wide when enabled.
 * Press Command+/ to toggle on and off. See the  "Flo Tools Mouse Group" of commands for details.
* Added version indicator. Go to the Keyboard Maestro Engine menu extra to see the version number.
* Added num pad group. enable with control+/. See the Num Pad Group of commands for details.
* Changed clipped tracks to speak tracks with 0DB, option shift 0

### Flo Tools 2.01

* added Flo Tools Update notification. When Pro Tools is opened, Flo Tools will automatically check for updates, and present a dialog if an update is necessary.

### Flo Tools 2.2

* Speak/Toggle Tab to Transients:	Command+Option+Tab
* Speak/Toggle Insertion Follows Playback:	Control+n
* Speak/select shufflemode:	f1
* Speak/Select Slip Mode:	f2
* Speak/Select Spot Mode:	f3
* Speak/Select Grid Mode (and Toggle Absolute/Relative Grid Mode):	f4
* Speak/toggle quickpunch:	Command+Shift+p
* Speak/Toggle loop playback:	Command+Shift+l
* Speak/Toggle Loop Record:	Option+l
* Speak/Toggle Pre/Post-Roll:	Command+k
* Mark clip to drag:	Command+Option+Shift+, (comma)
* Drag clip:	Command+Option+Shift+. (period)
* Resize track list Table:	Command+Control+Shift+t
* Resize clip list table:	Command+Control+Shift+c
* Speak Selected Clips:	Option+Shift+p
* Speak/copy mouse coordinates relative to screen: Command+Option+Shift+a
* Increase/Decrease  Instrument Volume:	Command+Option+up/down arrow
* added Flo Tools Selected Tab group. This allows Flo Tools to speak tab names in dialogs such as pro tools preferences or peripherals. Press Command+1, Command+2, etc. to trigger this feature.
* created Flo Tools MIDI Event List macro group, which contains the following commands:
 * Speak/Edit Pitch for Selected Note:	Option+p
 * Speak/Edit Attack Velocity for Selected Note:	Option+a
 * Speak/Edit Release Velocity for Selected Note:	Option+r
 * Move to next Column:	Control+right arrow
 * Move to previous Column:	Control+left arrow
 * Edit Event:	Control+Command+Return
* For more detailed information about new features and improvements in version 2.2, click [Here.](/Flo-Tools-2.2-release/)

### Flo Tools 2.3:

* Select Clip Keyboard Focus: Command+Option+2
* Select Group Keyboard Focus: Command+Option+3
* Select Timeline Keyboard Focus: Command+Option+1
* Speak and select Previous Playlist: Shift + Up Arrow
* Speak and select Next Playlist: Shift+Down Arrow
* Speak and Select Previous Track: Control+P
* Speak and select Next Track: Control+; (semicolon)
* Speak and add Previous Track to Selection: Control+Shift+P
* Speak and add Next Track to Selection: Control+Shift+;(semicolon)
* Speak and retract Selection from Top Track: Control+Option+P (must be passed through)
* Speak and retract Selection from Bottom Track: Control+Option+; (semicolon) (must be passed through)
* Toggle Input Monitor: Option+K
* Added Shortcuts Helper:
 * Command+Control+Shift+K: Start Shortcuts Helper
 * escape: Stop Shortcuts Helper
 * Command+Control+Shift+H: List all shortcuts for the current dialog or window