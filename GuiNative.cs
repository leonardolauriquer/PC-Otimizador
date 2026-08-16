using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Management;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace PCOtimizador
{
    static class UiText
    {
        static readonly Dictionary<string, string[]> Values = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase)
        {
            { "app.title", new[] { "PC Otimizador Pro", "PC Optimizer Pro" } },
            { "title.optimizer", new[] { "OTIMIZADOR", "OPTIMIZER" } },
            { "brand", new[] { "PC\nOTIMIZADOR", "PC\nOPTIMIZER" } },
            { "nav.inicio", new[] { "INÍCIO", "HOME" } },
            { "nav.limpeza", new[] { "LIMPEZA", "CLEANUP" } },
            { "nav.desempenho", new[] { "DESEMPENHO", "PERFORMANCE" } },
            { "nav.internet", new[] { "INTERNET", "NETWORK" } },
            { "nav.inicializacao", new[] { "INICIALIZAÇÃO", "STARTUP" } },
            { "nav.ferramentas", new[] { "FERRAMENTAS", "TOOLS" } },
            { "nav.dispositivo", new[] { "DISPOSITIVO", "DEVICE" } },
            { "nav.configuracoes", new[] { "CONFIGURAÇÕES", "SETTINGS" } },
            { "nav.protection", new[] { "PROTEÇÃO\nATIVA", "PROTECTION\nACTIVE" } },
            { "language.label", new[] { "IDIOMA", "LANGUAGE" } },
            { "language.pt", new[] { "Português", "Portuguese" } },
            { "language.en", new[] { "English", "English" } },
            { "header.dashboard", new[] { "Painel · Escolha um perfil · Passe o mouse para detalhes", "Dashboard · Choose a profile · Hover for details" } },
            { "header.limpeza", new[] { "Limpeza · Temporários seguros e espaço recuperável", "Cleanup · Safe temporary files and recoverable space" } },
            { "header.desempenho", new[] { "Desempenho · Mais resposta para jogos e tarefas", "Performance · More response for games and heavy tasks" } },
            { "header.internet", new[] { "Internet · Diagnóstico e otimização de rede", "Network · Diagnostics and network optimization" } },
            { "header.inicializacao", new[] { "Inicialização · Rotinas seguras e manutenção", "Startup · Safe routines and maintenance" } },
            { "header.ferramentas", new[] { "Ferramentas · Medir, agendar e abrir logs", "Tools · Measure, schedule and open logs" } },
            { "header.dispositivo", new[] { "Dispositivo · Hardware, sistema, frequências e sensores", "Device · Hardware, system, frequencies and sensors" } },
            { "header.configuracoes", new[] { "Configurações · Idioma, segurança e como usar", "Settings · Language, safety and how to use" } },
            { "dryrun", new[] { "SIMULAÇÃO", "DRY-RUN" } },
            { "badge.safe", new[] { "SEGURO", "SAFE" } },
            { "badge.risk", new[] { "RISCO", "RISK" } },
            { "cancel", new[] { "PARAR", "STOP" } },
            { "task.ready", new[] { "Pronto — escolha um perfil acima", "Ready — choose a profile above" } },
            { "stats.empty", new[] { "ANTES   — GB livres\nRode um perfil para ver o resultado", "BEFORE   — GB free\nRun a profile to see the result" } },
            { "health.empty", new[] { "Saúde\n—/100", "Health\n—/100" } },
            { "health.caption", new[] { "Saúde", "Health" } },
            { "status.activity", new[] { "Atividade registrada.", "Activity recorded." } },
            { "task.starting", new[] { "Iniciando...", "Starting..." } },
            { "stats.running", new[] { "EM ANDAMENTO\nAguarde o progresso.", "IN PROGRESS\nPlease wait for progress." } },
            { "task.update.checking", new[] { "Verificando atualizações...", "Checking for updates..." } },
            { "status.update.checking", new[] { "Consultando lançamentos no GitHub...", "Checking GitHub releases..." } },
            { "task.update.timeout", new[] { "Pronto (verificação expirada)", "Ready (update check timed out)" } },
            { "task.update.offline", new[] { "Pronto (atualização indisponível)", "Ready (update unavailable)" } },
            { "page.limpeza.title", new[] { "Limpeza segura", "Safe cleanup" } },
            { "page.limpeza.desc", new[] { "Libere espaço sem tocar nos seus arquivos pessoais.", "Free space without touching your personal files." } },
            { "page.desempenho.title", new[] { "Desempenho", "Performance" } },
            { "page.desempenho.desc", new[] { "Perfis para jogos, tarefas pesadas e saúde do sistema.", "Profiles for games, heavy tasks and system health." } },
            { "page.internet.title", new[] { "Internet", "Network" } },
            { "page.internet.desc", new[] { "Ações transparentes para diagnosticar e melhorar sua conexão.", "Transparent actions to diagnose and improve your connection." } },
            { "page.inicializacao.title", new[] { "Inicialização", "Startup" } },
            { "page.inicializacao.desc", new[] { "Manutenção programada e diagnóstico sem alterações agressivas.", "Scheduled maintenance and diagnostics without aggressive changes." } },
            { "page.ferramentas.title", new[] { "Ferramentas", "Tools" } },
            { "page.ferramentas.desc", new[] { "Ações que medem ou configuram — sem limpeza agressiva.", "Actions that measure or configure — no aggressive cleanup." } },
            { "page.dispositivo.title", new[] { "Informações do dispositivo", "Device information" } },
            { "page.dispositivo.desc", new[] { "Inventário detalhado do hardware, sistema, frequências e sensores disponíveis.", "Detailed inventory of hardware, system, frequencies and available sensors." } },
            { "page.configuracoes.title", new[] { "Configurações", "Settings" } },
            { "page.configuracoes.desc", new[] { "Idioma, proteção e orientações para usar o aplicativo com segurança.", "Language, protection and guidance for safe use." } },
            { "card.safe.title", new[] { "LIMPEZA SEGURA", "SAFE CLEANUP" } },
            { "card.safe.sub", new[] { "Temporários e caches regeneráveis", "Regenerable temporary files and caches" } },
            { "card.gamer.title", new[] { "TURBO PARA JOGOS", "GAMING TURBO" } },
            { "card.gamer.sub", new[] { "Mais desempenho para jogos e tarefas pesadas", "More performance for games and heavy tasks" } },
            { "card.net.title", new[] { "INTERNET", "NETWORK" } },
            { "card.net.sub", new[] { "DNS, ARP e conexão com confirmação", "DNS, ARP and connection with confirmation" } },
            { "card.notebook.title", new[] { "PORTÁTIL", "LAPTOP" } },
            { "card.notebook.sub", new[] { "Equilíbrio entre autonomia e desempenho", "Balance battery life and performance" } },
            { "card.health.title", new[] { "Pontuação de saúde", "Health score" } },
            { "card.health.sub", new[] { "Nota 0–100 do PC", "PC score from 0–100" } },
            { "card.scan.title", new[] { "Estimar espaço", "Estimate space" } },
            { "card.scan.sub", new[] { "Simula quanto poderia liberar", "Simulates how much could be freed" } },
            { "card.schedule.title", new[] { "Agendar", "Schedule" } },
            { "card.schedule.sub", new[] { "Domingo 10h · somente SEGURO", "Sunday 10 AM · SAFE only" } },
            { "card.logs.title", new[] { "Abrir logs", "Open logs" } },
            { "card.logs.sub", new[] { "Histórico das sessões", "Session history" } },
            { "card.run", new[] { "ABRIR", "OPEN" } },
            { "settings.language.title", new[] { "Idioma da interface", "Interface language" } },
            { "settings.language.desc", new[] { "Troque o idioma sem reiniciar o aplicativo.", "Change the language without restarting the app." } },
            { "settings.safety.title", new[] { "Proteção ativa", "Protection active" } },
            { "settings.safety.text", new[] { "Documentos, Fotos, Vídeos, Música, Desktop, Downloads e OneDrive nunca são alvos da limpeza segura.", "Documents, Pictures, Videos, Music, Desktop, Downloads and OneDrive are never targets of safe cleanup." } },
            { "settings.help.title", new[] { "Como usar", "How to use" } },
            { "settings.help.text", new[] { "1. Ative SIMULAÇÃO para revisar.\n2. Rode Saúde ou Estimar espaço.\n3. Execute um perfil somente após conferir a confirmação.\n\nPerfis de RISCO sempre pedem confirmação explícita.", "1. Enable DRY-RUN to review.\n2. Run Health or Estimate space.\n3. Execute a profile only after reviewing the confirmation.\n\nRISK profiles always require explicit confirmation." } },
            { "button.runSafe", new[] { "Executar limpeza segura", "Run safe cleanup" } },
            { "button.runGamer", new[] { "Executar Turbo Gamer", "Run Turbo Gamer" } },
            { "button.runNet", new[] { "Diagnosticar internet", "Diagnose network" } },
            { "button.health", new[] { "Ver pontuação de saúde", "View health score" } },
            { "button.scan", new[] { "Estimar espaço", "Estimate space" } },
            { "button.schedule", new[] { "Agendar rotina", "Schedule routine" } },
            { "button.logs", new[] { "Abrir pasta de registros", "Open log folder" } },
            { "button.refreshDevice", new[] { "ATUALIZAR DADOS", "REFRESH DATA" } },
            { "device.loading", new[] { "Coletando informações...", "Collecting information..." } },
            { "device.unavailable", new[] { "Não disponível pelo Windows", "Not available from Windows" } },
            { "device.system", new[] { "Computador e sistema", "Computer and system" } },
            { "device.cpu", new[] { "Processador", "Processor" } },
            { "device.gpu", new[] { "Placa de vídeo", "Graphics adapter" } },
            { "device.memory", new[] { "Memória RAM", "Memory" } },
            { "device.board", new[] { "Placa-mãe e BIOS", "Motherboard and BIOS" } },
            { "device.storage", new[] { "Armazenamento", "Storage" } },
            { "device.network", new[] { "Rede", "Network" } },
            { "device.sensors", new[] { "Sensores e atividade", "Sensors and activity" } },
            { "device.error", new[] { "Falha ao consultar: ", "Query failed: " } }
        };

        public static string Get(string key, bool english)
        {
            string[] value;
            if (!Values.TryGetValue(key, out value)) return key;
            return value[english ? 1 : 0];
        }
    }

    static class Program
    {
        [DllImport("user32.dll")]
        static extern bool SetProcessDPIAware();

        [STAThread]
        static void Main()
        {
            try { SetProcessDPIAware(); } catch { }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }

    sealed class RoundPanel : Panel
    {
        public int Radius = 16;
        public Color BorderColor = Color.FromArgb(40, 60, 90);
        public int BorderWidth = 1;
        public bool Glow;

        public RoundPanel()
        {
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                      ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            if (Width < 2 || Height < 2) return;
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            var rect = new Rectangle(0, 0, Width - 1, Height - 1);
            using (var path = RoundRect(rect, Radius))
            {
                if (Glow)
                {
                    using (var glowPen = new Pen(Color.FromArgb(42, BorderColor), 5f))
                        e.Graphics.DrawPath(glowPen, path);
                }
                using (var brush = new SolidBrush(BackColor))
                using (var pen = new Pen(BorderColor, BorderWidth))
                {
                    e.Graphics.FillPath(brush, path);
                    e.Graphics.DrawPath(pen, path);
                }
            }
            base.OnPaint(e);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            if (Width > 1 && Height > 1)
            {
                using (var path = RoundRect(new Rectangle(0, 0, Width, Height), Radius))
                    Region = new Region(path);
            }
        }

        public static GraphicsPath RoundRect(Rectangle r, int radius)
        {
            int d = Math.Max(1, radius * 2);
            var p = new GraphicsPath();
            if (radius <= 0) { p.AddRectangle(r); return p; }
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }
    }

    sealed class GlowProgress : Panel
    {
        int _value;
        public int Value
        {
            get { return _value; }
            set { _value = Math.Max(0, Math.Min(100, value)); Invalidate(); }
        }

        public GlowProgress()
        {
            DoubleBuffered = true;
            BackColor = Color.Transparent;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                      ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            if (Width < 20 || Height < 6) return;
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            int h = Math.Min(20, Math.Max(10, Height - 4));
            int y = (Height - h) / 2;
            var track = new Rectangle(0, y, Width - 1, h);
            using (var trackPath = RoundPanel.RoundRect(track, h / 2))
            using (var trackBrush = new SolidBrush(Color.FromArgb(18, 28, 42)))
            using (var trackPen = new Pen(Color.FromArgb(70, 84, 101), 1f))
            {
                e.Graphics.FillPath(trackBrush, trackPath);
                e.Graphics.DrawPath(trackPen, trackPath);
            }
            int fillWidth = (int)Math.Round((Width - 2) * (_value / 100.0));
            if (fillWidth > 2)
            {
                var fill = new Rectangle(1, y + 1, Math.Max(2, fillWidth), Math.Max(2, h - 2));
                using (var glow = new Pen(Color.FromArgb(50, 0, 229, 192), 7f))
                    e.Graphics.DrawLine(glow, fill.Left + 4, fill.Y + fill.Height / 2, fill.Right - 3, fill.Y + fill.Height / 2);
                using (var path = RoundPanel.RoundRect(fill, Math.Max(1, fill.Height / 2)))
                using (var brush = new LinearGradientBrush(fill, Color.FromArgb(31, 211, 255), Color.FromArgb(0, 229, 192), 0f))
                    e.Graphics.FillPath(brush, path);
            }
            base.OnPaint(e);
        }
    }

    sealed class TogglePill : CheckBox
    {
        static readonly Color Off = Color.FromArgb(21, 30, 44);
        static readonly Color On = Color.FromArgb(0, 143, 132);
        public TogglePill()
        {
            Appearance = Appearance.Button;
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            AutoSize = false;
            TextAlign = ContentAlignment.MiddleCenter;
            Cursor = Cursors.Hand;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                      ControlStyles.OptimizedDoubleBuffer, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            var rect = new Rectangle(0, 0, Width - 1, Height - 1);
            using (var path = RoundPanel.RoundRect(rect, Height / 2))
            using (var brush = new SolidBrush(Checked ? On : Off))
            using (var pen = new Pen(Checked ? Color.FromArgb(0, 229, 192) : Color.FromArgb(69, 85, 105), 1f))
            {
                e.Graphics.FillPath(brush, path);
                e.Graphics.DrawPath(pen, path);
            }
            TextRenderer.DrawText(e.Graphics, Text, Font, rect, Checked ? Color.White : Color.FromArgb(180, 196, 210),
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        }
    }

    sealed class IconCanvas : Panel
    {
        static string _fluentFontName;
        public string Kind;
        public Color AccentColor = Color.FromArgb(0, 229, 192);
        public int Stroke = 2;
        public bool ShowTile = true;

        public IconCanvas(string kind, int size)
        {
            Kind = kind;
            Size = new Size(size, size);
            BackColor = Color.Transparent;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                      ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            if (Width < 8 || Height < 8) return;
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            e.Graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            float s = Math.Min(Width, Height);
            var tile = new RectangleF(s * .08f, s * .08f, s * .84f, s * .84f);
            string glyph = FluentGlyph(Kind);
            using (var brush = new SolidBrush(AccentColor))
            {
                if (ShowTile)
                {
                    using (var tilePath = RoundPanel.RoundRect(Rectangle.Round(tile), (int)Math.Max(6, s * .20f)))
                    using (var tileBrush = new SolidBrush(Color.FromArgb(18, AccentColor)))
                    using (var tilePen = new Pen(Color.FromArgb(55, AccentColor), 1f))
                    {
                        e.Graphics.FillPath(tileBrush, tilePath);
                        e.Graphics.DrawPath(tilePen, tilePath);
                    }
                }
                float iconSize = s >= 78 ? 48f : (s >= 58 ? 40f : (s >= 42 ? 32f : (s >= 30 ? 24f : 20f)));
                using (var iconFont = new Font(FluentFontName(), iconSize, FontStyle.Regular, GraphicsUnit.Pixel))
                using (var format = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center, FormatFlags = StringFormatFlags.NoWrap })
                using (var glowBrush = new SolidBrush(Color.FromArgb(34, AccentColor)))
                {
                    var bounds = new RectangleF(0, 0, Width, Height);
                    e.Graphics.DrawString(glyph, iconFont, glowBrush, new RectangleF(-1, -1, Width + 2, Height + 2), format);
                    e.Graphics.DrawString(glyph, iconFont, brush, bounds, format);
                }
            }
            base.OnPaint(e);
        }

        static string FluentFontName()
        {
            if (!string.IsNullOrEmpty(_fluentFontName)) return _fluentFontName;
            foreach (var family in FontFamily.Families)
                if (string.Equals(family.Name, "Segoe Fluent Icons", StringComparison.OrdinalIgnoreCase)) return _fluentFontName = family.Name;
            return _fluentFontName = "Segoe MDL2 Assets";
        }

        static string FluentGlyph(string kind)
        {
            switch ((kind ?? "").ToLowerInvariant())
            {
                case "home": return "\uE80F";       // Home
                case "broom": return "\uEA99";      // Broom
                case "gauge": return "\uE9D9";      // Diagnostic
                case "globe": return "\uE774";      // Globe
                case "laptop": return "\uE7F8";     // DeviceLaptopNoPic
                case "power": return "\uE7E8";      // PowerButton
                case "tools": return "\uE90F";      // Repair
                case "gear": return "\uE713";       // Settings
                case "shield": return "\uEA18";     // Shield
                case "drive": return "\uE958";      // StorageOptical
                case "heart": return "\uEB51";      // Heart
                case "health": return "\uE95E";     // Health
                case "network": return "\uE968";    // Network
                case "clock": return "\uE917";      // Clock
                case "folder": return "\uE838";     // FolderOpen
                case "device": return "\uE772";     // Devices
                case "cpu": return "\uE950";        // Component
                case "component": return "\uE950";  // Component
                case "gpu": return "\uE7F9";        // DeviceMonitorRightPic
                case "memory": return "\uE965";     // MediaStorageTower
                case "sensor": return "\uE957";     // Sensor
                default: return "\uE946";             // Info
            }
        }

        void DrawIcon(Graphics g, Pen pen, Brush brush)
        {
            float s = Math.Min(Width, Height);
            float cx = Width / 2f;
            float cy = Height / 2f;
            float l = s * .16f;
            float r = s * .84f;
            float t = s * .14f;
            float b = s * .86f;
            switch ((Kind ?? "").ToLowerInvariant())
            {
                case "shield":
                    using (var p = new GraphicsPath())
                    {
                        p.AddLine(cx, t, r, s * .30f);
                        p.AddLine(r, s * .30f, r - s * .04f, s * .60f);
                        p.AddBezier(r - s * .04f, s * .60f, cx + s * .20f, s * .82f, cx, b, cx, b);
                        p.AddBezier(cx, b, cx - s * .20f, s * .82f, l + s * .04f, s * .60f, l + s * .04f, s * .60f);
                        p.AddLine(l + s * .04f, s * .60f, l, s * .30f);
                        p.CloseFigure();
                        g.DrawPath(pen, p);
                    }
                    g.DrawLines(pen, new[] { new PointF(cx - s * .18f, s * .49f), new PointF(cx - s * .04f, s * .63f), new PointF(cx + s * .22f, s * .36f) });
                    break;
                case "heart":
                    using (var heart = new GraphicsPath())
                    {
                        heart.AddBezier(cx, b, l + s * .05f, s * .55f, l + s * .02f, t + s * .10f, cx - s * .18f, t + s * .22f);
                        heart.AddBezier(cx - s * .18f, t + s * .22f, cx - s * .02f, t - s * .01f, cx - s * .01f, t + s * .18f, cx, t + s * .27f);
                        heart.AddBezier(cx, t + s * .27f, cx + s * .01f, t + s * .18f, cx + s * .02f, t - s * .01f, cx + s * .18f, t + s * .22f);
                        heart.AddBezier(cx + s * .18f, t + s * .22f, r - s * .02f, t + s * .10f, r - s * .05f, s * .55f, cx, b);
                        g.DrawPath(pen, heart);
                    }
                    g.DrawLine(pen, cx - s * .20f, cy, cx - s * .05f, cy + s * .12f);
                    g.DrawLine(pen, cx - s * .05f, cy + s * .12f, cx + s * .22f, cy - s * .16f);
                    break;
                case "health":
                    g.DrawEllipse(pen, l, t, s * .68f, s * .68f);
                    g.DrawLine(pen, l + s * .10f, cy, cx - s * .16f, cy);
                    g.DrawLine(pen, cx - s * .16f, cy, cx - s * .08f, cy - s * .13f);
                    g.DrawLine(pen, cx - s * .08f, cy - s * .13f, cx + s * .02f, cy + s * .14f);
                    g.DrawLine(pen, cx + s * .02f, cy + s * .14f, cx + s * .12f, cy - s * .09f);
                    g.DrawLine(pen, cx + s * .12f, cy - s * .09f, r - s * .10f, cy - s * .09f);
                    break;
                case "gauge":
                    g.DrawArc(pen, l, t, s * .68f, s * .68f, 135, 270);
                    g.DrawLine(pen, cx, cy + s * .05f, cx + s * .22f, cy - s * .22f);
                    g.FillEllipse(brush, cx - s * .06f, cy - s * .06f, s * .12f, s * .12f);
                    g.DrawLine(pen, cx - s * .28f, cy + s * .22f, cx - s * .36f, cy + s * .29f);
                    g.DrawLine(pen, cx + s * .28f, cy + s * .22f, cx + s * .36f, cy + s * .29f);
                    break;
                case "globe":
                    g.DrawEllipse(pen, l, t, s * .68f, s * .68f);
                    g.DrawEllipse(pen, cx - s * .20f, t, s * .40f, s * .68f);
                    g.DrawLine(pen, l, cy, r, cy);
                    g.DrawArc(pen, l, cy - s * .20f, s * .68f, s * .40f, 180, 180);
                    g.DrawArc(pen, l, cy - s * .20f, s * .68f, s * .40f, 0, 180);
                    break;
                case "laptop":
                    g.DrawRectangle(pen, l + s * .08f, t + s * .04f, s * .52f, s * .45f);
                    g.DrawLine(pen, l, b - s * .10f, r, b - s * .10f);
                    g.DrawLine(pen, l, b - s * .10f, l + s * .12f, b - s * .02f);
                    g.DrawLine(pen, r, b - s * .10f, r - s * .12f, b - s * .02f);
                    g.DrawLine(pen, l + s * .12f, b - s * .02f, r - s * .12f, b - s * .02f);
                    break;
                case "broom":
                    g.DrawLine(pen, cx + s * .20f, t, cx - s * .12f, cy + s * .18f);
                    g.DrawLine(pen, cx - s * .12f, cy + s * .18f, cx - s * .30f, b - s * .10f);
                    g.DrawLine(pen, cx - s * .24f, b - s * .16f, cx + s * .06f, b - s * .07f);
                    g.DrawLine(pen, cx - s * .30f, b - s * .10f, cx - s * .12f, b - s * .02f);
                    break;
                case "home":
                    g.DrawLines(pen, new[] { new PointF(l, cy - s * .02f), new PointF(cx, t), new PointF(r, cy - s * .02f) });
                    g.DrawRectangle(pen, l + s * .10f, cy - s * .02f, s * .48f, s * .40f);
                    g.DrawRectangle(pen, cx - s * .07f, b - s * .23f, s * .14f, s * .21f);
                    break;
                case "power":
                    g.DrawArc(pen, l, t + s * .02f, s * .68f, s * .68f, 40, 280);
                    g.DrawLine(pen, cx, t, cx, cy + s * .12f);
                    break;
                case "tools":
                    g.DrawLine(pen, l + s * .16f, t + s * .16f, r - s * .16f, b - s * .16f);
                    g.DrawLine(pen, r - s * .16f, t + s * .16f, l + s * .16f, b - s * .16f);
                    g.DrawEllipse(pen, l, t, s * .20f, s * .20f);
                    g.DrawEllipse(pen, r - s * .20f, b - s * .20f, s * .20f, s * .20f);
                    break;
                case "gear":
                    g.DrawEllipse(pen, l + s * .12f, t + s * .12f, s * .44f, s * .44f);
                    g.DrawEllipse(pen, cx - s * .08f, cy - s * .08f, s * .16f, s * .16f);
                    for (int i = 0; i < 8; i++)
                    {
                        double a = i * Math.PI / 4.0;
                        float x1 = cx + (float)Math.Cos(a) * s * .32f;
                        float y1 = cy + (float)Math.Sin(a) * s * .32f;
                        float x2 = cx + (float)Math.Cos(a) * s * .43f;
                        float y2 = cy + (float)Math.Sin(a) * s * .43f;
                        g.DrawLine(pen, x1, y1, x2, y2);
                    }
                    break;
                case "drive":
                    DrawRoundedRectangle(g, pen, l, cy - s * .20f, s * .68f, s * .34f, s * .08f);
                    g.FillEllipse(brush, r - s * .14f, cy + s * .02f, s * .06f, s * .06f);
                    break;
                case "network":
                    g.DrawLine(pen, cx, cy - s * .16f, l + s * .18f, b - s * .18f);
                    g.DrawLine(pen, cx, cy - s * .16f, r - s * .18f, b - s * .18f);
                    g.DrawLine(pen, l + s * .18f, b - s * .18f, r - s * .18f, b - s * .18f);
                    g.FillEllipse(brush, cx - s * .10f, cy - s * .26f, s * .20f, s * .20f);
                    g.FillEllipse(brush, l + s * .08f, b - s * .28f, s * .20f, s * .20f);
                    g.FillEllipse(brush, r - s * .28f, b - s * .28f, s * .20f, s * .20f);
                    break;
                case "clock":
                    g.DrawEllipse(pen, l + s * .03f, t + s * .03f, s * .62f, s * .62f);
                    g.DrawLine(pen, cx, cy, cx, t + s * .19f);
                    g.DrawLine(pen, cx, cy, cx + s * .18f, cy + s * .12f);
                    g.FillEllipse(brush, cx - s * .045f, cy - s * .045f, s * .09f, s * .09f);
                    break;
                case "folder":
                    using (var folder = new GraphicsPath())
                    {
                        folder.AddLine(l, t + s * .20f, cx - s * .12f, t + s * .20f);
                        folder.AddLine(cx - s * .12f, t + s * .20f, cx - s * .02f, t + s * .10f);
                        folder.AddLine(cx - s * .02f, t + s * .10f, r, t + s * .10f);
                        folder.AddLine(r, t + s * .10f, r - s * .04f, b - s * .12f);
                        folder.AddLine(r - s * .04f, b - s * .12f, l + s * .04f, b - s * .12f);
                        folder.CloseFigure();
                        g.DrawPath(pen, folder);
                    }
                    break;
                default:
                    g.DrawEllipse(pen, l, t, s * .68f, s * .68f);
                    break;
            }
        }

        static void DrawRoundedRectangle(Graphics g, Pen pen, float x, float y, float w, float h, float radius)
        {
            using (var p = RoundPanel.RoundRect(new Rectangle((int)x, (int)y, (int)w, (int)h), (int)radius))
                g.DrawPath(pen, p);
        }
    }

    public class MainForm : Form
    {
        readonly string _root;
        readonly string _cancelFile;
        readonly string _logsDir;
        readonly ToolTip _tips;

        Panel _sidebar;
        Panel _content;
        Panel _chrome;
        GlowProgress _bar;
        TogglePill _dry;
        Button _btnCancel;
        Label _pctLabel;
        Label _taskLabel;
        Label _statusLabel;
        Label _beforeAfter;
        Label _healthLabel;
        Label _heroSub;
        Label _protectDot;
        Panel _progressBox;
        Panel _statsBox;
        Panel _diskIconHost;
        Panel _healthIconHost;
        Panel _statsDivider;
        TableLayoutPanel _presetGrid;
        FlowLayoutPanel _toolsFlow;
        FlowLayoutPanel _deviceFlow;
        Button _deviceRefresh;
        readonly Dictionary<string, Label> _deviceValues = new Dictionary<string, Label>(StringComparer.OrdinalIgnoreCase);
        Panel _helpScroll;
        RoundPanel _helpBox;
        Label _helpLabel;
        Label _safetyTitle;
        Label _safetyText;
        Label _languageCaption;
        Button _languagePtButton;
        Button _languageEnButton;
        Label _brandLabel;
        Label _protectLabel;
        TextBox _log;
        readonly List<Panel> _navBtns = new List<Panel>();
        readonly Dictionary<string, Panel> _pages = new Dictionary<string, Panel>(StringComparer.OrdinalIgnoreCase);
        readonly Dictionary<string, List<Control>> _localized = new Dictionary<string, List<Control>>(StringComparer.OrdinalIgnoreCase);

        sealed class FeatureSpec
        {
            public string Icon;
            public string TitleKey;
            public string SubKey;
            public string ButtonKey;
            public Color Accent;
            public Action Action;
        }

        Process _proc;
        bool _running;
        bool _cancelRequested;
        bool _english;
        string _activeNav = "inicio";
        int _healthScore;
        string _diskFree = "—";
        string _diskTot = "—";
        bool _deviceLoaded;
        int _deviceRequestId;

        static readonly Color Bg = Color.FromArgb(4, 8, 14);
        static readonly Color PanelBg = Color.FromArgb(6, 13, 22);
        static readonly Color Card = Color.FromArgb(10, 20, 31);
        static readonly Color CardHi = Color.FromArgb(15, 31, 46);
        static readonly Color Border = Color.FromArgb(36, 69, 85);
        static readonly Color Accent = Color.FromArgb(0, 229, 214);
        static readonly Color Accent2 = Color.FromArgb(49, 205, 245);
        static readonly Color Warn = Color.FromArgb(251, 191, 36);
        static readonly Color Danger = Color.FromArgb(248, 113, 113);
        static readonly Color TextMain = Color.FromArgb(241, 245, 249);
        static readonly Color Muted = Color.FromArgb(158, 169, 184);
        static readonly Color Ok = Color.FromArgb(52, 211, 153);

        [DllImport("user32.dll")]
        static extern bool ReleaseCapture();

        [DllImport("user32.dll")]
        static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

        const int WM_NCLBUTTONDOWN = 0xA1;
        const int HTCAPTION = 0x2;

        public MainForm()
        {
            _root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
            _cancelFile = Path.Combine(Path.GetTempPath(), "pc-otimizador-cancel.flag");
            _logsDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "PC-Otimizador-Logs");

            _tips = new ToolTip
            {
                AutoPopDelay = 14000,
                InitialDelay = 400,
                ReshowDelay = 200,
                ShowAlways = true,
                IsBalloon = false,
                ToolTipTitle = "PC Otimizador Pro"
            };

            Text = T("app.title");
            var workArea = Screen.PrimaryScreen != null ? Screen.PrimaryScreen.WorkingArea : new Rectangle(0, 0, 1360, 860);
            Size = new Size(Math.Max(980, Math.Min(1360, workArea.Width - 24)), Math.Max(680, Math.Min(860, workArea.Height - 24)));
            // Keep the full dashboard usable on compact laptop displays.  The
            // layout below reflows the inner pages and keeps the four presets
            // equal-width, so a 980x680 window is still a supported size.
            MinimumSize = new Size(980, 680);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.None;
            MaximizeBox = true;
            BackColor = Bg;
            ForeColor = TextMain;
            Font = new Font("Segoe UI", 9.5f);
            AutoScaleMode = AutoScaleMode.Dpi;
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                      ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);

            _content = new Panel { BackColor = Bg };
            Controls.Add(_content);

            _sidebar = new Panel { BackColor = PanelBg };
            Controls.Add(_sidebar);
            BuildSidebar();

            BuildChrome();
            BuildDashboardChrome();
            BuildPageInicio();
            BuildPageLimpeza();
            BuildPageDesempenho();
            BuildPageInternet();
            BuildPageInicializacao();
            BuildPageFerramentas();
            BuildPageDispositivo();
            BuildPageConfiguracoes();
            ShowPage("inicio");
            HighlightNav("inicio");

            Shown += (s, e) =>
            {
                LayoutVisuals();
                CheckMandatoryUpdate();
                if (IsDisposed) return;
                RefreshHealthAsync();
            };
            Resize += (s, e) => LayoutVisuals();
            LayoutRoot();
            LogLine("Verifica atualização no GitHub ao abrir. Passe o mouse nos cards.");
        }

        string T(string key)
        {
            return UiText.Get(key, _english);
        }

        TControl Register<TControl>(TControl control, string key) where TControl : Control
        {
            List<Control> controls;
            if (!_localized.TryGetValue(key, out controls))
            {
                controls = new List<Control>();
                _localized[key] = controls;
            }
            controls.Add(control);
            control.Text = T(key);
            return control;
        }

        void SetLanguage(bool english)
        {
            _english = english;
            Text = T("app.title");
            _tips.ToolTipTitle = T("app.title");
            foreach (var kv in _localized)
                foreach (var control in kv.Value)
                    if (control != null && !control.IsDisposed) control.Text = T(kv.Key);
            if (_languageCaption != null) _languageCaption.Text = T("language.label");
            if (_brandLabel != null) _brandLabel.Text = T("brand");
            if (_protectLabel != null) _protectLabel.Text = T("nav.protection");
            if (_dry != null) _dry.Text = T("dryrun");
            if (_btnCancel != null) _btnCancel.Text = T("cancel");
            if (_statusLabel != null && !string.IsNullOrWhiteSpace(_statusLabel.Text)) _statusLabel.Text = "[" + DateTime.Now.ToString("HH:mm:ss") + "] " + T("status.activity");
            if (_taskLabel != null && !_running) _taskLabel.Text = T("task.ready");
            if (_beforeAfter != null && !_running) _beforeAfter.Text = T("stats.empty");
            if (_healthLabel != null && !_running && _healthScore == 0) _healthLabel.Text = T("health.empty");
            UpdateHero();
            if (_languagePtButton != null)
            {
                _languagePtButton.BackColor = english ? Card : Color.FromArgb(0, 92, 91);
                _languagePtButton.ForeColor = english ? Muted : Color.White;
            }
            if (_languageEnButton != null)
            {
                _languageEnButton.BackColor = english ? Color.FromArgb(0, 92, 91) : Card;
                _languageEnButton.ForeColor = english ? Color.White : Muted;
            }
            if (_deviceLoaded) LoadDeviceInfoAsync(true);
            Invalidate(true);
        }

        void UpdateHero()
        {
            if (_heroSub == null) return;
            string key = _activeNav == "inicio" ? "header.dashboard" : "header." + (_pages.ContainsKey(_activeNav) ? _activeNav : "configuracoes");
            _heroSub.Text = T(key);
        }

        void LayoutRoot()
        {
            int sidebarWidth = 246;
            int clientWidth = Math.Max(sidebarWidth + 1, ClientSize.Width);
            int clientHeight = Math.Max(1, ClientSize.Height);
            if (_sidebar != null) _sidebar.Bounds = new Rectangle(0, 0, sidebarWidth, clientHeight);
            if (_content != null) _content.Bounds = new Rectangle(sidebarWidth, 0, clientWidth - sidebarWidth, clientHeight);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            LayoutRoot();
            if (Width > 2 && Height > 2)
            {
                using (var path = RoundPanel.RoundRect(new Rectangle(0, 0, Width, Height), 18))
                    Region = new Region(path);
            }
            LayoutVisuals();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            if (Width < 2 || Height < 2) return;
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (var pen = new Pen(Color.FromArgb(36, 139, 157), 1.3f))
            using (var path = RoundPanel.RoundRect(new Rectangle(1, 1, Width - 3, Height - 3), 18))
                e.Graphics.DrawPath(pen, path);
        }

        void BuildChrome()
        {
            _chrome = new Panel { Dock = DockStyle.Top, Height = 100, BackColor = Bg };
            _content.Controls.Add(_chrome);

            var titleFont = new Font("Segoe UI Semibold", 28.5f);
            var pcSize = TextRenderer.MeasureText("PC", titleFont);
            var optSize = TextRenderer.MeasureText("OTIMIZADOR", titleFont);
            var proSize = TextRenderer.MeasureText("PRO", titleFont);
            var pc = new Label { Text = "PC", Font = titleFont, ForeColor = TextMain, Location = new Point(34, 16), Size = pcSize, AutoSize = false };
            var opt = Register(new Label { Font = titleFont, ForeColor = Accent, Location = new Point(34 + pcSize.Width + 10, 16), Size = optSize, AutoSize = false }, "title.optimizer");
            var pro = new Label { Text = "PRO", Font = titleFont, ForeColor = TextMain, Location = new Point(34 + pcSize.Width + 10 + optSize.Width + 15, 16), Size = proSize, AutoSize = false };
            _chrome.Controls.Add(pc); _chrome.Controls.Add(opt); _chrome.Controls.Add(pro);
            _heroSub = new Label { Text = T("header.dashboard"), Location = new Point(38, 70), Size = new Size(520, 20), AutoSize = false, AutoEllipsis = true, ForeColor = Muted, Font = new Font("Segoe UI", 9.5f) };
            _chrome.Controls.Add(_heroSub);
            WireDrag(_chrome); WireDrag(pc); WireDrag(opt); WireDrag(pro);

            _dry = new TogglePill { Text = T("dryrun"), Location = new Point(0, 20), Size = new Size(104, 30), Anchor = AnchorStyles.Top | AnchorStyles.Right, TabStop = false };
            _chrome.Controls.Add(_dry);
            Tip(_dry, "Simula a limpeza sem apagar nada. Ideal na primeira vez.");

            var min = ChromeButton("—");
            var max = ChromeButton("□");
            var close = ChromeButton("×");
            min.Click += (s, e) => WindowState = FormWindowState.Minimized;
            max.Click += (s, e) => ToggleMaximize();
            close.Click += (s, e) => Close();
            _chrome.Controls.Add(min); _chrome.Controls.Add(max); _chrome.Controls.Add(close);
            _chrome.Resize += (s, e) =>
            {
                int right = _chrome.ClientSize.Width - 14;
                close.Location = new Point(right - close.Width, 16);
                max.Location = new Point(close.Left - max.Width - 4, 16);
                min.Location = new Point(max.Left - min.Width - 4, 16);
                _dry.Location = new Point(Math.Max(pro.Right + 18, right - _dry.Width), 62);
            };
        }

        Button ChromeButton(string text)
        {
            var b = new Button { Text = text, Size = new Size(34, 28), FlatStyle = FlatStyle.Flat, BackColor = Bg, ForeColor = Accent, Font = new Font("Segoe UI Light", 14f), Cursor = Cursors.Hand, Anchor = AnchorStyles.Top | AnchorStyles.Right };
            b.FlatAppearance.BorderSize = 0;
            b.MouseEnter += (s, e) => b.BackColor = CardHi;
            b.MouseLeave += (s, e) => b.BackColor = Bg;
            return b;
        }

        void ToggleMaximize()
        {
            WindowState = WindowState == FormWindowState.Maximized ? FormWindowState.Normal : FormWindowState.Maximized;
        }

        void WireDrag(Control c)
        {
            c.MouseDown += (s, e) =>
            {
                if (e.Button == MouseButtons.Left)
                {
                    ReleaseCapture();
                    SendMessage(Handle, WM_NCLBUTTONDOWN, (IntPtr)HTCAPTION, IntPtr.Zero);
                }
            };
        }

        void BuildDashboardChrome()
        {
            _progressBox = new RoundPanel { BackColor = Card, BorderColor = Border, Glow = true };
            _content.Controls.Add(_progressBox);
            _pctLabel = new Label { Text = "0%", Font = new Font("Segoe UI Semibold", 32f), ForeColor = Accent, TextAlign = ContentAlignment.MiddleCenter };
            _progressBox.Controls.Add(_pctLabel);
            _bar = new GlowProgress { Value = 0 };
            _progressBox.Controls.Add(_bar);
            _taskLabel = new Label { Text = T("task.ready"), ForeColor = Accent, TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 12f) };
            _progressBox.Controls.Add(_taskLabel);
            _btnCancel = FlatBtn(0, 0, 92, 32, T("cancel"), Color.FromArgb(95, 29, 43));
            _btnCancel.Enabled = false;
            _btnCancel.Visible = false;
            _btnCancel.ForeColor = Color.FromArgb(255, 190, 198);
            _btnCancel.Click += (s, e) => CancelRun();
            _progressBox.Controls.Add(_btnCancel);
            Tip(_btnCancel, "Cancela a execução em andamento de forma cooperativa.");

            _statsBox = new RoundPanel { BackColor = Card, BorderColor = Border };
            _content.Controls.Add(_statsBox);
            _diskIconHost = new Panel { BackColor = Color.Transparent };
            _diskIconHost.Controls.Add(new IconCanvas("drive", 78) { AccentColor = Accent2, ShowTile = false, Dock = DockStyle.Fill });
            _statsBox.Controls.Add(_diskIconHost);
            _beforeAfter = new Label { Text = T("stats.empty"), ForeColor = TextMain, Font = new Font("Segoe UI Semibold", 13f), TextAlign = ContentAlignment.MiddleLeft };
            _statsBox.Controls.Add(_beforeAfter);
            _healthIconHost = new Panel { BackColor = Color.Transparent };
            _healthIconHost.Controls.Add(new IconCanvas("health", 78) { AccentColor = Accent, ShowTile = false, Dock = DockStyle.Fill });
            _statsBox.Controls.Add(_healthIconHost);
            _statsDivider = new Panel { BackColor = Color.FromArgb(42, 69, 82), Width = 1 };
            _statsBox.Controls.Add(_statsDivider);
            _healthLabel = new Label { Text = T("health.empty"), ForeColor = Accent, Font = new Font("Segoe UI Semibold", 19f), TextAlign = ContentAlignment.MiddleLeft };
            _statsBox.Controls.Add(_healthLabel);
            Tip(_healthLabel, "Nota de saúde 0–100 (disco, RAM, lixo recuperável).");
            _statusLabel = new Label { Text = "", ForeColor = Muted, AutoEllipsis = true, TextAlign = ContentAlignment.MiddleLeft };
            _content.Controls.Add(_statusLabel);
            _log = new TextBox { Multiline = true, ReadOnly = true, Visible = false };
        }

        void LayoutVisuals()
        {
            if (_content == null || _chrome == null) return;
            int w = Math.Max(600, _content.ClientSize.Width - 60);
            int h = Math.Max(520, _content.ClientSize.Height);
            int gridHeight = Math.Max(220, Math.Min(250, h / 3));
            int gridY = 108;
            int progressY = gridY + gridHeight + 20;
            int progressH = 154;
            int statsY = progressY + progressH + 18;
            int statsH = Math.Max(120, Math.Min(190, h - statsY - 68));
            bool dashboard = string.Equals(_activeNav, "inicio", StringComparison.OrdinalIgnoreCase);
            int pageHeight = dashboard ? gridHeight : Math.Max(220, h - gridY - 30);
            if (_presetGrid != null)
            {
                int cellWidth = Math.Max(160, w / 4);
                int gridWidth = cellWidth * 4;
                int gridLeft = Math.Max(0, (w - gridWidth) / 2);
                // _presetGrid is a child of the page, which already starts at gridY.
                // Keep its coordinates relative to that page; applying gridY twice
                // makes the progress panel overlap and hide the card bottoms.
                _presetGrid.Bounds = new Rectangle(gridLeft, 0, gridWidth, gridHeight);
                for (int i = 0; i < _presetGrid.ColumnStyles.Count; i++)
                {
                    _presetGrid.ColumnStyles[i].SizeType = SizeType.Absolute;
                    _presetGrid.ColumnStyles[i].Width = cellWidth;
                }
            }
            foreach (var kv in _pages) kv.Value.Bounds = new Rectangle(30, gridY, w, pageHeight);
            foreach (var pageEntry in _pages)
            {
                foreach (Control child in pageEntry.Value.Controls)
                {
                    var flow = child as FlowLayoutPanel;
                    if (flow != null && (flow == _toolsFlow || flow == _deviceFlow || string.Equals(flow.Tag as string, "feature-flow", StringComparison.Ordinal)))
                        flow.Bounds = new Rectangle(0, 92, pageEntry.Value.ClientSize.Width, Math.Max(90, pageEntry.Value.ClientSize.Height - 92));
                    var heading = child as Label;
                    if (heading != null && (heading.Top == 18 || heading.Top == 58))
                        heading.Size = new Size(Math.Max(120, pageEntry.Value.ClientSize.Width - heading.Left - 18), heading.Top == 18 ? 38 : 24);
                }
            }
            if (_helpScroll != null)
            {
                var helpPage = _pages["configuracoes"];
                _helpScroll.Bounds = new Rectangle(0, 92, helpPage.ClientSize.Width, Math.Max(120, helpPage.ClientSize.Height - 92));
                // The fixed-height guide can require a vertical scrollbar. Leave
                // its gutter in the width calculation so the card never clips
                // horizontally when the window is compact.
                int helpWidth = Math.Max(260, helpPage.ClientSize.Width - 42);
                _helpBox.Bounds = new Rectangle(12, 12, helpWidth, 360);
                _helpLabel.Bounds = new Rectangle(26, 24, Math.Max(208, helpWidth - 52), 150);
                if (_safetyTitle != null) _safetyTitle.Bounds = new Rectangle(26, 190, Math.Max(208, helpWidth - 52), 24);
                if (_safetyText != null) _safetyText.Bounds = new Rectangle(26, 216, Math.Max(208, helpWidth - 52), 100);
            }
            if (_deviceRefresh != null && _pages.ContainsKey("dispositivo"))
            {
                var devicePage = _pages["dispositivo"];
                _deviceRefresh.Bounds = new Rectangle(Math.Max(20, devicePage.ClientSize.Width - 178), 18, 160, 32);
                foreach (Control child in devicePage.Controls)
                    if (child is Label && child.Top == 18) child.Width = Math.Max(160, devicePage.ClientSize.Width - 220);
            }
            if (_progressBox != null)
            {
                _progressBox.Visible = dashboard;
                _progressBox.Bounds = new Rectangle(30, progressY, w, progressH);
                _pctLabel.Bounds = new Rectangle(120, 1, Math.Max(200, w - 240), 68);
                _bar.Bounds = new Rectangle(34, 72, Math.Max(40, w - 68), 22);
                _taskLabel.Bounds = new Rectangle(24, 105, Math.Max(80, w - 48), 28);
                _btnCancel.Bounds = new Rectangle(w - 112, 14, 92, 32);
            }
            if (_statsBox != null)
            {
                _statsBox.Visible = dashboard;
                _statsBox.Bounds = new Rectangle(30, statsY, w, statsH);
                int half = w / 2;
                _diskIconHost.Bounds = new Rectangle(22, 15, 82, Math.Max(70, statsH - 30));
                _beforeAfter.Bounds = new Rectangle(120, 15, Math.Max(180, half - 150), Math.Max(70, statsH - 30));
                _statsDivider.Bounds = new Rectangle(half, 24, 1, Math.Max(52, statsH - 48));
                _healthIconHost.Bounds = new Rectangle(half + 16, 15, 82, Math.Max(70, statsH - 30));
                _healthLabel.Bounds = new Rectangle(half + 114, 15, Math.Max(180, w - half - 135), Math.Max(70, statsH - 30));
            }
            if (_statusLabel != null)
            {
                _statusLabel.Visible = dashboard;
                _statusLabel.Bounds = new Rectangle(34, h - 32, Math.Max(100, w - 8), 24);
            }
        }

        void CheckMandatoryUpdate()
        {
            var upd = Path.Combine(_root, "Update.ps1");
            if (!File.Exists(upd)) { LogLine(Local(_english, "Atualizador ausente nesta pasta.", "Updater is missing from this folder.")); return; }
            _taskLabel.Text = T("task.update.checking");
            _statusLabel.Text = T("status.update.checking");
            Application.DoEvents();
            try
            {
                string relaunch = Path.Combine(_root, "PC-Otimizador.exe");
                if (!File.Exists(relaunch)) relaunch = Path.Combine(_root, "Executar.bat");
                var psi = new ProcessStartInfo
                {
                    FileName = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe"),
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + upd + "\" -Root \"" + _root + "\" -Relaunch \"" + relaunch + "\"",
                    WorkingDirectory = _root,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = false,
                    CreateNoWindow = true,
                    StandardOutputEncoding = Encoding.UTF8
                };
                using (var p = Process.Start(psi))
                {
                    string line;
                    while ((line = p.StandardOutput.ReadLine()) != null)
                    {
                        if (line.StartsWith("##UPDATE##|")) LogLine(line.Substring(11));
                        else if (!string.IsNullOrWhiteSpace(line)) LogLine(line.Trim());
                        Application.DoEvents();
                    }
                    if (!p.WaitForExit(300000)) { LogLine(Local(_english, "Verificação de atualização excedeu o tempo limite.", "Update check timed out.")); _taskLabel.Text = T("task.update.timeout"); return; }
                    int code = p.ExitCode;
                    if (code == 10)
                    {
                        MessageBox.Show(Local(_english, "Nova versão encontrada.\nO programa vai fechar e atualizar sozinho.", "A new version was found.\nThe app will close and update automatically."), Local(_english, "Atualização obrigatória", "Required update"), MessageBoxButtons.OK, MessageBoxIcon.Information);
                        Application.Exit(); return;
                    }
                    if (code == 2)
                    {
                        MessageBox.Show(Local(_english, "Falha na atualização obrigatória.\nVerifique a internet e tente de novo.\n\nhttps://github.com/leonardolauriquer/PC-Otimizador/releases", "Required update failed.\nCheck your connection and try again.\n\nhttps://github.com/leonardolauriquer/PC-Otimizador/releases"), Local(_english, "Atualização", "Update"), MessageBoxButtons.OK, MessageBoxIcon.Error);
                        Application.Exit(); return;
                    }
                    _taskLabel.Text = T("task.ready");
                }
            }
            catch (Exception ex) { LogLine(Local(_english, "Verificação de atualização: ", "Update check: ") + ex.Message); _taskLabel.Text = T("task.update.offline"); }
        }

        void BuildSidebar()
        {
            var logo = new IconCanvas("gauge", 72) { AccentColor = Accent, Location = new Point(30, 22) };
            _sidebar.Controls.Add(logo);
            _brandLabel = Register(new Label { Font = new Font("Segoe UI Semibold", 12f), ForeColor = TextMain, Location = new Point(112, 32), Size = new Size(120, 44) }, "brand");
            var brand = _brandLabel;
            _sidebar.Controls.Add(brand);
            WireDrag(logo); WireDrag(brand);
            int y = 118;
            AddNav("inicio", "INÍCIO", "home", y, () => ShowPage("inicio")); y += 52;
            AddNav("limpeza", "LIMPEZA", "broom", y, () => ShowPage("limpeza")); y += 52;
            AddNav("desempenho", "DESEMPENHO", "gauge", y, () => ShowPage("desempenho")); y += 52;
            AddNav("internet", "INTERNET", "globe", y, () => ShowPage("internet")); y += 52;
            AddNav("inicializacao", "INICIALIZAÇÃO", "power", y, () => ShowPage("inicializacao")); y += 52;
            AddNav("ferramentas", "FERRAMENTAS", "tools", y, () => ShowPage("ferramentas")); y += 52;
            AddNav("dispositivo", "DISPOSITIVO", "device", y, () => ShowPage("dispositivo")); y += 52;
            AddNav("configuracoes", "CONFIGURAÇÕES", "gear", y, () => ShowPage("configuracoes"));

            var separator = new Panel { BackColor = Color.FromArgb(28, 46, 59), Height = 1, Dock = DockStyle.Bottom };
            _sidebar.Controls.Add(separator);
            var languagePanel = new Panel { Dock = DockStyle.Bottom, Height = 54, BackColor = PanelBg };
            _languageCaption = Register(new Label { ForeColor = Muted, Font = new Font("Segoe UI Semibold", 8f), Location = new Point(20, 12), AutoSize = true }, "language.label");
            languagePanel.Controls.Add(_languageCaption);
            _languagePtButton = new Button { Text = "PT", Location = new Point(88, 7), Size = new Size(56, 28), FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(0, 92, 91), ForeColor = Color.White, Font = new Font("Segoe UI Semibold", 8.5f), Cursor = Cursors.Hand };
            _languageEnButton = new Button { Text = "EN", Location = new Point(149, 7), Size = new Size(56, 28), FlatStyle = FlatStyle.Flat, BackColor = Card, ForeColor = Muted, Font = new Font("Segoe UI Semibold", 8.5f), Cursor = Cursors.Hand };
            _languagePtButton.FlatAppearance.BorderColor = Border;
            _languageEnButton.FlatAppearance.BorderColor = Border;
            _languagePtButton.ForeColor = Color.White;
            _languageEnButton.ForeColor = Muted;
            _languagePtButton.Click += (s, e) => SetLanguage(false);
            _languageEnButton.Click += (s, e) => SetLanguage(true);
            languagePanel.Controls.Add(_languagePtButton);
            languagePanel.Controls.Add(_languageEnButton);
            _sidebar.Controls.Add(languagePanel);
            var protect = new Panel { Dock = DockStyle.Bottom, Height = 88, BackColor = PanelBg, Padding = new Padding(20, 16, 16, 10) };
            _sidebar.Controls.Add(protect);
            var shield = new IconCanvas("shield", 34) { AccentColor = Accent, Location = new Point(20, 21) };
            protect.Controls.Add(shield);
            _protectDot = new Label { Text = "●", ForeColor = Ok, AutoSize = true, Font = new Font("Segoe UI", 10f), Location = new Point(190, 34) };
            protect.Controls.Add(_protectDot);
            _protectLabel = Register(new Label { ForeColor = TextMain, Font = new Font("Segoe UI Semibold", 9f), Location = new Point(68, 20), Size = new Size(110, 40) }, "nav.protection");
            var protLbl = _protectLabel;
            protect.Controls.Add(protLbl);
            Tip(protect, "Documentos, Fotos, Downloads, Desktop, Música e OneDrive estão protegidos.");
        }

        void AddNav(string key, string text, string icon, int y, Action act)
        {
            var p = new Panel { Tag = key, Location = new Point(14, y), Size = new Size(218, 42), BackColor = PanelBg, Cursor = Cursors.Hand };
            var iconPanel = new IconCanvas(icon, 26) { AccentColor = Muted, Location = new Point(16, 8) };
            var label = Register(new Label { ForeColor = Muted, Font = new Font("Segoe UI Semibold", 9.5f), Location = new Point(57, 11), AutoSize = true, Cursor = Cursors.Hand }, "nav." + key);
            p.Controls.Add(iconPanel); p.Controls.Add(label);
            EventHandler click = (s, e) => { HighlightNav(key); act(); };
            p.Click += click; iconPanel.Click += click; label.Click += click;
            p.MouseEnter += (s, e) => { if (_activeNav != key) p.BackColor = CardHi; };
            p.MouseLeave += (s, e) => { if (_activeNav != key) p.BackColor = PanelBg; };
            _sidebar.Controls.Add(p); _navBtns.Add(p); Tip(p, text + " — clique para abrir");
        }

        void HighlightNav(string key)
        {
            _activeNav = key;
            foreach (var p in _navBtns)
            {
                bool selected = string.Equals((string)p.Tag, key, StringComparison.OrdinalIgnoreCase);
                p.BackColor = selected ? Card : PanelBg;
                var icon = p.Controls.Count > 0 ? p.Controls[0] as IconCanvas : null;
                var label = p.Controls.Count > 1 ? p.Controls[1] as Label : null;
                if (icon != null) { icon.AccentColor = selected ? Accent : Muted; icon.Invalidate(); }
                if (label != null) label.ForeColor = selected ? Accent : Muted;
                p.Invalidate(true);
            }
            UpdateHero();
        }

        void BuildPageInicio()
        {
            var page = new Panel { BackColor = Bg };
            _content.Controls.Add(page); _pages["inicio"] = page;
            _presetGrid = new TableLayoutPanel { ColumnCount = 4, RowCount = 1, BackColor = Color.Transparent, Margin = new Padding(0), Padding = new Padding(0), GrowStyle = TableLayoutPanelGrowStyle.FixedSize, Dock = DockStyle.None };
            for (int i = 0; i < 4; i++) _presetGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 200f));
            _presetGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
            page.Controls.Add(_presetGrid);
            _presetGrid.Controls.Add(MakePresetCard("card.safe.title", "card.safe.sub", "badge.safe", "shield", Accent, () => RunPreset("safe", false), "Temporários e caches regeneráveis. Não esvazia a Lixeira."), 0, 0);
            _presetGrid.Controls.Add(MakePresetCard("card.gamer.title", "card.gamer.sub", "badge.risk", "gauge", Danger, () => RunPreset("gamer", true), "Pode ativar Alto Desempenho e DNS Cloudflare."), 1, 0);
            _presetGrid.Controls.Add(MakePresetCard("card.net.title", "card.net.sub", "badge.risk", "globe", Warn, () => RunPreset("net", true), "Flush DNS/ARP; pode renovar IP e DNS Cloudflare."), 2, 0);
            _presetGrid.Controls.Add(MakePresetCard("card.notebook.title", "card.notebook.sub", "badge.safe", "laptop", Ok, () => RunPreset("notebook", false), "Limpeza segura + plano de energia equilibrado."), 3, 0);
        }

        RoundPanel MakePresetCard(string titleKey, string subKey, string badgeKey, string icon, Color accent, Action onClick, string tip)
        {
            var p = new RoundPanel { BackColor = Card, BorderColor = Border, Radius = 14, Margin = new Padding(8), Dock = DockStyle.Fill, Cursor = Cursors.Hand };
            var rail = new Panel { BackColor = accent, Width = 3, Dock = DockStyle.Left };
            p.Controls.Add(rail);
            var iconPanel = new IconCanvas(icon, 86) { AccentColor = accent, Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right };
            var titleLabel = Register(new Label { ForeColor = TextMain, Font = new Font("Segoe UI Semibold", 11.5f), TextAlign = ContentAlignment.MiddleCenter, AutoEllipsis = true, Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right }, titleKey);
            var subLabel = Register(new Label { ForeColor = Muted, Font = new Font("Segoe UI", 8.8f), TextAlign = ContentAlignment.TopCenter, AutoEllipsis = true, Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right }, subKey);
            var badgeLabel = Register(new Label { ForeColor = accent, Font = new Font("Segoe UI Semibold", 8f), AutoSize = true, Location = new Point(18, 14) }, badgeKey);
            p.Controls.Add(iconPanel); p.Controls.Add(titleLabel); p.Controls.Add(subLabel); p.Controls.Add(badgeLabel);
            p.Resize += (s, e) =>
            {
                int center = Math.Max(0, p.ClientSize.Width / 2 - 43);
                iconPanel.Bounds = new Rectangle(center, 30, 86, 86);
                titleLabel.Bounds = new Rectangle(14, 126, Math.Max(40, p.ClientSize.Width - 28), 28);
                subLabel.Bounds = new Rectangle(16, 158, Math.Max(40, p.ClientSize.Width - 32), Math.Max(28, p.ClientSize.Height - 177));
            };
            EventHandler click = (s, e) => { if (!_running) onClick(); };
            p.Click += click; iconPanel.Click += click; titleLabel.Click += click; subLabel.Click += click; badgeLabel.Click += click;
            p.MouseEnter += (s, e) => { p.BackColor = CardHi; p.BorderColor = accent; p.Glow = true; p.Invalidate(); };
            p.MouseLeave += (s, e) => { p.BackColor = Card; p.BorderColor = Border; p.Glow = false; p.Invalidate(); };
            Tip(p, tip); Tip(titleLabel, tip);
            return p;
        }

        void BuildFeaturePage(string pageKey, string titleKey, string descKey, FeatureSpec[] specs)
        {
            var page = new Panel { BackColor = Bg, Visible = false };
            _content.Controls.Add(page); _pages[pageKey] = page;
            page.Controls.Add(Register(new Label { Font = new Font("Segoe UI Semibold", 22f), ForeColor = TextMain, Location = new Point(10, 18), Size = new Size(600, 38), AutoEllipsis = true }, titleKey));
            page.Controls.Add(Register(new Label { ForeColor = Muted, Location = new Point(12, 58), Size = new Size(600, 24), AutoEllipsis = true }, descKey));
            var flow = new FlowLayoutPanel
            {
                BackColor = Color.Transparent,
                AutoScroll = true,
                WrapContents = true,
                FlowDirection = FlowDirection.LeftToRight,
                Padding = new Padding(4),
                Margin = new Padding(0),
                Tag = "feature-flow"
            };
            for (int i = 0; i < specs.Length; i++) flow.Controls.Add(FeatureCard(specs[i]));
            page.Controls.Add(flow);
        }

        RoundPanel FeatureCard(FeatureSpec spec)
        {
            var p = new RoundPanel { Size = new Size(300, 132), Margin = new Padding(8), BackColor = Card, BorderColor = Border, Radius = 14, Cursor = Cursors.Hand };
            var rail = new Panel { BackColor = spec.Accent, Width = 3, Dock = DockStyle.Left };
            var icon = new IconCanvas(spec.Icon, 52) { AccentColor = spec.Accent, Location = new Point(18, 18) };
            var title = Register(new Label { Font = new Font("Segoe UI Semibold", 11f), ForeColor = TextMain, Location = new Point(84, 18), Size = new Size(198, 25), AutoEllipsis = true }, spec.TitleKey);
            var sub = Register(new Label { Font = new Font("Segoe UI", 8.8f), ForeColor = Muted, Location = new Point(84, 47), Size = new Size(198, 34), AutoEllipsis = true }, spec.SubKey);
            var run = Register(new Button { FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(15, 35, 46), ForeColor = spec.Accent, Font = new Font("Segoe UI Semibold", 8f), Location = new Point(84, 91), Size = new Size(126, 27), Cursor = Cursors.Hand }, spec.ButtonKey);
            run.FlatAppearance.BorderColor = Color.FromArgb(45, 90, 105);
            p.Controls.Add(rail); p.Controls.Add(icon); p.Controls.Add(title); p.Controls.Add(sub); p.Controls.Add(run);
            EventHandler click = (o, e) => { if (!_running && spec.Action != null) spec.Action(); };
            p.Click += click; icon.Click += click; title.Click += click; sub.Click += click; run.Click += click;
            p.MouseEnter += (o, e) => { p.BackColor = CardHi; p.BorderColor = spec.Accent; p.Glow = true; p.Invalidate(); };
            p.MouseLeave += (o, e) => { p.BackColor = Card; p.BorderColor = Border; p.Glow = false; p.Invalidate(); };
            Tip(p, T(spec.TitleKey));
            return p;
        }

        void BuildPageLimpeza()
        {
            BuildFeaturePage("limpeza", "page.limpeza.title", "page.limpeza.desc", new[]
            {
                new FeatureSpec { Icon = "shield", TitleKey = "card.safe.title", SubKey = "card.safe.sub", ButtonKey = "button.runSafe", Accent = Accent, Action = () => RunPreset("safe", false) },
                new FeatureSpec { Icon = "laptop", TitleKey = "card.notebook.title", SubKey = "card.notebook.sub", ButtonKey = "button.runSafe", Accent = Ok, Action = () => RunPreset("notebook", false) },
                new FeatureSpec { Icon = "drive", TitleKey = "card.scan.title", SubKey = "card.scan.sub", ButtonKey = "button.scan", Accent = Accent2, Action = () => RunCli("-Mode scan -AutoYes") }
            });
        }

        void BuildPageDesempenho()
        {
            BuildFeaturePage("desempenho", "page.desempenho.title", "page.desempenho.desc", new[]
            {
                new FeatureSpec { Icon = "gauge", TitleKey = "card.gamer.title", SubKey = "card.gamer.sub", ButtonKey = "button.runGamer", Accent = Danger, Action = () => RunPreset("gamer", true) },
                new FeatureSpec { Icon = "heart", TitleKey = "card.health.title", SubKey = "card.health.sub", ButtonKey = "button.health", Accent = Accent, Action = () => RunCli("-Mode health -AutoYes") },
                new FeatureSpec { Icon = "laptop", TitleKey = "card.notebook.title", SubKey = "card.notebook.sub", ButtonKey = "button.runSafe", Accent = Ok, Action = () => RunPreset("notebook", false) }
            });
        }

        void BuildPageInternet()
        {
            BuildFeaturePage("internet", "page.internet.title", "page.internet.desc", new[]
            {
                new FeatureSpec { Icon = "globe", TitleKey = "card.net.title", SubKey = "card.net.sub", ButtonKey = "button.runNet", Accent = Warn, Action = () => RunPreset("net", true) },
                new FeatureSpec { Icon = "network", TitleKey = "card.scan.title", SubKey = "card.scan.sub", ButtonKey = "button.scan", Accent = Accent2, Action = () => RunCli("-Mode scan -AutoYes") },
                new FeatureSpec { Icon = "heart", TitleKey = "card.health.title", SubKey = "card.health.sub", ButtonKey = "button.health", Accent = Accent, Action = () => RunCli("-Mode health -AutoYes") }
            });
        }

        void BuildPageInicializacao()
        {
            BuildFeaturePage("inicializacao", "page.inicializacao.title", "page.inicializacao.desc", new[]
            {
                new FeatureSpec { Icon = "clock", TitleKey = "card.schedule.title", SubKey = "card.schedule.sub", ButtonKey = "button.schedule", Accent = Accent, Action = () => ScheduleWeekly() },
                new FeatureSpec { Icon = "heart", TitleKey = "card.health.title", SubKey = "card.health.sub", ButtonKey = "button.health", Accent = Accent2, Action = () => RunCli("-Mode health -AutoYes") },
                new FeatureSpec { Icon = "folder", TitleKey = "card.logs.title", SubKey = "card.logs.sub", ButtonKey = "button.logs", Accent = Ok, Action = () => OpenLogsFolder() }
            });
        }

        void BuildPageFerramentas()
        {
            var page = new Panel { BackColor = Bg, Visible = false };
            _content.Controls.Add(page); _pages["ferramentas"] = page;
            page.Controls.Add(Register(new Label { Font = new Font("Segoe UI Semibold", 22f), ForeColor = TextMain, Location = new Point(10, 18), AutoSize = true }, "page.ferramentas.title"));
            page.Controls.Add(Register(new Label { ForeColor = Muted, Location = new Point(12, 58), AutoSize = true }, "page.ferramentas.desc"));
            _toolsFlow = new FlowLayoutPanel { BackColor = Color.Transparent, AutoScroll = true, WrapContents = true, FlowDirection = FlowDirection.LeftToRight, Padding = new Padding(4), Margin = new Padding(0) };
            _toolsFlow.Controls.Add(ToolCard("card.health.title", "card.health.sub", "shield", () => RunCli("-Mode health -AutoYes")));
            _toolsFlow.Controls.Add(ToolCard("card.scan.title", "card.scan.sub", "drive", () => RunCli("-Mode scan -AutoYes")));
            _toolsFlow.Controls.Add(ToolCard("card.schedule.title", "card.schedule.sub", "clock", () => ScheduleWeekly()));
            _toolsFlow.Controls.Add(ToolCard("card.logs.title", "card.logs.sub", "folder", OpenLogsFolder));
            page.Controls.Add(_toolsFlow);
        }

        RoundPanel ToolCard(string titleKey, string subKey, string icon, Action act)
        {
            var p = new RoundPanel { Size = new Size(280, 90), Margin = new Padding(8), BackColor = Card, BorderColor = Border, Radius = 12, Cursor = Cursors.Hand };
            var i = new IconCanvas(icon, 42) { AccentColor = Accent, Location = new Point(16, 23) };
            var t = Register(new Label { Font = new Font("Segoe UI Semibold", 12f), ForeColor = Accent, Location = new Point(72, 16), Size = new Size(190, 26), AutoEllipsis = true }, titleKey);
            var s = Register(new Label { ForeColor = Muted, Location = new Point(72, 47), Size = new Size(190, 30), AutoEllipsis = true }, subKey);
            p.Controls.Add(i); p.Controls.Add(t); p.Controls.Add(s);
            EventHandler click = (o, e) => { if (!_running) act(); };
            p.Click += click; i.Click += click; t.Click += click; s.Click += click;
            p.MouseEnter += (o, e) => { p.BackColor = CardHi; p.BorderColor = Accent; };
            p.MouseLeave += (o, e) => { p.BackColor = Card; p.BorderColor = Border; };
            Tip(p, T(titleKey) + "\n" + T(subKey));
            return p;
        }

        void BuildPageDispositivo()
        {
            var page = new Panel { BackColor = Bg, Visible = false };
            _content.Controls.Add(page); _pages["dispositivo"] = page;
            page.Controls.Add(Register(new Label { Font = new Font("Segoe UI Semibold", 22f), ForeColor = TextMain, Location = new Point(10, 18), Size = new Size(560, 38), AutoEllipsis = true }, "page.dispositivo.title"));
            page.Controls.Add(Register(new Label { ForeColor = Muted, Location = new Point(12, 58), Size = new Size(720, 24), AutoEllipsis = true }, "page.dispositivo.desc"));
            _deviceRefresh = Register(FlatBtn(0, 0, 160, 32, "", Color.FromArgb(0, 92, 91)), "button.refreshDevice");
            _deviceRefresh.Click += (s, e) => LoadDeviceInfoAsync(true);
            page.Controls.Add(_deviceRefresh);

            _deviceFlow = new FlowLayoutPanel
            {
                BackColor = Color.Transparent,
                AutoScroll = true,
                WrapContents = true,
                FlowDirection = FlowDirection.LeftToRight,
                Padding = new Padding(4),
                Margin = new Padding(0),
                Tag = "device-flow"
            };
            _deviceFlow.Controls.Add(DeviceInfoCard("system", "device.system", "device"));
            _deviceFlow.Controls.Add(DeviceInfoCard("cpu", "device.cpu", "cpu"));
            _deviceFlow.Controls.Add(DeviceInfoCard("gpu", "device.gpu", "gpu"));
            _deviceFlow.Controls.Add(DeviceInfoCard("memory", "device.memory", "memory"));
            _deviceFlow.Controls.Add(DeviceInfoCard("board", "device.board", "component"));
            _deviceFlow.Controls.Add(DeviceInfoCard("storage", "device.storage", "drive"));
            _deviceFlow.Controls.Add(DeviceInfoCard("network", "device.network", "network"));
            _deviceFlow.Controls.Add(DeviceInfoCard("sensors", "device.sensors", "sensor"));
            page.Controls.Add(_deviceFlow);
            SetDeviceLoading();
        }

        RoundPanel DeviceInfoCard(string key, string titleKey, string iconKind)
        {
            var card = new RoundPanel { Size = new Size(315, 168), Margin = new Padding(8), BackColor = Card, BorderColor = Border, Radius = 14 };
            var icon = new IconCanvas(iconKind, 42) { AccentColor = Accent, Location = new Point(16, 16) };
            var title = Register(new Label { Font = new Font("Segoe UI Semibold", 11.5f), ForeColor = Accent, Location = new Point(70, 18), Size = new Size(225, 26), AutoEllipsis = true }, titleKey);
            var value = new Label { Font = new Font("Segoe UI", 9f), ForeColor = TextMain, Location = new Point(18, 64), Size = new Size(279, 88), AutoEllipsis = true };
            card.Controls.Add(icon); card.Controls.Add(title); card.Controls.Add(value);
            _deviceValues[key] = value;
            return card;
        }

        void SetDeviceLoading()
        {
            foreach (var label in _deviceValues.Values) label.Text = T("device.loading");
        }

        void LoadDeviceInfoAsync(bool force)
        {
            if (_deviceFlow == null || (_deviceLoaded && !force)) return;
            int request = Interlocked.Increment(ref _deviceRequestId);
            bool english = _english;
            SetDeviceLoading();
            if (_deviceRefresh != null) _deviceRefresh.Enabled = false;
            ThreadPool.QueueUserWorkItem(delegate
            {
                Dictionary<string, string> data;
                try { data = ReadDeviceInfo(english); }
                catch (Exception ex)
                {
                    data = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    foreach (var key in _deviceValues.Keys) data[key] = UiText.Get("device.error", english) + ex.Message;
                }
                if (IsDisposed || !IsHandleCreated) return;
                BeginInvoke(new Action(delegate
                {
                    if (request != _deviceRequestId || IsDisposed) return;
                    foreach (var kv in _deviceValues)
                    {
                        string value;
                        kv.Value.Text = data.TryGetValue(kv.Key, out value) && !string.IsNullOrWhiteSpace(value) ? value : UiText.Get("device.unavailable", english);
                    }
                    _deviceLoaded = true;
                    if (_deviceRefresh != null) _deviceRefresh.Enabled = true;
                }));
            });
        }

        static string Local(bool english, string portuguese, string englishText)
        {
            return english ? englishText : portuguese;
        }

        static string WmiJoin(string scopePath, string query, Func<ManagementObject, string> formatter)
        {
            var lines = new List<string>();
            try
            {
                var scope = new ManagementScope(string.IsNullOrEmpty(scopePath) ? @"\\.\root\cimv2" : scopePath);
                scope.Connect();
                using (var searcher = new ManagementObjectSearcher(scope, new ObjectQuery(query)))
                using (var results = searcher.Get())
                {
                    foreach (ManagementObject item in results)
                    {
                        using (item)
                        {
                            string line = formatter(item);
                            if (!string.IsNullOrWhiteSpace(line)) lines.Add(line.Trim());
                        }
                    }
                }
            }
            catch { }
            return string.Join("\n", lines.ToArray());
        }

        static string WmiValue(ManagementObject item, string property)
        {
            try
            {
                object value = item[property];
                return value == null ? "" : Convert.ToString(value).Trim();
            }
            catch { return ""; }
        }

        static string FormatBytes(string raw)
        {
            ulong bytes;
            if (!UInt64.TryParse(raw, out bytes) || bytes == 0) return "—";
            double value = bytes;
            string[] units = { "B", "KB", "MB", "GB", "TB" };
            int unit = 0;
            while (value >= 1024 && unit < units.Length - 1) { value /= 1024; unit++; }
            return value.ToString(value >= 100 ? "0" : "0.0") + " " + units[unit];
        }

        static Dictionary<string, string> ReadDeviceInfo(bool english)
        {
            var data = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            data["system"] = WmiJoin(null, "SELECT Manufacturer,Model,SystemType,TotalPhysicalMemory FROM Win32_ComputerSystem", delegate(ManagementObject m)
            {
                return WmiValue(m, "Manufacturer") + " " + WmiValue(m, "Model") + "\n" +
                    Local(english, "Tipo: ", "Type: ") + WmiValue(m, "SystemType") + "\n" +
                    Local(english, "RAM total: ", "Total RAM: ") + FormatBytes(WmiValue(m, "TotalPhysicalMemory"));
            });
            string os = WmiJoin(null, "SELECT Caption,Version,OSArchitecture FROM Win32_OperatingSystem", delegate(ManagementObject m)
            {
                return WmiValue(m, "Caption") + "\n" + Local(english, "Versão: ", "Version: ") + WmiValue(m, "Version") + " · " + WmiValue(m, "OSArchitecture");
            });
            if (!string.IsNullOrWhiteSpace(os)) data["system"] = data["system"] + "\n" + os;

            data["cpu"] = WmiJoin(null, "SELECT Name,NumberOfCores,NumberOfLogicalProcessors,CurrentClockSpeed,MaxClockSpeed,LoadPercentage FROM Win32_Processor", delegate(ManagementObject m)
            {
                return WmiValue(m, "Name") + "\n" +
                    Local(english, "Núcleos/threads: ", "Cores/threads: ") + WmiValue(m, "NumberOfCores") + "/" + WmiValue(m, "NumberOfLogicalProcessors") + "\n" +
                    Local(english, "Frequência: ", "Frequency: ") + WmiValue(m, "CurrentClockSpeed") + "/" + WmiValue(m, "MaxClockSpeed") + " MHz\n" +
                    Local(english, "Uso: ", "Load: ") + WmiValue(m, "LoadPercentage") + "%";
            });
            data["gpu"] = WmiJoin(null, "SELECT Name,AdapterRAM,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution FROM Win32_VideoController", delegate(ManagementObject m)
            {
                return WmiValue(m, "Name") + "\n" + Local(english, "Memória: ", "Memory: ") + FormatBytes(WmiValue(m, "AdapterRAM")) + "\n" +
                    Local(english, "Driver: ", "Driver: ") + WmiValue(m, "DriverVersion") + "\n" +
                    Local(english, "Resolução: ", "Resolution: ") + WmiValue(m, "CurrentHorizontalResolution") + " × " + WmiValue(m, "CurrentVerticalResolution");
            });
            data["memory"] = WmiJoin(null, "SELECT Manufacturer,PartNumber,Capacity,Speed,ConfiguredClockSpeed FROM Win32_PhysicalMemory", delegate(ManagementObject m)
            {
                string speed = WmiValue(m, "ConfiguredClockSpeed");
                if (string.IsNullOrEmpty(speed) || speed == "0") speed = WmiValue(m, "Speed");
                return WmiValue(m, "Manufacturer") + " " + WmiValue(m, "PartNumber") + "\n" + FormatBytes(WmiValue(m, "Capacity")) + " · " + speed + " MHz";
            });
            string board = WmiJoin(null, "SELECT Manufacturer,Product,Version FROM Win32_BaseBoard", delegate(ManagementObject m)
            {
                return WmiValue(m, "Manufacturer") + " " + WmiValue(m, "Product") + " · " + WmiValue(m, "Version");
            });
            string bios = WmiJoin(null, "SELECT Manufacturer,SMBIOSBIOSVersion,ReleaseDate FROM Win32_BIOS", delegate(ManagementObject m)
            {
                return "BIOS: " + WmiValue(m, "Manufacturer") + " " + WmiValue(m, "SMBIOSBIOSVersion");
            });
            data["board"] = board + (string.IsNullOrWhiteSpace(bios) ? "" : "\n" + bios);
            data["storage"] = WmiJoin(null, "SELECT Model,InterfaceType,MediaType,Size FROM Win32_DiskDrive", delegate(ManagementObject m)
            {
                return WmiValue(m, "Model") + "\n" + WmiValue(m, "InterfaceType") + " · " + FormatBytes(WmiValue(m, "Size"));
            });
            data["network"] = WmiJoin(null, "SELECT Description,MACAddress,IPAddress FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled=True", delegate(ManagementObject m)
            {
                string ip = "";
                try
                {
                    var addresses = m["IPAddress"] as string[];
                    if (addresses != null && addresses.Length > 0) ip = addresses[0];
                }
                catch { }
                return WmiValue(m, "Description") + "\nIP: " + ip + "\nMAC: " + WmiValue(m, "MACAddress");
            });
            string temperatures = WmiJoin(@"\\.\root\WMI", "SELECT CurrentTemperature,InstanceName FROM MSAcpi_ThermalZoneTemperature", delegate(ManagementObject m)
            {
                double raw;
                if (!Double.TryParse(WmiValue(m, "CurrentTemperature"), out raw) || raw <= 0) return "";
                return Local(english, "Temperatura ACPI: ", "ACPI temperature: ") + (raw / 10.0 - 273.15).ToString("0.0") + " °C";
            });
            string load = WmiJoin(null, "SELECT LoadPercentage,CurrentClockSpeed FROM Win32_Processor", delegate(ManagementObject m)
            {
                return Local(english, "CPU: ", "CPU: ") + WmiValue(m, "LoadPercentage") + "% · " + WmiValue(m, "CurrentClockSpeed") + " MHz";
            });
            data["sensors"] = load + "\n" + (string.IsNullOrWhiteSpace(temperatures) ? UiText.Get("device.unavailable", english) : temperatures);
            return data;
        }

        void BuildPageConfiguracoes()
        {
            var page = new Panel { BackColor = Bg, Visible = false };
            _content.Controls.Add(page); _pages["configuracoes"] = page;
            page.Controls.Add(Register(new Label { Font = new Font("Segoe UI Semibold", 22f), ForeColor = TextMain, Location = new Point(10, 18), Size = new Size(600, 38), AutoEllipsis = true }, "page.configuracoes.title"));
            page.Controls.Add(Register(new Label { ForeColor = Muted, Location = new Point(12, 58), Size = new Size(600, 24), AutoEllipsis = true }, "page.configuracoes.desc"));
            _helpScroll = new Panel { BackColor = Bg, AutoScroll = true };
            _helpBox = new RoundPanel { BackColor = Card, BorderColor = Border, Radius = 14 };
            _helpScroll.Controls.Add(_helpBox);
            page.Controls.Add(_helpScroll);
            _helpLabel = Register(new Label { ForeColor = TextMain, Font = new Font("Segoe UI", 10.5f), AutoEllipsis = false }, "settings.help.text");
            _helpBox.Controls.Add(_helpLabel);
            _safetyTitle = Register(new Label { ForeColor = Accent, Font = new Font("Segoe UI Semibold", 10.5f), AutoEllipsis = true }, "settings.safety.title");
            _safetyTitle.Location = new Point(26, 190); _safetyTitle.Size = new Size(280, 24);
            _helpBox.Controls.Add(_safetyTitle);
            _safetyText = Register(new Label { ForeColor = Muted, Font = new Font("Segoe UI", 9.2f), AutoEllipsis = true }, "settings.safety.text");
            _safetyText.Location = new Point(26, 216); _safetyText.Size = new Size(660, 64);
            _helpBox.Controls.Add(_safetyText);
        }

        void ShowPage(string name)
        {
            string target = _pages.ContainsKey(name) ? name : "inicio";
            foreach (var kv in _pages) kv.Value.Visible = string.Equals(kv.Key, target, StringComparison.OrdinalIgnoreCase);
            HighlightNav(target);
            UpdateHero();
            LayoutVisuals();
            if (string.Equals(target, "dispositivo", StringComparison.OrdinalIgnoreCase)) LoadDeviceInfoAsync(false);
        }

        Button FlatBtn(int x, int y, int w, int h, string text, Color bg)
        {
            var b = new Button { Text = text, Location = new Point(x, y), Size = new Size(w, h), FlatStyle = FlatStyle.Flat, BackColor = bg, ForeColor = TextMain, Font = new Font("Segoe UI Semibold", 8.5f), Cursor = Cursors.Hand };
            b.FlatAppearance.BorderSize = 0;
            b.MouseEnter += (s, e) => b.BackColor = Color.FromArgb(Math.Min(255, bg.R + 16), Math.Min(255, bg.G + 16), Math.Min(255, bg.B + 16));
            b.MouseLeave += (s, e) => b.BackColor = bg;
            return b;
        }

        void Tip(Control c, string text)
        {
            if (c != null && !string.IsNullOrEmpty(text)) _tips.SetToolTip(c, text);
        }

        void ScheduleWeekly()
        {
            string message = Local(_english, "Criar limpeza automática?\n\n• Domingo às 10:00\n• Somente Limpeza Segura\n• Não altera DNS/energia", "Create automatic cleanup?\n\n• Sunday at 10:00 AM\n• Safe Cleanup only\n• Does not change DNS/power settings");
            if (MessageBox.Show(message, Local(_english, "Agendar", "Schedule"), MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
            RunCli("-Mode schedule -AutoYes");
        }

        void OpenLogsFolder()
        {
            try
            {
                if (!Directory.Exists(_logsDir)) Directory.CreateDirectory(_logsDir);
                Process.Start("explorer.exe", _logsDir);
                LogLine(Local(_english, "Abrindo registros: ", "Opening logs: ") + _logsDir);
            }
            catch (Exception ex) { MessageBox.Show(ex.Message, "Logs"); }
        }

        void CancelRun()
        {
            _cancelRequested = true;
            try { File.WriteAllText(_cancelFile, "1"); } catch { }
            _taskLabel.Text = Local(_english, "Cancelando (aguardando a etapa atual)...", "Cancelling (waiting for the current step)...");
            _pctLabel.ForeColor = Warn;
            LogLine(Local(_english, "Cancelamento seguro solicitado.", "Safe cancellation requested."));
        }

        void RefreshHealthAsync()
        {
            ThreadPool.QueueUserWorkItem(_ =>
            {
                try
                {
                    var cli = Path.Combine(_root, "PC-Otimizador-CLI.ps1");
                    if (!File.Exists(cli)) return;
                    var psi = new ProcessStartInfo
                    {
                        FileName = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe"),
                        Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + cli + "\" -Mode health -AutoYes -StreamProgress",
                        WorkingDirectory = _root,
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = false,
                        CreateNoWindow = true,
                        StandardOutputEncoding = Encoding.UTF8
                    };
                    using (var p = Process.Start(psi))
                    {
                        string line;
                        while ((line = p.StandardOutput.ReadLine()) != null)
                        {
                            if (line.StartsWith("##HEALTH##|"))
                            {
                                var parts = line.Substring("##HEALTH##|".Length).Split('|');
                                if (parts.Length >= 1)
                                {
                                    int.TryParse(parts[0], out _healthScore);
                                    string grade = parts.Length > 1 ? parts[1] : "";
                                    BeginInvoke(new Action(() => { if (!IsDisposed && IsHandleCreated) _healthLabel.Text = T("health.caption") + "\n" + _healthScore + "/100" + (grade != "" ? "  (" + grade + ")" : ""); }));
                                }
                            }
                        }
                        p.WaitForExit(60000);
                    }
                }
                catch { }
            });
        }

        void RunPreset(string name, bool highRisk)
        {
            if (name == "safe" || name == "notebook" || name == "full") HighlightNav("limpeza");
            else if (name == "gamer") HighlightNav("desempenho");
            else if (name == "net") HighlightNav("internet");
            ShowPage("inicio");
            string explain = PresetExplain(name);
            string msg = explain + "\n\n" + Local(_english, "Executar '" + name + "'", "Run '" + name + "'") + (_dry.Checked ? " (" + T("dryrun") + ")" : "") + "?";
            if (highRisk && !_dry.Checked)
            {
                if (MessageBox.Show(Local(_english, "ATENÇÃO — pode alterar DNS / IP / energia\n\n", "WARNING — may change DNS / IP / power settings\n\n") + explain + "\n\n" + Local(_english, "Continuar?", "Continue?"), Local(_english, "Confirmar RISCO", "Confirm RISK"), MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes) return;
            }
            else if (MessageBox.Show(msg, Local(_english, "Confirmar", "Confirm"), MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
            var args = "-Preset " + name + " -AutoYes -StreamProgress";
            if (_dry.Checked) args += " -DryRun";
            if (highRisk && !_dry.Checked) args += " -AllowHighRisk";
            RunCli(args);
        }

        string PresetExplain(string name)
        {
            if (_english)
            {
                switch (name)
                {
                    case "safe": return "Safe Cleanup: temporary files, caches and TRIM.\nDoes not empty the Recycle Bin or change DNS/power settings.";
                    case "gamer": return "Gaming Turbo: cleanup, high performance and optional DNS/network adjustments.";
                    case "net": return "Network: flushes DNS/ARP and may renew IP and use Cloudflare DNS.";
                    case "notebook": return "Laptop: safe cleanup and balanced power plan.";
                    case "full": return "Full: broad cleanup including CleanMgr, Recycle Bin and app/browser caches.";
                    default: return "Profile: " + name;
                }
            }
            switch (name)
            {
                case "safe": return "Limpeza Segura: temporários, caches e TRIM.\nNão esvazia a Lixeira nem mexe em DNS/energia.";
                case "gamer": return "Turbo/Gamer: limpeza + alto desempenho + possíveis ajustes de DNS/rede.";
                case "net": return "Internet: flush DNS/ARP; pode renovar IP e DNS Cloudflare.";
                case "notebook": return "Notebook: limpeza segura + plano equilibrado (bateria).";
                case "full": return "Completo: limpeza ampla incluindo CleanMgr, lixeira e caches de apps/navegador.";
                default: return "Perfil: " + name;
            }
        }

        void RunCli(string extraArgs)
        {
            if (_running) return;
            if (!string.Equals(_activeNav, "inicio", StringComparison.OrdinalIgnoreCase)) ShowPage("inicio");
            var cli = Path.Combine(_root, "PC-Otimizador-CLI.ps1");
            var engine = Path.Combine(_root, "Engine.ps1");
            var presets = Path.Combine(_root, "core", "presets.json");
            if (!File.Exists(cli) || !File.Exists(engine))
            {
                MessageBox.Show(Local(_english, "Faltam arquivos obrigatórios na pasta do programa:\nPC-Otimizador-CLI.ps1 e Engine.ps1\n\nExtraia o ZIP completo da versão publicada.", "Required files are missing from the program folder:\nPC-Otimizador-CLI.ps1 and Engine.ps1\n\nExtract the complete release ZIP."), Local(_english, "Arquivo ausente", "Missing file"), MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            if (!File.Exists(presets)) LogLine("Aviso: core/presets.json ausente — usando fallback do Engine.");
            try { if (File.Exists(_cancelFile)) File.Delete(_cancelFile); } catch { }
            _running = true;
            _cancelRequested = false;
            _btnCancel.Enabled = true;
            _btnCancel.Visible = true;
            _bar.Value = 0;
            _pctLabel.Text = "0%";
            _pctLabel.ForeColor = Accent;
            _taskLabel.Text = T("task.starting");
            _beforeAfter.Text = T("stats.running");
            LogLine("Início: " + extraArgs);
            var psi = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe"),
                Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + cli + "\" " + extraArgs,
                WorkingDirectory = _root,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
                StandardOutputEncoding = Encoding.UTF8
            };
            ThreadPool.QueueUserWorkItem(_ =>
            {
                try
                {
                    _proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
                    _proc.OutputDataReceived += (s, e) => { if (e.Data != null) BeginInvoke(new Action(() => HandleLine(e.Data))); };
                    _proc.ErrorDataReceived += (s, e) => { if (e.Data != null) BeginInvoke(new Action(() => LogLine("ERR " + e.Data))); };
                    _proc.Start();
                    _proc.BeginOutputReadLine(); _proc.BeginErrorReadLine(); _proc.WaitForExit();
                    int exitCode = _proc.ExitCode;
                    BeginInvoke(new Action(() =>
                    {
                        if (IsDisposed || !IsHandleCreated) return;
                        _running = false; _btnCancel.Enabled = false; _btnCancel.Visible = false;
                        if (_cancelRequested)
                        {
                            _taskLabel.Text = Local(_english, "Cancelado", "Cancelled"); _pctLabel.ForeColor = Warn; LogLine(Local(_english, "Execução cancelada pelo usuário.", "Run cancelled by the user."));
                        }
                        else if (exitCode != 0)
                        {
                            _taskLabel.Text = Local(_english, "Falhou (código ", "Failed (code ") + exitCode + ")"; _pctLabel.ForeColor = Danger; LogLine(Local(_english, "A linha de comando terminou com código ", "Command line finished with code ") + exitCode + ".");
                            MessageBox.Show(Local(_english, "A operação não foi concluída. Consulte o registro para detalhes.", "The operation did not complete. Check the log for details."), T("app.title"), MessageBoxButtons.OK, MessageBoxIcon.Error);
                        }
                        else
                        {
                            if (_bar.Value < 100) _bar.Value = 100;
                            _pctLabel.Text = "100%"; _taskLabel.Text = Local(_english, "Concluído", "Completed"); _pctLabel.ForeColor = Accent;
                        }
                        HighlightNav("inicio");
                    }));
                }
                catch (Exception ex)
                {
                    BeginInvoke(new Action(() => { _running = false; _btnCancel.Enabled = false; _btnCancel.Visible = false; LogLine(ex.Message); MessageBox.Show(ex.Message + Local(_english, "\n\nSe o antivírus bloqueou, use Executar.bat.", "\n\nIf antivirus blocked the app, use Executar.bat."), Local(_english, "Erro", "Error")); }));
                }
            });
        }

        void HandleLine(string line)
        {
            if (string.IsNullOrEmpty(line)) return;
            if (line.StartsWith("##PROGRESS##|"))
            {
                var p = line.Split('|');
                if (p.Length >= 5)
                {
                    int cur, total, pct;
                    int.TryParse(p[1], out cur); int.TryParse(p[2], out total); int.TryParse(p[4], out pct);
                    _bar.Value = Math.Max(0, Math.Min(100, pct)); _pctLabel.Text = _bar.Value + "%"; _taskLabel.Text = string.Format("[{0}/{1}] {2}", cur, total, p[3]);
                }
                return;
            }
            if (line.StartsWith("##LOG##|"))
            {
                var p = line.Split(new[] { '|' }, 3); if (p.Length >= 3) LogLine(p[2]); return;
            }
            if (line.StartsWith("##RESULT##|BEFORE|"))
            {
                var p = line.Split('|');
                if (p.Length >= 6)
                {
                    _diskFree = p[2]; _diskTot = p[3];
                    _beforeAfter.Text = Local(_english, "ANTES   " + p[2] + " GB\nlivres de " + p[3] + " GB   ·   RAM ", "BEFORE   " + p[2] + " GB\nfree of " + p[3] + " GB   ·   RAM ") + p[4] + "/" + p[5] + " GB";
                }
                return;
            }
            if (line.StartsWith("##RESULT##|AFTER|"))
            {
                var p = line.Split('|');
                if (p.Length >= 8)
                {
                    string freed = p[6]; string score = p.Length > 8 ? p[8] : "—";
                    _beforeAfter.Text = Local(_english, "ANTES   " + _diskFree + " GB   →   DEPOIS   " + p[2] + " GB\n" + (_dry.Checked ? "Estimado ~" : "Liberado ~"), "BEFORE   " + _diskFree + " GB   →   AFTER   " + p[2] + " GB\n" + (_dry.Checked ? "Estimated ~" : "Freed ~")) + freed + " MB   ·   RAM " + p[4] + "/" + p[5] + " GB";
                    _healthLabel.Text = T("health.caption") + "\n" + score + "/100"; LogLine(Local(_english, _dry.Checked ? "Estimativa: ~" : "Resultado: +", _dry.Checked ? "Estimate: ~" : "Result: +") + freed + " MB | " + T("health.caption") + " " + score);
                }
                return;
            }
            if (line.StartsWith("##HEALTH##|"))
            {
                var parts = line.Substring("##HEALTH##|".Length).Split('|');
                if (parts.Length >= 1) { _healthLabel.Text = T("health.caption") + "\n" + parts[0] + "/100" + (parts.Length > 1 ? "  (" + parts[1] + ")" : ""); _beforeAfter.Text = Local(_english, "SAÚDE DO SISTEMA\n", "SYSTEM HEALTH\n") + string.Join("  ·  ", parts); }
                return;
            }
            if (line.StartsWith("##DONE##|"))
            {
                string status = line.Substring(9); LogLine("Status: " + status);
                if (status.IndexOf("CANCEL", StringComparison.OrdinalIgnoreCase) >= 0) { _cancelRequested = true; _taskLabel.Text = Local(_english, "Cancelado", "Cancelled"); _pctLabel.ForeColor = Warn; }
                return;
            }
            LogLine(line);
        }

        void LogLine(string msg)
        {
            if (_statusLabel != null) _statusLabel.Text = "[" + DateTime.Now.ToString("HH:mm:ss") + "] " + (_english ? T("status.activity") : msg);
            try
            {
                if (!Directory.Exists(_logsDir)) Directory.CreateDirectory(_logsDir);
                File.AppendAllText(Path.Combine(_logsDir, "gui-live.txt"), DateTime.Now.ToString("HH:mm:ss") + " " + msg + Environment.NewLine, Encoding.UTF8);
            }
            catch { }
        }
    }
}
