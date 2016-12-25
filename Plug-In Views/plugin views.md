---
layout: page
title: Plugin Views
permalink: /Plug-In Views/
---

<script src="/js/audio.js"></script>

<audio controls id="audioFloTools2.0PlugInViews" onPlaying="playing(this)" onPause="pauseing(this)" onEnded="ending(this)">
<source src="/Plug-In Views/Flo Tools Plug-In Views demo.m4a" type="audio/mp4">
Your browser does not support html5 audio.
</audio>

Flo Tools provides an alternative means of browsing parameters in the Plug-In window. The script relies on user-generated text files to provide Flo Tools with a template for navigating parameters along with the option to move the mouse pointer to specific coordinates within the Plug-In window.

When a plug-in is instantiated, if Flo Tools detects a matching plug-in view file, it will load the default view for the plug-in.

With the view loaded, pressing Control plus the arrow keys allows the user to navigate to the available parameters according to the formatting of the template file. If a parameter is mapped to specific coordinates, the mouse pointer will automatically move to those coordinates. Issuing a mouse click at that location will activate the item.

For example, for a control that includes an edit field, clicking the edit field makes it possible to simply enter a value rather than incrementing the parameter using VoiceOver. For toggle controls such as bypass or invert polarity, issuing a mouse click will change the state of the control. If the Flo Tools Plug-In Monitor is enabled, Flo Tools will automatically speak the changes as they are made.

## Getting Started with Plug-In Views:

Flo Tools provides a few plug-in views for the Dyn 3 compressor and the EQ 3  7-band EQ.

These plug-in view files  are located in ~/Library/Application Support/Flo Tools/Plug-In Views. To see how this feature works, do the following:

1. Instantiate the EQ 3 7-band EQ on a track. Notice that Flo Tools says, "Default View for EQ 3 7-Band."
2. Press Control+right arrow. Flo Tools says, "Input Level, 0.0 dB." Press Control+right arrow again and Flo Tools says, "Output Level, 0.0 db." Notice that pressing Control+right arrow again only repeats the previous message and there is nothing further to the right of "Output Level".
3. Now press Control+down arrow and Flo Tools says, "High Pass Freq, 20.0 Hz." Press Control+left arrow and Flo Tools says, "High-Pass Q, 1.0." Using Control plus the arrow keys, navigate around the plug-in parameters and notice that they are organized into columns and rows.
4. Navigate down to the Mid-Band Freq. Flo Tools says, "Mid-Band Freq, 1000.0 Hz."
5. With the Plug-In Monitor engaged (Option+/), press Control+Option+Shift+Space Bar to issue a mouse click.
6. Type, '3.5K" and press Return. Flo Tools says, "3.50 kHz, Mid-Band Freq."

Using the above steps, one can edit parameters directly by typing their values instead of using VoiceOver to increment or decrement. However, you can also increase or decrease a parameter’s value by pressing up or down arrows after you’ve clicked on the parameter’s text field.


## Creating Custom Views:

To create a custom plug-in view, do the following:

1. Instantiate a plug-in for which you’d like to create a custom view and make sure the Plug-In window is open.
2. Press Control+Option+Shift+m twice and  navigate to the Keyboard Maestro Engine menu extra.
3. Select "Display Template" from the Keyboard Maestro Engine menu. Flo Tools opens a dialog box with a text area populated with the name of the plug-in along with any visible parameters.
4. Press Command+a to select the text and copy it to the clipboard by pressing Command+c.
5. Open a new text document and paste the contents of the clipboard into the text file. The first line of the document will contain the exact name of the plug-in followed by the names of the parameters with coordinates formatted with braces, brackets and commas according to the JSON standard.
6. Select the first line of text in the document and press Command+x to cut it to the clipboard. Make sure to select only the text in the first line and not to also select the invisible carriage return by pressing Shift+down arrow. This will result in a space being appended to the filename.
7. Save the document and paste the name of the plug-in that was cut from the first line of the text into the name field in the Save dialog. Make sure to save the document as a plain text file. Any other format will not work.
8. Navigate back to Pro Tools. Flo Tools should say, "Default View for (and then the name of the plug-in)."

You’re now ready to add coordinate values into the text file that will instruct Flo Tools where to move the mouse pointer whenever you navigate that plug-in with Control plus the arrow keys.

For the following section you’ll most likely need sighted assistance to help position the mouse pointer over specific elements.

## Copying Screen Coordinates:

To obtain the screen coordinates for an element, do the following:

1. Position the mouse pointer directly over the element for which you’d like to create an entry.
2. Press Command+Option+Shift+c to copy the coordinates. Flo Tools speaks the mouse pointer coordinates in points from the top left corner of the window and copies the coordinates to the clipboard.
3. Navigate to the plug-in view text file and locate the name of the element for which you just copied coordinates. Notice that after each parameter name, there are two zeros separated by a comma.
4. Delete the two zeros along with the comma between them and paste the coordinates that were copied to the clipboard.
5. Save the document and navigate back to Pro Tools. If Flo Tools once again says, "Default view for," etc., you’ve successfully added the coordinates. If Flo Tools doesn’t indicate that the default view has been loaded, that probably means that you’ve inadvertently added an extra space or deleted an extra comma or something similar. Double-check your previous edit to the text file.

You can test each parameter in the Plug-In window as you go along by navigating with Control plus the left or right arrows, issuing a click and typing in a value then pressing Return.

##Plug-In Tabs:

Some plug-ins have multiple parts or tabs in their user interface to organize information. Plug-In views supports this organization system by allowing a user to create coordinates to access these tabs by clicking them.

To create views to accommodate multiple tabs, do the following:

1. If you haven’t already done so, create a default view text file. (Refer to the steps above).
2. Determine how many tabs there are in the plug-in and create that many copies of the document.
3. Edit the names of the text files so that they are exactly the same as the original file and then append each with a hyphen and then a number starting with 1, 2, 3, etc. up to a maximum of 9.
4. Starting with the document ending in -1, replace the word "default" in the first line with the name of the tab.
5. Also in the first line, replace the numbers "-1,-1" with the coordinates of the tab where you want Flo Tools to click in order to access that particular tab.
6. Follow the above steps for documents ending in -2, -3, etc. to create the  files with their view names and click coordinates and save them.

If you’ve created and saved the files properly, pressing Command+1, Command+2, etc. within the plug-in window should load the corresponding plug-in views and Flo Tools should speak the names you’ve assigned to the various views as they’re bing loaded.

Note: when creating views for plug-ins with multiple tabs, it’s a good idea to have the contents of the file ending in -1 to be a duplicate of the default file (the file with no hyphen and number). This is the view that flo Tools will always load by default and it helps to have that view be identical to the first tab to have a consistent starting point so that, every time that plug-in is loaded, the first tab will be active.

When creating and working with multiple views for a plug-in, it’s sometimes necessary to load the default view manually. Press Command+0 to load the default view. This corresponds to the file which has no number appended to it and simply contains the plug-in’s name.

For a more detailed walk-through of Plug-in Views in Flo Tools, please refer to the audio tutorial.
