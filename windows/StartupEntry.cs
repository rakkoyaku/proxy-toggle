using Microsoft.Win32;

namespace ProxyToggle;

/// <summary>
/// "Run at logon" via the per-user Run key. HKCU, so no elevation.
/// The installer removes this value on uninstall, whoever wrote it.
/// </summary>
internal static class StartupEntry
{
    public const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    public const string ValueName = "ProxyToggle";

    private static string CommandLine => $"\"{Environment.ProcessPath}\"";

    private static string? Current
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey);
            return key?.GetValue(ValueName) as string;
        }
    }

    /// <summary>
    /// True when an entry exists at all — not only when it points at this exact binary.
    /// An entry left behind by an older install still launches something at logon, so
    /// reporting it as "off" would be a lie.
    /// </summary>
    public static bool IsEnabled => Current is not null;

    public static void Enable()
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey, writable: true);
        key.SetValue(ValueName, CommandLine, RegistryValueKind.String);
    }

    public static void Disable()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true);
        key?.DeleteValue(ValueName, throwOnMissingValue: false);
    }

    public static void Toggle()
    {
        if (IsEnabled) Disable();
        else Enable();
    }

    /// <summary>
    /// Repoint a stale entry at the current binary. Moving the app, or switching between
    /// the portable and installed copies, otherwise leaves the logon entry aimed at a
    /// path that may no longer exist.
    /// </summary>
    public static void RepairIfStale()
    {
        if (Current is not { } existing) return;
        if (string.Equals(existing, CommandLine, StringComparison.OrdinalIgnoreCase)) return;
        Enable();
    }
}
