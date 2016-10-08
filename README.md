# Flo Tools
#Welcome!
Welcome to Flo Tools! This open source product is a series of UI scripts for VoiceOver designed to enhance the accessibility of Pro Tools for visually-impaired users   by streamlining and automating tasks to dramatically improve workflows.

This Read Me file is divided into headings for easier screen reader navigation. Read on to get started.

#Acknowledgements:

Flo Tools was first developed as a concept by Chi Kim and Rocco Fiorentino, in the [Assistive Music Technology Lab](http://berklee.edu/amtlab) at Berklee College of Music. After the initial project at Berklee was completed, Slau Halatyn joined the team, and the group worked together to continue developing the scripts outside of the classroom. Many thanks to Chi Kim for his countless hours of creative scripting, to Rocco Fiorentino for his scripting contributions and writing of documentation, and to Slau Halatyn, for his invaluable feedback and expert knowledge in Pro Tools. We sincerely hope Flo Tools will enhance the work flow of Pro Tools users with visual impairments!

#Disclaimer and License:

Support is only available through a volunteer based community.

Flo Tools  
Copyright (C) 2016 Chi Kim  
Copyright (C) 2016 Rocco Fiorentino  
Copyright (C) 2016 Slau Halatyn

Flow Tools is free software. You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your discretion) any later version.

