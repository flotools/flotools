# **What’s New in Flo Tools 2022.4**
Greetings from the flo Tools team! We have a couple of things to tell you about with this new release—nothing major but we wanted to point out some things that have changed a bit along with a few new macros.

##Pro Tools Versions and Flo Tools
For several years, we've tried to synchronize Flo Tools with Pro Tools whenever possible. We've come to a point where it's now important to consider which version of Flo Tools will work with which version of Pro Tools. Starting with Flo Tools 2022.4, it's more important to make sure you're using the latest version of Pro Tools. If you're not using Pro Tools 2022.4, it's best to use the previous version of Flo Tools. For the most part, things would work alright but there are a few things that wouldn't. Although we might not always be able to match Flo Tools with Pro Tools versions, a rule of thumb would be to use the latest versions of each. However, if you can't be on the latest version of Pro Tools right now, stick with the previous version of Flo Tools.

##Speak/Toggle wait for Note
flo Tools can now report the status of the "wait for Note" feature and toggle it without having to go into the MIDI Control Cluster. Pressing Option+F11 once will speak the status and double-tapping Option+F11 will toggle its state providing, of course, that the MIDI Controls cluster is visible. There is an option to use F11 for "Wait for Note" under the MIDI tab of Pro Tools preferences. The flo Tools "Speak/Toggle wait for Note" function will work regardless of this preference. We've gotten a few requests for this one so we hope it comes in handy.

##Speak/Toggle Conductor
Determining the status of the Conductor and turning it on or off has always required going into the MIDI Controls cluster. Flo Tools can now report the status of the Conductor and allows you to toggle it on or off without the need to navigate to the MIDI Controls cluster. Pressing Option+F12 will speak the Conductor status and double-tapping will toggle its state.

##Speak/Toggle Track Punch
For those users with Track Punch as an option, pressing the Command+Shift+T shortcut will now speak the menu option just like other menu items under the Options menu. Double-tapping Command+Shift+T will toggle the state, in other words, selecting it.

##"List Tracks with Flo Tools"
There are two new features in Pro Tools 2022.4 that use the same keyboard shortcuts as some of the track listing macros in Flo Tools. We considered eliminating these track listing commands because they weren't particularly popular but users seemed to appreciate the option of having the feature available. We decided to combine the various macros into one command to bring up a palette of choices. The new macro is called "List Tracks with flo Tools" and its keyboard shortcut is Control+Option+Shift+L.

when you issue the "List Tracks with flo Tools" command, Flo Tools presents you with a Keyboard Maestro palette of 12  macros. These include actions for listing all record-enabled tracks, all hidden tracks, all muted or unmuted tracks, selected and unselected tracks, etc. Each one of these macros had dedicated shortcuts. Now they all use the same shortcut to bring up the palette and then you can either navigate with VoiceOver to click on the desired macro or narrow down with first letter navigation. It's one extra step to get to the various list dialogs available but now there's only one keyboard shortcut to remember and we've freed up a bunch of other keyboard shortcut combinations.

##Changes to Speak Track Name / Select Track Pop-Up Menu
We've changed the name of this macro to "Speak and select Track / show Right-Click Menu" to more accurately reflect its function. Now a single tap of the letter T with the Inspector will speak and select the focused track and double-tapping will show the track's right-click menu just as it always has.

There are two things worth mentioning about the single-tap portion of this macro:

1. With the Inspector, if you focus VoiceOver on an unselected track and press the letter T, the track will become selected and any previously selected trackk or tracks become deselected.
1. If the focused track is already selected and there are other tracks selected, pressing the letter T will simply speak the track name and indicate that it is selected but it will not deselect the previously selected tracks.

##Flo Tools Key Set
There's a new feature in Pro Tools 2022.4 and that is the Keyboard Shortcuts window. There are over twelve hundred items for which you can define and/or customize shortcuts. That includes the default Pro Tools shortcuts themselves. Given that these shortcuts have been around for decades, we would strongly encourage users not to change the default Pro Tools shortcuts so that users can be on the same page when it comes to one of the most important aspects of working with Pro Tools as blind users and that is a common set of keyboard shortcuts.

That said, the flo Tools team has certainly had to step on a few default Pro Tools shortcuts over the years to try and keep a level of consistency with modifiers and Flo Tools shortcuts. So, ultimately, it's up to the user to determine whether they want to go ahead and make changes.

Let's look at two custom shortcuts that we've prepared for blind users that are technically not a part of flo Tools, per se, but we're just making them available through this version of Flo Tools

The two customized shortcuts are located in a key set called "Flo Tools Key Set" which the Flo Tools Installer will put in a folder named "Keyboard Shortcuts" within the Pro Tools Presets folder in your Pro Tools folder. If you've installed Pro Tools 2022.4 already, this folder is already in your Pro Tools folder. If you haven't yet installed Pro Tools 2022.4, the flo Tools Installer will create the necessary folder for you. Consult the Pro Tools documentation for more information on using the Keyboard Shortcuts window.

The two customized shortcuts are as follows:

###1. Spot Clip to Insertion
Finally, in Pro Tools 2022.4, there's a new option to spot clips to the insertion cursor on a track. It's available under the Clips List menu but there's also an option to assign a keyboard shortcut to the function. We've assigned Control+Option+Shift+s to the "Spot Clip to Insertion" command. Again, this is a Pro Tools command and not flo Tools. You can certainly reassign the shortcut to whatever you want. We're simply providing a default that happens to be available, perhaps easy to remember and maybe most Flo Tools users will simply use the keyboard shortcut as it is defined in this key set.

###2. rename Selected Track
One of the most common commands accessed through the Inspector is the Rename function within the track's right-click menu. Now you can rename any selected track by pressing Command+Return. This also works on multiple track selections.

##Changes to Speak/Toggle Link Timeline and Edit Selection, and Speak/Link Track and Edit Selection
There was a small issue with these two macros in that they could interfere with the ability to type a capital letter T or a question mark under certain circumstances. These macros no longer interfere with typing in edit fields. However, it's worth noting that, because of this change, these two macros behave a little differently. Now, instead of reporting first and toggling only after a double-tap, these commands will toggle the status each time and report the change. We've also updated the macro names to "Toggle and Speak Link Timeline and Edit Selection" and "Toggle and Speak Track and Edit Selection."

##shortcuts Helper Updates
As usual, there are some updates to the Shortcuts Helper macros to correct some errors and add some shortcuts newly introduced in Pro Tools 2022.4.

##Miscellaneous Fixes
Among some things that have been fixed are the following:

* flo Tools monitoring macros adjusted to minimize fan noise on some systems
* Bypass shortcut in Plug-in window now works when automation is enabled
* "Deselect all" now automatically makes sure the Track List Table is shown in order to accurately determine track selection

##General Notes
Of course, we're only addressing changes that are specific to Flo Tools. We aren't covering new features in Pro Tools that are great for blind users that have nothing to do with Flo Tools specifically like the new Pro Tools search feature. Of course, ongoing discussions through social media and communities are the best place to find out about things like that. We'll try to get in a few new flo tools features on the next release. For now, enjoy Pro Tools and Flo Tools 2022.4!

All the best from The Flo Tools Team!
