# List Unsoloed Tracks

- Group: Flo Tools
- UID: 943B53A6-0CB8-484E-8A3F-B5B101F138C0
- Enabled: True
- Triggers: none

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  {
  vo = Application("VoiceOver")
  app = Application.currentApplication()
  app.includeStandardAdditions = true
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  masterFilter = {name:{_contains:" - Master Track"}}
  soloSpecifier = ObjectSpecifier().buttons["Solo"].value
  soloFilter = {_match:[soloSpecifier,"Selected"]}
  safeFilter = {_match:[soloSpecifier,{_contains:"safe"}]}
  inactiveFilter = {_match:[soloSpecifier,{_contains:"inactive"}]}
  tracks = mix.groups.whose({_not:[masterFilter, soloFilter, safeFilter, inactiveFilter]}).name()
  if (tracks.length==0) vo.output("No tracks are unsoloed.")
   else {
  title = tracks.length+" Unsoloed"
  prompt = "Choose tracks to solo."
  ok = "Solo"
  selections = app.chooseFromList(tracks, {withTitle:title, withPrompt:prompt, okButtonName:ok, multipleSelectionsAllowed:true})
  for (s in selections) {
  track = mix.groups.byName(selections[s])
  track.buttons.byName("Solo").click()
  }
  }
  }
  ```
