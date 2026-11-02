# Select Grid Value

- Group: Flo Tools
- UID: 3E8EB020-8956-4CBC-8C42-0833286D55F4
- Enabled: True
- Triggers: Opt+Cmd+F8

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  edit.groups.byName("Grid/Nudge Cluster").popUpButtons.byName("Grid Value").click()
  ```
