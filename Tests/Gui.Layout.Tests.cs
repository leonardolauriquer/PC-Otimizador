using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;

namespace PCOtimizador
{
    // Headless layout contract for the native WinForms shell.  It deliberately
    // exercises the same bounds used by the real form instead of relying only
    // on string/static checks.
    static class GuiLayoutTests
    {
        static int _failed;

        static void Check(bool condition, string name)
        {
            if (condition) Console.WriteLine("PASS " + name);
            else { Console.WriteLine("FAIL " + name); _failed++; }
        }

        static T Field<T>(MainForm form, string name) where T : class
        {
            var f = typeof(MainForm).GetField(name, BindingFlags.Instance | BindingFlags.NonPublic);
            return f == null ? null : f.GetValue(form) as T;
        }

        static void Invoke(MainForm form, string name)
        {
            typeof(MainForm).GetMethod(name, BindingFlags.Instance | BindingFlags.NonPublic)
                .Invoke(form, null);
        }

        static bool Inside(Rectangle child, Rectangle parent)
        {
            return child.Left >= parent.Left && child.Top >= parent.Top &&
                   child.Right <= parent.Right && child.Bottom <= parent.Bottom;
        }

        static Rectangle InContent(Control page, Control child)
        {
            return new Rectangle(page.Left + child.Left, page.Top + child.Top, child.Width, child.Height);
        }

        static IDictionary Pages(MainForm form)
        {
            return Field<IDictionary>(form, "_pages");
        }

