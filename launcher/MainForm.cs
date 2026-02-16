using System.Diagnostics;
using System.IO.Compression;
using System.Drawing.Drawing2D;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace KwLauncher;

public sealed class MainForm : Form
{
    private const string ConfigFileName = "launcher_config.json";
    private const string LocalVersionFileName = "game_version.txt";
    private const string TempPackageFileName = "kw_update.zip";
    private const string TempExeFileName = "kw.exe.new";
    private const string TempPckFileName = "kw.pck.new";
    private const string GameExeFileName = "kw.exe";
    private const string GamePckFileName = "kw.pck";

    private readonly Label _titleLabel = new();
    private readonly Label _subtitleLabel = new();
    private readonly Label _versionLabel = new();
    private readonly Label _statusLabel = new();
    private readonly Label _endpointLabel = new();
    private readonly Button _actionButton = new();
    private readonly Panel _accentBar = new();
    private readonly System.Windows.Forms.Timer _fxTimer = new();

    private LauncherConfig _config = LauncherConfig.Default;
    private UpdateManifest? _manifest;
    private LauncherMode _mode = LauncherMode.Connect;
    private bool _busy;
    private string _localVersion = "0.0.0";
    private float _fxPhase;

    private enum LauncherMode
    {
        Connect,
        Update
    }

    public MainForm()
    {
        Text = "KW Launcher";
        Width = 380;
        Height = 270;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = true;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(17, 26, 37);
        ForeColor = Color.FromArgb(232, 240, 248);
        Font = new Font("Segoe UI", 9, FontStyle.Regular);
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);
        UpdateStyles();
        Paint += (_, e) => DrawFuturisticBackground(e.Graphics);

        _accentBar.Left = 0;
        _accentBar.Top = 0;
        _accentBar.Width = Width;
        _accentBar.Height = 6;
        _accentBar.BackColor = Color.FromArgb(0, 196, 255);

        _titleLabel.Text = "KW";
        _titleLabel.Left = 20;
        _titleLabel.Top = 20;
        _titleLabel.Width = 340;
        _titleLabel.Font = new Font("Segoe UI", 22, FontStyle.Bold);
        _titleLabel.ForeColor = Color.FromArgb(234, 246, 255);
        _titleLabel.BackColor = Color.Transparent;
        _titleLabel.TextAlign = ContentAlignment.MiddleCenter;

        _subtitleLabel.Text = "Online Client";
        _subtitleLabel.Left = 20;
        _subtitleLabel.Top = 60;
        _subtitleLabel.Width = 340;
        _subtitleLabel.Font = new Font("Segoe UI Semibold", 10, FontStyle.Regular);
        _subtitleLabel.ForeColor = Color.FromArgb(130, 187, 214);
        _subtitleLabel.BackColor = Color.Transparent;
        _subtitleLabel.TextAlign = ContentAlignment.MiddleCenter;

        _versionLabel.Text = "Version: -";
        _versionLabel.Left = 20;
        _versionLabel.Top = 92;
        _versionLabel.Width = 340;
        _versionLabel.Font = new Font("Segoe UI", 9, FontStyle.Regular);
        _versionLabel.ForeColor = Color.FromArgb(172, 206, 224);
        _versionLabel.BackColor = Color.Transparent;
        _versionLabel.TextAlign = ContentAlignment.MiddleCenter;

        _statusLabel.Text = "Loading...";
        _statusLabel.Left = 20;
        _statusLabel.Top = 118;
        _statusLabel.Width = 340;
        _statusLabel.Height = 40;
        _statusLabel.ForeColor = Color.FromArgb(214, 228, 238);
        _statusLabel.BackColor = Color.Transparent;
        _statusLabel.TextAlign = ContentAlignment.MiddleCenter;

        _endpointLabel.Text = "";
        _endpointLabel.Left = 20;
        _endpointLabel.Top = 164;
        _endpointLabel.Width = 340;
        _endpointLabel.Font = new Font("Consolas", 9, FontStyle.Regular);
        _endpointLabel.ForeColor = Color.FromArgb(122, 168, 192);
        _endpointLabel.BackColor = Color.Transparent;
        _endpointLabel.TextAlign = ContentAlignment.MiddleCenter;

