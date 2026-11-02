using System;
using System.Diagnostics;
using System.IO;
using System.Security;
using System.Security.Principal;
using System.Text;

namespace LoLBypass
{
    /// <summary>
    /// Two scheduled tasks, both "run with highest privileges" so the app never shows a UAC prompt:
    ///  - "LoL Bypass"    : at logon (10 s delay), starts the app hidden in the tray (--silent)
    ///  - "LoL Bypass UI" : on demand, used by the Start menu / Desktop shortcut to open the window
    /// </summary>
    internal static class Tasks
    {
        public const string LogonTask = "LoL Bypass";
        public const string UiTask = "LoL Bypass UI";

        static int Schtasks(string args, out string output)
        {
            var psi = new ProcessStartInfo("schtasks.exe", args)
            {
                UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true
            };
            using (var p = Process.Start(psi))
            {
                output = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd();
                p.WaitForExit(15000);
                return p.ExitCode;
            }
        }

        public static bool Exists(string name) => Schtasks($"/Query /TN \"{name}\"", out _) == 0;

        public static bool RunUiTask() => Schtasks($"/Run /TN \"{UiTask}\"", out _) == 0;

        public static bool StartupEnabled
        {
            get
            {
                if (Schtasks($"/Query /TN \"{LogonTask}\" /XML", out string xml) != 0) return false;
                return xml.IndexOf("<Enabled>false</Enabled>", StringComparison.OrdinalIgnoreCase) < 0;
            }
        }

        public static void SetStartup(bool on)
        {
            if (!Exists(LogonTask)) { if (on) Register(LogonTask, true, true); return; }
            Schtasks($"/Change /TN \"{LogonTask}\" {(on ? "/ENABLE" : "/DISABLE")}", out _);
        }

        static string UserId => WindowsIdentity.GetCurrent().Name;

        static string BuildXml(bool logonTrigger, bool enabled, string args)
        {
            string exe = SecurityElement.Escape(Path.Combine(Engine.AppDir, "LoLBypass.exe"));
            string user = SecurityElement.Escape(UserId);
            string trigger = logonTrigger
                ? $"<Triggers><LogonTrigger><Enabled>true</Enabled><UserId>{user}</UserId><Delay>PT10S</Delay></LogonTrigger></Triggers>"
                : "<Triggers />";
            return
$@"<?xml version=""1.0"" encoding=""UTF-16""?>
<Task version=""1.2"" xmlns=""http://schemas.microsoft.com/windows/2004/02/mit/task"">
  <RegistrationInfo><Description>LoL Bypass - play Riot games without a VPN</Description></RegistrationInfo>
  {trigger}
  <Principals>
    <Principal id=""Author"">
      <UserId>{user}</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd><RestartOnIdle>false</RestartOnIdle></IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>{(enabled ? "true" : "false")}</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context=""Author"">
    <Exec>
      <Command>{exe}</Command>
      <Arguments>{args}</Arguments>
      <WorkingDirectory>{SecurityElement.Escape(Engine.AppDir)}</WorkingDirectory>
    </Exec>
  </Actions>
</Task>";
        }

        static bool Register(string name, bool logonTrigger, bool enabled)
        {
            string xml = BuildXml(logonTrigger, enabled, logonTrigger ? "--silent" : "");
            string tmp = Path.Combine(Path.GetTempPath(), "lolbypass-task-" + Guid.NewGuid().ToString("N") + ".xml");
            try
            {
                File.WriteAllText(tmp, xml, Encoding.Unicode);
                return Schtasks($"/Create /TN \"{name}\" /XML \"{tmp}\" /F", out _) == 0;
            }
            finally { try { File.Delete(tmp); } catch { } }
        }

        /// <summary>Called by the installer (elevated).</summary>
        public static int Install(bool startup)
        {
            bool ok = Register(UiTask, false, true);
            ok &= Register(LogonTask, true, startup);
            return ok ? 0 : 1;
        }

        /// <summary>Called by the uninstaller (elevated).</summary>
        public static int Remove()
        {
            Schtasks($"/Delete /TN \"{LogonTask}\" /F", out _);
            Schtasks($"/Delete /TN \"{UiTask}\" /F", out _);
            return 0;
        }
    }
}
