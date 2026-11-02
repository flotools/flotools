# Flo Tools Preferences

- Group: Flo Tools
- UID: 4958F0C0-2806-4D1F-A1DA-C0124F1AD759
- Enabled: True
- Triggers: Ctrl+Cmd+,

## Actions

- ExecuteMacro: {"Asynchronously": false, "MacroUID": "6F1D7002-0C9A-43CE-A540-B01795448B53", "TimeOutAbortsMacro": true, "UseParameter": false}
- CustomPrompt: {"Floating": true, "Text": "<script>\nfunction KMInit() {\nstr = window.KeyboardMaestro.GetVariable('FTPreference')\nconsole.log(\"Input: \"+str)\nwindow.preference = JSON.parse(str)\nwindow.setTimeout(set, 100)\n}\n\nfunction set() {\nfor (key in window.preference) {\nvalue = window.preference[key]\nif (typeof(value) == typeof(true)) {\nselector = \"input[name='\"+key+\"']\"\nconsole.log(selector)\nwindow.document.querySelector(selector).checked = value\ncontinue\n}\nselector = \"input[name='\"+key+\"'][value='\"+value+\"']\"\nconsole.log(selector)\nelement = window.document.querySelector(selector)\nif (element != null) {\nelement.checked = true\ncontinue\n}\nselector = \"select[name='\"+key+\"']\"\nconsole.log(selector)\nelement = window.document.querySelector(selector)\nif (element != null) {\nfor (i=0; i<element.options.length; i++) {\nif (element.options[i].value == value) {\nelement.options[i].selected = true\nbreak\n}\n}\ncontinue\n}\n\n}\n}\n\nfunction ok() {\nselector = \"input,select\"\nsettings = window.document.querySelectorAll(selector)\nfor (s in settings) {\nelement = settings[s]\nif (element.tagName == null) continue\nconsole.log(\"Name: \"+element.name+\", tag: \"+element.tagName);\nif (element.type == \"checkbox\") {\nwindow.preference[element.name] = element.checked\n} else if (element.type == \"radio\" & element.checked == true) {\nwindow.preference[element.name] = element.value\n} else if (element.tagName == \"SELECT\") {\nwindow.preference[element.name] = element.options[element.selectedIndex].value\n}\n}\nstr = JSON.stringify(window.preference)\nconsole.log(\"Output: \"+str)\nwindow.KeyboardMaestro.SetVariable( 'FTPreference', str)\nwindow.KeyboardMaestro.Cancel()\n}\n\nfunction cancel() {\nwindow.KeyboardMaestro.Cancel()\n}\n\n</script>\n\n<div id='preference'>\n<p>\n<input name=\"temporary inspector\" type=\"checkbox\" />Use temporary inspector<br/>\n<input name=\"starts with Flo Tools inspector\" type=\"checkbox\" />Turn on the Flo Tools inspector when Pro Tools starts<br/>\nDoubletap Timeout: \n<select name=\"timeout\">\n<option value=\"200\">200</option>\n<option value=\"300\">300</option>\n<option value=\"400\">400</option>\n<option value=\"500\">500</option>\n</select>\n</p>\n\n<p>\n<button onClick=\"cancel()\">CANCEL</button>\n<button onClick=\"ok()\">OK</button>\n</p>\n</div>", "TimeOutAbortsMacro": true, "UseText": true}
- ExecuteJavaScriptForAutomation
  ```javascript
  app = Application.currentApplication()
  app.includeStandardAdditions = true
  kme = Application("Keyboard Maestro Engine")
  sys = Application('System Events')
  str = kme.getvariable("FTPreference")
  console.log(str)
  home = sys.currentUser.homeDirectory()
  fileName = home+"/Library/Application Support/Flo Tools/flotools.json"
  file = app.openForAccess(Path(fileName), {writePermission:true})
  app.setEof(file, {to:0})
  app.write(str, {to:file, as:"text"})
  app.closeAccess(file)
  ```
- ExecuteMacro: {"Asynchronously": false, "MacroUID": "6F1D7002-0C9A-43CE-A540-B01795448B53", "TimeOutAbortsMacro": true, "UseParameter": false}
