using System.Diagnostics;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
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
    private readonly Label _statusLabel = new();
    private readonly Button _actionButton = new();

    private LauncherConfig _config = LauncherConfig.Default;
    private UpdateManifest? _manifest;
    private LauncherMode _mode = LauncherMode.Connect;
    private bool _busy;

    private enum LauncherMode
    {
        Connect,
        Update
    }

    public MainForm()
    {
        Text = "KW Launcher";
        Width = 320;
        Height = 190;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = true;
        StartPosition = FormStartPosition.CenterScreen;

        _titleLabel.Text = "KW";
        _titleLabel.Left = 20;
        _titleLabel.Top = 18;
        _titleLabel.Width = 260;
        _titleLabel.Font = new Font("Segoe UI", 16, FontStyle.Bold);
        _titleLabel.TextAlign = ContentAlignment.MiddleCenter;

        _statusLabel.Text = "Loading...";
        _statusLabel.Left = 20;
        _statusLabel.Top = 56;
        _statusLabel.Width = 260;
        _statusLabel.TextAlign = ContentAlignment.MiddleCenter;

        _actionButton.Text = "Connect";
        _actionButton.Left = 90;
        _actionButton.Top = 92;
        _actionButton.Width = 120;
        _actionButton.Height = 34;
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

        Controls.AddRange([_titleLabel, _statusLabel, _actionButton]);
        Shown += async (_, _) => await InitializeAsync();
    }

    private async Task InitializeAsync()
    {
        _config = LoadConfig();
        await RefreshModeAsync();
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

        var localVersion = ReadLocalGameVersion();
        if (string.IsNullOrWhiteSpace(_config.UpdateManifestUrl))
        {
            _statusLabel.Text = $"Ready (v{localVersion})";
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
            var hasUpdate = hasRemotePayload && (!hasLocalGame || IsVersionNewer(_manifest.Version!, localVersion));
            if (hasUpdate)
            {
                _mode = LauncherMode.Update;
                _actionButton.Text = "Update";
                _statusLabel.Text = $"Update available: {_manifest.Version}";
            }
            else
            {
                _mode = LauncherMode.Connect;
                _actionButton.Text = "Connect";
                _statusLabel.Text = hasLocalGame
                    ? $"Ready (v{localVersion})"
                    : "Game missing. Upload update payload.";
            }
        }
        catch
        {
            _statusLabel.Text = "No update check. Connect only.";
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

            WriteLocalGameVersion(_manifest.Version);
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
    }

    private static bool IsVersionNewer(string remote, string local)
    {
        static int[] Parse(string s)
            => s.Split('.').Select(x => int.TryParse(x, out var v) ? v : 0).ToArray();

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
    }
}
