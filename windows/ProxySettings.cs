using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace ProxyToggle;

/// <summary>
/// Reads and writes the per-user WinINET proxy configuration — the same settings
/// exposed by Settings &gt; Network &amp; Internet &gt; Proxy. Everything lives under
/// HKEY_CURRENT_USER, so no elevation is required.
/// </summary>
internal static class ProxySettings
{
    private const string SettingsKey = @"Software\Microsoft\Windows\CurrentVersion\Internet Settings";
    private const string ConnectionsKey = SettingsKey + @"\Connections";

    /// <summary>Bit 1 of the per-connection flags DWORD: "use a manual proxy server".</summary>
    private const int ManualProxyFlag = 0x02;

    public readonly record struct State(bool Enabled, string Server, string Bypass)
    {
        public string ServerDisplay => string.IsNullOrWhiteSpace(Server) ? "(未設定)" : Server;
    }

    public static State Read()
    {
        using var key = Registry.CurrentUser.OpenSubKey(SettingsKey);
        if (key is null) return new State(false, "", "");

        var enabled = key.GetValue("ProxyEnable") is int v && v != 0;
        var server = key.GetValue("ProxyServer") as string ?? "";
        var bypass = key.GetValue("ProxyOverride") as string ?? "";
        return new State(enabled, server, bypass);
    }

    public static void Set(bool enable)
    {
        using (var key = Registry.CurrentUser.CreateSubKey(SettingsKey, writable: true))
        {
            key.SetValue("ProxyEnable", enable ? 1 : 0, RegistryValueKind.DWord);
        }

        PatchConnectionBlobs(enable);
        NotifyWinInet();
    }

    public static bool Toggle()
    {
        var next = !Read().Enabled;
        Set(next);
        return next;
    }

    /// <summary>
    /// ProxyEnable alone is not always honoured: WinINET also keeps a binary blob per
    /// connection (DefaultConnectionSettings, SavedLegacySettings, …) whose flags DWORD
    /// at offset 8 decides between direct / manual proxy / PAC. Flip the manual-proxy bit
    /// there too and bump the revision counter at offset 4 so the blob is reloaded.
    /// </summary>
    private static void PatchConnectionBlobs(bool enable)
    {
        using var connections = Registry.CurrentUser.OpenSubKey(ConnectionsKey, writable: true);
        if (connections is null) return;

        foreach (var name in connections.GetValueNames())
        {
            if (connections.GetValueKind(name) != RegistryValueKind.Binary) continue;
            if (connections.GetValue(name) is not byte[] blob || blob.Length < 12) continue;

            var flags = BitConverter.ToInt32(blob, 8);
            var updated = enable ? flags | ManualProxyFlag : flags & ~ManualProxyFlag;
            if (updated == flags) continue;

            BitConverter.GetBytes(updated).CopyTo(blob, 8);
            BitConverter.GetBytes(BitConverter.ToInt32(blob, 4) + 1).CopyTo(blob, 4);
            connections.SetValue(name, blob, RegistryValueKind.Binary);
        }
    }

    private const int INTERNET_OPTION_REFRESH = 37;
    private const int INTERNET_OPTION_SETTINGS_CHANGED = 39;

    [DllImport("wininet.dll", SetLastError = true)]
    private static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);

    /// <summary>Tell already-running processes to pick the new settings up immediately.</summary>
    private static void NotifyWinInet()
    {
        InternetSetOption(IntPtr.Zero, INTERNET_OPTION_SETTINGS_CHANGED, IntPtr.Zero, 0);
        InternetSetOption(IntPtr.Zero, INTERNET_OPTION_REFRESH, IntPtr.Zero, 0);
    }
}
