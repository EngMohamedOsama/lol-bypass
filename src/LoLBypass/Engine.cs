using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.ServiceProcess;
using System.Text.RegularExpressions;
using System.Threading;

namespace LoLBypass
{
    /// <summary>
    /// Runs GoodbyeDPI (TCP: login / chat / Vanguard / store) and zapret winws (UDP: match servers),
    /// keeps them alive, and restarts Vanguard (vgc) behind the bypass.
    /// </summary>
    internal sealed class Engine
    {
        public static readonly string AppDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
        public static readonly string DataDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "LoL Bypass");

        public string GdpiExe => Path.Combine(AppDir, @"bin\goodbyedpi\goodbyedpi.exe");
        public string WinwsExe => Path.Combine(AppDir, @"bin\zapret\winws.exe");
        public string IpSet => Path.Combine(AppDir, "riot-game-ips.txt");
        public string ConfigPath => Path.Combine(DataDir, "config.ini");
        public string LogPath => Path.Combine(DataDir, "bypass.log");

        public const string GdpiArgs =
            "-1 --port 8443 --port 5222 --port 5223 --port 2099 --port 8088 --port 8393 --port 8394 --port 8400";

        public static readonly string[] StrategyNames =
        {
            "Fake packets x6", "Fake packets x12", "IP fragmentation", "Fake + IP fragmentation"
        };

        static readonly string[] StrategyArgs =
        {
            "--dpi-desync=fake --dpi-desync-repeats=6",
            "--dpi-desync=fake --dpi-desync-repeats=12",
            "--dpi-desync=ipfrag2",
            "--dpi-desync=fake,ipfrag2 --dpi-desync-repeats=6"
        };

        readonly object _lock = new object();
        public bool Paused { get; private set; } = true;

        public Engine()
        {
            Directory.CreateDirectory(DataDir);
        }

        // ---------- config ----------
        public int Strategy
        {
            get
            {
                try
                {
                    if (File.Exists(ConfigPath))
                    {
                        var m = Regex.Match(File.ReadAllText(ConfigPath), @"Strategy\s*=\s*([1-4])");
                        if (m.Success) return int.Parse(m.Groups[1].Value);
                    }
                }
                catch { }
                return 1;
            }
            set
            {
                try { File.WriteAllText(ConfigPath, "Strategy=" + Math.Max(1, Math.Min(4, value)) + "\r\n"); } catch { }
            }
        }

        public string WinwsArgs
        {
            get
            {
                string m = StrategyArgs[Strategy - 1];
                // profile 1: League / TFT match servers (UDP 5000-9999, Riot's own IP ranges)
                // profile 2: VALORANT match servers (UDP 7000-8999, any IP - some run outside Riot's ranges)
                return "--wf-udp=5000-9999 " +
                       $"--filter-udp=5000-9999 --ipset=\"{IpSet}\" --dpi-desync-any-protocol=1 --dpi-desync-cutoff=n3 {m} --new " +
                       $"--filter-udp=7000-8999 --dpi-desync-any-protocol=1 --dpi-desync-cutoff=n3 {m}";
            }
        }

        // ---------- log ----------
        public void Log(string msg)
        {
            try
            {
                lock (_lock)
                {
                    File.AppendAllText(LogPath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss}  {msg}\r\n");
                    var fi = new FileInfo(LogPath);
                    if (fi.Length > 512 * 1024)
                    {
                        var tail = File.ReadAllLines(LogPath).Skip(Math.Max(0, File.ReadAllLines(LogPath).Length - 500)).ToArray();
                        File.WriteAllLines(LogPath, tail);
                    }
                }
            }
            catch { }
        }

        // ---------- processes ----------
        public static bool IsRunning(string name) => Process.GetProcessesByName(name).Length > 0;
        public bool GdpiRunning => IsRunning("goodbyedpi");
        public bool WinwsRunning => IsRunning("winws");
        public bool Active => !Paused && GdpiRunning && WinwsRunning;

        public bool FilesPresent => File.Exists(GdpiExe) && File.Exists(WinwsExe);

