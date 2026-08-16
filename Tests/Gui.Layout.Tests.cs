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
            var bar = Field<Control>(form, "_bar");
            var pct = Field<Control>(form, "_pctLabel");
            var task = Field<Control>(form, "_taskLabel");
            Check(Inside(bar.Bounds, progress.ClientRectangle), size + " progress bar is contained");
            Check(Inside(pct.Bounds, progress.ClientRectangle) && Inside(task.Bounds, progress.ClientRectangle), size + " progress labels are contained");

            var chrome = Field<Panel>(form, "_chrome");
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

            var tools = Field<FlowLayoutPanel>(form, "_toolsFlow");
            Check(tools != null && tools.AutoScroll && tools.WrapContents, size + " tools page is responsive and scrollable");
            if (tools != null) Check(tools.Controls.Count == 4, size + " tools page has four cards");
            var helpScroll = Field<Panel>(form, "_helpScroll");
            var helpBox = Field<Control>(form, "_helpBox");
            bool helpFitsHorizontally = helpScroll != null && helpBox != null && helpBox.Left >= 0 && helpBox.Right <= helpScroll.ClientSize.Width;
            Check(helpScroll != null && helpScroll.AutoScroll && helpFitsHorizontally, size + " help page is contained and scrollable");

            var nav = Field<IList>(form, "_navBtns");
            Check(nav != null && nav.Count == 7, size + " sidebar navigation is complete");
            foreach (string pageName in new[] { "inicio", "ferramentas", "ajuda" })
            {
                InvokePage(form, pageName);
                string expected = pageName == "inicio" ? "Dashboard" : (pageName == "ferramentas" ? "Ferramentas" : "Configurações");
                var hero = Field<Label>(form, "_heroSub");
                Check(hero != null && hero.Text.StartsWith(expected, StringComparison.Ordinal), size + " page switch " + pageName);
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
            Console.WriteLine(_failed == 0 ? "ALL GUI LAYOUT TESTS PASSED" : _failed + " GUI LAYOUT TESTS FAILED");
            Environment.ExitCode = _failed == 0 ? 0 : 1;
        }
    }
}
