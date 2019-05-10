# **What’s New in Flo Tools 2019.5**

Oh, if you only knew what excitement the Flo Tools team has been experiencing over the last several months…
Over what, you might ask? (And we thought you might ask.)

 Well, for one thing, we’ve had to rewrite a ton of macros virtually every time a new beta build of Pro Tools came down the pike. Why all the big changes? While working toward Mojave compatibility, Avid completely rewrote a significant portion of the Pro Tools interface. As is par for the course, when UI elements are rebuilt, things often change just enough to require code changes to UI automation scripts. We won’t lie—it was a roller coaster ride but everything finally settled down and we're just catching our breath.

## Compatibility
Let's get to the big takeaway: Flo Tools 2019.5 is compatible with Pro Tools 2019.5 but not Pro Tools 2018.12 and earlier. 

Unless you've upgraded to Pro Tools 2019.5, you should not update to Flo Tools 2019.5. If you're still on Pro Tools 2018, you should remain on Flo Tools 2018.7. 

Just so that we're absolutely crystal clear on this point: Flo Tools 2019.5 will only work with Pro Tools 2019.5 and no earlier versions of Pro Tools. We haven't tested with Pro Tools First but we think it'll probably work at least as well as with earlier versions of Pro Tools First.

At the risk of confusing people, Pro Tools 2019.5 is Mojave compatible but it also works with Sierra and High Sierra. So, can you use Flo Tools 2019.5 with, say, Sierra? Yes, Flo Tools 2019.5 will work under sierra. One caveat is mentioned below but, for now, let's recap:

* Pro Tools 2019.5 will work with Sierra, High Sierra and Mojave
* 2019.5 is the only version of Pro Tools compatible with Mojave
* Flo Tools 2019.5 will work in Sierra, High Sierra and Mojave
* Flo Tools 2019.5 will only work with Pro Tools 2019.5

We had originally thought Flo Tools 2019.5 would be purely a compatibility update but we did manage to sneak in a few new things. That said, now that this version is out, we’ll be working on some new features for the next update soon. So, what’s new? Funny you should ask…

## A Heads Up on Upgrading to Mojave
If you're considering upgrading to Mojave, be aware that, after updating the operating system, you'll need to do the following:

1. Go to the Security and Privacy pane of System Preferences
2. Select the Privacy Tab
3. Select Accessibility in the Privacy Categories Table
4. If necessary, click the lock to make changes and enter your password
5. In the second table, uncheck then recheck the Keyboard Maestro and Keyboard Maestro Engine items and restart your computer.

If you haven't yet updated to Mojave, be forewarned that you'll be required to say okay to a bunch of things when installing software. 

Apple has made it necessary to approve access of several types for security reasons. As a result, the Flo Tools installation process is interrupted several times with such requests from the system. 

Make sure to approve and agree to everything during the installation process or else Flo Tools will not work. 

To be clear, if you install Flo Tools 2019.5 under Sierra or High Sierra, you won't be confronted with these requests to grant permission. It's only under Mojave that this would be the case.

## Modify Your Modifiers
We’ve said it before but, at this point, it’s practically a requirement. More and more, Pro Tools is utilizing the Control+Option modifiers either as a pair or in conjunction with other modifiers. 

With the previous version of Flo Tools, we began using the Control+Option modifiers for certain macros and, at this point, Flo Tools is starting to give feedback on Pro Tools commands which use those modifiers too. 

So, if you haven’t done so already, we encourage you to use the Caps Lock key as your VoiceOver key. You can find that preference in the General Category of the VoiceOver Utility. 

If you don’t know how to get to the VoiceOver Utility, we will now issue a good brow beating. Had enough? OK, it’s VO+f8. Now we’ll wait here while you go make the change. What? Back already? Alright, let’s move on…

## No More VoiceOver Focus Issues
OK, technically, this isn’t a Flo Tools improvement but, given that Flo Tools is all about efficiency and user experience, we thought it was important enough to mention that, at least in Mojave, the super annoying issue of VoiceOver losing focus and being thrown to the top left of the window after closing other windows or dialogs has finally been fixed. 

So now, whenever you use Command+Option+W to close all windows, VoiceOver will land right back where it was before. Yes, life is good once again!

