# Select main counter

- Group: Flo Tools
- UID: 4E3AFEFC-3AB6-400E-87C6-8BC0AA1A3F51
- Enabled: True
- Triggers: Opt+Cmd+F4

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  edit.groups.byName("Counter Display Cluster").buttons.byName("Main Counter selector").click()
  ```
