# Flo Tools
#Welcome!
Welcome to Flo Tools! This open source product is a series of UI scripts for VoiceOver designed to enhance the accessibility of Pro Tools for visually-impaired users   by streamlining and automating tasks to dramatically improve workflows.

This Read Me file is divided into headings for easier screen reader navigation. Read on to get started.

#Acknowledgements:

Flo Tools was first developed as a concept by Chi Kim and Rocco Fiorentino, in the [Assistive Music Technology Lab](http://berklee.edu/amtlab) at Berklee College of Music. After the initial project at Berklee was completed, Slau Halatyn joined the team, and the group worked together to continue developing the scripts outside of the classroom. Many thanks to Chi Kim for his countless hours of creative scripting, to Rocco Fiorentino for his scripting contributions and providing documentation. And to Slau Halatyn, for his invaluable feedback and expert knowledge in Pro Tools. We sincerely hope Flo Tools will enhance the work flow of Pro Tools users with visual impairments!

#Disclaimer and License:

Support is only available through a volunteer based community.

Flo Tools  
Copyright (C) 2016 Chi Kim  
Copyright (C) 2016 Rocco Fiorentino

Flow Tools is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Flo Tools is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the [GNU General Public License](http://www.gnu.org/licenses/) for more details.

#Download:

You can download the zip file directly from [here](https://github.com/rfiorentino1/Flo-Tools/archive/master.zip)

The  zip file referenced in this read me will automatically decompress itself into a folder on Mac OS. Please refer to this downloaded folder, called "Flo Tools Master", when reading this document.

#System Requirements:

Flo Tools supports Mac OS version 10.10 or later, and Pro Tools version 12.3 or later. Earlier versions of Mac OS and Pro Tools may provide limited functionality with Flo Tools, but have not been tested and are not guaranteed to function correctly.

#Installation
Flo Tools relies on a third party program, called Keyboard Maestro. Download instructions are below.

##Keyboard Maestro Installation:

1. Go to the Keyboard Maestro homepage by clicking [here](https://www.keyboardmaestro.com/) and download the Keyboard Maestro application from the website.

2. Copy the Keyboard Maestro application from the downloads folder to your applications folder. From there, open Keyboard Maestro.


##Flo Tools Installation
To install Flo Tools, go to the provided zip file, and open the file called "Flo Tools.kmmacros"

If successful, Keyboard Maestro should announce, "Successfully imported macros."

For the scripts to run correctly, open Keyboard Maestro Preferences, and under the general tab, check the checkbox that says "start Keyboard Maestro Engine at log-in."

##Important Notes about Keyboard Maestro:

Keyboard Maestro contains some default macro groups that conflict with common Mac OS keyboard shortcuts. To disable these, go to the switcher group, and clipboard group, and disable them. This can be done by selecting the group, then selecting the disable group button.

Keyboard Maestro is limited by a 30-day trial period. After this time, you will need to purchase a one-time license to continue using the program, and subsequently, Flo Tools.


###Getting Started

###Auditory Feedback:

Flo Tools uses 2 distinct sounds to provide auditory feedback. The first is [this sound](file:///System/Library/Sounds/Pop.aiff), which signals that something is in process and the user needs to wait for Flo Tools to complete a task. An example of this would be deselecting all tracks in a large session.

The second is [this sound](file:///System/Library/Sounds/Tink.aiff), which tells a user that something has been toggled, such as solo on and off.

###Commands:

Flo Tools has two groups of commands. The first, called "Flo Tools", is always active, and applies to the entire session. The second group, called "Flo Tools Inspector", is active by default, but can be toggled on and off. The inspector only applies to an individual track.

Below is a list of Flo Tools commands, and their associated functions, separated by their respective groups.

###Flo Tools:

Where two actions are listed, double-tapping the key will perform the second action.

- Speak/Edit selection start: Command+f1
- Speak/Edit Selection End: Command+f2
- Speak/Edit Selection Length: Command+f3
- Speak/Edit main counter: Command+f4
Speak/Edit Sub Counter: Command+f6
Speak/Edit Nudge value: Command+f7
Speak Grid Value: Command+f8
Speak/Edit Pre-Roll: Command+f9
Speak/Edit Post-Roll:	Command+f10
- Close All Floating Windows: Command+Option+w
- Zoom/Maximize Window: Command+Option+Shift+z
- Show All Tracks: Option+f1
- Hide All Tracks: Option+f2
- Show Only Selected Tracks: Option+Shift+f1
- Hide Selected Tracks: Option+Shift+f2
- Speak Selected Tracks, Deselect All Tracks: Option+Shift+t
- Speak Input Monitor-Enabled Tracks, Disable Input Monitor On All Tracks: Option+Shift+k
- Beta: Speak Record-Enabled Tracks, Disarm All Record Enabled Tracks: Option+Shift+r
- Speak Soloed Tracks, Unsolo All Tracks: Option+Shift+s
- Speak Muted Tracks, Unmute All Tracks: Option+Shift+m
- Speak Record Safe Tracks: Command+Option+Shift+r
- Speak Solo Safe Tracks: Command+Option+Shift+s
- Speak Clipped Tracks: Option+Shift+c
Speak/Toggle Click: Option+7 on the num pad
Speak/Toggle Count In:	Option+8 on the num pad
Speak/Toggle MIDI Merge: Option+9 on the num pad
- Command-Click: Command+Control+` (accent)
- Command+Option-Click: Command+Option+` (accent)
- Control-Click: Control+` (accent)
- Control+Option-Click: Control+Option+` (accent), must be passed through
- Control+Option+Shift-Click: Control+Option+Shift+` (accent), must be passed through
- Option-Click: Option+` (accent)
Shift-Click: Shift+` (accent)
- Option+Shift-Click: Option+Shift+` (accent)


###Flo Tools Inspector:

The following commands apply to the track on which VoiceOver is currently focused . This means the track must be under the VoiceOver cursor, and the user should not be interacting with anything inside the track.

Note: The inspector must be disabled to use first-letter navigation in pop-up menus in Pro Tools.

Where 2 actions are listed, double tapping the key will perform the second action.

- Activate Inspector: /
- Deactivate Inspector: Shift+/
- Speak Track Name, Select Track Pop-Up Menu: t
- Speak/Open Inserts A through J: 1 through 0
- Assign Inserts A through J: Command+1 through 0
- Speak/Open Sends A through J: Control+1 through 0
- Assign Sends A through J: Command+Control+1 through 0
- Speak/Select Audio Input: i
Speak/Select MIDI Input: Option+i
- Speak/Select Audio Output: o
Speak/Select MIDI Output: Option+o
- Beta: Speak/Select Automation Mode: a
- Speak/Select Group: g
- Speak/Reset Pan: n
- Speak/Toggle Input Monitor: k
- Speak/Toggle Record State: r
- Speak/Toggle Solo: s
- Speak/Toggle Mute: m
Speak/Toggle MIDI Mute: Option+m
- Speak/Reset Volume Fader: v
Speak/Reset MIDI Volume Fader: Option+v
- Speak/Reset Level Meter: l
- Speak/Reset Peak Meter: p
- Speak/Reset Gain Reduction Meter: g
- Speak/Edit Comments: c
- Track Options Menu: h
- Speak/Select Playlist: \
- Beta: Speak/Select Track View: w
- Speak/Toggle Freeze Status: f
- Speak/Select Timebase: b
- Beta: Speak/Select Elastic Audio Plugin: e


####Changing Shortcuts

The shortcuts outlined above are the default assignments for Flo Tools. They can be changed based on personal preference, however, when Flo Tools is updated, the shortcuts will revert back to their default assignments. If you feel that you want to change a shortcut, open Keyboard Maestro and do the following:

1. Go to the view menu, and select "start editing macros."
2. Find the Macro Groups scroll area and interact with it. Inside, find and select the appropriate Flo Tools macro group by pressing VO space on it.
3. Stop interacting with this area and move to the right to the macros scroll area.

  - Interact, and find the script with the shortcut you want to change. Press VO space to select it, and press tab.

This should move you inside the edit screen of the macro. VO right arrow, and you should see a button, labeled with the current shortcut for the script.

To change it, simply type your new desired shortcut and then stop interacting with the edit area. Be careful not to press command tab here, as this will assign it self as a new shortcut.

####Updating or reinstalling Flo Tools:

When there is an update to Flo Tools, or if you simply want to reinstall it, both macro groups in Keyboard Maestro must be deleted. This can be done by doing the following:

1. Open Keyboard Maestro and go to the Flo Tools Macro Group.
2. Press VO space on it, then shift right arrow, to select both the Flo Tools, and Flo Tools inspector groups simultaneously.
3. Stop interacting with the groups scroll area, and VO right arrow to "delete macro group." VO space to confirm deletion. Note that this cannot be undone once you have pressed delete.
4. Before opening the macro file again to reinstall Flo Tools, make sure the macro groups are removed from the groups scroll area. If so, the above process was completed successfully.

####Known Issues

* Items marked as "Beta" may not function as expected, and should not be used regularly until they are no longer in the beta stage.
* Checking the arm state of tracks does not report consistently. This is due to the way that Pro Tools indicates whether a track is record enabled. To work around this, check the arm state multiple times.


####Reporting Issues:

GitHub provides a convenient and reliable way to track and resolve issues. Please click [here](https://github.com/rfiorentino1/Flo-Tools/issues), and search for your issue. If you don't find an open issue relating to your problem with Flo Tools, you can create a new one by clicking on "new issue" and filling out the required fields.

Before reporting an issue, please check that the item being queried by Flo Tools is visible on the screen if Flo Tools is not functioning as expected. For example, if command 1 is pressed to report insert A of a track, and nothing is spoken, make sure that inserts a through e are checked in the view menu before reporting this as a Flo Tools issue.
