using System;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Windows.Forms;

namespace LoLBypass
{
    internal static class Theme
    {
        public static readonly Color Bg = Hex("#010A13");
        public static readonly Color BgTop = Hex("#091428");
        public static readonly Color Panel = Hex("#0A1428");
        public static readonly Color Field = Hex("#1E2328");
        public static readonly Color Gold = Hex("#C8AA6E");
        public static readonly Color GoldDark = Hex("#785A28");
        public static readonly Color GoldLight = Hex("#F0E6D2");
        public static readonly Color Text = Hex("#CDBE91");
        public static readonly Color Muted = Hex("#A09B8C");
        public static readonly Color Dim = Hex("#5B5A56");
        public static readonly Color Teal = Hex("#0AC8B9");
        public static readonly Color TealDark = Hex("#005A82");
        public static readonly Color Red = Hex("#BE1E37");

        public static Font Font(float size, FontStyle style = FontStyle.Regular) => new Font("Segoe UI", size, style, GraphicsUnit.Point);
        public static Font Semi(float size) => new Font("Segoe UI Semibold", size, FontStyle.Regular, GraphicsUnit.Point);

        public static Color Hex(string h) => ColorTranslator.FromHtml(h);

        public static void HQ(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        }

        /// <summary>Rectangle with cut corners (Riot client style).</summary>
        public static GraphicsPath Chamfer(RectangleF r, float c)
        {
            var p = new GraphicsPath();
            p.AddPolygon(new[]
            {
                new PointF(r.Left + c, r.Top), new PointF(r.Right - c, r.Top), new PointF(r.Right, r.Top + c),
                new PointF(r.Right, r.Bottom - c), new PointF(r.Right - c, r.Bottom), new PointF(r.Left + c, r.Bottom),
                new PointF(r.Left, r.Bottom - c), new PointF(r.Left, r.Top + c)
            });
            return p;
        }

        public static PointF[] Hexagon(float cx, float cy, float r)
        {
            var pts = new PointF[6];
            for (int i = 0; i < 6; i++)
            {
                double a = Math.PI / 180 * (60 * i - 90);
                pts[i] = new PointF(cx + (float)(r * Math.Cos(a)), cy + (float)(r * Math.Sin(a)));
            }
            return pts;
        }