        static void CheckSize(MainForm form, Size size)
        {
            form.ClientSize = size;
            form.CreateControl();
            // A real window makes its child hierarchy visible during Show();
            // mirror that state without running the startup/update event.
            var contentHost = Field<Panel>(form, "_content");
            contentHost.Visible = true;
            Invoke(form, "LayoutRoot");
            Invoke(form, "LayoutVisuals");
            form.PerformLayout();

            var content = Field<Panel>(form, "_content");
            var sidebar = Field<Panel>(form, "_sidebar");
            var pageMap = Pages(form);
            var home = (Panel)pageMap["inicio"];
            var grid = Field<TableLayoutPanel>(form, "_presetGrid");
            var progress = Field<Panel>(form, "_progressBox");
            var stats = Field<Panel>(form, "_statsBox");

            Check(form.ClientSize == size, size + " client size is accepted");
            Check(sidebar.Bounds == new Rectangle(0, 0, 246, size.Height), size + " sidebar fills height");
            Check(content.Bounds == new Rectangle(246, 0, size.Width - 246, size.Height), size + " content fills remainder");
            Check(grid.Top == 0, size + " preset grid uses page-relative coordinates");
            Check(Inside(grid.Bounds, new Rectangle(Point.Empty, home.ClientSize)), size + " preset grid is inside home page");
            Check(InContent(home, grid).Bottom <= progress.Top, size + " preset cards clear progress panel");

            var cards = new List<Control>();
            foreach (Control c in grid.Controls) cards.Add(c);
            Check(cards.Count == 4, size + " has four preset cards");
            if (cards.Count == 4)
            {
                int width = cards[0].Width;
                bool equal = true;
                foreach (Control card in cards)
                    equal = equal && card.Width == width && Inside(card.Bounds, grid.ClientRectangle);
                Check(equal, size + " preset cards are equal and contained");
            }

            Check(progress.Bottom <= stats.Top, size + " progress and stats do not overlap");
            Check(stats.Height <= 190, size + " stats panel has compact height");
            var bar = Field<Control>(form, "_bar");
            var pct = Field<Control>(form, "_pctLabel");
            var task = Field<Control>(form, "_taskLabel");
            var cancel = Field<Control>(form, "_btnCancel");
            Check(Inside(bar.Bounds, progress.ClientRectangle), size + " progress bar is contained");
            Check(Inside(pct.Bounds, progress.ClientRectangle) && Inside(task.Bounds, progress.ClientRectangle), size + " progress labels are contained");
            var percentTextSize = TextRenderer.MeasureText(pct.Text, pct.Font, new Size(pct.Width, Int32.MaxValue), TextFormatFlags.NoPadding);
            Check(percentTextSize.Height <= pct.Height, size + " progress percentage text is not clipped");
            Check(cancel != null && !cancel.Visible, size + " idle cancel button is hidden");

            var chrome = Field<Panel>(form, "_chrome");
            var heroSub = Field<Label>(form, "_heroSub");
            Check(heroSub != null && heroSub.Top >= 70 && Inside(heroSub.Bounds, chrome.ClientRectangle), size + " header subtitle is readable and contained");
            int titleLabels = 0;
            int chromeButtons = 0;
            foreach (Control c in chrome.Controls)
            {
                if (c is Label && (c.Text == "PC" || c.Text == "OTIMIZADOR" || c.Text == "PRO"))
                {
                    titleLabels++;
                    Check(!c.AutoSize && Inside(c.Bounds, chrome.ClientRectangle), size + " title label is contained");
                }
                if (c is Button) chromeButtons++;
            }
            Check(titleLabels == 3, size + " title has three stable segments");
            Check(chromeButtons == 3, size + " custom chrome has min/max/close controls");
            Control rightmostTitle = null;
            foreach (Control c in chrome.Controls)
            {
                if (c is Label && (c.Text == "PC" || c.Text == "OTIMIZADOR" || c.Text == "PRO"))
                    if (rightmostTitle == null || c.Right > rightmostTitle.Right) rightmostTitle = c;
            }
            bool titleClearsChrome = rightmostTitle != null;
            foreach (Control c in chrome.Controls)
                if (c is Button && rightmostTitle != null)
                    titleClearsChrome = titleClearsChrome && !rightmostTitle.Bounds.IntersectsWith(c.Bounds);
            Check(titleClearsChrome, size + " title clears window controls");

            var tools = Field<FlowLayoutPanel>(form, "_toolsFlow");
            Check(tools != null && tools.AutoScroll && tools.WrapContents, size + " tools page is responsive and scrollable");
            if (tools != null) Check(tools.Controls.Count == 5, size + " tools page has five cards");
            var helpScroll = Field<Panel>(form, "_helpScroll");
            var helpBox = Field<Control>(form, "_helpBox");
            bool helpFitsHorizontally = helpScroll != null && helpBox != null && helpBox.Left >= 0 && helpBox.Right <= helpScroll.ClientSize.Width;
            Check(helpScroll != null && helpScroll.AutoScroll && helpFitsHorizontally, size + " help page is contained and scrollable");
            Check(helpScroll != null && helpScroll.Top >= 92, size + " help content does not cover settings heading");
            var telemetryToggle = Field<Control>(form, "_telemetryToggle");
            Check(telemetryToggle != null && helpBox != null && telemetryToggle.Left >= 0 && telemetryToggle.Right <= helpBox.ClientSize.Width && telemetryToggle.Bottom <= helpBox.ClientSize.Height,
                size + " telemetry consent control is contained");

            var nav = Field<IList>(form, "_navBtns");
            Check(nav != null && nav.Count == 8, size + " sidebar navigation is complete");
            Check(pageMap.Count == 8, size + " has eight distinct sidebar pages");
            if (nav != null)
            {
                Panel settingsNav = null;
                foreach (object item in nav)
                {
                    var panel = item as Panel;
                    if (panel != null && string.Equals(panel.Tag as string, "configuracoes", StringComparison.Ordinal)) settingsNav = panel;
                }
                if (settingsNav != null)
                    typeof(Control).GetMethod("OnClick", BindingFlags.Instance | BindingFlags.NonPublic).Invoke(settingsNav, new object[] { EventArgs.Empty });
                Check(settingsNav != null && Field<string>(form, "_activeNav") == "configuracoes", size + " settings navigation opens settings page");
            }
            foreach (string featurePageName in new[] { "limpeza", "desempenho", "internet" })
            {
                var featurePage = pageMap[featurePageName] as Panel;
                FlowLayoutPanel featureFlow = null;
                if (featurePage != null)
                    foreach (Control child in featurePage.Controls)
                        if (child is FlowLayoutPanel && string.Equals(child.Tag as string, "feature-flow", StringComparison.Ordinal)) featureFlow = (FlowLayoutPanel)child;
                Check(featureFlow != null && featureFlow.AutoScroll && featureFlow.Controls.Count == 3, size + " page " + featurePageName + " has functional cards");
            }
            var deviceFlow = Field<FlowLayoutPanel>(form, "_deviceFlow");
            Check(deviceFlow != null && deviceFlow.AutoScroll && deviceFlow.Controls.Count == 8, size + " device page has eight hardware sections");
            Check(Field<CheckedListBox>(form, "_startupList") != null, size + " startup programs list exists");
            Check(Field<Button>(form, "_startupApply") != null, size + " startup apply button exists");
            foreach (string pageName in new[] { "inicio", "limpeza", "desempenho", "internet", "inicializacao", "ferramentas", "dispositivo", "configuracoes" })
            {
                InvokePage(form, pageName);
                string expected = pageName == "inicio" ? "Painel" :
                    (pageName == "limpeza" ? "Limpeza" :
                    (pageName == "desempenho" ? "Desempenho" :
                    (pageName == "internet" ? "Internet" :
                    (pageName == "inicializacao" ? "Inicialização" :
                    (pageName == "ferramentas" ? "Ferramentas" :
                    (pageName == "dispositivo" ? "Dispositivo" : "Configurações"))))));
                var hero = Field<Label>(form, "_heroSub");
                Check(hero != null && hero.Text.StartsWith(expected, StringComparison.Ordinal), size + " page switch " + pageName);
                var progressPanel = Field<Control>(form, "_progressBox");
                if (pageName != "inicio") Check(progressPanel != null && !progressPanel.Visible, size + " dashboard chrome hidden on " + pageName);
            }
            var languagePt = Field<Button>(form, "_languagePtButton");
            var languageEn = Field<Button>(form, "_languageEnButton");
            Check(languagePt != null && languageEn != null, size + " language selector has PT and EN buttons");
            if (languagePt != null && languageEn != null)
            {
                typeof(Button).GetMethod("OnClick", BindingFlags.Instance | BindingFlags.NonPublic).Invoke(languageEn, new object[] { EventArgs.Empty });
                var localized = Field<IDictionary>(form, "_localized");
                var homeControls = localized == null ? null : localized["nav.inicio"] as IList;
                var homeLabel = homeControls == null || homeControls.Count == 0 ? null : homeControls[0] as Label;
                Check(homeLabel != null && homeLabel.Text == "HOME", size + " switches to English");
                Check(form.Text == "PC Optimizer Pro", size + " English mode localizes title");
                Check(telemetryToggle != null && (telemetryToggle.Text == "ENABLED" || telemetryToggle.Text == "DISABLED"), size + " English mode localizes telemetry consent");
                var safeControls = localized == null ? null : localized["card.safe.title"] as IList;
                bool allSafeEnglish = safeControls != null && safeControls.Count >= 2;
                if (allSafeEnglish) foreach (Control safe in safeControls) allSafeEnglish = allSafeEnglish && safe.Text == "SAFE CLEANUP";
                Check(allSafeEnglish, size + " translates repeated dashboard cards");
                typeof(Button).GetMethod("OnClick", BindingFlags.Instance | BindingFlags.NonPublic).Invoke(languagePt, new object[] { EventArgs.Empty });
                Check(homeLabel != null && homeLabel.Text == "INÍCIO", size + " switches back to Portuguese");
                Check(form.Text == "PC Otimizador Pro", size + " Portuguese mode localizes title");
                Check(telemetryToggle != null && (telemetryToggle.Text == "ATIVADA" || telemetryToggle.Text == "DESATIVADA"), size + " Portuguese mode localizes telemetry consent");
            }
        }

