# Refresh Preference

- Group: Flo Tools
- UID: 6F1D7002-0C9A-43CE-A540-B01795448B53
- Enabled: True
- Triggers: none

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  app = Application.currentApplication()
  app.includeStandardAdditions = true
  kme = Application("Keyboard Maestro Engine")
  sys = Application('System Events')
  home = sys.currentUser.homeDirectory()
  fileName = home+"/Library/Application Support/Flo Tools/flotools.json"
  try {
  str = app.read(Path(fileName))
  console.log(str)
  } catch(err) {
  str = '{"temporary inspector":false,"starts with Flo Tools inspector":false,"timeout":"200"}'
  file = app.openForAccess(Path(fileName), {writePermission:true})
  app.setEof(file, {to:0})
  app.write(str, {to:file, as:"text"})
  app.closeAccess(file)
  }
  kme.setvariable("FTPreference", {to:str})
  preference = JSON.parse(str)
  if (preference["temporary inspector"] == true) {
  xml = "<array>	<dict>		<key>Action</key>		<string>Enable</string>		<key>MacroActionType</key>		<string>SetMacroEnable</string>		<key>MacroUID</key>		<string>E63048EB-FBD0-41A9-A4C7-8922216F11D3</string>	</dict></array>"
  kme.doScript(xml)
  } else {
  xml = "<array>	<dict>		<key>Action</key>		<string>Disable</string>		<key>MacroActionType</key>		<string>SetMacroEnable</string>		<key>MacroUID</key>		<string>E63048EB-FBD0-41A9-A4C7-8922216F11D3</string>	</dict></array>"
  kme.doScript(xml)
  }
  kme.setvariable("FTTimeout", {to:preference["timeout"]})
  ```
