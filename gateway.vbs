' OpenClaw Gateway (v2026.7.1-2) - protected launcher
Set sh = CreateObject("WScript.Shell")
ocDir = sh.ExpandEnvironmentStrings("%USERPROFILE%") & "\.openclaw"
' Step 1: repair gateway.cmd node path (ASCII junction) if mangled by openclaw
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File """ & ocDir & "\fix-gateway-cmd.ps1""", 0, True
' Step 2: launch the gateway via the (now repaired) cmd script
sh.Run """" & ocDir & "\gateway.cmd""", 0, False
