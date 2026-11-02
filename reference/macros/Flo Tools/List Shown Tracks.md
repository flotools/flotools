# List Shown Tracks

- Group: Flo Tools
- UID: 7040C918-4589-43DA-AEE2-71CD77243B57
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
  allTracks = mix.tables.byName("Track List").rows.uiElements[1].buttons[0].name()
  show = ObjectSpecifier().uiElements[0].buttons[0].name
  tracks = mix.tables.byName("Track List").rows.whose({_match:[show,{_contains:"Shown"}]}).uiElements[1].buttons[0].name()
  for (t in tracks) {
  tracks[t] = tracks[t].replace(/^Selected /, "")
  }
  if (tracks.length == 0) vo.output("No tracks are currently shown.")
  else {
  title = tracks.length+" Shown"
  prompt = "Choose tracks to hide."
  ok = "Hide"
  selections = app.chooseFromList(tracks, {withTitle:title, withPrompt:prompt, okButtonName:ok, multipleSelectionsAllowed:true})
  for (s in selections) {
  t = allTracks.indexOf(selections[s])
  track = mix.tables.byName("Track List").rows[t].uiElements[0].buttons[0].click()
  }
  }
  ```
