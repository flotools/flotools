# Select Nudge Value

- Group: Flo Tools
- UID: 6BD51E8B-0600-4469-86C3-0FFDC5FFE017
- Enabled: True
- Triggers: Opt+Cmd+F7

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  edit.groups.byName("Grid/Nudge Cluster").popUpButtons.byName("Nudge value").click()
  ```
