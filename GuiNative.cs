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
        readonly string _logsDir;
        readonly TextBox _log;
        readonly Label _status;
        readonly Label _task;
        readonly Label _result;
        readonly Label _title;
        readonly Label _tipBanner;
        readonly CheckBox _dry;
        readonly ProgressBar _bar;
        readonly Button _btnCancel;
        readonly ToolTip _tips;
        readonly List<Panel> _cards = new List<Panel>();
        readonly List<Button> _actionBtns = new List<Button>();
        Process _proc;
        bool _light;
        bool _running;
        int _tipIndex;

        static readonly Color DarkBg = Color.FromArgb(6, 8, 14);
        static readonly Color DarkCard = Color.FromArgb(16, 22, 36);
        static readonly Color DarkMuted = Color.FromArgb(100, 116, 139);
        static readonly Color Accent = Color.FromArgb(0, 229, 192);
        static readonly Color LightBg = Color.FromArgb(245, 247, 250);
        static readonly Color LightCard = Color.FromArgb(255, 255, 255);
        static readonly Color LightMuted = Color.FromArgb(71, 85, 105);

        static readonly string[] Tips = new[]
        {
            "Dica: marque Dry-run para ver o que seria limpo sem apagar nada.",
            "Dica: Limpeza Segura (SAFE) é o ideal na primeira vez.",
            "Dica: Documentos, Fotos, Downloads e OneDrive nunca são apagados.",
            "Dica: Gamer/Internet (RISK) podem mudar DNS ou plano de energia.",
            "Dica: Health Score 0–100 resume disco, RAM e lixo recuperável.",
            "Dica: Agendar cria limpeza segura todo domingo às 10h.",
            "Dica: Whitelist protege pastas extras que você indicar.",
            "Dica: logs ficam em Documentos\\PC-Otimizador-Logs."
        };

        public MainForm()
        {
            _root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
            _cancelFile = Path.Combine(Path.GetTempPath(), "pc-otimizador-cancel.flag");
            _logsDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
                "PC-Otimizador-Logs");

            _tips = new ToolTip
            {
                AutoPopDelay = 15000,
                InitialDelay = 350,
                ReshowDelay = 200,
                ShowAlways = true,
                IsBalloon = true,
                ToolTipTitle = "PC Otimizador Pro",
                ToolTipIcon = ToolTipIcon.Info
            };

            Text = "PC Otimizador Pro v5.3";
            Size = new Size(1000, 780);
            MinimumSize = new Size(920, 680);
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
                Location = new Point(24, 14),
                AutoSize = true
            };
            Controls.Add(_title);
            Tip(_title, "Limpeza e otimização segura para Windows.\nNão apaga seus arquivos pessoais.");

            var btnHelp = MakeBtn(820, 12, 70, 32, "Ajuda", Color.FromArgb(30, 41, 59));
            btnHelp.Click += (s, e) => ShowHelp();
            Controls.Add(btnHelp);
            _actionBtns.Add(btnHelp);
            Tip(btnHelp, "Abre o guia rápido: o que cada botão faz, o que é SAFE/RISK e dicas de segurança.");

            var btnTip = MakeBtn(900, 12, 60, 32, "Dica", Color.FromArgb(30, 64, 55));
            btnTip.Click += (s, e) => NextTip(true);
            Controls.Add(btnTip);
            _actionBtns.Add(btnTip);
            Tip(btnTip, "Mostra a próxima dica útil no painel amarelo.");

            _status = new Label
            {
                Text = "Passe o mouse nos botões para ver explicações. Comece por Limpeza Segura ★",
                Location = new Point(26, 50),
                Size = new Size(940, 22),
                ForeColor = DarkMuted
            };
            Controls.Add(_status);
            Tip(_status, "Barra de status: mostra o que está acontecendo agora.");

            _tipBanner = new Label
            {
                Text = "💡  " + Tips[0],
                Location = new Point(24, 74),
                Size = new Size(940, 28),
                BackColor = Color.FromArgb(30, 41, 20),
                ForeColor = Color.FromArgb(253, 224, 71),
                Padding = new Padding(10, 5, 10, 5),
                Font = new Font("Segoe UI", 9f),
                Cursor = Cursors.Hand
            };
            _tipBanner.Click += (s, e) => NextTip(true);
            Controls.Add(_tipBanner);
            Tip(_tipBanner, "Clique para ver outra dica. Estas mensagens ajudam a usar o app com segurança.");

            _dry = new CheckBox
            {
                Text = "Dry-run (simular — não apaga nada)",
                Location = new Point(26, 110),
                AutoSize = true,
                ForeColor = Color.FromArgb(251, 191, 36)
            };
            Controls.Add(_dry);
            Tip(_dry,
                "Modo simulação.\n\n" +
                "• Lista o que seria limpo e estima o espaço\n" +
                "• Não remove arquivos\n" +
                "• Ideal antes da primeira limpeza real");

            int y = 145;
            _cards.Add(MakeCard(24, y, 220, 118,
                "Limpeza Segura", "SAFE ★", "Recomendado p/ iniciantes",
                Color.FromArgb(0, 229, 192),
                () => RunPreset("safe", false),
                "Limpeza Segura (recomendado)\n\n" +
                "Remove: temporários, lixeira, caches regeneráveis, logs, TRIM.\n" +
                "NÃO muda: DNS, IP, plano de energia.\n" +
                "NÃO apaga: Documentos, Fotos, Downloads, Desktop, OneDrive.\n\n" +
                "Use esta opção na maioria das vezes."));

            _cards.Add(MakeCard(256, y, 220, 118,
                "Turbo / Gamer", "RISK", "DNS + alto desempenho",
                Color.FromArgb(248, 113, 113),
                () => RunPreset("gamer", true),
                "Turbo / Gamer (atenção)\n\n" +
                "Além da limpeza, pode:\n" +
                "• Ativar plano Alto Desempenho (gasta mais bateria)\n" +
                "• Trocar DNS para Cloudflare 1.1.1.1\n" +
                "• Ajustes de rede (Nagle)\n\n" +
                "Peça confirmação extra. Em notebook, prefira Notebook."));

            _cards.Add(MakeCard(488, y, 220, 118,
                "Internet", "RISK", "DNS Cloudflare + IP",
                Color.FromArgb(251, 191, 36),
                () => RunPreset("net", true),
                "Reparar Internet (atenção)\n\n" +
                "• Flush DNS/ARP\n" +
                "• Renova o endereço IP (rede pode cair por segundos)\n" +
                "• Pode definir DNS Cloudflare\n\n" +
                "Útil se a internet está lenta ou com DNS quebrado.\n" +
                "Se sua empresa força DNS corporativo, não use."));

            _cards.Add(MakeCard(720, y, 220, 118,
                "Notebook", "SAFE", "Equilibrado p/ bateria",
                Color.FromArgb(52, 211, 153),
                () => RunPreset("notebook", false),
                "Notebook (bateria)\n\n" +
                "Limpeza segura + plano de energia Equilibrado.\n" +
                "Evita Alto Desempenho (que drena a bateria).\n" +
                "Bom para uso diário em laptop."));

            foreach (var c in _cards) Controls.Add(c);

            y = 280;
            AddActionBtn(24, y, 140, "Health Score", () => RunCli("-Mode health -AutoYes"),
                "Nota de saúde do PC (0–100).\n\nConsidera disco cheio, RAM e lixo recuperável.\nNão altera o sistema — só mede.");
            AddActionBtn(176, y, 120, "Estimar", () => RunCli("-Mode scan -AutoYes"),
                "Varre e estima quantos MB/GB a Limpeza Segura liberaria.\nNão apaga nada.");
            AddActionBtn(308, y, 120, "Completo", () => RunPreset("full", false),
                "Preset Completo: limpeza ampla + caches de apps/navegador.\nNão inclui DNS Cloudflare nem Alto Desempenho.\nDemora mais que a Limpeza Segura.");
            AddActionBtn(440, y, 120, "Agendar", () =>
            {
                if (MessageBox.Show(
                    "Criar tarefa semanal?\n\n" +
                    "• Todo domingo às 10:00\n" +
                    "• Só Limpeza Segura (sem DNS/energia)\n" +
                    "• Roda em segundo plano com admin\n\nContinuar?",
                    "Agendar limpeza", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
                    return;
                RunCli("-Mode schedule -AutoYes");
            },
                "Agenda limpeza segura automática (domingo 10h).\nNão agenda perfis RISK.");
            AddActionBtn(572, y, 120, "Whitelist", () => RunCli("-Mode whitelist -AutoYes"),
                "Lista pastas que o otimizador NUNCA apaga.\n\nJá inclui Documentos, Fotos, Vídeos, Música, Desktop, Downloads, OneDrive.\nVocê pode acrescentar outras pastas.");
            AddActionBtn(704, y, 110, "Abrir logs", OpenLogsFolder,
                "Abre a pasta Documentos\\PC-Otimizador-Logs com o histórico de cada sessão.");
            AddActionBtn(826, y, 100, "Tema", ToggleTheme,
                "Alterna tema escuro / claro.");

            y = 330;
            _task = new Label
            {
                Text = "Pronto — passe o mouse nos cards para detalhes",
                Location = new Point(26, y),
                Size = new Size(680, 22),
                ForeColor = Accent,
                Font = new Font("Segoe UI Semibold", 10f)
            };
            Controls.Add(_task);

            _btnCancel = MakeBtn(780, y - 4, 146, 32, "Cancelar", Color.FromArgb(127, 29, 29));
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
            Tip(_btnCancel, "Interrompe a execução atual.\nPassos longos (DISM/SFC) podem demorar um pouco para parar.");

            _bar = new ProgressBar
            {
                Location = new Point(24, 362),
                Size = new Size(902, 18),
                Minimum = 0,
                Maximum = 100
            };
            Controls.Add(_bar);
            Tip(_bar, "Progresso da limpeza em andamento.");

            _result = new Label
            {
                Text = "Resumo antes/depois aparece aqui.\nDica: rode Health Score ou Estimar antes da primeira limpeza.",
                Location = new Point(24, 390),
                Size = new Size(902, 72),
                BackColor = DarkCard,
                ForeColor = Color.White,
                Padding = new Padding(12),
                Font = new Font("Segoe UI", 10f)
            };
            Controls.Add(_result);
            Tip(_result, "Painel de resultado: espaço em disco, RAM e Health Score antes/depois.");

            _log = new TextBox
            {
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Location = new Point(24, 474),
                Size = new Size(902, 240),
                BackColor = Color.FromArgb(4, 6, 10),
                ForeColor = Color.FromArgb(110, 231, 183),
                Font = new Font("Consolas", 8.5f),
                BorderStyle = BorderStyle.FixedSingle,
                Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right
            };
            Controls.Add(_log);
            Tip(_log, "Log ao vivo da sessão. O mesmo conteúdo é salvo em Documentos\\PC-Otimizador-Logs.");

            Log("Bem-vindo! Passe o mouse nos botões (balões de ajuda) ou clique em Ajuda.");
            Log("Recomendado: Dry-run → Estimar → Limpeza Segura.");
            NextTip(false);
        }

        void Tip(Control c, string text)
        {
            if (c == null || string.IsNullOrEmpty(text)) return;
            _tips.SetToolTip(c, text);
        }

        void NextTip(bool fromClick)
        {
            if (fromClick) _tipIndex = (_tipIndex + 1) % Tips.Length;
            _tipBanner.Text = "💡  " + Tips[_tipIndex] + "  (clique para outra)";
            if (fromClick) Log("Dica: " + Tips[_tipIndex]);
        }

        void ShowHelp()
        {
            string msg =
                "GUIA RÁPIDO\n" +
                "────────────\n\n" +
                "1) Marque Dry-run e rode Limpeza Segura → vê o que aconteceria.\n" +
                "2) Desmarque Dry-run e rode de novo para limpar de verdade.\n" +
                "3) Health Score / Estimar → só medem, não apagam.\n\n" +
                "SAFE = não muda DNS nem energia.\n" +
                "RISK = pede confirmação extra (DNS / IP / alto desempenho).\n\n" +
                "NUNCA apagamos: Documentos, Fotos, Vídeos, Música,\n" +
                "Desktop, Downloads, OneDrive e pastas da Whitelist.\n\n" +
                "Logs: Documentos\\PC-Otimizador-Logs\n" +
                "Cancelar: botão vermelho durante a execução.\n\n" +
                "Dúvida? Prefira sempre Limpeza Segura ★";
            MessageBox.Show(msg, "Ajuda — PC Otimizador Pro", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        void OpenLogsFolder()
        {
            try
            {
                if (!Directory.Exists(_logsDir))
                    Directory.CreateDirectory(_logsDir);
                Process.Start("explorer.exe", _logsDir);
                Log("Abrindo pasta de logs: " + _logsDir);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Não foi possível abrir a pasta de logs.\n" + ex.Message, "Logs");
            }
        }

        void AddActionBtn(int x, int y, int w, string text, Action act, string tip)
        {
            var b = MakeBtn(x, y, w, 36, text, Color.FromArgb(30, 41, 59));
            b.Click += (s, e) => act();
            Controls.Add(b);
            _actionBtns.Add(b);
            Tip(b, tip);
        }

        Panel MakeCard(int x, int y, int w, int h, string title, string badge, string riskHint, Color accent, Action onClick, string tip)
        {
            var p = new Panel { Location = new Point(x, y), Size = new Size(w, h), BackColor = DarkCard, Cursor = Cursors.Hand };
            p.Controls.Add(new Panel { Location = new Point(0, 0), Size = new Size(4, h), BackColor = accent, Name = "rail" });
            var b = new Label { Text = badge, ForeColor = accent, Location = new Point(14, 10), AutoSize = true, Font = new Font("Segoe UI Semibold", 8f), Name = "badge" };
            var t = new Label { Text = title, ForeColor = Color.White, Location = new Point(14, 34), Size = new Size(w - 24, 28), Font = new Font("Segoe UI Semibold", 12f), Name = "title" };
            var hint = new Label { Text = riskHint, ForeColor = DarkMuted, Location = new Point(14, 66), Size = new Size(w - 24, 20), Font = new Font("Segoe UI", 8f), Name = "hint" };
            var go = new Label { Text = "Iniciar →", ForeColor = accent, Location = new Point(14, h - 26), AutoSize = true, Name = "go" };
            p.Controls.Add(b); p.Controls.Add(t); p.Controls.Add(hint); p.Controls.Add(go);
            EventHandler click = (s, e) => { if (!_running) onClick(); };
            p.Click += click; t.Click += click; b.Click += click; go.Click += click; hint.Click += click;
            Tip(p, tip);
            Tip(t, tip);
            Tip(b, tip);
            Tip(hint, tip);
            Tip(go, tip);
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
            _tipBanner.BackColor = _light ? Color.FromArgb(254, 249, 195) : Color.FromArgb(30, 41, 20);
            _tipBanner.ForeColor = _light ? Color.FromArgb(113, 63, 18) : Color.FromArgb(253, 224, 71);
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
            string explain = PresetExplain(name);
            string msg = explain + "\n\nExecutar perfil '" + name + "'" + (_dry.Checked ? " (DRY-RUN — só simula)" : "") + "?";
            if (highRisk && !_dry.Checked)
            {
                msg = "ATENÇÃO — perfil com risco de rede/energia\n\n" + explain +
                      "\n\nPode alterar DNS, renovar IP ou mudar o plano de energia.\nContinuar?";
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

        static string PresetExplain(string name)
        {
            switch (name)
            {
                case "safe":
                    return "Limpeza Segura: temporários, lixeira, caches, TRIM.\nNão mexe em DNS/energia. Não apaga arquivos pessoais.";
                case "gamer":
                    return "Turbo/Gamer: limpeza + alto desempenho + possíveis ajustes de DNS/rede.";
                case "net":
                    return "Internet: flush DNS/ARP, pode renovar IP e usar DNS Cloudflare.";
                case "notebook":
                    return "Notebook: limpeza segura + plano equilibrado (melhor p/ bateria).";
                case "full":
                    return "Completo: limpeza ampla incluindo caches de apps/navegador (mais demorado).";
                default:
                    return "Perfil: " + name;
            }
        }

        void RunCli(string extraArgs)
        {
            if (_running) return;
            var cli = Path.Combine(_root, "PC-Otimizador-CLI.ps1");
            if (!File.Exists(cli))
            {
                MessageBox.Show(
                    "Falta PC-Otimizador-CLI.ps1 na mesma pasta do .exe.\n\n" +
                    "Extraia o ZIP completo (não só o .exe).",
                    "Arquivo faltando", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            try { if (File.Exists(_cancelFile)) File.Delete(_cancelFile); } catch { }

            _running = true;
            _btnCancel.Enabled = true;
            _bar.Value = 0;
            _task.Text = "Iniciando...";
            _status.Text = "Executando — progresso ao vivo. Use Cancelar se precisar parar.";
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
                        _status.Text = "Pronto. Clique em Abrir logs para ver o histórico.";
                    }));
                }
                catch (Exception ex)
                {
                    BeginInvoke(new Action(() =>
                    {
                        _running = false;
                        _btnCancel.Enabled = false;
                        Log(ex.Message);
                        MessageBox.Show(ex.Message + "\n\nSe o antivírus bloqueou, use Executar.bat.", "Erro",
                            MessageBoxButtons.OK, MessageBoxIcon.Error);
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
                var parts = line.Substring("##HEALTH##|".Length).Split('|');
                if (parts.Length >= 2)
                {
                    _result.Text = string.Format(
                        "Health Score: {0}/100 (nota {1})\n{2}\nQuanto maior o score, melhor o 'fôlego' do PC.",
                        parts[0], parts[1], string.Join("  |  ", parts));
                }
                else
                {
                    _result.Text = line.Replace("##HEALTH##|", "Health Score: ").Replace("|", "  |  ");
                }
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
