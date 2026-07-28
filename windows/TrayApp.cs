using System.Diagnostics;

namespace ProxyToggle;

internal sealed class TrayApp : ApplicationContext
{
    private const int PollIntervalMs = 1500;
    private const int TooltipLimit = 63; // NotifyIcon.Text is capped by Windows Forms

    private readonly TrayIcons _icons = new();
    private readonly NotifyIcon _notifyIcon;
    private readonly System.Windows.Forms.Timer _poll;

    private readonly ToolStripMenuItem _statusItem;
    private readonly ToolStripMenuItem _serverItem;
    private readonly ToolStripMenuItem _toggleItem;
    private readonly ToolStripMenuItem _startupItem;

    private ProxySettings.State _state;
    private bool _painted;

    public TrayApp()
    {
        _statusItem = new ToolStripMenuItem { Enabled = false };
        _serverItem = new ToolStripMenuItem { Enabled = false };
        _toggleItem = new ToolStripMenuItem();
        _toggleItem.Click += (_, _) => Toggle();
        _startupItem = new ToolStripMenuItem("ログイン時に起動") { CheckOnClick = false };
        _startupItem.Click += (_, _) => ToggleStartup();

        var settingsItem = new ToolStripMenuItem("プロキシ設定を開く…");
        settingsItem.Click += (_, _) => OpenProxySettings();

        var exitItem = new ToolStripMenuItem("終了");
        exitItem.Click += (_, _) => ExitThread();

        var menu = new ContextMenuStrip();
        menu.Items.AddRange(new ToolStripItem[]
        {
            _statusItem,
            _serverItem,
            new ToolStripSeparator(),
            _toggleItem,
            new ToolStripSeparator(),
            settingsItem,
            _startupItem,
            new ToolStripSeparator(),
            exitItem,
        });
        menu.Opening += (_, _) => UpdateMenu();

        _notifyIcon = new NotifyIcon
        {
            ContextMenuStrip = menu,
            Visible = true,
            Icon = _icons.Off,
        };
        _notifyIcon.MouseClick += (_, e) => { if (e.Button == MouseButtons.Left) Toggle(); };

        _poll = new System.Windows.Forms.Timer { Interval = PollIntervalMs };
        _poll.Tick += (_, _) => Refresh();
        _poll.Start();

        // Keep an existing logon entry pointing at wherever this copy now lives.
        try { StartupEntry.RepairIfStale(); } catch { /* best effort */ }

        Refresh();
    }

    private void ToggleStartup()
    {
        try
        {
            StartupEntry.Toggle();
        }
        catch (Exception ex)
        {
            MessageBox.Show($"自動起動の設定を変更できませんでした。\n\n{ex.Message}",
                            "ProxyToggle", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
        _startupItem.Checked = StartupEntry.IsEnabled;
    }

    private void Toggle()
    {
        try
        {
            ProxySettings.Set(!_state.Enabled);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"プロキシ設定を変更できませんでした。\n\n{ex.Message}",
                            "ProxyToggle", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
        Refresh();
    }

    /// <summary>Re-reads the registry so changes made elsewhere show up here too.</summary>
    private void Refresh()
    {
        var next = ProxySettings.Read();
        if (_painted && next == _state) return;

        _state = next;
        _painted = true;
        _notifyIcon.Icon = _icons.For(next.Enabled);
        _notifyIcon.Text = Truncate($"プロキシ {(next.Enabled ? "有効" : "無効")} — {next.ServerDisplay}", TooltipLimit);
    }

    private void UpdateMenu()
    {
        Refresh();
        _statusItem.Text = $"プロキシ: {(_state.Enabled ? "有効" : "無効")}";
        _serverItem.Text = $"  サーバー: {_state.ServerDisplay}";
        _toggleItem.Text = _state.Enabled ? "OFF にする" : "ON にする";
        _startupItem.Checked = StartupEntry.IsEnabled;
    }

    private static void OpenProxySettings()
    {
        try
        {
            Process.Start(new ProcessStartInfo("ms-settings:network-proxy") { UseShellExecute = true });
        }
        catch
        {
            Process.Start(new ProcessStartInfo("rundll32.exe", "inetcpl.cpl,LaunchConnectionDialog")
            { UseShellExecute = true });
        }
    }

    private static string Truncate(string value, int max) =>
        value.Length <= max ? value : value[..(max - 1)] + "…";

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _poll.Dispose();
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
            _icons.Dispose();
        }
        base.Dispose(disposing);
    }
}