Oh, yeah, about that caveat mentioned above, if you're using Sierra or High Sierra, the focus issue has apparently improved but it's not fixed under those operating systems. It's really the changes in Mojave where the updated code in Pro Tools 2019.5 addresses the focus issues. So, unless you really enjoy being blown back to the top left corner every single time you do something, yeah, you just might consider making that jump to Mojave.

## A Few Commands No Longer in Beta
Fortuitously, as a byproduct of a bunch of things being rewritten in Pro Tools, a few controls have been updated so as to reveal themselves to the UI in such a way that Flo Tools has better access to them. 

As a result, a few macros have now been officially promoted out of beta. Which macros? Again, funny you should ask…

* Speak/Select Track View: No more having to double-tap the W key just to see which track view is selected. Just tap the W key once while the Flo Tools Inspector is enabled and Flo Tools will let you know whether a track is in Waveform view or one of the other view types. Double-tapping will, of course, allow you to change views as it always has.
* Speak/Select Automation: Another time saver: press the letter A once and the Flo Tools Inspector will report a track’s automation state while double-tapping brings up the automation mode menu.
* Speak/Select Elastic Audio: Just like its former beta buddies above, pressing the letter E once will speak the current Elastic Audio type (if any) while a double-tap brings up the menu.

While the 3 macros mentioned above were officially promoted out of beta, we confess that there was another macro that wasn't officially considered beta in previous versions of Flo Tools but it technically didn't behave as originally intended (through no fault of our own, naturally). Again, as a result of Avid's changes, we've gained better access to a couple of things in the Plug-in window. Now don't get too excited—it's just some quality of life improvement.

* Speak/Choose Preset: Maybe some of you weren't too familiar with double-tapping Option+p to quickly open the Preset menu in the Plug-in window. well, the idea was that a single tap was supposed to speak the name of the current preset while double-tapping would pop open the menu. The problem was that, while the currently selected preset was visible to voiceOver itself, it wasn't accessible through UI automation. Well, as one of the beneficieries of Avid's work, Flo Tools can now report the currently loaded preset when you press Option+p once.
* Previous/Next Preset: Although Left Bracket and Right Bracket always did work correctly in that they selected the previous and next presets, they weren't able to report the name of the newly loaded preset because of the aforementioned invisibility of the information through automation. As of Flo Tools 2019.5, pressing Left/Right Bracket will load a new preset as well as speak the preset's name.

## New Announcement When Editing Counters
This change actually depends on whether a counter is set to bars and beats or minutes and seconds. As a result of a particular change in Pro Tools 2019, when entering a value while a counter is set to minutes and seconds, it is necessary to press either Delete or a decimal before typing in a new value. 

This does not apply to the old school method of typing the asterisk  or slash key from the numeric keypad but rather when double-tapping Command+f1, for example. Flo Tools will say, "Press Delete then type Start Value." 
This requirement to press Delete first only applies to when you’re in minutes and seconds and not in bars and beats. Flo Tools will sense the difference and remind you to press delete only when the counter in question is set to minutes and seconds. Oo, it’s almost as if Flo Tools is on the verge of artificial intelligence… or not.

## Shortcut Changes in the Inspector
* Increase/Decrease Instrument Volume: We’ve changed the Increase/Decrease Instrument Volume shortcut in the Flo Tools Inspector from Command+Option+Up/Down Arrow to Control+Option+Up/Down Arrow. Wait, Control+Option? But that’ll conflict with… Oh, never mind, you’ve already changed your VoiceOver key to Caps Lock, right? Of course you did. OK, moving right along…

## New macros
* Pan Instrument left/Right, Control Option Left/Right Arrow: How did we miss this? Flo Tools Inspector has other shortcuts for instrument tracks but we kind of skipped over the instrument’s pan control. To be clear, we’re not talking about an instrument track’s main pan control but rather the pan control located within the Instrument section of an instrument track’s channel strip. It’s a single pan knob that Pro Tools identifies as "MIDI Pan Indicator."
* Speak/Reset Instrument Pan, Option+N: What would an instrument pan be without a quick means to reset it? To speak or reset the Instrument Pan with the Flo Tools Inspector, use Option+N. 
* Speak And Navigate to First or Last playlist, shift+home/End
* Speak And Move Back or Ahead 5 Playlists: shift+page Up/Page down

These playlist commands were introduced in Pro Tools 2018.12 but, since there was no update to Flo Tools at that time because we were playing a game of Broken Beta Build Bingo, we’re adding them now.

