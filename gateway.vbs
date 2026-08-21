' OpenClaw Gateway (v2026.7.1-2) - protected launcher
' Step 1: repair gateway.cmd node path (ASCII junction) if mangled by openclaw
CreateObject("WScript.Shell").Run "powershell -NoProfile -ExecutionPolicy Bypass -File ""C:\Users\chuzijun\.openclaw\fix-gateway-cmd.ps1""", 0, True
' Step 2: launch the gateway via the (now repaired) cmd script
CreateObject("WScript.Shell").Run """C:\Users\chuzijun\.openclaw\gateway.cmd""", 0, False
