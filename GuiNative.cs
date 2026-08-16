using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace PCOtimizador
{
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
        public int Radius = 12;
        public Color BorderColor = Color.FromArgb(40, 60, 90);
        public int BorderWidth = 1;

        public RoundPanel()
        {
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            var rect = new Rectangle(0, 0, Width - 1, Height - 1);
            using (var path = RoundRect(rect, Radius))
            using (var brush = new SolidBrush(BackColor))
            using (var pen = new Pen(BorderColor, BorderWidth))
            {
                e.Graphics.FillPath(brush, path);
                e.Graphics.DrawPath(pen, path);
            }
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            using (var path = RoundRect(new Rectangle(0, 0, Width, Height), Radius))
            {
                Region = new Region(path);
            }
        }

        static GraphicsPath RoundRect(Rectangle r, int radius)
        {
            int d = radius * 2;
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

    public class MainForm : Form
    {
        readonly string _root;
        readonly string _cancelFile;
        readonly string _logsDir;
        readonly ToolTip _tips;

        Panel _sidebar;
        Panel _content;
        Label _pctLabel;
        Label _taskLabel;
        Label _statusLabel;
        Label _beforeAfter;
        Label _healthLabel;
        Label _heroSub;
        Label _protectDot;
        ProgressBar _bar;
        CheckBox _dry;
        Button _btnCancel;
        TextBox _log;
        readonly List<Button> _navBtns = new List<Button>();
        readonly Dictionary<string, Panel> _pages = new Dictionary<string, Panel>(StringComparer.OrdinalIgnoreCase);

        Process _proc;
        bool _running;
        bool _cancelRequested;
        string _activeNav = "inicio";
        int _healthScore = 0;
        string _diskFree = "—";
        string _diskTot = "—";

        static readonly Color Bg = Color.FromArgb(6, 8, 14);
        static readonly Color PanelBg = Color.FromArgb(10, 14, 22);
        static readonly Color Card = Color.FromArgb(16, 22, 36);
        static readonly Color CardHi = Color.FromArgb(22, 32, 52);
        static readonly Color Border = Color.FromArgb(40, 60, 90);
        static readonly Color Accent = Color.FromArgb(0, 229, 192);
        static readonly Color Accent2 = Color.FromArgb(56, 189, 248);
        static readonly Color Warn = Color.FromArgb(251, 191, 36);
        static readonly Color Danger = Color.FromArgb(248, 113, 113);
        static readonly Color TextMain = Color.FromArgb(241, 245, 249);
        static readonly Color Muted = Color.FromArgb(100, 116, 139);
        static readonly Color Ok = Color.FromArgb(52, 211, 153);

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

            Text = "PC Otimizador Pro";
            Size = new Size(1120, 740);
            MinimumSize = new Size(980, 680);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.Sizable;
            MaximizeBox = true;
            BackColor = Bg;
            ForeColor = TextMain;
            Font = new Font("Segoe UI", 9.5f);
            AutoScaleMode = AutoScaleMode.Dpi;
            DoubleBuffered = true;

            _sidebar = new Panel
            {
                Dock = DockStyle.Left,
                Width = 220,
                BackColor = PanelBg,
                Padding = new Padding(0)
            };
            Controls.Add(_sidebar);
            BuildSidebar();

            _content = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Bg,
                Padding = new Padding(28, 20, 28, 20)
            };
            Controls.Add(_content);

            // Shared chrome (always visible under pages)
            var header = new Label
            {
                Text = "PC  OTIMIZADOR  PRO",
                Font = new Font("Segoe UI Semibold", 18f),
                ForeColor = Accent,
                Location = new Point(28, 18),
                AutoSize = true
            };
            _content.Controls.Add(header);

            _heroSub = new Label
            {
                Text = "Dashboard · Limpeza segura · Nunca apaga Documentos/Fotos/Downloads",
                Location = new Point(30, 54),
                Size = new Size(700, 22),
                ForeColor = Muted
            };
            _content.Controls.Add(_heroSub);

            _dry = new CheckBox
            {
                Text = "Dry-run (simular)",
                Location = new Point(760, 22),
                AutoSize = true,
                ForeColor = Warn,
                Anchor = AnchorStyles.Top | AnchorStyles.Right
            };
            _content.Controls.Add(_dry);
            Tip(_dry, "Simula a limpeza sem apagar nada. Ideal na primeira vez.");

            // Progress block
            var progressBox = MakeCard(28, 390, 820, 110);
            progressBox.Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom;
            _content.Controls.Add(progressBox);

            _pctLabel = new Label
            {
                Text = "0%",
                Font = new Font("Segoe UI Semibold", 28f),
                ForeColor = Accent,
                Location = new Point(18, 14),
                AutoSize = true
            };
            progressBox.Controls.Add(_pctLabel);

            _bar = new ProgressBar
            {
                Location = new Point(18, 58),
                Size = new Size(680, 14),
                Minimum = 0,
                Maximum = 100,
                Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top
            };
            progressBox.Controls.Add(_bar);

            _taskLabel = new Label
            {
                Text = "Pronto — escolha um perfil acima",
                Location = new Point(18, 80),
                Size = new Size(680, 20),
                ForeColor = Accent,
                Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top
            };
            progressBox.Controls.Add(_taskLabel);

            _btnCancel = FlatBtn(720, 20, 80, 32, "Parar", Danger);
            _btnCancel.Enabled = false;
            _btnCancel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            _btnCancel.Click += (s, e) => CancelRun();
            progressBox.Controls.Add(_btnCancel);
            Tip(_btnCancel, "Cancela a execução em andamento.");

            // Stats block
            var stats = MakeCard(28, 512, 820, 90);
            stats.Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom;
            _content.Controls.Add(stats);

            _beforeAfter = new Label
            {
                Text = "Disco  — GB livres\nRode um perfil para ver antes → depois",
                Location = new Point(18, 16),
                Size = new Size(420, 56),
                ForeColor = TextMain,
                Font = new Font("Segoe UI", 10f)
            };
            stats.Controls.Add(_beforeAfter);

            var sep = new Panel
            {
                Location = new Point(460, 16),
                Size = new Size(1, 58),
                BackColor = Border
            };
            stats.Controls.Add(sep);

            _healthLabel = new Label
            {
                Text = "Health\n—/100",
                Location = new Point(490, 16),
                Size = new Size(280, 56),
                ForeColor = Accent,
                Font = new Font("Segoe UI Semibold", 14f)
            };
            stats.Controls.Add(_healthLabel);
            Tip(_healthLabel, "Nota de saúde 0–100 (disco, RAM, lixo recuperável).");

            // Log strip
            _log = new TextBox
            {
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Location = new Point(860, 90),
                Size = new Size(0, 0),
                Visible = false
            };
            // Keep a compact log under stats via status label instead of huge console on home
            _statusLabel = new Label
            {
                Text = "",
                Location = new Point(28, 610),
                Size = new Size(820, 40),
                ForeColor = Muted,
                Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom
            };
            _content.Controls.Add(_statusLabel);

            BuildPageInicio();
            BuildPageFerramentas();
            BuildPageAjuda();
            ShowPage("inicio");
            HighlightNav("inicio");

            Shown += (s, e) =>
            {
                CheckMandatoryUpdate();
                if (IsDisposed) return;
                RefreshHealthAsync();
            };
            LogLine("Verifica atualizacao no GitHub ao abrir. Passe o mouse nos cards.");
        }

        void CheckMandatoryUpdate()
        {
            var upd = Path.Combine(_root, "Update.ps1");
            if (!File.Exists(upd))
            {
                LogLine("Update.ps1 ausente — sem auto-update nesta pasta.");
                return;
            }

            _taskLabel.Text = "Verificando atualizacoes...";
            _statusLabel.Text = "Consultando GitHub Releases (obrigatorio)...";
            Application.DoEvents();

            try
            {
                string relaunch = Path.Combine(_root, "PC-Otimizador.exe");
                if (!File.Exists(relaunch))
                    relaunch = Path.Combine(_root, "Executar.bat");

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
                        if (line.StartsWith("##UPDATE##|"))
                            LogLine(line.Substring("##UPDATE##|".Length));
                        else if (!string.IsNullOrWhiteSpace(line))
                            LogLine(line.Trim());
                        Application.DoEvents();
                    }
                    p.WaitForExit(300000);
                    int code = p.ExitCode;
                    if (code == 10)
                    {
                        MessageBox.Show(
                            "Nova versao encontrada.\nO programa vai fechar e atualizar sozinho.\nDepois reabre automaticamente.",
                            "Atualizacao obrigatoria",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Information);
                        Application.Exit();
                        return;
                    }
                    if (code == 2)
                    {
                        MessageBox.Show(
                            "Falha na atualizacao obrigatoria.\nVerifique a internet e tente de novo.\n\n" +
                            "https://github.com/leonardolauriquer/PC-Otimizador/releases",
                            "Atualizacao",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Error);
                        Application.Exit();
                        return;
                    }
                    _taskLabel.Text = "Pronto — escolha um perfil acima";
                }
            }
            catch (Exception ex)
            {
                LogLine("Update check: " + ex.Message);
                _taskLabel.Text = "Pronto (update offline?)";
            }
        }

        void BuildSidebar()
        {
            var brand = new Label
            {
                Text = "  ◈  PC OTIMIZADOR",
                Font = new Font("Segoe UI Semibold", 11f),
                ForeColor = Accent,
                Location = new Point(12, 22),
                Size = new Size(196, 28)
            };
            _sidebar.Controls.Add(brand);

            int y = 70;
            AddNav("inicio", "INÍCIO", y, () => ShowPage("inicio")); y += 48;
            AddNav("limpeza", "LIMPEZA", y, () => ShowPage("inicio")); y += 48;
            AddNav("desempenho", "DESEMPENHO", y, () => ShowPage("inicio")); y += 48;
            AddNav("internet", "INTERNET", y, () => ShowPage("inicio")); y += 48;
            AddNav("ferramentas", "FERRAMENTAS", y, () => ShowPage("ferramentas")); y += 48;
            AddNav("ajuda", "AJUDA", y, () => ShowPage("ajuda")); y += 48;

            var protect = new RoundPanel
            {
                Location = new Point(16, 620),
                Size = new Size(188, 56),
                BackColor = Card,
                BorderColor = Border,
                Anchor = AnchorStyles.Bottom | AnchorStyles.Left
            };
            _sidebar.Controls.Add(protect);

            _protectDot = new Label
            {
                Text = "●",
                ForeColor = Ok,
                Location = new Point(12, 16),
                AutoSize = true,
                Font = new Font("Segoe UI", 12f)
            };
            protect.Controls.Add(_protectDot);

            var protLbl = new Label
            {
                Text = "PROTEÇÃO ATIVA\nWhitelist ligada",
                ForeColor = TextMain,
                Location = new Point(36, 12),
                Size = new Size(140, 36),
                Font = new Font("Segoe UI", 8.5f)
            };
            protect.Controls.Add(protLbl);
            Tip(protect, "Documentos, Fotos, Downloads, Desktop, Música e OneDrive estão protegidos.");
        }

        void AddNav(string key, string text, int y, Action act)
        {
            var b = new Button
            {
                Text = "  " + text,
                Tag = key,
                Location = new Point(12, y),
                Size = new Size(196, 40),
                FlatStyle = FlatStyle.Flat,
                BackColor = PanelBg,
                ForeColor = Muted,
                Font = new Font("Segoe UI Semibold", 9.5f),
                TextAlign = ContentAlignment.MiddleLeft,
                Cursor = Cursors.Hand
            };
            b.FlatAppearance.BorderSize = 1;
            b.FlatAppearance.BorderColor = PanelBg;
            b.Click += (s, e) =>
            {
                HighlightNav(key);
                act();
            };
            _sidebar.Controls.Add(b);
            _navBtns.Add(b);
        }

        void HighlightNav(string key)
        {
            _activeNav = key;
            foreach (var b in _navBtns)
            {
                bool on = string.Equals((string)b.Tag, key, StringComparison.OrdinalIgnoreCase)
                          || (key == "inicio" && (string)b.Tag == "inicio");
                // keep limpeza/desempenho/internet highlighted only when that nav key matches
                on = string.Equals((string)b.Tag, key, StringComparison.OrdinalIgnoreCase);
                b.ForeColor = on ? Accent : Muted;
                b.BackColor = on ? Card : PanelBg;
                b.FlatAppearance.BorderColor = on ? Accent : PanelBg;
            }
        }

        void BuildPageInicio()
        {
            var page = new Panel
            {
                Location = new Point(28, 88),
                Size = new Size(820, 290),
                BackColor = Bg,
                Name = "page_inicio"
            };
            _content.Controls.Add(page);
            _pages["inicio"] = page;

            page.Controls.Add(MakePresetCard(0, 0, 190, 150,
                "LIMPEZA SEGURA", "Ideal para manter o PC limpo e protegido.", "SAFE", Accent,
                () => RunPreset("safe", false),
                "Recomendado. Temp e caches regeneráveis. Não esvazia a Lixeira."));

            page.Controls.Add(MakePresetCard(206, 0, 190, 150,
                "TURBO GAMER", "Máximo desempenho para jogos e tarefas pesadas.", "RISK", Danger,
                () => RunPreset("gamer", true),
                "Pode ativar Alto Desempenho e DNS Cloudflare."));

            page.Controls.Add(MakePresetCard(412, 0, 190, 150,
                "INTERNET", "Otimiza conexão e melhora a navegação.", "RISK", Warn,
                () => RunPreset("net", true),
                "Flush DNS/ARP; pode renovar IP e DNS Cloudflare."));

            page.Controls.Add(MakePresetCard(618, 0, 190, 150,
                "NOTEBOOK", "Perfil ideal para notebooks e bateria.", "SAFE", Ok,
                () => RunPreset("notebook", false),
                "Limpeza segura + plano de energia equilibrado."));

            var row2 = new Label
            {
                Text = "Atalhos:  Estimar  ·  Completo  ·  Agendar  ·  Whitelist  ·  Abrir logs",
                Location = new Point(0, 170),
                Size = new Size(820, 22),
                ForeColor = Muted
            };
            page.Controls.Add(row2);

            int x = 0;
            page.Controls.Add(SmallAction(ref x, 200, "Estimar", () => RunCli("-Mode scan -AutoYes"), "Só mede quanto espaço liberaria."));
             page.Controls.Add(SmallAction(ref x, 200, "Completo", () => RunPreset("full", true), "Limpeza ampla; inclui ações irreversíveis."));
            page.Controls.Add(SmallAction(ref x, 200, "Agendar", () => ScheduleWeekly(), "Limpeza Segura todo domingo 10h."));
            page.Controls.Add(SmallAction(ref x, 200, "Whitelist", () => RunCli("-Mode whitelist -AutoYes"), "Pastas que nunca serão apagadas."));
            page.Controls.Add(SmallAction(ref x, 200, "Logs", OpenLogsFolder, "Abre Documentos\\PC-Otimizador-Logs."));
            page.Controls.Add(SmallAction(ref x, 200, "Health", () => RunCli("-Mode health -AutoYes"), "Atualiza a nota 0–100."));
        }

        Button SmallAction(ref int x, int y, string text, Action act, string tip)
        {
            var b = FlatBtn(x, y, 120, 34, text, CardHi);
            b.Click += (s, e) => act();
            Tip(b, tip);
            x += 130;
            return b;
        }

        void BuildPageFerramentas()
        {
            var page = new Panel
            {
                Location = new Point(28, 88),
                Size = new Size(820, 290),
                BackColor = Bg,
                Visible = false
            };
            _content.Controls.Add(page);
            _pages["ferramentas"] = page;

            var title = new Label
            {
                Text = "Ferramentas",
                Font = new Font("Segoe UI Semibold", 16f),
                ForeColor = TextMain,
                Location = new Point(0, 0),
                AutoSize = true
            };
            page.Controls.Add(title);

            var info = new Label
            {
                Text = "Ações que só medem ou configuram — sem limpeza agressiva.",
                ForeColor = Muted,
                Location = new Point(0, 36),
                Size = new Size(700, 22)
            };
            page.Controls.Add(info);

            int x = 0, y = 80;
            page.Controls.Add(ToolCard(ref x, y, "Health Score", "Nota 0–100 do PC", () => RunCli("-Mode health -AutoYes")));
            page.Controls.Add(ToolCard(ref x, y, "Estimar MB", "Simula quanto liberaria", () => RunCli("-Mode scan -AutoYes")));
            x = 0; y = 180;
            page.Controls.Add(ToolCard(ref x, y, "Agendar", "Domingo 10h · SAFE", () => ScheduleWeekly()));
            page.Controls.Add(ToolCard(ref x, y, "Abrir logs", "Histórico das sessões", OpenLogsFolder));
        }

        RoundPanel ToolCard(ref int x, int y, string title, string sub, Action act)
        {
            var p = MakeCard(x, y, 250, 80);
            p.Cursor = Cursors.Hand;
            var t = new Label { Text = title, Font = new Font("Segoe UI Semibold", 12f), ForeColor = Accent, Location = new Point(16, 16), AutoSize = true };
            var s = new Label { Text = sub, ForeColor = Muted, Location = new Point(16, 44), AutoSize = true };
            p.Controls.Add(t); p.Controls.Add(s);
            EventHandler click = (o, e) => { if (!_running) act(); };
            p.Click += click; t.Click += click; s.Click += click;
            Tip(p, title + "\n" + sub);
            x += 270;
            return p;
        }

        void BuildPageAjuda()
        {
            var page = new Panel
            {
                Location = new Point(28, 88),
                Size = new Size(820, 290),
                BackColor = Bg,
                Visible = false
            };
            _content.Controls.Add(page);
            _pages["ajuda"] = page;

            var box = MakeCard(0, 0, 820, 270);
            page.Controls.Add(box);

            var help = new Label
            {
                Text =
                    "GUIA RÁPIDO\n\n" +
                    "1. Marque Dry-run e rode Limpeza Segura → vê o que aconteceria.\n" +
                    "2. Desmarque Dry-run e rode de novo para limpar de verdade.\n" +
                    "3. Health / Estimar só medem — não apagam.\n\n" +
                    "SAFE = não muda DNS nem energia.\n" +
                    "RISK = pede confirmação (DNS / IP / alto desempenho).\n\n" +
                    "Nunca apagamos: Documentos, Fotos, Vídeos, Música, Desktop, Downloads, OneDrive.\n" +
                    "Logs: Documentos\\PC-Otimizador-Logs\n\n" +
                    "Na dúvida, use só Limpeza Segura.",
                Location = new Point(20, 16),
                Size = new Size(780, 240),
                ForeColor = TextMain,
                Font = new Font("Segoe UI", 10f)
            };
            box.Controls.Add(help);
        }

        void ShowPage(string name)
        {
            foreach (var kv in _pages)
                kv.Value.Visible = string.Equals(kv.Key, name, StringComparison.OrdinalIgnoreCase);

            if (name == "inicio")
                _heroSub.Text = "Dashboard · Escolha um perfil · Passe o mouse para detalhes";
            else if (name == "ferramentas")
                _heroSub.Text = "Ferramentas · Medir, agendar e abrir logs";
            else
                _heroSub.Text = "Ajuda · Como usar com segurança";
        }

        RoundPanel MakeCard(int x, int y, int w, int h)
        {
            return new RoundPanel
            {
                Location = new Point(x, y),
                Size = new Size(w, h),
                BackColor = Card,
                BorderColor = Border,
                Radius = 12
            };
        }

        RoundPanel MakePresetCard(int x, int y, int w, int h, string title, string sub, string badge, Color accent, Action onClick, string tip)
        {
            var p = MakeCard(x, y, w, h);
            p.Cursor = Cursors.Hand;

            var rail = new Panel { Location = new Point(0, 0), Size = new Size(4, h), BackColor = accent };
            p.Controls.Add(rail);

            var b = new Label
            {
                Text = badge,
                ForeColor = accent,
                Location = new Point(14, 12),
                AutoSize = true,
                Font = new Font("Segoe UI Semibold", 8f)
            };
            var t = new Label
            {
                Text = title,
                ForeColor = TextMain,
                Location = new Point(14, 36),
                Size = new Size(w - 28, 40),
                Font = new Font("Segoe UI Semibold", 11f)
            };
            var s = new Label
            {
                Text = sub,
                ForeColor = Muted,
                Location = new Point(14, 82),
                Size = new Size(w - 28, 40),
                Font = new Font("Segoe UI", 8f)
            };
            var go = new Label
            {
                Text = "Iniciar  →",
                ForeColor = accent,
                Location = new Point(14, h - 28),
                AutoSize = true,
                Font = new Font("Segoe UI Semibold", 9f)
            };
            p.Controls.Add(b); p.Controls.Add(t); p.Controls.Add(s); p.Controls.Add(go);

            EventHandler click = (o, e) => { if (!_running) onClick(); };
            p.Click += click; b.Click += click; t.Click += click; s.Click += click; go.Click += click;
            p.MouseEnter += (o, e) => p.BackColor = CardHi;
            p.MouseLeave += (o, e) => p.BackColor = Card;

            Tip(p, tip);
            Tip(t, tip);
            return p;
        }

        Button FlatBtn(int x, int y, int w, int h, string text, Color bg)
        {
            var b = new Button
            {
                Text = text,
                Location = new Point(x, y),
                Size = new Size(w, h),
                FlatStyle = FlatStyle.Flat,
                BackColor = bg,
                ForeColor = TextMain,
                Font = new Font("Segoe UI Semibold", 9f),
                Cursor = Cursors.Hand
            };
            b.FlatAppearance.BorderSize = 0;
            return b;
        }

        void Tip(Control c, string text)
        {
            if (c != null && !string.IsNullOrEmpty(text))
                _tips.SetToolTip(c, text);
        }

        void ScheduleWeekly()
        {
            if (MessageBox.Show(
                "Criar limpeza automática?\n\n• Domingo às 10:00\n• Só Limpeza Segura (SAFE)\n• Não altera DNS/energia",
                "Agendar", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
                return;
            RunCli("-Mode schedule -AutoYes");
        }

        void OpenLogsFolder()
        {
            try
            {
                if (!Directory.Exists(_logsDir)) Directory.CreateDirectory(_logsDir);
                Process.Start("explorer.exe", _logsDir);
                LogLine("Abrindo logs: " + _logsDir);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "Logs");
            }
        }

        void CancelRun()
        {
            _cancelRequested = true;
            try { File.WriteAllText(_cancelFile, "1"); } catch { }
            // Cooperativo: NÃO matar o processo (senão finally do Engine não reinicia BITS/WU/Explorer).
            _taskLabel.Text = "Cancelando (aguardando etapa atual)...";
            _pctLabel.ForeColor = Warn;
            LogLine("Cancelamento cooperativo solicitado (sem Kill).");
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
                    BeginInvoke(new Action(() =>
                    {
                        if (IsDisposed || !IsHandleCreated) return;
                        _healthLabel.Text = "Health\n" + _healthScore + "/100" + (grade != "" ? "  (" + grade + ")" : "");
                    }));
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
            string msg = explain + "\n\nExecutar '" + name + "'" + (_dry.Checked ? " (DRY-RUN)" : "") + "?";
            if (highRisk && !_dry.Checked)
            {
                if (MessageBox.Show("ATENÇÃO — pode alterar DNS / IP / energia\n\n" + explain + "\n\nContinuar?",
                    "Confirmar RISK", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes)
                    return;
            }
            else if (MessageBox.Show(msg, "Confirmar", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
                return;

            var args = "-Preset " + name + " -AutoYes -StreamProgress";
            if (_dry.Checked) args += " -DryRun";
            if (highRisk && !_dry.Checked) args += " -AllowHighRisk";
            RunCli(args);
        }

        static string PresetExplain(string name)
        {
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
            var cli = Path.Combine(_root, "PC-Otimizador-CLI.ps1");
            var engine = Path.Combine(_root, "Engine.ps1");
            var presets = Path.Combine(_root, "core", "presets.json");
            if (!File.Exists(cli) || !File.Exists(engine))
            {
                MessageBox.Show(
                    "Faltam arquivos obrigatórios na pasta do programa:\n" +
                    "PC-Otimizador-CLI.ps1 e Engine.ps1\n\nExtraia o ZIP completo da Release.",
                    "Arquivo faltando", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            if (!File.Exists(presets))
                LogLine("Aviso: core/presets.json ausente — usando fallback do Engine.");

            try { if (File.Exists(_cancelFile)) File.Delete(_cancelFile); } catch { }

            _running = true;
            _cancelRequested = false;
            _btnCancel.Enabled = true;
            _bar.Value = 0;
            _pctLabel.Text = "0%";
            _pctLabel.ForeColor = Accent;
            _taskLabel.Text = "Iniciando...";
            _beforeAfter.Text = "Em andamento...\nAguarde o progresso.";
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
                    _proc.BeginOutputReadLine();
                    _proc.BeginErrorReadLine();
                    _proc.WaitForExit();
                    int exitCode = _proc.ExitCode;
                    BeginInvoke(new Action(() =>
                    {
                        if (IsDisposed || !IsHandleCreated) return;
                        _running = false;
                        _btnCancel.Enabled = false;
                        bool cancelled = _cancelRequested;
                        if (cancelled)
                        {
                            _taskLabel.Text = "Cancelado";
                            _pctLabel.ForeColor = Warn;
                            LogLine("Execução cancelada pelo usuário.");
                        }
                        else if (exitCode != 0)
                        {
                            _taskLabel.Text = "Falhou (código " + exitCode + ")";
                            _pctLabel.ForeColor = Danger;
                            LogLine("CLI terminou com código " + exitCode + ".");
                            MessageBox.Show("A operação não foi concluída. Consulte o log para detalhes.", "PC Otimizador", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        }
                        else
                        {
                            if (_bar.Value < 100) _bar.Value = 100;
                            _pctLabel.Text = "100%";
                            _taskLabel.Text = "Concluído";
                            _pctLabel.ForeColor = Accent;
                        }
                        HighlightNav("inicio");
                    }));
                }
                catch (Exception ex)
                {
                    BeginInvoke(new Action(() =>
                    {
                        _running = false;
                        _btnCancel.Enabled = false;
                        LogLine(ex.Message);
                        MessageBox.Show(ex.Message + "\n\nSe o antivírus bloqueou, use Executar.bat.", "Erro");
                    }));
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
                    int.TryParse(p[1], out cur);
                    int.TryParse(p[2], out total);
                    int.TryParse(p[4], out pct);
                    pct = Math.Max(0, Math.Min(100, pct));
                    _bar.Value = pct;
                    _pctLabel.Text = pct + "%";
                    _taskLabel.Text = string.Format("[{0}/{1}] {2}", cur, total, p[3]);
                }
                return;
            }
            if (line.StartsWith("##LOG##|"))
            {
                var p = line.Split(new[] { '|' }, 3);
                if (p.Length >= 3) LogLine(p[2]);
                return;
            }
            if (line.StartsWith("##RESULT##|BEFORE|"))
            {
                var p = line.Split('|');
                if (p.Length >= 6)
                {
                    _diskFree = p[2];
                    _diskTot = p[3];
                    _beforeAfter.Text = "ANTES  " + p[2] + " GB livres de " + p[3] + " GB\nRAM " + p[4] + "/" + p[5] + " GB";
                }
                return;
            }
            if (line.StartsWith("##RESULT##|AFTER|"))
            {
                var p = line.Split('|');
                if (p.Length >= 8)
                {
                    string freed = p[6];
                    string score = p.Length > 8 ? p[8] : "—";
                    _beforeAfter.Text =
                        "ANTES  " + _diskFree + " GB  →  DEPOIS  " + p[2] + " GB livres\n" +
                        (_dry.Checked ? "Estimado ~" : "Liberado ~") + freed + " MB   |   RAM " + p[4] + "/" + p[5] + " GB";
                    _healthLabel.Text = "Health\n" + score + "/100";
                    LogLine((_dry.Checked ? "Estimativa: ~" : "Resultado: +") + freed + " MB | Health " + score);
                }
                return;
            }
            if (line.StartsWith("##HEALTH##|"))
            {
                var parts = line.Substring("##HEALTH##|".Length).Split('|');
                if (parts.Length >= 1)
                {
                    _healthLabel.Text = "Health\n" + parts[0] + "/100" + (parts.Length > 1 ? "  (" + parts[1] + ")" : "");
                    _beforeAfter.Text = string.Join("  |  ", parts);
                }
                return;
            }
            if (line.StartsWith("##DONE##|"))
            {
                string status = line.Substring(9);
                LogLine("Status: " + status);
                if (status.IndexOf("CANCEL", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    _cancelRequested = true;
                    _taskLabel.Text = "Cancelado";
                    _pctLabel.ForeColor = Warn;
                }
                return;
            }
            LogLine(line);
        }

        void LogLine(string msg)
        {
            _statusLabel.Text = "[" + DateTime.Now.ToString("HH:mm:ss") + "] " + msg;
            try
            {
                if (!Directory.Exists(_logsDir)) Directory.CreateDirectory(_logsDir);
                File.AppendAllText(Path.Combine(_logsDir, "gui-live.txt"),
                    DateTime.Now.ToString("HH:mm:ss") + " " + msg + Environment.NewLine, Encoding.UTF8);
            }
            catch { }
        }
    }
}