* Previous/Next track view on selected tracks: Control Command left/Right arrow
* Previous/Next track view on all tracks: Control Option Command left/Right arrow
* Toggle Track view on all tracks: Option Hyphen

These commands have been a part of Pro Tools since practically the beginning. 

You may recall that Flo Tools 2018.7 introduced a sort of safety net to prevent users from unwittingly changing the track view and finding themselves no longer able to edit waveforms because the track view might have been changed to volume or something else. 

well, now that the Flo Tools Inspector has the ability to easily report track view status, we’ve made it possible to use these shortcuts to switch track views with keyboard shortcuts instead of having to pop-up the menu. 

There’s still a sort of safety net in place. That is, let’s say you’ve pressed Command+Control+Shift+Right Arrow, thinking you’re panning right on the right channel of a stereo track and you’ve forgotten to turn on the Inspector, you’ll be alerted that you’ve just changed the track view of the selected track. 

With that, you can simply either undo the action or press the same modifiers with the opposite arrow key to cycle the track view back.

* Adjust all track heights to fit in Edit window: control+option+command+up/down arrow

Why did we include this command? Well, basically, because we can. Actually, it’s similar to the commands listed just above in that you’re alerted to the fact that track heights have all been adjusted and you can verify the height of one track and know that all tracks are set to the same height. You may never need this command but, if you do, Flo Tools has you covered. Covered in what? We’re not sure exactly but, you’re covered.

## Audio Suite Macros
We’ve added a macro group named Flo Tools Audio Suite with 3 new macros for quickly accessing a few buttons without the need to stop interacting with the Audio Suite plug-in view.

* Analyze: control+option+shift+command+a
* Preview Processing: control+option+shift+command+p
* Bypass:  control+option+shift+command+b
* Render: control+option+shift+command+r

Note that the Analyze button is not always present in the Audio Suite window. If it’s not available in the currently loaded plug-in, Flo Tools will alert you that there is no Analyze button. 

Also, it should be noted that depending on the particular plug-in, the visible name of the Analyze button can sometimes be different from what voiceOver sees. For example, the Analyze button might appear to sighted users as the Capture button. 

For that matter, sometimes the Render button can actually appear to say "Process." Regardless of what is visually displayed, whenever the buttons are available, these shortcuts will either press them or let you know that you’re losing your mind and trying to Analyze something with a plug-in that has no such feature. Good luck with that.

## Some Renamed Shortcuts
To be a little clearer and more consistent, we’ve renamed the following macros. What did we used to call them? Never you mind—just get used to the new names, OK? Here they come:

* Pan left on mono/left channel, Command Control Left Arrow
* Pan right on mono/left channel, Command Control Right Arrow
* Pan left on right channel, Command Control Shift Left Arrow
* Pan right on right channel, Command Control Shift Right Arrow

## Shortcut Helper Updates
Yeah, yeah, there have been small but important changes to some Shortcut Helper macros but those are too numerous and too under the hood to mention. As always, if you notice any mistakes or incorrect language in any helper macros, let us know. And if you hear any fowl language from the helper macros, it might have been typed while we were yet again rewriting macros… 

Actually, we’re pretty sure everything is rated G.

##Introducing the Virtual Extended Keyboard
Flo Num Pad is now called Virtual Extended Keyboard. Why the name change? Well, its function has now expanded to support users of those pesky Touch Bars on the newer Mac Book Pros. The Virtual Extended Keyboard allows you to use the FN key along with other qwerty keys to simulate the Function Keys f1 through f12 and f16 through f19. Why the gap? Why not f13, 14 and 15? Apparently, Apple has reserved those for things like screen brightness and other nonsense. Oh well, . at any rate, here are the shortcuts:

* FN+1 (on the numbers row): f1
* FN+2 (on the numbers row): f2
* FN+3 (on the numbers row): f3
* FN+4 (on the numbers row): f4
* FN+q: f5
* FN+w: f6
* FN+e: f7
* FN+r: f8
* FN+a: f9
* FN+s: f10
* FN+d: f11
* FN+f: f12
* FN+z: f16
* FN+x: f17
* FN+c: f18
* FN+v: f19


## Thank You
As always, thanks for using Flo Tools and we hope it continues to help you make the most of your Pro Tools experience.

Go with the Flo!

The Flo Tools Team