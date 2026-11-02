# Tab 5

- Group: Flo Tools Selected Tab
- UID: C7AA19FE-CA82-48A7-9421-E43298342E17
- Enabled: True
- Triggers: Cmd+5

## Actions

- SetVariableToText: command = '%ExecutingThisMacro%'
- ExecuteJavaScriptForAutomation
  ```javascript
  command = Application("Keyboard Maestro Engine").getvariable("command")
  command = parseInt(command.substring(command.length-1))
  window = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0].windows[0]
  obj = window.radioButtons[command-1]
  obj.click()
  Application("VoiceOver").output(obj.name()+" selected")
  ```
