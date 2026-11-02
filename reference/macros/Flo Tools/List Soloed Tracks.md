# List Soloed Tracks

- Group: Flo Tools
- UID: 901A4E73-54C8-436C-A98F-8F42FF754509
- Enabled: True
- Triggers: none

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  app = Application.currentApplication()
  app.includeStandardAdditions = true
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  masterFilter = {name:{_contains:" - Master Track"}}
  soloSpecifier = ObjectSpecifier().buttons["Solo"].value
  soloFilter = {_match:[soloSpecifier,""]}
  safeFilter = {_match:[soloSpecifier,{_contains:"safe"}]}
  inactiveFilter = {_match:[soloSpecifier,{_contains:"inactive"}]}
  tracks = mix.groups.whose({_not:[masterFilter, soloFilter, safeFilter, inactiveFilter]}).name()
  if (tracks.length==0) vo.output("No tracks are soloed.")
   else {
  title = tracks.length+" Soloed"
  prompt = "Choose tracks to unsolo."
  ok = "Unsolo"
  selections = app.chooseFromList(tracks, {withTitle:title, withPrompt:prompt, okButtonName:ok, multipleSelectionsAllowed:true})
  for (s in selections) {
  track = mix.groups.byName(selections[s])
  track.buttons.byName("Solo").click()
  }}
  ```
