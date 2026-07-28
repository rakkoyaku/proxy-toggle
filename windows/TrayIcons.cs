using System.Drawing.Drawing2D;

namespace ProxyToggle;

/// <summary>
/// Draws the notification-area icons at runtime, so the state is readable at a glance
/// without shipping .ico resources: a filled green dot when the proxy is on, a hollow
/// grey ring when it is off.
/// </summary>
internal sealed class TrayIcons : IDisposable
{
    private static readonly Color OnColor = Color.FromArgb(48, 209, 88);
    private static readonly Color OffColor = Color.FromArgb(142, 142, 147);

    public Icon On { get; }
    public Icon Off { get; }

    public TrayIcons()
    {
        var size = Math.Max(16, SystemInformation.SmallIconSize.Width);
        On = Render(size, OnColor, filled: true);
        Off = Render(size, OffColor, filled: false);
    }

    public Icon For(bool enabled) => enabled ? On : Off;

    private static Icon Render(int size, Color color, bool filled)
    {
        using var bitmap = new Bitmap(size, size);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);

            var stroke = Math.Max(2f, size / 8f);
            var inset = stroke;
            var box = new RectangleF(inset, inset, size - inset * 2, size - inset * 2);

            if (filled)
            {
                using var brush = new SolidBrush(color);
                g.FillEllipse(brush, box);
            }

            using var pen = new Pen(color, stroke);
            g.DrawEllipse(pen, box);
        }

        // Icon.FromHandle does not own the HICON, so keep a managed copy and release
        // the native handle right away instead of leaking one per icon.
        var handle = bitmap.GetHicon();
        try
        {
            using var temp = Icon.FromHandle(handle);
            return (Icon)temp.Clone();
        }
        finally
        {
            NativeMethods.DestroyIcon(handle);
        }
    }

    public void Dispose()
    {
        On.Dispose();
        Off.Dispose();
    }
}
