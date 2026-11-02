# Close All Floating Windows

- Group: Flo Tools
- UID: F94D2326-4E17-4F5C-8A08-C06CF944F61F
- Enabled: True
- Triggers: Opt+Cmd+W

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  editFilter = {name:{_contains:"Edit:"}}
  mixFilter = {name:{_contains:"Mix:"}}
  while (pt.windows.whose({_not:[mixFilter, editFilter]}).length > 0) {
  close = pt.windows.whose({_not:[mixFilter, editFilter]})[0].attributes["AXCloseButton"].value()
  close.click()
  }
  ```