        static void InvokePage(MainForm form, string page)
        {
            typeof(MainForm).GetMethod("ShowPage", BindingFlags.Instance | BindingFlags.NonPublic)
                .Invoke(form, new object[] { page });
        }

        [STAThread]
        public static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            foreach (var size in new[] { new Size(1357, 857), new Size(1280, 720), new Size(1024, 680) })
            {
                using (var form = new MainForm()) CheckSize(form, size);
            }
            var safeIds = ActionCatalog.IdsFor("safe", ".");
            Check(safeIds != null && safeIds.Length > 0, "safe consent catalog loads");
            bool recycleInSafe = false;
            foreach (var id in safeIds) if (string.Equals(id, "recycle", StringComparison.OrdinalIgnoreCase)) recycleInSafe = true;
            Check(!recycleInSafe, "safe consent catalog excludes recycle");
            Check(ActionEstimates.FormatHint(0, true, false) == "ajuste", "consent estimate labels settings");
            Check(ActionEstimates.FormatHint(2048, false, false).IndexOf("GB", StringComparison.Ordinal) >= 0, "consent estimate formats gigabytes");
            Check(ActionEstimates.FormatTotal(12, false, 3, false).IndexOf("Estimativa", StringComparison.Ordinal) >= 0, "consent estimate total is localized");
            Check(UserPrefs.LoadSelection("missing-preset-xyz") == null, "unknown preset has no remembered selection");
            Console.WriteLine(_failed == 0 ? "ALL GUI LAYOUT TESTS PASSED" : _failed + " GUI LAYOUT TESTS FAILED");
            Environment.ExitCode = _failed == 0 ? 0 : 1;
        }
    }
}
