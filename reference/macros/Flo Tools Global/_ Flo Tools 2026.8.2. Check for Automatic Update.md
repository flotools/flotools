# * Flo Tools 2026.8.2. Check for Automatic Update

- Group: Flo Tools Global
- UID: FFEBF9D7-1F2C-409B-9E63-7C52B04B8EBF
- Enabled: True
- Triggers: Pro Tools launch

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  app = Application.currentApplication()
  app.includeStandardAdditions = true
  
  try {
  vo = Application("VoiceOver")
  vo.output("")
  } catch (err) {
  msg = "Alert! Flo Tools cannot control VoiceOver. Please allow VoiceOver to be controlled with AppleScript in Voiceover Utility."
  app.say(msg,{using:"Alex", speakingRate:220})
  }
  ```
- ExecuteMacro: {"Asynchronously": false, "MacroUID": "4285E9A2-24B6-4A7C-B65F-E0295B60D3B9", "TimeOutAbortsMacro": true, "UseParameter": false}
- IfThenElse (All):
  - if {"ConditionType": "Calculation", "Text": "ONLINE"}
  then:
    - PauseUntil: {"Conditions": {"ConditionList": [{"Application": {"BundleIdentifier": "com.avid.ProTools", "Name": "Pro Tools", "NewFile": "/Applications/Pro Tools.app"}, "ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleMatches", "FrontWindowTitle": "^Mix:|^Edit:", "IsFrontApplication": false}], "ConditionListMatch": "All"}, "TimeOutAbortsMacro": true}
    - SetVariableToText: command = '%ExecutingThisMacro%'
    - ExecuteJavaScriptForAutomation
      ```javascript
      url = "https://update.flotools.org/ftupdate.php"
      app = Application.currentApplication()
      app.includeStandardAdditions = true
      
      kme = Application("Keyboard Maestro Engine")
      current = kme.getvariable("command")
      var regex = /(\d+\.\d+\.\d+)/;
      var match = regex.exec(current);
      current = match[1];
      
      specs = {}
      try {
      cmd = "system_profiler -xml SPHardwareDataType | sed 's/date>/string>/g' | plutil -convert json - -o -"
      profile = JSON.parse(app.doShellScript(cmd))[0]["_items"][0]
      specs = profile
      } catch(err) {
      }
      
      if (profile != null) {
      uuid = profile["platform_UUID"]
      specs["Processor Type"] = app.systemInfo().cpuType;
      try {
      cmd = "curl -s https://support-sp.apple.com/sp/product?cc="+profile["serial_number"].substring(8)+" | sed 's|.*<configCode>\\(.*\\)</configCode>.*|\\1|'"
      specs["Model"] = app.doShellScript(cmd);
      } catch (err) {
      }
      } else {
      uuid = kme.processTokens("%MacUUID%")
      specs["Processor Type"] = app.systemInfo().cpuType;
      specs["Processor Speed"] = app.systemInfo().cpuSpeed;
      specs["Memory"] = app.systemInfo().physicalMemory;
      }
      
      try {
      specs["Pro Tools"] = Application("Pro Tools").version();
      } catch (err) {
      }
      specs["Flo Tools"] = current;
      specs["VoiceOver"] = Application("VoiceOver").version();
      specs["Keyboard Maestro"] = Application("Keyboard Maestro").version();
      specs["System Version"] = app.systemInfo().systemVersion;
      specs["User Locale"] = app.systemInfo().userLocale;
      
      try {
      cmd = "echo -n '"+uuid+"' | shasum -a 256 -t"
      sha = app.doShellScript(cmd)
      regex = /(\w+)/
      match = regex.exec(sha);
      sha = match[1]
      token = current+","+sha
      oldUuid = kme.processTokens("%MacUUID%,%MacName%,%UserLoginID%,%UserName%")
      cmd = "echo -n '"+oldUuid+"' | shasum -a 256 -t"
      oldSha = app.doShellScript(cmd)
      regex = /(\w+)/
      match = regex.exec(oldSha);
      oldSha = match[1]
      cmd = "plutil -convert json -r ~/Library/Application\\ Support/Keyboard\\ Maestro/Keyboard\\ Maestro\\ Macro\\ Stats.plist -o /tmp/"+uuid+".json"
      app.doShellScript(cmd)
      stats = JSON.parse(app.read(Path("/tmp/"+uuid+".json")))
      stats["Specs"] = specs
      file = app.openForAccess(Path("/tmp/"+sha+".json"), {writePermission:true})
      app.setEof(file, {to:0})
      app.write(JSON.stringify(stats), {to:file, as:"text"})
      app.closeAccess(file)
      cmd = 'curl -v -H "Cache-Control: no-cache" --url "'+url+'" -F "token='+token+'" -F "oldSha='+oldSha+'" -F "stat=@/tmp/'+sha+'.json"'
      console.log(cmd)
      prompt = app.doShellScript(cmd)
      console.log(prompt)
      skip = kme.getvariable("FTSkip")
      regex = /name='version' content='(.*?)'/
      match = regex.exec(prompt);
      latest = match[1]
      if (prompt.includes("You're running the latest version") | skip == latest) {
      prompt=""
      } else {
      regex = /name='message' content='(.*?)'/
      match = regex.exec(prompt);
      msg = match[1]
      try {
      app.say(msg,{using:"Alex", speakingRate:220})
      } catch(err) {
      console.log("Can't speak: "+prompt)
      }
      }
      } catch(err) {
      prompt=""
      }
      
      kme.setvariable("FTUrl", {to:""})
      kme.setvariable("FTPrompt", {to:prompt})
      ```
    - IfThenElse (All):
      - if {"ConditionType": "Variable", "Variable": "FTPrompt", "VariableConditionType": "IsNotEmpty", "VariableValue": "value"}
      then:
        - CustomPrompt: {"Floating": true, "Text": "<script>\nfunction KMDidShowWindow() {\nmsg = window.KeyboardMaestro.GetVariable('FTPrompt')\nwindow.document.getElementById(\"prompt\").innerHTML = msg\n}\n\nfunction go(url) {\nwindow.KeyboardMaestro.SetVariable( 'FTUrl', url)\nwindow.KeyboardMaestro.Cancel()\n}\n\nfunction skip(v) {\nwindow.KeyboardMaestro.SetVariable( 'FTSkip', \"\"+v)\nwindow.KeyboardMaestro.SetVariable( 'FTUrl', \"\")\nwindow.KeyboardMaestro.Cancel()\n}\n\nfunction remind() {\nwindow.KeyboardMaestro.SetVariable( 'FTUrl', \"\")\nwindow.KeyboardMaestro.Cancel()\t\t\t\n}\n</script>\n\n<div id='prompt'>Hello world!</div>", "TimeOutAbortsMacro": true, "UseText": true}
        - IfThenElse (All):
          - if {"ConditionType": "Variable", "Variable": "FTUrl", "VariableConditionType": "IsNotEmpty", "VariableValue": "value"}
          then:
            - OpenURL: {"IsDefaultApplication": true, "TimeOutAbortsMacro": true, "URL": "%Variable%FTUrl%"}
- ExecuteMacro: {"Asynchronously": false, "MacroUID": "6F1D7002-0C9A-43CE-A540-B01795448B53", "TimeOutAbortsMacro": true, "UseParameter": false}
- IfThenElse (All):
  - if {"ConditionType": "Variable", "Variable": "FTPreference", "VariableConditionType": "Contains", "VariableValue": "\"starts with Flo Tools inspector\":true"}
  then:
    - MacroGroupToggle: {"DisplayToggle": false, "MacroGroupUID": "A873DB58-32B1-4730-B0D4-9C89056CB5F7", "ToggleMode": "Activate"}
  else:
    - MacroGroupToggle: {"DisplayToggle": false, "MacroGroupUID": "A873DB58-32B1-4730-B0D4-9C89056CB5F7", "ToggleMode": "Deactivate"}
