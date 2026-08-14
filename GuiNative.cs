using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
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

    public class MainForm : Form
    {
        readonly string _root;
        readonly string _cancelFile;
        readonly TextBox _log;
        readonly Label _status;
        readonly Label _task;
        readonly Label _result;
        readonly Label _title;
        readonly CheckBox _dry;
        readonly ProgressBar _bar;
        readonly Button _btnCancel;
        readonly List<Control> _themeables = new List<Control>();
        readonly List<Panel> _cards = new List<Panel>();
        readonly List<Button> _actionBtns = new List<Button>();
        Process _proc;
        bool _light;
        bool _running;

        static readonly Color DarkBg = Color.FromArgb(6, 8, 14);
        static readonly Color DarkCard = Color.FromArgb(16, 22, 36);
        static readonly Color DarkMuted = Color.FromArgb(100, 116, 139);
        static readonly Color Accent = Color.FromArgb(0, 229, 192);
        static readonly Color LightBg = Color.FromArgb(245, 247, 250);
        static readonly Color LightCard = Color.FromArgb(255, 255, 255);
        static readonly Color LightMuted = Color.FromArgb(71, 85, 105);

        public MainForm()
        {
            _root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
            _cancelFile = Path.Combine(Path.GetTempPath(), "pc-otimizador-cancel.flag");
            Text = "PC Otimizador Pro v5.3";
            Size = new Size(980, 740);
            MinimumSize = new Size(900, 640);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.Sizable;
            MaximizeBox = true;
            BackColor = DarkBg;
            ForeColor = Color.FromArgb(241, 245, 249);
            Font = new Font("Segoe UI", 9.5f);
            AutoScaleMode = AutoScaleMode.Dpi;

            _title = new Label
            {
                Text = "◈  PC OTIMIZADOR PRO",
                Font = new Font("Segoe UI Semibold", 16f),
                ForeColor = Accent,
                Location = new Point(24, 16),
                AutoSize = true
            };
            Controls.Add(_title);

            _status = new Label
            {
                Text = "Escolha um perfil. Badges: SAFE / RISK. Progresso ao vivo · Cancelar · Antes/depois.",
                Location = new Point(26, 52),
                Size = new Size(920, 22),
                ForeColor = DarkMuted
            };
            Controls.Add(_status);

            _dry = new CheckBox
            {
                Text = "Dry-run (simular)",
                Location = new Point(26, 80),
                AutoSize = true,
                ForeColor = Color.FromArgb(251, 191, 36)
            };
            Controls.Add(_dry);

            int y = 115;
            _cards.Add(MakeCard(24, y, 220, 108, "Limpeza Segura", "SAFE", "Sem DNS/energia", Color.FromArgb(0, 229, 192), () => RunPreset("safe", false)));
            _cards.Add(MakeCard(256, y, 220, 108, "Turbo / Gamer", "RISK", "DNS + alto desempenho", Color.FromArgb(248, 113, 113), () => RunPreset("gamer", true)));
            _cards.Add(MakeCard(488, y, 220, 108, "Internet", "RISK", "DNS Cloudflare + IP", Color.FromArgb(251, 191, 36), () => RunPreset("net", true)));
            _cards.Add(MakeCard(720, y, 220, 108, "Notebook", "SAFE", "Plano equilibrado", Color.FromArgb(52, 211, 153), () => RunPreset("notebook", false)));
            foreach (var c in _cards) Controls.Add(c);

            y = 240;
            AddActionBtn(24, y, 150, "Health Score", () => RunCli("-Mode health -AutoYes"));
            AddActionBtn(186, y, 130, "Estimar", () => RunCli("-Mode scan -AutoYes"));
            AddActionBtn(328, y, 130, "Completo", () => RunPreset("full", false));
            AddActionBtn(470, y, 150, "Agendar", () => RunCli("-Mode schedule -AutoYes"));
            AddActionBtn(632, y, 130, "Whitelist", () => RunCli("-Mode whitelist -AutoYes"));
            AddActionBtn(774, y, 120, "Tema", ToggleTheme);

            y = 290;
            _task = new Label
            {
                Text = "Pronto",
                Location = new Point(26, y),
                Size = new Size(700, 22),
                ForeColor = Accent,
                Font = new Font("Segoe UI Semibold", 10f)
            };
            Controls.Add(_task);

            _btnCancel = MakeBtn(780, y - 4, 140, 32, "Cancelar", Color.FromArgb(127, 29, 29));
            _btnCancel.Enabled = false;
            _btnCancel.Click += (s, e) =>
            {
                try { File.WriteAllText(_cancelFile, "1"); } catch { }
                try
                {
                    if (_proc != null && !_proc.HasExited)
                        _proc.Kill();
                }
                catch { }
                _task.Text = "Cancelando...";
                Log("Cancelamento solicitado (flag + kill processo).");
            };
            Controls.Add(_btnCancel);

            _bar = new ProgressBar
            {
                Location = new Point(24, 322),
                Size = new Size(896, 18),
                Minimum = 0,
                Maximum = 100
            };
            Controls.Add(_bar);

            _result = new Label
            {
                Text = "Resumo antes/depois aparece aqui após a execução.",
                Location = new Point(24, 350),
                Size = new Size(896, 70),
                BackColor = DarkCard,
                ForeColor = Color.White,
                Padding = new Padding(12),
                Font = new Font("Segoe UI", 10f)
            };
            Controls.Add(_result);
            _themeables.Add(_result);

            _log = new TextBox
            {
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Location = new Point(24, 430),
                Size = new Size(896, 250),
                BackColor = Color.FromArgb(4, 6, 10),
                ForeColor = Color.FromArgb(110, 231, 183),
                Font = new Font("Consolas", 8.5f),
                BorderStyle = BorderStyle.FixedSingle,
                Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right
            };
            Controls.Add(_log);

            Log("v5.3: core/presets.json, whitelist boundary, risk badges, DPI, SHA256 release.");
        }

        void AddActionBtn(int x, int y, int w, string text, Action act)
        {
            var b = MakeBtn(x, y, w, 36, text, Color.FromArgb(30, 41, 59));
            b.Click += (s, e) => act();
            Controls.Add(b);
            _actionBtns.Add(b);
        }

        Panel MakeCard(int x, int y, int w, int h, string title, string badge, string riskHint, Color accent, Action onClick)
        {
            var p = new Panel { Location = new Point(x, y), Size = new Size(w, h), BackColor = DarkCard, Cursor = Cursors.Hand };
            p.Controls.Add(new Panel { Location = new Point(0, 0), Size = new Size(4, h), BackColor = accent, Name = "rail" });
            var b = new Label { Text = badge, ForeColor = accent, Location = new Point(14, 10), AutoSize = true, Font = new Font("Segoe UI Semibold", 8f), Name = "badge" };
            var t = new Label { Text = title, ForeColor = Color.White, Location = new Point(14, 32), Size = new Size(w - 24, 28), Font = new Font("Segoe UI Semibold", 12f), Name = "title" };
            var hint = new Label { Text = riskHint, ForeColor = DarkMuted, Location = new Point(14, 62), Size = new Size(w - 24, 20), Font = new Font("Segoe UI", 8f), Name = "hint" };
            var go = new Label { Text = "Iniciar →", ForeColor = accent, Location = new Point(14, h - 26), AutoSize = true, Name = "go" };
            p.Controls.Add(b); p.Controls.Add(t); p.Controls.Add(hint); p.Controls.Add(go);
            EventHandler click = (s, e) => { if (!_running) onClick(); };
            p.Click += click; t.Click += click; b.Click += click; go.Click += click; hint.Click += click;
            return p;
        }

        Button MakeBtn(int x, int y, int w, int h, string text, Color bg)
        {
            var b = new Button
            {
                Text = text,
                Location = new Point(x, y),
                Size = new Size(w, h),
                FlatStyle = FlatStyle.Flat,
                BackColor = bg,
                ForeColor = Color.White,
                Font = new Font("Segoe UI Semibold", 9f)
            };
            b.FlatAppearance.BorderSize = 0;
            return b;
        }

        void ToggleTheme()
        {
            _light = !_light;
            BackColor = _light ? LightBg : DarkBg;
            ForeColor = _light ? Color.FromArgb(15, 23, 42) : Color.FromArgb(241, 245, 249);
            _title.ForeColor = _light ? Color.FromArgb(15, 118, 110) : Accent;
            _status.ForeColor = _light ? LightMuted : DarkMuted;
            _task.ForeColor = _light ? Color.FromArgb(15, 118, 110) : Accent;
            _log.BackColor = _light ? Color.White : Color.FromArgb(4, 6, 10);
            _log.ForeColor = _light ? Color.FromArgb(15, 23, 42) : Color.FromArgb(110, 231, 183);
            _result.BackColor = _light ? Color.FromArgb(226, 232, 240) : DarkCard;
            _result.ForeColor = _light ? Color.FromArgb(15, 23, 42) : Color.White;
            foreach (var card in _cards)
            {
                card.BackColor = _light ? LightCard : DarkCard;
                foreach (Control c in card.Controls)
                {
                    if (c.Name == "title") c.ForeColor = _light ? Color.FromArgb(15, 23, 42) : Color.White;
                    if (c.Name == "hint") c.ForeColor = _light ? LightMuted : DarkMuted;
                }
            }
            foreach (var b in _actionBtns)
            {
                if (b == _btnCancel) continue;
                b.BackColor = _light ? Color.FromArgb(51, 65, 85) : Color.FromArgb(30, 41, 59);
                b.ForeColor = Color.White;
            }
        }

        void RunPreset(string name, bool highRisk)
        {
            string msg = "Executar perfil '" + name + "'" + (_dry.Checked ? " (DRY-RUN)" : "") + "?";
            if (highRisk && !_dry.Checked)
            {
                msg = "ATENÇÃO: o perfil '" + name + "' pode alterar DNS e/ou plano de energia / renovar IP.\n\nContinuar?";
                if (MessageBox.Show(msg, "Confirmar alto risco", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes)
                    return;
            }
            else if (MessageBox.Show(msg, "Confirmar", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
            {
                return;
            }

            var args = "-Preset " + name + " -AutoYes -StreamProgress";
            if (_dry.Checked) args += " -DryRun";
            if (highRisk && !_dry.Checked) args += " -AllowHighRisk";
            RunCli(args);
        }

        void RunCli(string extraArgs)
        {
            if (_running) return;
            var cli = Path.Combine(_root, "PC-Otimizador-CLI.ps1");
            if (!File.Exists(cli))
            {
                MessageBox.Show("Falta PC-Otimizador-CLI.ps1 na pasta do exe.", "Erro");
                return;
            }
            try { if (File.Exists(_cancelFile)) File.Delete(_cancelFile); } catch { }

            _running = true;
            _btnCancel.Enabled = true;
            _bar.Value = 0;
            _task.Text = "Iniciando...";
            _status.Text = "Executando — progresso ao vivo. Pode cancelar.";
            _result.Text = "Em andamento...";

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
                    _proc.ErrorDataReceived += (s, e) => { if (e.Data != null) BeginInvoke(new Action(() => Log("ERR " + e.Data))); };
                    _proc.Start();
                    _proc.BeginOutputReadLine();
                    _proc.BeginErrorReadLine();
                    _proc.WaitForExit();
                    BeginInvoke(new Action(() =>
                    {
                        _running = false;
                        _btnCancel.Enabled = false;
                        _bar.Value = 100;
                        _task.Text = "Concluído";
                        _status.Text = "Pronto. Logs em Documentos\\PC-Otimizador-Logs";
                    }));
                }
                catch (Exception ex)
                {
                    BeginInvoke(new Action(() =>
                    {
                        _running = false;
                        _btnCancel.Enabled = false;
                        Log(ex.Message);
                        MessageBox.Show(ex.Message, "Erro");
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
                    _bar.Value = Math.Max(0, Math.Min(100, pct));
                    _task.Text = string.Format("[{0}/{1}] {2}", cur, total, p[3]);
                }
                return;
            }
            if (line.StartsWith("##LOG##|"))
            {
                var p = line.Split(new[] { '|' }, 3);
                if (p.Length >= 3) Log(p[2]);
                return;
            }
            if (line.StartsWith("##RESULT##|AFTER|"))
            {
                var p = line.Split('|');
                if (p.Length >= 8)
                {
                    _result.Text = string.Format(
                        "DEPOIS  Disco livre: {0} / {1} GB   |   RAM: {2}/{3} GB\nLiberado ~{4} MB   |   Health Score: {5}\nLog: {6}",
                        p[2], p[3], p[4], p[5], p[6], p.Length > 8 ? p[8] : "—", p[7]);
                }
                return;
            }
            if (line.StartsWith("##RESULT##|BEFORE|"))
            {
                var p = line.Split('|');
                if (p.Length >= 6)
                {
                    _result.Text = string.Format("ANTES  Disco livre: {0}/{1} GB   |   RAM: {2}/{3} GB\nExecutando...", p[2], p[3], p[4], p[5]);
                }
                return;
            }
            if (line.StartsWith("##DONE##|"))
            {
                Log("Status final: " + line.Substring(9));
                return;
            }
            if (line.StartsWith("##HEALTH##|"))
            {
                _result.Text = line.Replace("##HEALTH##|", "Health Score: ").Replace("|", "  |  ");
                return;
            }
            Log(line);
        }

        void Log(string msg)
        {
            _log.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + msg + Environment.NewLine);
        }
    }
}