Flo Tools is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY, expressed or implied, of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the [GNU General Public License](http://www.gnu.org/licenses/) for more details.

#Download:

The zip file for Flo Tools can be downloaded directly from [here.](https://github.com/flotools/flotools/archive/master.zip)

This  zip file, referenced in this read me, will automatically decompress itself into a folder on Mac OS. Please refer to this downloaded folder, called "Flo Tools Master", when reading this document.

#System Requirements:

Flo Tools supports Mac OS version 10.10 or later, and Pro Tools version 12.3 or later. Earlier versions of Mac OS and Pro Tools may provide limited functionality with Flo Tools, but have not been tested and are not guaranteed to function correctly.

#Installation
Flo Tools relies on a third party program called "Keyboard Maestro" to perform it's functions. Download instructions for Keyboard Maestro are below.

##Keyboard Maestro Installation:

1. Go to the Keyboard Maestro homepage by clicking [here](https://www.keyboardmaestro.com/) and download the Keyboard Maestro application from the website.

2. Copy the Keyboard Maestro application from the downloads folder to the applications folder. From there, open Keyboard Maestro.

If using Keyboard Maestro for the first time, please check the boxes for both Keyboard Maestro and Keyboard Maestro Engine in system preferences, under "Security and Privacy", "Accessibility." These must be enabled for Flo Tools to function correctly.##Important Notes about Keyboard Maestro:

Keyboard Maestro contains some default macro groups that conflict with common Mac OS keyboard shortcuts. These are found in the switcher group, and clipboard group, and can be disabled by selecting the group, then selecting the "Enable/disable Group" button.

Keyboard Maestro is limited by a 30-day trial period. After this time, a purchase of a one-time license is required to continue using the program, and subsequently, Flo Tools. More information about purchasing a license can be found [here.](https://wiki.keyboardmaestro.com/manual/Purchase)


##Flo Tools Installation
To install Flo Tools, go to the provided zip file, and open the file called "Flo Tools.KMMACROS"

If successful, Keyboard Maestro should announce, "Successfully imported macros."

For the scripts to run properly, open Keyboard Maestro Preferences, and under the general tab, check the box labeled, "Start Keyboard Maestro Engine at log-in." Note that the Keyboard Maestro window does not need to be open for the scripts to run.

##Optimizing Pro Tools for Flo Tools:

For all functions of Flo Tools to work as expected, it is recommended to apply the following settings and window configurations  in Pro Tools:

1. The checkbox labeled "Allow VoiceOver to be controlled with AppleScript" in the General pane of VoiceOver Utility should be checked.
2. The Mix and Edit windows should both be open at all times.
3. The "Track List Table" in the mix window should always be shown.
4. Within the Display tab of the Pro Tools Preferences dialog,  the check boxes labeled "function" and "details" under basics, tooltips, should be checked.
5. Track Heights should be set to "medium" for optimal Flo Tools performance.
6. Both "Transport" and "expanded transport" should be checked in the toolbar menu of the edit window.

Pro Tools includes a Keyboard Focus mode, within which commands are issued through single letter keystrokes. When Keyboard Focus mode is not active, these same commands can be issued by adding the Control key as a modifier. Since certain Flo Tools commands are issued with single letter taps and double-taps, it is recommended that users avoid the Keyboard Focus mode in Pro Tools. Although Flo Tools will function as expected in Keyboard Focus mode, users may inadvertently press a keystroke not used by Flo Tools and pass unwanted commands through to Pro Tools, yielding unexpected results. To allow use of the  Control modifier instead of keyboard focus mode for Pro Tools, and make single letter commands available for Flo Tools, move VoiceOver focus either on the Clips list by pressing Command-Option-2, or the Groups List by pressing Command-Option-3 while in the edit window.

If the default keyboard is not set to US English in System Preferences, Keyboards, please add the US English Keyboard, and switch to it when using Flo Tools.


#Getting Started
##Auditory Feedback:

Flo Tools uses 2 distinct sounds to provide auditory feedback. The first is [This Sound](https://dl.dropboxusercontent.com/u/27635324/Flo%20Tools/pop.aiff), which signals that something is in process and the user needs to wait for Flo Tools to complete a task. An example of this would be deselecting all tracks in a large session.

The second is [This Sound](https://dl.dropboxusercontent.com/u/27635324/Flo%20Tools/tink.aiff), which tells a user that something has been toggled, such as solo on and off.



##Commands:

Flo Tools has two groups of commands. The first, called "Flo Tools", is always active, and applies to the entire session. The second group, called "Flo Tools Inspector", is active by default, but can be toggled on and off. The inspector only applies to an individual track.

Below is a list of Flo Tools commands, and their associated functions, separated by their respective groups.

##Flo Tools:

Where two actions are listed, double-tapping the key will perform the second action.

- Speak/Edit selection start: Command+f1
- Speak/Edit Selection End: Command+f2
- Speak/Edit Selection Length: Command+f3
- Speak/Edit main counter: Command+f4
- Select main counter:	Command+Option+f4
- Speak/Edit Sub Counter:	Command+f6
- Select Sub Counter:	Command+Option+f6
- Speak/Edit Nudge Value:	Command+f7
- Select Nudge Value:	Command+Option+f7
- Speak/Edit Grid Value:	Command+f8
- Select Grid Value:	Command+Option+f8
- Speak/Edit Pre-Roll Amount:	Command+f9
- Speak/Edit Post-Roll Amount:	Command+f10
- Close All Floating Windows: Command+Option+w
- Zoom/Maximize Window: Command+Option+Shift+z
- Speak Shown Tracks, Show Track List Pop-up Menu:	Option+Shift+w
- List Shown Tracks:	Control+Shift+w
- Speak Hidden Tracks, Show Track List Pop-up Menu:	Option+Shift+h
- List Hidden Tracks:	Control+Shift+h
- Speak Selected Tracks, Deselect All Tracks: Option+Shift+t
- List Selected Tracks, List Unselected Tracks:	Control+Shift+t
- Speak Input Monitor-Enabled Tracks, Disable Input Monitor On All Tracks: Option+Shift+k
- List Input Monitor-Enabled Tracks, List Input Monitor-Disabled  Tracks:	Control+Shift+k
- Beta: Speak Record-Enabled Tracks, Disarm All Record Enabled Tracks: Option+Shift+r
- Beta: List Record-Enabled Tracks, List Record-Disabled Tracks:	Control+Shift+r
- Speak Soloed Tracks, UnSolo All Tracks: Option+Shift+s
- List Soloed Tracks, List Unsoloed Tracks:	Control+Shift+s
- Speak Muted Tracks, UnMute All Tracks: Option+Shift+m
- List Muted Tracks, List Unmuted Tracks:	Control+Shift+m
 - Note that this shortcut overrides one of the Pro Tools shortcuts for "Nudge the Selected Clip Gain Back." Use either Control+Shift+minus or Control+Shift+comma instead
- Speak Record Safe Tracks: Command+Option+Shift+r
- Speak Solo Safe Tracks: Command+Option+Shift+s
- Speak Clipped Tracks: Option+Shift+c
 - Note that this macro overrides the Pro Tools shortcut for "Commit." Use either the track's contextual menu or choose "Commit" from the Tracks menu.
- Speak/Toggle Metronome:	Option+num pad 7
- Speak/Toggle Count In:	Option+num pad8
- Speak/Toggle Midi Merge:	Option+num pad 9
- Option-Click:	Option+` (accent)
- Option+Shift-Click:	Option+Shift+` (accent)
- Command-Click:	Command+` (accent)
- Shift-Click:	Shift+` (accent)
- Control-Click:	Control+` (accent)
- Command+Control-Click:	Command+Control+` (accent)
- Command+Option-Click:	Command+Option+` (accent)
- Command+Option+Control-Click:	Command+Option+Control+` (accent) (must be passed through)
- Command+Shift-Click:	Command+Shift+` (accent)
- Command+Option+Shift-Click:	Command+Option+Shift+` (accent)
- Control+Shift-Click:	Control+Shift+` (accent)
- Control+Option-Click:	Control+Option+` (accent) (must be passed through)
- Control+Option+Shift-Click:	Control+Option+Shift+` (accent) (must be passed through)


##Plugin Monitor:

This  feature of Flo Tools is for  control surface users with Pro Tools. When controlling a plugin's parameters using a control surface, the plugin monitor will speak the value of the parameter as it changes in real time.

- Activate Plugin Monitor:	Option+/
- Deactivate Plugin Monitor:	Option+Shift+/


##Flo Tools Inspector:

The following commands apply to the track on which VoiceOver is currently focused . This means the track name must be under the VoiceOver cursor, and the user should not be interacting with anything inside the track.

Note: The inspector must be disabled to use first-letter navigation in pop-up menus in Pro Tools.

Where 2 actions are listed, double tapping the key will perform the second action.

- Activate Inspector: /
- Deactivate Inspector: Shift+/
 - Note that this overrides the Pro Tools shortcut for "Link Timeline and Edit Selection." To link or unlink the timeline and edit selection, use the Options menu instead.
- Speak Track Name, Select Track Pop-Up Menu: t
- Speak/Open Inserts A through J:	1 through 0 on the numbers row
- Assign Inserts A through J:	Command+1 through 0 on the numbers row
 - Note that Command+1 through 7 are shortcuts for selecting Pro Tools edit tools. There are alternative shortcuts located within the F keys. See the Pro Tools Keyboard Shortcuts pdf for details.
 - Note that, when Flo Tools Inspector is active,  the macro for assigning Insert J (Command+0) overrides the Pro Tools shortcut for "Quantize Clip to Nearest Grid." Use the Clip menu or deactivate Flo Tools Inspector with Shift+/ to pass through the shortcut.
- Speak/Open Sends A through J:	Control+1 through 0 on the numbers row
- Assign Sends A through J:	Command+Control+1 through 0 on the numbers row
- Speak/Select Track Input: i
- Speak/Select Instrument Input: Option+i
- Speak/Select Track Output: o
- Speak/Select Instrument Output: Option+o
- Beta: Speak/Select Automation Mode: a
- Speak/Select Group: g
- Speak/Reset Pan: n
- Speak/Toggle Input Monitor: k
- Speak/Toggle Record State: r
- Speak/Toggle Solo: s
- Speak/Toggle Mute: m
- Speak/Toggle Instrument Mute: Option+m
- Speak/Reset Volume Fader: v
- Speak/Reset Instrument Volume Fader: Option+v
- Speak Level Meter, Toggle Level Meter Monitor:	l
- Speak/Reset Peak Meter: p
- Speak Gain Reduction Meter, Toggle Gain Reduction Meter Monitor:	semicolon
- Speak Gain Reduction Meter Maximum:	Shift+semicolon
- Speak/Edit Comments: c
- Track Options Menu: h
- Speak/Select Playlist: \
- Beta: Speak/Select Track View: w
- Speak/Toggle Freeze Status: f
- Speak/Select Timebase: b
- Beta: Speak/Select Elastic Audio Plugin: e

#Misc:

##Changing Shortcuts

The shortcuts outlined above are the default assignments for Flo Tools. They may be changed based on personal preference, however, when Flo Tools is updated, the shortcuts will revert back to their default assignments. To  change a shortcut, open Keyboard Maestro and do the following:

1. Go to the view menu, and select "start editing macros."
2. Find the Macro Groups scroll area and interact with it. Inside, find and select the appropriate Flo Tools macro group by pressing VO space on it.
3. Stop interacting with this area and move to the right to the macros scroll area.

  - Interact, and find the script with the desired shortcut  to change. Press VO space to select it, and press tab.

This should move the VoiceOver Cursor  inside the edit screen of the macro. VO right arrow to the  button labeled with the current shortcut for the script.

To change it, simply type the new desired shortcut and then stop interacting with the edit area. Be careful not to press command tab here, as this will assign it self as a new shortcut.

##Updating or reinstalling Flo Tools:

When there is an update to Flo Tools, or to simply reinstall it, both macro groups in Keyboard Maestro must be deleted. This can be done by doing the following:

1. Open Keyboard Maestro and go to the Flo Tools Macro Group.
2. Press VO space on it, then shift right arrow, to select both the Flo Tools, and Flo Tools inspector groups simultaneously.
3. Stop interacting with the groups scroll area, and VO right arrow to "delete macro group." VO space to confirm deletion. Note that this cannot be undone once you have pressed delete.
4. Before opening the Flo Tools Macro file again, make sure the macro groups are removed from the groups scroll area. If so, the above process was completed successfully.

##Known Issues

* Items marked as "Beta" may not function as expected, and should not be used regularly until they are no longer in the beta stage.
* Checking the arm state of tracks does not report consistently. This is due to the way that Pro Tools indicates whether a track is record enabled. To work around this, check the arm state multiple times.


##Reporting Issues:

GitHub provides a convenient and reliable way to track and resolve issues. Please click [here,](https://github.com/flotools/flotools/issues) and search for your issue. If you don't find an open issue relating to your problem with Flo Tools, you can create a new one by clicking on "new issue" and filling out the required fields.

Before reporting an issue, please check that the item being queried by Flo Tools is visible on the screen if Flo Tools is not functioning as expected. For example, if 1 is pressed to report insert A of a track, and nothing is spoken, make sure that inserts A through E are checked in the view menu before reporting this as a Flo Tools issue.
