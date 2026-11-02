' Opens LoL Bypass through its elevated scheduled task (no admin prompt).
Set sh = CreateObject("WScript.Shell")
rc = sh.Run("schtasks.exe /run /tn ""LoL Bypass UI""", 0, True)
If rc <> 0 Then MsgBox "LoL Bypass is not installed on this PC. Run Install.bat first.", 48, "LoL Bypass"
