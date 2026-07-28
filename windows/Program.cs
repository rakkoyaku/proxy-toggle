namespace ProxyToggle;

internal static class Program
{
    private const string MutexName = @"Local\ProxyToggle.SingleInstance";

    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length > 0) return RunCommand(args[0]);

        using var mutex = new Mutex(initiallyOwned: true, MutexName, out var isFirstInstance);
        if (!isFirstInstance)
        {
            MessageBox.Show("ProxyToggle はすでに起動しています。", "ProxyToggle",
                            MessageBoxButtons.OK, MessageBoxIcon.Information);
            return 0;
        }

        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new TrayApp());
        return 0;
    }

    /// <summary>
    /// Headless mode, so the same binary is scriptable:
    /// ProxyToggle.exe --status | --on | --off | --toggle
    /// </summary>
    private static int RunCommand(string arg)
    {
        var attached = AttachToParentConsole();
        try
        {
            switch (arg.TrimStart('-', '/').ToLowerInvariant())
            {
                case "status":
                    var state = ProxySettings.Read();
                    Console.WriteLine($"{(state.Enabled ? "on" : "off")}\t{state.Server}\t{state.Bypass}");
                    return 0;
                case "on":
                    ProxySettings.Set(true);
                    Console.WriteLine("on");
                    return 0;
                case "off":
                    ProxySettings.Set(false);
                    Console.WriteLine("off");
                    return 0;
                case "toggle":
                    Console.WriteLine(ProxySettings.Toggle() ? "on" : "off");
                    return 0;
                default:
                    Console.Error.WriteLine("usage: ProxyToggle.exe [--status|--on|--off|--toggle]");
                    return 2;
            }
        }
        finally
        {
            Console.Out.Flush();
            if (attached) NativeMethods.FreeConsole();
        }
    }

    /// <summary>
    /// This is a WinExe, so it starts without a console. Borrow the caller's console —
    /// but only when stdout is not already redirected, otherwise attaching would steal
    /// the standard handles away from the caller's pipe and the output would vanish.
    /// </summary>
    private static bool AttachToParentConsole()
    {
        var stdout = NativeMethods.GetStdHandle(NativeMethods.STD_OUTPUT_HANDLE);
        if (stdout != IntPtr.Zero && stdout != NativeMethods.INVALID_HANDLE_VALUE) return false;
        if (!NativeMethods.AttachConsole(NativeMethods.ATTACH_PARENT_PROCESS)) return false;

        // Console.Out was bound to a null writer at startup; rebind it to the real handle.
        Console.SetOut(new StreamWriter(Console.OpenStandardOutput()) { AutoFlush = true });
        Console.SetError(new StreamWriter(Console.OpenStandardError()) { AutoFlush = true });
        return true;
    }
}