        _actionButton.Text = "Connect";
        _actionButton.Left = 95;
        _actionButton.Top = 192;
        _actionButton.Width = 190;
        _actionButton.Height = 40;
        _actionButton.FlatStyle = FlatStyle.Flat;
        _actionButton.FlatAppearance.BorderSize = 0;
        _actionButton.BackColor = Color.FromArgb(0, 167, 225);
        _actionButton.ForeColor = Color.FromArgb(11, 20, 28);
        _actionButton.Font = new Font("Segoe UI Semibold", 11, FontStyle.Regular);
        _actionButton.Cursor = Cursors.Hand;
        _actionButton.MouseEnter += (_, _) =>
        {
            if (!_busy)
            {
                _actionButton.BackColor = Color.FromArgb(23, 185, 244);
            }
        };
        _actionButton.MouseLeave += (_, _) =>
        {
            if (!_busy)
            {
                _actionButton.BackColor = Color.FromArgb(0, 167, 225);
            }
        };
        _actionButton.Click += async (_, _) =>
        {
            if (_mode == LauncherMode.Update)
            {
                await UpdateGameAsync();
            }
            else
            {
                LaunchGame();
            }
        };

        Controls.AddRange([_accentBar, _titleLabel, _subtitleLabel, _versionLabel, _statusLabel, _endpointLabel, _actionButton]);
        _fxTimer.Interval = 33;
        _fxTimer.Tick += (_, _) =>
        {
            _fxPhase = (_fxPhase + 0.9f) % 44f;
            Invalidate();
        };
        _fxTimer.Start();
        Shown += async (_, _) => await InitializeAsync();
        FormClosed += (_, _) => _fxTimer.Stop();
    }

    private async Task InitializeAsync()
    {
        _config = NormalizeConfig(LoadConfig());
        _endpointLabel.Text = $"{_config.DefaultHost}:{_config.DefaultPort}";
        await RefreshModeAsync();
    }

    private static LauncherConfig NormalizeConfig(LauncherConfig cfg)
    {
        var host = cfg.DefaultHost?.Trim() ?? "";
        var needsHostFix = string.IsNullOrWhiteSpace(host)
            || host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase)
            || host.Equals("localhost", StringComparison.OrdinalIgnoreCase);

        if (!needsHostFix || string.IsNullOrWhiteSpace(cfg.UpdateManifestUrl))
        {
            return cfg;
        }

        if (!Uri.TryCreate(cfg.UpdateManifestUrl, UriKind.Absolute, out var manifestUri))
        {
            return cfg;
        }

        if (manifestUri.IsLoopback || string.IsNullOrWhiteSpace(manifestUri.Host))
        {
            return cfg;
        }

        return new LauncherConfig
        {
            UpdateManifestUrl = cfg.UpdateManifestUrl,
            DefaultHost = manifestUri.Host,
            DefaultPort = cfg.DefaultPort
        };
    }

    private LauncherConfig LoadConfig()
    {
        var path = Path.Combine(AppContext.BaseDirectory, ConfigFileName);
        if (!File.Exists(path))
        {
            return LauncherConfig.Default;
        }

        try
        {
            var json = File.ReadAllText(path, Encoding.UTF8);
            var cfg = JsonSerializer.Deserialize<LauncherConfig>(json);
            return cfg ?? LauncherConfig.Default;
        }
        catch
        {
            return LauncherConfig.Default;
        }
    }

    private async Task RefreshModeAsync()
    {
        _manifest = null;
        _mode = LauncherMode.Connect;
        _actionButton.Text = "Connect";

        _localVersion = ReadLocalGameVersion();
        UpdateVersionLabel();
        if (string.IsNullOrWhiteSpace(_config.UpdateManifestUrl))
        {
            _statusLabel.Text = $"Ready (v{_localVersion})";
            return;
        }

        SetBusy(true);
        _statusLabel.Text = "Checking updates...";
        try
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
            var json = await client.GetStringAsync(_config.UpdateManifestUrl);
            _manifest = JsonSerializer.Deserialize<UpdateManifest>(json);
            if (_manifest is null || string.IsNullOrWhiteSpace(_manifest.Version))
            {
                _statusLabel.Text = "Manifest invalid. Connect only.";
                return;
            }

            var hasLocalGame = HasLocalGameFiles();
            var hasRemotePayload = HasDownloadPayload(_manifest);
            var hasHashMismatch = hasLocalGame && HasIntegrityMismatch(_manifest);
            var hasUpdate = hasRemotePayload && (
                !hasLocalGame
                || IsVersionNewer(_manifest.Version!, _localVersion)
                || hasHashMismatch
            );
            UpdateVersionLabel();
            if (hasUpdate)
            {
                _mode = LauncherMode.Update;
                _actionButton.Text = "Update";
                _statusLabel.Text = hasHashMismatch
                    ? $"Integrity mismatch. Update required ({_manifest.Version})"
                    : $"Update available: {_manifest.Version}";
            }
            else
            {
                _mode = LauncherMode.Connect;
                _actionButton.Text = "Connect";
                _statusLabel.Text = hasLocalGame
                    ? $"Ready (v{_localVersion})"
                    : "Game missing. Upload update payload.";
            }
        }
        catch
        {
            _statusLabel.Text = "No update check. Connect only.";
            UpdateVersionLabel();
        }
        finally
        {
            SetBusy(false);
        }
    }

    private string ReadLocalGameVersion()
    {
        var path = Path.Combine(AppContext.BaseDirectory, LocalVersionFileName);
        if (!File.Exists(path))
        {
            return "0.0.0";
        }
        return File.ReadAllText(path, Encoding.UTF8).Trim();
    }

    private void WriteLocalGameVersion(string version)
    {
        var path = Path.Combine(AppContext.BaseDirectory, LocalVersionFileName);
        File.WriteAllText(path, version, Encoding.UTF8);
        _localVersion = version;
    }

    private void UpdateVersionLabel()
    {
        var latestVersion = _manifest?.Version;
        _versionLabel.Text = string.IsNullOrWhiteSpace(latestVersion)
            ? $"Version: {_localVersion}"
            : $"Version: {_localVersion} | Latest: {latestVersion}";
    }

    private async Task UpdateGameAsync()
    {
        if (_manifest is null || string.IsNullOrWhiteSpace(_manifest.Version))
        {
            return;
        }

        SetBusy(true);
        _statusLabel.Text = "Downloading update...";
        try
        {
            var baseDir = AppContext.BaseDirectory;
            using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(3) };

            if (!string.IsNullOrWhiteSpace(_manifest.PackageUrl))
            {
                var tempZipPath = Path.Combine(baseDir, TempPackageFileName);
                var zipBytes = await client.GetByteArrayAsync(_manifest.PackageUrl);
                await File.WriteAllBytesAsync(tempZipPath, zipBytes);
                ZipFile.ExtractToDirectory(tempZipPath, baseDir, true);
                File.Delete(tempZipPath);
            }
            else
            {
                if (!string.IsNullOrWhiteSpace(_manifest.ExeUrl))
                {
                    var tempExePath = Path.Combine(baseDir, TempExeFileName);
                    var targetExePath = Path.Combine(baseDir, GameExeFileName);
                    var exeBytes = await client.GetByteArrayAsync(_manifest.ExeUrl);
                    await File.WriteAllBytesAsync(tempExePath, exeBytes);
                    File.Copy(tempExePath, targetExePath, true);
                    File.Delete(tempExePath);
                }

                if (!string.IsNullOrWhiteSpace(_manifest.PckUrl))
                {
                    var tempPckPath = Path.Combine(baseDir, TempPckFileName);
                    var targetPckPath = Path.Combine(baseDir, GamePckFileName);
                    var pckBytes = await client.GetByteArrayAsync(_manifest.PckUrl);
                    await File.WriteAllBytesAsync(tempPckPath, pckBytes);
                    File.Copy(tempPckPath, targetPckPath, true);
                    File.Delete(tempPckPath);
                }
            }

            if (HasIntegrityMismatch(_manifest))
            {
                throw new InvalidOperationException("Integrity check failed after update.");
            }

            WriteLocalGameVersion(_manifest.Version);
            UpdateVersionLabel();
            _statusLabel.Text = $"Updated to {_manifest.Version}";

            _mode = LauncherMode.Connect;
            _actionButton.Text = "Connect";
        }
        catch (Exception ex)
        {
            _statusLabel.Text = $"Update failed: {ex.Message}";
        }
        finally
        {
            SetBusy(false);
        }
    }

    private void LaunchGame()
    {
        var gameExe = Path.Combine(AppContext.BaseDirectory, GameExeFileName);
        var gamePck = Path.Combine(AppContext.BaseDirectory, GamePckFileName);
        if (!File.Exists(gameExe))
        {
            _statusLabel.Text = "kw.exe not found";
            return;
        }
        if (!File.Exists(gamePck))
        {
            _statusLabel.Text = "kw.pck not found";
            return;
        }

        var args = $"--mode=client --host={_config.DefaultHost} --port={_config.DefaultPort}";
        var psi = new ProcessStartInfo
        {
            FileName = gameExe,
            Arguments = args,
            WorkingDirectory = AppContext.BaseDirectory,
            UseShellExecute = false
        };

        try
        {
            Process.Start(psi);
            Close();
        }
        catch (Exception ex)
        {
            _statusLabel.Text = $"Launch failed: {ex.Message}";
        }
    }

    private void SetBusy(bool value)
    {
        _busy = value;
        _actionButton.Enabled = !_busy;
        _actionButton.BackColor = _busy
            ? Color.FromArgb(68, 103, 122)
            : Color.FromArgb(0, 167, 225);
    }

    private void DrawFuturisticBackground(Graphics g)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;

        using (var bgBrush = new LinearGradientBrush(
                   ClientRectangle,
                   Color.FromArgb(11, 18, 30),
                   Color.FromArgb(23, 34, 52),
                   LinearGradientMode.Vertical))
        {
            g.FillRectangle(bgBrush, ClientRectangle);
        }

        using (var glowBrush = new SolidBrush(Color.FromArgb(28, 0, 205, 255)))
        {
            g.FillEllipse(glowBrush, -70, 8, 220, 220);
            g.FillEllipse(glowBrush, Width - 170, Height - 170, 220, 220);
        }

        using (var gridPen = new Pen(Color.FromArgb(26, 100, 170, 210), 1f))
        {
            for (var x = -40; x < Width + 40; x += 22)
            {
                g.DrawLine(gridPen, x + _fxPhase, 0, x + _fxPhase - 34, Height);
            }
        }

        using (var panelBrush = new SolidBrush(Color.FromArgb(90, 8, 16, 28)))
        using (var borderPen = new Pen(Color.FromArgb(92, 80, 190, 230), 1.2f))
        {
            var cardRect = new Rectangle(14, 14, Width - 44, Height - 66);
            using var path = RoundedRect(cardRect, 14);
            g.FillPath(panelBrush, path);
            g.DrawPath(borderPen, path);
        }
    }

    private static GraphicsPath RoundedRect(Rectangle rect, int radius)
    {
        var path = new GraphicsPath();
        var diameter = radius * 2;
        var arc = new Rectangle(rect.Location, new Size(diameter, diameter));

        path.AddArc(arc, 180, 90);
        arc.X = rect.Right - diameter;
        path.AddArc(arc, 270, 90);
        arc.Y = rect.Bottom - diameter;
        path.AddArc(arc, 0, 90);
        arc.X = rect.Left;
        path.AddArc(arc, 90, 90);
        path.CloseFigure();
        return path;
    }

    private static bool IsVersionNewer(string remote, string local)
    {
        static int[] Parse(string s)
        {
            var matches = Regex.Matches(s ?? "", @"\d+");
            if (matches.Count == 0)
            {
                return [0];
            }

            var values = new int[matches.Count];
            for (var i = 0; i < matches.Count; i++)
            {
                values[i] = int.TryParse(matches[i].Value, out var v) ? v : 0;
            }
            return values;
        }

        var r = Parse(remote);
        var l = Parse(local);
        var count = Math.Max(r.Length, l.Length);
        for (var i = 0; i < count; i++)
        {
            var rv = i < r.Length ? r[i] : 0;
            var lv = i < l.Length ? l[i] : 0;
            if (rv > lv) return true;
            if (rv < lv) return false;
        }
        return false;
    }

    private static bool HasDownloadPayload(UpdateManifest manifest)
        => !string.IsNullOrWhiteSpace(manifest.PackageUrl)
           || !string.IsNullOrWhiteSpace(manifest.ExeUrl)
           || !string.IsNullOrWhiteSpace(manifest.PckUrl);

    private bool HasIntegrityMismatch(UpdateManifest manifest)
    {
        var baseDir = AppContext.BaseDirectory;
        var exePath = Path.Combine(baseDir, GameExeFileName);
        var pckPath = Path.Combine(baseDir, GamePckFileName);

        if (!string.IsNullOrWhiteSpace(manifest.ExeSha256)
            && File.Exists(exePath)
            && !string.Equals(ComputeSha256(exePath), manifest.ExeSha256, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if (!string.IsNullOrWhiteSpace(manifest.PckSha256)
            && File.Exists(pckPath)
            && !string.Equals(ComputeSha256(pckPath), manifest.PckSha256, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return false;
    }

    private static string ComputeSha256(string filePath)
    {
        using var stream = File.OpenRead(filePath);
        var hashBytes = SHA256.HashData(stream);
        return Convert.ToHexString(hashBytes).ToLowerInvariant();
    }

    private bool HasLocalGameFiles()
    {
        var baseDir = AppContext.BaseDirectory;
        return File.Exists(Path.Combine(baseDir, GameExeFileName))
               && File.Exists(Path.Combine(baseDir, GamePckFileName));
    }

    private sealed class LauncherConfig
    {
        [JsonPropertyName("update_manifest_url")]
        public string UpdateManifestUrl { get; init; } = "";

        [JsonPropertyName("default_host")]
        public string DefaultHost { get; init; } = "127.0.0.1";

        [JsonPropertyName("default_port")]
        public int DefaultPort { get; init; } = 8080;

        public static LauncherConfig Default => new();
    }

    private sealed class UpdateManifest
    {
        [JsonPropertyName("version")]
        public string? Version { get; init; }

        [JsonPropertyName("package_url")]
        public string? PackageUrl { get; init; }

        [JsonPropertyName("exe_url")]
        public string? ExeUrl { get; init; }

        [JsonPropertyName("pck_url")]
        public string? PckUrl { get; init; }

        [JsonPropertyName("exe_sha256")]
        public string? ExeSha256 { get; init; }

        [JsonPropertyName("pck_sha256")]
        public string? PckSha256 { get; init; }
    }
}
