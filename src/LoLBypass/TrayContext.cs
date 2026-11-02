using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace LoLBypass
{
    /// <summary>Owns the engine, the tray icon, the window and the watchdog.</summary>
    internal sealed class TrayContext : ApplicationContext
    {
        readonly Engine _engine = new Engine();
        readonly NotifyIcon _tray;
        readonly MainForm _form;
        readonly System.Windows.Forms.Timer _watchdog = new System.Windows.Forms.Timer { Interval = 10000 };
        readonly System.Windows.Forms.Timer _ui = new System.Windows.Forms.Timer { Interval = 1500 };
        readonly ToolStripMenuItem _miToggle;
        readonly EventWaitHandle _showEvent;
        volatile bool _busy;
        bool _exiting;

        public TrayContext(bool silent)
        {
            Icon icon = LoadIcon();

            _form = new MainForm(_engine, icon);
            _form.ToggleRequested += (s, e) => Toggle();
            _form.StrategyChanged += (s, e) => { if (!_engine.Paused) RunBusy(() => _engine.Start(false)); };
            _form.HideRequested += (s, e) => HideWindow(true);
            _form.FormClosing += (s, e) => { if (!_exiting && e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; HideWindow(true); } };
            var _ = _form.Handle; // create handle so BeginInvoke works while hidden

            var menu = new ContextMenuStrip { Renderer = new DarkRenderer(), ShowImageMargin = false };
            var open = new ToolStripMenuItem("Open LoL Bypass") { Font = Theme.Font(9f, FontStyle.Bold) };
            open.Click += (s, e) => ShowWindow();
            _miToggle = new ToolStripMenuItem("Stop bypass");
            _miToggle.Click += (s, e) => Toggle();
            var restart = new ToolStripMenuItem("Restart bypass");
            restart.Click += (s, e) => RunBusy(() => _engine.Start(true));
            var log = new ToolStripMenuItem("Open log");
            log.Click += (s, e) => { try { Process.Start("notepad.exe", "\"" + _engine.LogPath + "\""); } catch { } };
            var exit = new ToolStripMenuItem("Exit (stop bypass)");
            exit.Click += (s, e) => Exit();
            menu.Items.AddRange(new ToolStripItem[] { open, new ToolStripSeparator(), _miToggle, restart, log, new ToolStripSeparator(), exit });

            _tray = new NotifyIcon { Icon = icon, Visible = true, ContextMenuStrip = menu, Text = "LoL Bypass" };
            _tray.MouseClick += (s, e) => { if (e.Button == MouseButtons.Left) ShowWindow(); };

            _watchdog.Tick += (s, e) => { if (!_busy) _engine.Watchdog(); UpdateUi(); };
            _ui.Tick += (s, e) => UpdateUi();

            // a second launch signals this event -> show window
            _showEvent = CreateShowEvent();
            new Thread(() =>
            {
                while (true)
                {
                    try { _showEvent.WaitOne(); } catch { return; }
                    if (_exiting) return;
                    try { _form.BeginInvoke((Action)ShowWindow); } catch { }
                }
            }) { IsBackground = true }.Start();

            _engine.Log($"=== LoL Bypass {Assembly.GetExecutingAssembly().GetName().Version} starting (silent={silent}) from {Engine.AppDir}");
            if (!_engine.FilesPresent)
            {
                _engine.Log("goodbyedpi.exe or winws.exe missing - antivirus?");
                _tray.ShowBalloonTip(8000, "LoL Bypass", "Bypass files are missing - your antivirus may have removed them. Reinstall LoL Bypass.", ToolTipIcon.Error);
            }

            if (!silent) ShowWindow();
            RunBusy(() => _engine.Start(true), () =>
            {
                if (silent) _tray.ShowBalloonTip(2500, "LoL Bypass", "Bypass active. Click the tray icon to open.", ToolTipIcon.Info);
            });
            _watchdog.Start(); _ui.Start();
        }

        static EventWaitHandle CreateShowEvent()
        {
            // allow any local user process (incl. non-elevated) to signal "show window"
            var sec = new EventWaitHandleSecurity();
            sec.AddAccessRule(new EventWaitHandleAccessRule(new SecurityIdentifier(WellKnownSidType.WorldSid, null),
                EventWaitHandleRights.Synchronize | EventWaitHandleRights.Modify, AccessControlType.Allow));
            return new EventWaitHandle(false, EventResetMode.AutoReset, Program.ShowEventName, out _, sec);
        }

        static Icon LoadIcon()
        {
            try
            {
                using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("LoLBypass.icon.ico"))
                    if (s != null) return new Icon(s);
            }
            catch { }
            return SystemIcons.Shield;
        }

        void RunBusy(Action work, Action after = null)
        {
            if (_busy) return;
            _busy = true;
            UpdateUi();
            Task.Run(() =>
            {
                try { work(); }
                catch (Exception ex) { _engine.Log("error: " + ex.Message); }
                finally
                {
                    _busy = false;
                    try { _form.BeginInvoke((Action)(() => { UpdateUi(); after?.Invoke(); })); } catch { }
                }
            });
        }

        void Toggle()
        {
            if (_engine.Paused) RunBusy(() => _engine.Start(true));
            else RunBusy(() => _engine.Stop());
        }

        void UpdateUi()
        {
            if (_exiting) return;
            _form.RefreshState(_busy);
            _miToggle.Text = _engine.Paused ? "Start bypass" : "Stop bypass";
            string state = _busy ? "starting" : _engine.Paused ? "off" : _engine.Active ? "active" : "reconnecting";
            string tip = $"LoL Bypass - {state} - strategy {_engine.Strategy}";
            _tray.Text = tip.Length > 63 ? tip.Substring(0, 63) : tip;
        }

        void ShowWindow()
        {
            UpdateUi();
            if (!_form.Visible) _form.Show();
            if (_form.WindowState == FormWindowState.Minimized) _form.WindowState = FormWindowState.Normal;
            _form.Activate();
            _form.BringToFront();
        }

        bool _hintShown;
        void HideWindow(bool hint)
        {
            _form.Hide();
            if (hint && !_hintShown)
            {
                _hintShown = true;
                _tray.ShowBalloonTip(2500, "LoL Bypass", "Still running in the tray. Right-click the icon to exit.", ToolTipIcon.Info);
            }
        }

        void Exit()
        {
            _exiting = true;
            _watchdog.Stop(); _ui.Stop();
            _engine.Stop();
            _engine.Log("exited by user");
            _tray.Visible = false;
            try { _showEvent.Set(); } catch { }
            _form.Close();
            ExitThread();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) { _tray.Dispose(); _form.Dispose(); _watchdog.Dispose(); _ui.Dispose(); }
            base.Dispose(disposing);
        }
    }
}
