using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace PCOtimizador
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
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
        readonly CheckBox _dry;
        readonly ProgressBar _bar;
        readonly Button _btnCancel;
        Process _proc;
        bool _light;
        bool _running;

        public MainForm()
        {
            _root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
            _cancelFile = Path.Combine(Path.GetTempPath(), "pc-otimizador-cancel.flag");
            Text = "PC Otimizador Pro v5";
            Size = new Size(960, 720);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            BackColor = Color.FromArgb(6, 8, 14);
            ForeColor = Color.FromArgb(241, 245, 249);
            Font = new Font("Segoe UI", 9.5f);

            Controls.Add(new Label
            {
                Text = "◈  PC OTIMIZADOR PRO",
                Font = new Font("Segoe UI Semibold", 16f),
                ForeColor = Color.FromArgb(0, 229, 192),
                Location = new Point(24, 16),
                AutoSize = true
            });

            _status = new Label
            {
                Text = "Escolha um perfil. Progresso ao vivo · Cancelar · Resumo antes/depois.",
                Location = new Point(26, 52),
                Size = new Size(900, 22),
                ForeColor = Color.FromArgb(100, 116, 139)
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
            Controls.Add(MakeCard(24, y, 210, 100, "Limpeza Segura", "★ SAFE", Color.FromArgb(0, 229, 192), () => RunPreset("safe")));
            Controls.Add(MakeCard(250, y, 210, 100, "Turbo / Gamer", "PERF", Color.FromArgb(56, 189, 248), () => RunPreset("gamer")));
            Controls.Add(MakeCard(476, y, 210, 100, "Internet", "NET", Color.FromArgb(251, 191, 36), () => RunPreset("net")));
            Controls.Add(MakeCard(702, y, 210, 100, "Notebook", "LAPTOP", Color.FromArgb(52, 211, 153), () => RunPreset("notebook")));

            y = 230;
            AddActionBtn(24, y, 150, "Health Score", () => RunCli("-Mode health -AutoYes"));
            AddActionBtn(186, y, 130, "Estimar", () => RunCli("-Mode scan -AutoYes"));
            AddActionBtn(328, y, 130, "Completo", () => RunPreset("full"));
            AddActionBtn(470, y, 150, "Agendar", () => RunCli("-Mode schedule -AutoYes"));
            AddActionBtn(632, y, 130, "Whitelist", () => RunCli("-Mode whitelist -AutoYes"));
            AddActionBtn(774, y, 120, "Tema", ToggleTheme);

            y = 280;
            _task = new Label
            {
                Text = "Pronto",
                Location = new Point(26, y),
                Size = new Size(700, 22),
                ForeColor = Color.FromArgb(0, 229, 192),
                Font = new Font("Segoe UI Semibold", 10f)
            };
            Controls.Add(_task);

            _btnCancel = MakeBtn(780, y - 4, 120, 32, "Cancelar", Color.FromArgb(127, 29, 29));
            _btnCancel.Enabled = false;
            _btnCancel.Click += (s, e) =>
            {
                try { File.WriteAllText(_cancelFile, "1"); } catch { }
                _task.Text = "Cancelando...";
                Log("Cancelamento solicitado...");
            };
            Controls.Add(_btnCancel);

            _bar = new ProgressBar
            {
                Location = new Point(24, 312),
                Size = new Size(880, 18),
                Minimum = 0,
                Maximum = 100
            };
            Controls.Add(_bar);

            _result = new Label
            {
                Text = "Resumo antes/depois aparece aqui apos a execucao.",
                Location = new Point(24, 340),
                Size = new Size(880, 70),
                BackColor = Color.FromArgb(16, 22, 36),
                ForeColor = Color.White,
                Padding = new Padding(12),
                Font = new Font("Segoe UI", 10f)
            };
            Controls.Add(_result);

            _log = new TextBox
            {
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Location = new Point(24, 420),
                Size = new Size(880, 240),
                BackColor = Color.FromArgb(4, 6, 10),
                ForeColor = Color.FromArgb(110, 231, 183),
                Font = new Font("Consolas", 8.5f),
                BorderStyle = BorderStyle.None
            };
            Controls.Add(_log);
            Log("v5: progresso ao vivo, cancelar, health, whitelist, SSD/HDD.");
        }

        void AddActionBtn(int x, int y, int w, string text, Action act)
        {
            var b = MakeBtn(x, y, w, 36, text, Color.FromArgb(30, 41, 59));
            b.Click += (s, e) => act();
            Controls.Add(b);
        }

        Panel MakeCard(int x, int y, int w, int h, string title, string badge, Color accent, Action onClick)
        {
            var p = new Panel { Location = new Point(x, y), Size = new Size(w, h), BackColor = Color.FromArgb(16, 22, 36), Cursor = Cursors.Hand };
            p.Controls.Add(new Panel { Location = new Point(0, 0), Size = new Size(4, h), BackColor = accent });
            var b = new Label { Text = badge, ForeColor = accent, Location = new Point(14, 10), AutoSize = true, Font = new Font("Segoe UI Semibold", 8f) };
            var t = new Label { Text = title, ForeColor = Color.White, Location = new Point(14, 36), Size = new Size(w - 24, 36), Font = new Font("Segoe UI Semibold", 12f) };
            var go = new Label { Text = "Iniciar →", ForeColor = accent, Location = new Point(14, h - 28), AutoSize = true };
            p.Controls.Add(b); p.Controls.Add(t); p.Controls.Add(go);
            EventHandler click = (s, e) => { if (!_running) onClick(); };
            p.Click += click; t.Click += click; b.Click += click; go.Click += click;
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
            BackColor = _light ? Color.FromArgb(245, 247, 250) : Color.FromArgb(6, 8, 14);
            ForeColor = _light ? Color.FromArgb(15, 23, 42) : Color.FromArgb(241, 245, 249);
            _status.ForeColor = _light ? Color.FromArgb(71, 85, 105) : Color.FromArgb(100, 116, 139);
            _log.BackColor = _light ? Color.White : Color.FromArgb(4, 6, 10);
            _log.ForeColor = _light ? Color.FromArgb(15, 23, 42) : Color.FromArgb(110, 231, 183);
            _result.BackColor = _light ? Color.FromArgb(226, 232, 240) : Color.FromArgb(16, 22, 36);
            _result.ForeColor = _light ? Color.FromArgb(15, 23, 42) : Color.White;
        }

        void RunPreset(string name)
        {
            var args = "-Preset " + name + " -AutoYes -StreamProgress";
            if (_dry.Checked) args += " -DryRun";
            if (MessageBox.Show("Executar perfil '" + name + "'" + (_dry.Checked ? " (DRY-RUN)" : "") + "?", "Confirmar",
                MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
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
                        _task.Text = "Concluido";
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
                // AFTER|diskFree|diskTot|ramUsed|ramTot|freedMB|log|score
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