        public static void CenterText(Graphics g, string s, Font f, Color c, RectangleF r)
        {
            using (var b = new SolidBrush(c))
            using (var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center, Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap })
                g.DrawString(s, f, b, r, sf);
        }
    }

    /// <summary>Base for owner-drawn controls: double buffered, transparent-looking over the form background.</summary>
    internal abstract class DrawnControl : Control
    {
        protected bool Hover, Down;

        protected DrawnControl()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw |
                     ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Cursor = Cursors.Hand;
        }

        protected override void OnMouseEnter(EventArgs e) { Hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { Hover = false; Down = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { if (e.Button == MouseButtons.Left) { Down = true; Invalidate(); } base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { Down = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
    }

    /// <summary>Big gold-framed button (START / STOP BYPASS).</summary>
    internal sealed class GoldButton : DrawnControl
    {
        [Browsable(false)] public bool Engaged { get; set; }

        public GoldButton() { Font = Theme.Font(15f, FontStyle.Bold); }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics; Theme.HQ(g);
            var r = new RectangleF(1.5f, 1.5f, Width - 3f, Height - 3f);
            using (var path = Theme.Chamfer(r, 8))
            {
                Color top = Down ? Theme.Hex("#0A323C") : Hover ? Theme.Hex("#1E282D") : Theme.Field;
                Color bottom = Down ? Theme.Hex("#091428") : Theme.Hex("#111820");
                using (var fill = new LinearGradientBrush(r, top, bottom, 90f)) g.FillPath(fill, path);

                Color b1 = Hover ? Theme.GoldLight : Theme.Gold;
                Color b2 = Engaged ? Theme.Dim : Theme.GoldDark;
                using (var border = new LinearGradientBrush(r, b1, b2, 90f))
                using (var pen = new Pen(border, 2.5f)) g.DrawPath(pen, path);
            }
            using (var inner = Theme.Chamfer(new RectangleF(6, 6, Width - 12, Height - 12), 5))
            using (var pen = new Pen(Color.FromArgb(Hover ? 90 : 45, Theme.Gold), 1f)) g.DrawPath(pen, inner);

            Theme.CenterText(g, Text, Font, Enabled ? (Hover ? Theme.GoldLight : Theme.Text) : Theme.Dim, ClientRectangle);
        }
    }

    /// <summary>Teal PLAY button like the Riot client.</summary>
    internal sealed class PlayButton : DrawnControl
    {
        public PlayButton() { Font = Theme.Font(12.5f, FontStyle.Bold); Text = "PLAY"; }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics; Theme.HQ(g);
            var r = new RectangleF(1.5f, 1.5f, Width - 3f, Height - 3f);
            using (var path = Theme.Chamfer(r, 6))
            {
                Color top = Down ? Theme.Hex("#005A82") : Hover ? Theme.Hex("#0A5A6A") : Theme.Hex("#0A323C");
                using (var fill = new LinearGradientBrush(r, top, Theme.Hex("#091428"), 90f)) g.FillPath(fill, path);
                using (var border = new LinearGradientBrush(r, Hover ? Theme.Hex("#CDFAFA") : Theme.Teal, Theme.TealDark, 90f))
                using (var pen = new Pen(border, 2f)) g.DrawPath(pen, path);
            }
            Theme.CenterText(g, Text, Font, Hover ? Color.White : Theme.Hex("#CDFAFA"), ClientRectangle);
        }
    }

    /// <summary>Dark selector that opens a themed dropdown menu.</summary>
    internal sealed class Selector : DrawnControl
    {
        string[] _items = new string[0];
        int _index;
        public event EventHandler SelectionChanged;

        public Selector() { Font = Theme.Semi(9.75f); }

        [Browsable(false)]
        public string[] Items { get => _items; set { _items = value ?? new string[0]; Invalidate(); } }

        [Browsable(false)]
        public int SelectedIndex
        {
            get => _index;
            set { _index = Math.Max(0, Math.Min(_items.Length - 1, value)); Invalidate(); }
        }

        protected override void OnClick(EventArgs e)
        {
            base.OnClick(e);
            var menu = new ContextMenuStrip { Renderer = new DarkRenderer(), ShowImageMargin = false, Font = Font };
            for (int i = 0; i < _items.Length; i++)
            {
                int idx = i;
                var item = new ToolStripMenuItem(_items[i]) { ForeColor = i == _index ? Theme.GoldLight : Theme.Text, AutoSize = false };
                item.Size = new Size(Width - 2, Height);
                item.Click += (s, a) => { SelectedIndex = idx; SelectionChanged?.Invoke(this, EventArgs.Empty); };
                menu.Items.Add(item);
            }
            menu.Show(this, new Point(0, Height));
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics; Theme.HQ(g);
            var r = new Rectangle(0, 0, Width - 1, Height - 1);
            using (var b = new SolidBrush(Hover ? Theme.Hex("#1E282D") : Theme.Field)) g.FillRectangle(b, r);
            using (var p = new Pen(Hover ? Theme.Gold : Theme.GoldDark)) g.DrawRectangle(p, r);
            string t = _items.Length > 0 ? _items[_index] : "";
            using (var b = new SolidBrush(Theme.Text))
            using (var sf = new StringFormat { LineAlignment = StringAlignment.Center, Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap })
                g.DrawString(t, Font, b, new RectangleF(10, 0, Width - 34, Height), sf);
            // chevron
            float cx = Width - 16, cy = Height / 2f;
            using (var p = new Pen(Theme.Gold, 2f))
                g.DrawLines(p, new[] { new PointF(cx - 5, cy - 2.5f), new PointF(cx, cy + 2.5f), new PointF(cx + 5, cy - 2.5f) });
        }
    }

    /// <summary>On/off switch.</summary>
    internal sealed class Toggle : DrawnControl
    {
        bool _on;
        public event EventHandler Changed;
        public Toggle() { Font = Theme.Font(9.5f); }

        [Browsable(false)]
        public bool On { get => _on; set { _on = value; Invalidate(); } }

        protected override void OnClick(EventArgs e) { _on = !_on; Invalidate(); Changed?.Invoke(this, EventArgs.Empty); base.OnClick(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics; Theme.HQ(g);
            float h = 20, w = 38, y = (Height - h) / 2f;
            var track = new RectangleF(1, y, w, h);
            using (var path = new GraphicsPath())
            {
                path.AddArc(track.Left, track.Top, h, h, 90, 180);
                path.AddArc(track.Right - h, track.Top, h, h, 270, 180);
                path.CloseFigure();
                using (var b = new SolidBrush(_on ? Theme.Hex("#0A323C") : Theme.Field)) g.FillPath(b, path);
                using (var p = new Pen(_on ? Theme.Teal : Theme.GoldDark, 1.5f)) g.DrawPath(p, path);
            }
            float kx = _on ? track.Right - h + 3 : track.Left + 3;
            using (var b = new SolidBrush(_on ? Theme.Teal : Theme.Muted)) g.FillEllipse(b, kx, y + 3, h - 6, h - 6);
            using (var b = new SolidBrush(Hover ? Theme.GoldLight : Theme.Muted))
            using (var sf = new StringFormat { LineAlignment = StringAlignment.Center })
                g.DrawString(Text, Font, b, new RectangleF(w + 12, 0, Width - w - 12, Height), sf);
        }
    }

    /// <summary>Hexagon emblem showing ON / OFF with a slow pulse when active.</summary>
    internal sealed class Emblem : Control
    {
        public enum State { Off, Starting, On }
        State _state = State.Off;
        float _phase;
        readonly Timer _anim = new Timer { Interval = 50 };

        public Emblem()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint |
                     ControlStyles.SupportsTransparentBackColor | ControlStyles.ResizeRedraw, true);
            BackColor = Color.Transparent;
            _anim.Tick += (s, e) => { _phase += 0.08f; Invalidate(); };
        }

        [Browsable(false)]
        public State Current
        {
            get => _state;
            set { _state = value; _anim.Enabled = value != State.Off; Invalidate(); }
        }

        protected override void Dispose(bool disposing) { if (disposing) _anim.Dispose(); base.Dispose(disposing); }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics; Theme.HQ(g);
            float cx = Width / 2f, cy = Height / 2f, R = Math.Min(Width, Height) / 2f - 4;
            Color accent = _state == State.On ? Theme.Teal : _state == State.Starting ? Theme.Gold : Theme.Dim;

            if (_state != State.Off)
            {
                float pulse = (float)(Math.Sin(_phase) * 0.5 + 0.5);
                for (int i = 3; i >= 1; i--)
                    using (var glow = new Pen(Color.FromArgb((int)(18 + 30 * pulse) / i, accent), 6 * i))
                        g.DrawPolygon(glow, Theme.Hexagon(cx, cy, R * 0.80f));
            }

            using (var outer = new LinearGradientBrush(new RectangleF(0, 0, Width, Height), Theme.Gold, Theme.GoldDark, 90f))
            {
                g.FillPolygon(outer, Theme.Hexagon(cx, cy, R));
            }
            using (var b = new SolidBrush(Theme.Bg)) g.FillPolygon(b, Theme.Hexagon(cx, cy, R - 7));
            using (var p = new Pen(Theme.GoldDark, 1.5f)) g.DrawPolygon(p, Theme.Hexagon(cx, cy, R - 13));
            using (var fill = new LinearGradientBrush(new RectangleF(0, 0, Width, Height), Theme.Panel, Theme.Bg, 90f))
                g.FillPolygon(fill, Theme.Hexagon(cx, cy, R * 0.72f));
            using (var p = new Pen(accent, 4f)) g.DrawPolygon(p, Theme.Hexagon(cx, cy, R * 0.72f));

            string txt = _state == State.On ? "ON" : _state == State.Starting ? "..." : "OFF";
            using (var f = Theme.Font(R * 0.30f, FontStyle.Bold))
                Theme.CenterText(g, txt, f, accent, new RectangleF(0, 0, Width, Height));
        }
    }

    /// <summary>Dark tray / dropdown menu renderer.</summary>
    internal sealed class DarkRenderer : ToolStripProfessionalRenderer
    {
        public DarkRenderer() : base(new DarkColors()) { RoundedEdges = false; }

        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
        {
            e.TextColor = !e.Item.Enabled ? Theme.Dim : e.Item.Selected ? Theme.GoldLight : (e.Item.ForeColor == SystemColors.ControlText ? Theme.Text : e.Item.ForeColor);
            base.OnRenderItemText(e);
        }

        sealed class DarkColors : ProfessionalColorTable
        {
            public override Color ToolStripDropDownBackground => Theme.Bg;
            public override Color MenuBorder => Theme.GoldDark;
            public override Color MenuItemBorder => Theme.GoldDark;
            public override Color MenuItemSelected => Theme.Field;
            public override Color MenuItemSelectedGradientBegin => Theme.Field;
            public override Color MenuItemSelectedGradientEnd => Theme.Field;
            public override Color MenuItemPressedGradientBegin => Theme.Panel;
            public override Color MenuItemPressedGradientEnd => Theme.Panel;
            public override Color ImageMarginGradientBegin => Theme.Bg;
            public override Color ImageMarginGradientMiddle => Theme.Bg;
            public override Color ImageMarginGradientEnd => Theme.Bg;
            public override Color SeparatorDark => Theme.GoldDark;
            public override Color SeparatorLight => Theme.Bg;
            public override Color CheckBackground => Theme.Field;
            public override Color CheckSelectedBackground => Theme.Field;
        }
    }
}
