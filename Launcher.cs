using System;
using System.Diagnostics;
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

            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string script = Path.Combine(baseDir, "PC-Otimizador.ps1");

            if (!File.Exists(script))
            {
                MessageBox.Show(
                    "Nao encontrei PC-Otimizador.ps1 na mesma pasta do executavel.\n\n" +
                    "Mantenha estes arquivos juntos:\n" +
                    "• PC-Otimizador.exe\n" +
                    "• PC-Otimizador.ps1",
                    "PC Otimizador Pro",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }

            string ps = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.System),
                @"WindowsPowerShell\v1.0\powershell.exe");

            if (!File.Exists(ps))
                ps = "powershell.exe";

            var psi = new ProcessStartInfo
            {
                FileName = ps,
                Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = baseDir
            };

            try
            {
                using (var p = Process.Start(psi))
                {
                    if (p == null)
                    {
                        MessageBox.Show("Falha ao iniciar o PowerShell.", "PC Otimizador Pro",
                            MessageBoxButtons.OK, MessageBoxIcon.Error);
                        return;
                    }
                    p.WaitForExit();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Erro ao iniciar:\n" + ex.Message +
                    "\n\nTente o arquivo Executar.bat como alternativa.",
                    "PC Otimizador Pro",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
        }
    }
}
