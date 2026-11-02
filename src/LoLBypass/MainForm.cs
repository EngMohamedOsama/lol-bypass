using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace LoLBypass
{
    internal sealed class MainForm : Form
    {
        readonly Engine _engine;
        public event EventHandler ToggleRequested;
        public event EventHandler StrategyChanged;
        public event EventHandler HideRequested;

        readonly Emblem _emblem = new Emblem();
        readonly Label _state = new Label();
        readonly Label _dotTcp = new Label(), _dotUdp = new Label();
        readonly Label _rowTcp = new Label(), _rowUdp = new Label();
        readonly GoldButton _main = new GoldButton();
        readonly Selector _game = new Selector();
        readonly PlayButton _play = new PlayButton();
        readonly Selector _strategy = new Selector();
        readonly Toggle _startup = new Toggle();
        readonly Label _hint = new Label();

        public MainForm(Engine engine, Icon icon)
        {
            _engine = engine;
            Text = "LoL Bypass";
            Icon = icon;
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.Dpi;
            AutoScaleDimensions = new SizeF(96f, 96f);
            ClientSize = new Size(440, 660);
            BackColor = Theme.Bg;
            DoubleBuffered = true;
            ShowInTaskbar = true;
            Font = Theme.Font(9.5f);

            // ---- title bar ----
            var title = MakeLabel("LOL BYPASS", 44, 10, 250, 26, Theme.Font(11.5f, FontStyle.Bold), Theme.Gold, ContentAlignment.MiddleLeft);
            var logo = new PictureBox { Location = new Point(14, 11), Size = new Size(24, 24), SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.Transparent, Image = new Icon(icon, 32, 32).ToBitmap() };
            var min = MakeGlyph("—", 360);
            var close = MakeGlyph("✕", 398);
            min.Click += (s, e) => HideRequested?.Invoke(this, EventArgs.Empty);
            close.Click += (s, e) => HideRequested?.Invoke(this, EventArgs.Empty);
            foreach (Control c in new Control[] { this, title, logo }) c.MouseDown += DragWindow;

            // ---- emblem + state ----
            _emblem.Location = new Point(130, 62); _emblem.Size = new Size(180, 180);
            Style(_state, 0, 252, 440, 34, Theme.Semi(17f), Theme.Teal, ContentAlignment.MiddleCenter);

            Style(_dotTcp, 74, 296, 18, 22, Theme.Font(10f), Theme.Teal, ContentAlignment.MiddleLeft);
            Style(_rowTcp, 94, 296, 300, 22, Theme.Semi(9.5f), Theme.Text, ContentAlignment.MiddleLeft);
            _rowTcp.Text = "LOGIN  ·  CHAT  ·  VANGUARD  ·  STORE";
            Style(_dotUdp, 74, 320, 18, 22, Theme.Font(10f), Theme.Teal, ContentAlignment.MiddleLeft);
            Style(_rowUdp, 94, 320, 300, 22, Theme.Semi(9.5f), Theme.Text, ContentAlignment.MiddleLeft);
            _rowUdp.Text = "MATCH SERVERS  (LOL · TFT · VALORANT)";
            _dotTcp.Text = _dotUdp.Text = "●";

            // ---- main button ----
            _main.Location = new Point(50, 368); _main.Size = new Size(340, 62);
            _main.Click += (s, e) => ToggleRequested?.Invoke(this, EventArgs.Empty);

            // ---- game + play ----
            var gameLbl = MakeLabel("GAME", 50, 448, 200, 18, Theme.Font(8.5f, FontStyle.Bold), Theme.Muted, ContentAlignment.MiddleLeft);
            _game.Location = new Point(50, 470); _game.Size = new Size(212, 40);
            _game.Items = Engine.Games.Select(x => x.Name).ToArray();
            _play.Location = new Point(272, 470); _play.Size = new Size(118, 40);
            _play.Click += (s, e) => PlayClicked();

            // ---- strategy ----
            var stratLbl = MakeLabel("MATCH STRATEGY", 50, 526, 300, 18, Theme.Font(8.5f, FontStyle.Bold), Theme.Muted, ContentAlignment.MiddleLeft);
            _strategy.Location = new Point(50, 548); _strategy.Size = new Size(340, 34);
            _strategy.Items = Enumerable.Range(0, 4).Select(i => $"{i + 1}  —  {Engine.StrategyNames[i]}").ToArray();
            _strategy.SelectedIndex = _engine.Strategy - 1;
            _strategy.SelectionChanged += (s, e) => { _engine.Strategy = _strategy.SelectedIndex + 1; StrategyChanged?.Invoke(this, EventArgs.Empty); };

            // ---- startup toggle ----
            _startup.Location = new Point(50, 594); _startup.Size = new Size(340, 28);
            _startup.Text = "Start with Windows (hidden in tray)";
            _startup.Changed += (s, e) => Tasks.SetStartup(_startup.On);

            Style(_hint, 0, 628, 440, 22, Theme.Font(8.25f), Theme.GoldDark, ContentAlignment.MiddleCenter);
            _hint.Text = "Closing this window keeps the bypass running in the tray";

            Controls.AddRange(new Control[]
            {
                logo, title, min, close, _emblem, _state, _dotTcp, _rowTcp, _dotUdp, _rowUdp, _main,
                gameLbl, _game, _play, stratLbl, _strategy, _startup, _hint
            });
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            try { _startup.On = Tasks.StartupEnabled; } catch { }
        }

        public void RefreshState(bool starting)
        {
            bool g = _engine.GdpiRunning, w = _engine.WinwsRunning;
            Emblem.State st;
            if (starting) { st = Emblem.State.Starting; _state.Text = "STARTING..."; _state.ForeColor = Theme.Gold; }
            else if (_engine.Paused) { st = Emblem.State.Off; _state.Text = "BYPASS OFF"; _state.ForeColor = Theme.Muted; }
            else if (g && w) { st = Emblem.State.On; _state.Text = "BYPASS ACTIVE"; _state.ForeColor = Theme.Teal; }
            else { st = Emblem.State.Starting; _state.Text = "RECONNECTING..."; _state.ForeColor = Theme.Gold; }

            if (_emblem.Current != st) _emblem.Current = st;
            _dotTcp.ForeColor = g ? Theme.Teal : (_engine.Paused ? Theme.Dim : Theme.Red);
            _dotUdp.ForeColor = w ? Theme.Teal : (_engine.Paused ? Theme.Dim : Theme.Red);
            _main.Text = _engine.Paused ? "START BYPASS" : "STOP BYPASS";
            _main.Engaged = !_engine.Paused;
            _main.Enabled = !starting;
            _main.Invalidate();
            if (_strategy.SelectedIndex != _engine.Strategy - 1) _strategy.SelectedIndex = _engine.Strategy - 1;
        }

        void PlayClicked()
        {
            if (_engine.Paused)
            {
                var r = MessageBox.Show(this, "The bypass is off. Start it first?", "LoL Bypass", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
                if (r == DialogResult.Yes) ToggleRequested?.Invoke(this, EventArgs.Empty);
            }
            if (!_engine.LaunchGame(_game.SelectedIndex, out string err))
                MessageBox.Show(this, err, "LoL Bypass", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }

        // ---------- painting ----------
        protected override void OnPaintBackground(PaintEventArgs e)
        {
            var g = e.Graphics; Theme.HQ(g);
            var r = ClientRectangle;
            using (var bg = new LinearGradientBrush(r, Theme.BgTop, Theme.Bg, 90f)) g.FillRectangle(bg, r);

            // soft teal glow behind the emblem
            using (var path = new GraphicsPath())
            {
                path.AddEllipse(60, 20, 320, 280);
                using (var pgb = new PathGradientBrush(path) { CenterColor = Color.FromArgb(40, Theme.TealDark), SurroundColors = new[] { Color.FromArgb(0, Theme.Bg) } })
                    g.FillPath(pgb, path);
            }

            using (var p = new Pen(Theme.GoldDark, 2f)) g.DrawRectangle(p, 1, 1, Width - 2, Height - 2);
            using (var p = new Pen(Theme.GoldDark, 1f))
            {
                g.DrawLine(p, 0, 46, Width, 46);
                g.DrawLine(p, 50, 352, Width - 50, 352);
            }
            // small gold diamond on the divider
            float cx = Width / 2f;
            using (var b = new SolidBrush(Theme.Gold))
                g.FillPolygon(b, new[] { new PointF(cx, 347), new PointF(cx + 5, 352), new PointF(cx, 357), new PointF(cx - 5, 352) });
        }

        // ---------- helpers ----------
        static Label MakeLabel(string text, int x, int y, int w, int h, Font f, Color c, ContentAlignment a)
        {
            var l = new Label(); Style(l, x, y, w, h, f, c, a); l.Text = text; return l;
        }

        static void Style(Label l, int x, int y, int w, int h, Font f, Color c, ContentAlignment a)
        {
            l.Location = new Point(x, y); l.Size = new Size(w, h); l.Font = f; l.ForeColor = c;
            l.TextAlign = a; l.BackColor = Color.Transparent; l.AutoSize = false;
        }

        Label MakeGlyph(string g, int x)
        {
            var l = MakeLabel(g, x, 8, 32, 30, Theme.Font(11f, FontStyle.Bold), Theme.Muted, ContentAlignment.MiddleCenter);
            l.Cursor = Cursors.Hand;
            l.MouseEnter += (s, e) => l.ForeColor = Theme.GoldLight;
            l.MouseLeave += (s, e) => l.ForeColor = Theme.Muted;
            return l;
        }

        [DllImport("user32.dll")] static extern bool ReleaseCapture();
        [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wp, IntPtr lp);

        void DragWindow(object sender, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left) return;
            ReleaseCapture();
            SendMessage(Handle, 0xA1 /*WM_NCLBUTTONDOWN*/, (IntPtr)2 /*HTCAPTION*/, IntPtr.Zero);
        }

        protected override CreateParams CreateParams
        {
            get
            {
                var cp = base.CreateParams;
                cp.ClassStyle |= 0x20000; // CS_DROPSHADOW
                cp.Style |= 0x20000;      // WS_MINIMIZEBOX (taskbar click minimizes)
                return cp;
            }
        }
    }
}
