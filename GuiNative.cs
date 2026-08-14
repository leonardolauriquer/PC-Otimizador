using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
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
        readonly TextBox _log;
        readonly Label _status;
        readonly CheckBox _dry;
        bool _light;

        public MainForm()
        {
            _root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
            Text = "PC Otimizador Pro";
            Size = new Size(920, 640);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            BackColor = Color.FromArgb(6, 8, 14);
            ForeColor = Color.FromArgb(241, 245, 249);
            Font = new Font("Segoe UI", 9.5f);

            var title = new Label
            {
                Text = "◈  PC OTIMIZADOR PRO",
                Font = new Font("Segoe UI Semibold", 16f),
                ForeColor = Color.FromArgb(0, 229, 192),
                Location = new Point(24, 18),
                AutoSize = true
            };
            Controls.Add(title);

            _status = new Label
            {
                Text = "Escolha um perfil. Nao apaga Documentos, Fotos ou Downloads.",
                Location = new Point(26, 58),
                Size = new Size(860, 24),
                ForeColor = Color.FromArgb(100, 116, 139)
            };
            Controls.Add(_status);

            _dry = new CheckBox
            {
                Text = "Dry-run (simular — nao apaga nada)",
                Location = new Point(26, 90),
                AutoSize = true,
                ForeColor = Color.FromArgb(251, 191, 36)
            };
            Controls.Add(_dry);

            int y = 130;
            Controls.Add(MakeCard(24, y, 200, 110, "Limpeza Segura", "Recomendado", Color.FromArgb(0, 229, 192), () => RunPreset("safe")));
            Controls.Add(MakeCard(240, y, 200, 110, "Turbo / Gamer", "Performance", Color.FromArgb(56, 189, 248), () => RunPreset("gamer")));
            Controls.Add(MakeCard(456, y, 200, 110, "Internet", "DNS / TCP", Color.FromArgb(251, 191, 36), () => RunPreset("net")));
            Controls.Add(MakeCard(672, y, 200, 110, "Notebook", "Bateria", Color.FromArgb(52, 211, 153), () => RunPreset("notebook")));

            y = 260;
            var btnScan = MakeBtn(24, y, 180, 40, "Varrer + estimar", Color.FromArgb(30, 41, 59));
            btnScan.Click += (s, e) => RunCli("-Mode scan -AutoYes");
            Controls.Add(btnScan);

            var btnFull = MakeBtn(220, y, 160, 40, "Completo", Color.FromArgb(30, 41, 59));
            btnFull.Click += (s, e) => RunPreset("full");
            Controls.Add(btnFull);

            var btnSched = MakeBtn(400, y, 180, 40, "Agendar semanal", Color.FromArgb(30, 41, 59));
            btnSched.Click += (s, e) => RunCli("-Mode schedule -AutoYes");
            Controls.Add(btnSched);

            var btnTheme = MakeBtn(600, y, 140, 40, "Tema claro", Color.FromArgb(30, 41, 59));
            btnTheme.Click += (s, e) => ToggleTheme();
            Controls.Add(btnTheme);

            var btnTerm = MakeBtn(760, y, 120, 40, "Menu .bat", Color.FromArgb(15, 118, 110));
            btnTerm.Click += (s, e) =>
            {
                var bat = Path.Combine(_root, "Executar.bat");
                if (File.Exists(bat)) Process.Start(new ProcessStartInfo(bat) { UseShellExecute = true });
            };
            Controls.Add(btnTerm);

            _log = new TextBox
            {
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Location = new Point(24, 320),
                Size = new Size(856, 250),
                BackColor = Color.FromArgb(4, 6, 10),
                ForeColor = Color.FromArgb(110, 231, 183),
                Font = new Font("Consolas", 9f),
                BorderStyle = BorderStyle.None
            };
            Controls.Add(_log);
            Log("Pronto. Use Limpeza Segura se nao souber o que escolher.");
            Log("Logs salvos em Documentos\\PC-Otimizador-Logs");
        }

        Panel MakeCard(int x, int y, int w, int h, string title, string badge, Color accent, Action onClick)
        {
            var p = new Panel { Location = new Point(x, y), Size = new Size(w, h), BackColor = Color.FromArgb(16, 22, 36), Cursor = Cursors.Hand };
            var edge = new Panel { Location = new Point(0, 0), Size = new Size(4, h), BackColor = accent };
            var b = new Label { Text = badge, ForeColor = accent, Location = new Point(14, 12), AutoSize = true, Font = new Font("Segoe UI Semibold", 8f) };
            var t = new Label { Text = title, ForeColor = Color.White, Location = new Point(14, 40), Size = new Size(w - 24, 40), Font = new Font("Segoe UI Semibold", 12f) };
            var go = new Label { Text = "Iniciar  →", ForeColor = accent, Location = new Point(14, h - 32), AutoSize = true, Font = new Font("Segoe UI Semibold", 9f) };
            p.Controls.Add(edge); p.Controls.Add(b); p.Controls.Add(t); p.Controls.Add(go);
            EventHandler click = (s, e) => onClick();
            p.Click += click; t.Click += click; b.Click += click; go.Click += click; edge.Click += click;
            return p;
        }

        Button MakeBtn(int x, int y, int w, int h, string text, Color bg)
        {
            return new Button
            {
                Text = text,
                Location = new Point(x, y),
                Size = new Size(w, h),
                FlatStyle = FlatStyle.Flat,
                BackColor = bg,
                ForeColor = Color.White,
                Font = new Font("Segoe UI Semibold", 9f)
            };
        }

        void ToggleTheme()
        {
            _light = !_light;
            BackColor = _light ? Color.FromArgb(245, 247, 250) : Color.FromArgb(6, 8, 14);
            ForeColor = _light ? Color.FromArgb(15, 23, 42) : Color.FromArgb(241, 245, 249);
            _status.ForeColor = _light ? Color.FromArgb(71, 85, 105) : Color.FromArgb(100, 116, 139);
            _log.BackColor = _light ? Color.White : Color.FromArgb(4, 6, 10);
            _log.ForeColor = _light ? Color.FromArgb(15, 23, 42) : Color.FromArgb(110, 231, 183);
        }

        void RunPreset(string name)
        {
            var args = "-Preset " + name + " -AutoYes";
            if (_dry.Checked) args += " -DryRun";
            if (MessageBox.Show("Executar perfil '" + name + "'?" + (_dry.Checked ? "\n(DRY-RUN)" : ""), "Confirmar", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
                return;
            RunCli(args);
        }

        void RunCli(string extraArgs)
        {
            var cli = Path.Combine(_root, "PC-Otimizador-CLI.ps1");
            var engine = Path.Combine(_root, "Engine.ps1");
            if (!File.Exists(cli) || !File.Exists(engine))
            {
                MessageBox.Show("Faltam PC-Otimizador-CLI.ps1 / Engine.ps1 na mesma pasta do .exe", "Erro", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            _status.Text = "Executando... aguarde.";
            Log("> " + extraArgs);
            var psi = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe"),
                Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + cli + "\" " + extraArgs,
                WorkingDirectory = _root,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };
            try
            {
                using (var p = Process.Start(psi))
                {
                    string o = p.StandardOutput.ReadToEnd();
                    string e = p.StandardError.ReadToEnd();
                    p.WaitForExit();
                    if (!string.IsNullOrWhiteSpace(o)) Log(o.Trim());
                    if (!string.IsNullOrWhiteSpace(e)) Log("ERR: " + e.Trim());
                    Log("Exit code: " + p.ExitCode);
                }
                _status.Text = "Concluido. Veja o log e Documentos\\PC-Otimizador-Logs";
                MessageBox.Show("Concluido.\nLogs em Documentos\\PC-Otimizador-Logs\nReinicie o PC se fez limpeza real.", "PC Otimizador Pro");
            }
            catch (Exception ex)
            {
                Log(ex.Message);
                MessageBox.Show(ex.Message, "Erro");
            }
        }

        void Log(string msg)
        {
            _log.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + msg + Environment.NewLine);
        }
    }
}
