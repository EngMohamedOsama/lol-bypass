using System;
using System.Diagnostics;
using System.Linq;
using System.Security.Principal;
using System.Threading;
using System.Windows.Forms;

namespace LoLBypass
{
    internal static class Program
    {
        public const string MutexName = @"Global\LoLBypassApp";
        public const string ShowEventName = @"Global\LoLBypassShow";

        static bool IsElevated =>
            new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);

        [STAThread]
        static int Main(string[] args)
        {
            var a = args.Select(x => x.ToLowerInvariant()).ToArray();

            // ---- installer / uninstaller hooks (run elevated by the setup) ----
            if (a.Contains("--install-tasks")) return Tasks.Install(!a.Contains("--no-startup"));
            if (a.Contains("--remove-tasks")) { Engine.KillAll(); return Tasks.Remove(); }
            if (a.Contains("--stop")) { CloseRunningInstance(); Engine.KillAll(); return 0; }

            bool silent = a.Contains("--silent");

            // ---- UI preview only (no bypass, no admin) - used for screenshots / design work ----
            if (a.Contains("--preview"))
            {
                Application.EnableVisualStyles();
                var eng = new Engine();
                var f = new MainForm(eng, System.Drawing.SystemIcons.Shield);
                f.Shown += (s, e) => f.RefreshState(false);
                Application.Run(f);
                return 0;
            }

            // ---- not elevated: hand over to the elevated task (no UAC prompt), else ask for admin ----
            if (!IsElevated)
            {
                if (Tasks.Exists(Tasks.UiTask) && Tasks.RunUiTask()) return 0;
                try
                {
                    Process.Start(new ProcessStartInfo(Application.ExecutablePath, string.Join(" ", args))
                    { UseShellExecute = true, Verb = "runas" });
                }
                catch { /* user said no to UAC */ }
                return 0;
            }

            // ---- single instance: a second launch just opens the existing window ----
            using (var mutex = new Mutex(true, MutexName, out bool created))
            {
                if (!created)
                {
                    if (!silent)
                        try { EventWaitHandle.OpenExisting(ShowEventName).Set(); } catch { }
                    return 0;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                using (var ctx = new TrayContext(silent))
                    Application.Run(ctx);
                GC.KeepAlive(mutex);
            }
            return 0;
        }

        static void CloseRunningInstance()
        {
            foreach (var p in Process.GetProcessesByName("LoLBypass"))
            {
                if (p.Id == Process.GetCurrentProcess().Id) continue;
                try { p.Kill(); p.WaitForExit(3000); } catch { }
            }
        }
    }
}
