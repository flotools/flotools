# * Flo Tools 2026.8.2. Check for Update

- Group: Flo Tools
- UID: 81FAF053-36E0-44EF-B9B9-F3EA638A0F44
- Enabled: True
- Triggers: StatusMenu {}

## Actions

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
  } catch(err) {
  prompt = "Server is temporarily unavailable. Please try again later.";
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