        void Launch(string exe, string args)
        {
            try
            {
                var psi = new ProcessStartInfo(exe, args)
                {
                    WorkingDirectory = Path.GetDirectoryName(exe),
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                Process.Start(psi);
                Log($"started {Path.GetFileName(exe)} {args}");
            }
            catch (Exception ex)
            {
                Log($"FAILED to start {exe}: {ex.Message}");
            }
        }

        public void StartGdpi() => Launch(GdpiExe, GdpiArgs);
        public void StartWinws() => Launch(WinwsExe, WinwsArgs);

        public static void KillAll()
        {
            foreach (var n in new[] { "goodbyedpi", "winws" })
                foreach (var p in Process.GetProcessesByName(n))
                    try { p.Kill(); p.WaitForExit(3000); } catch { }
        }

        public void Start(bool restartVanguard)
        {
            lock (_lock)
            {
                KillAll();
                Thread.Sleep(500);
                StartGdpi();
                StartWinws();
                Paused = false;
            }
            // a helper can lose its WinDivert handle on first launch (Vanguard / driver race);
            // confirm both are alive and relaunch whichever died before we call it "on"
            for (int i = 0; i < 3; i++)
            {
                Thread.Sleep(700);
                lock (_lock)
                {
                    if (Paused) return;
                    if (!GdpiRunning) StartGdpi();
                    if (!WinwsRunning) StartWinws();
                }
            }
            if (restartVanguard) RestartVanguard();
            Log("bypass ON (strategy " + Strategy + ")");
        }

        public void Stop()
        {
            lock (_lock)
            {
                Paused = true;
                KillAll();
            }
            Log("bypass OFF");
        }

        /// <summary>Restarts any part that died. Called by the watchdog timer.</summary>
        public void Watchdog()
        {
            if (Paused) return;
            lock (_lock)
            {
                if (!GdpiRunning) { Log("goodbyedpi not running - restarting"); StartGdpi(); }
                if (!WinwsRunning) { Log("winws not running - restarting"); StartWinws(); }
            }
        }

        public void RestartVanguard()
        {
            try
            {
                using (var sc = new ServiceController("vgc"))
                {
                    if (sc.Status != ServiceControllerStatus.Running) return;
                    sc.Stop();
                    sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(10));
                    sc.Start();
                    sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(10));
                    Log("vgc restarted behind the bypass");
                }
            }
            catch (Exception ex) { Log("vgc restart skipped: " + ex.Message); }
        }

        // ---------- Riot Client ----------
        public static string FindRiotClient()
        {
            try
            {
                string json = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                    @"Riot Games\RiotClientInstalls.json");
                if (File.Exists(json))
                {
                    string text = File.ReadAllText(json);
                    foreach (var key in new[] { "rc_default", "rc_live", "rc_beta" })
                    {
                        var m = Regex.Match(text, "\"" + key + "\"\\s*:\\s*\"([^\"]+)\"");
                        if (m.Success)
                        {
                            string p = m.Groups[1].Value.Replace("\\\\", "\\").Replace('/', '\\');
                            if (File.Exists(p)) return p;
                        }
                    }
                }
            }
            catch { }
            foreach (var p in new[]
                     {
                         @"C:\Riot Games\Riot Client\RiotClientServices.exe",
                         @"D:\Riot Games\Riot Client\RiotClientServices.exe"
                     })
                if (File.Exists(p)) return p;
            return null;
        }

        public static readonly (string Name, string Product)[] Games =
        {
            ("League of Legends / TFT", "league_of_legends"),
            ("VALORANT", "valorant"),
            ("Legends of Runeterra", "bacon")
        };

        public bool LaunchGame(int index, out string error)
        {
            error = null;
            string rc = FindRiotClient();
            if (rc == null) { error = "Riot Client not found. Install it from riotgames.com first."; return false; }
            try
            {
                Process.Start(new ProcessStartInfo(rc,
                    $"--launch-product={Games[index].Product} --launch-patchline=live") { UseShellExecute = true });
                Log("launched " + Games[index].Name);
                return true;
            }
            catch (Exception ex) { error = ex.Message; return false; }
        }
    }
}
