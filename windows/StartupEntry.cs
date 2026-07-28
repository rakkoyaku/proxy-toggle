using Microsoft.Win32;

namespace ProxyToggle;

/// <summary>Per-user "run at logon" entry. HKCU, so no elevation.</summary>
internal static class StartupEntry
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "ProxyToggle";

    private static string CommandLine => $"\"{Environment.ProcessPath}\"";

    public static bool IsEnabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey);
            return key?.GetValue(ValueName) is string existing
                   && string.Equals(existing, CommandLine, StringComparison.OrdinalIgnoreCase);
        }
    }

    public static void Toggle()
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey, writable: true);
        if (IsEnabled) key.DeleteValue(ValueName, throwOnMissingValue: false);
        else key.SetValue(ValueName, CommandLine, RegistryValueKind.String);
    }
}
