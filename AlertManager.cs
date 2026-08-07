using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using Qt.MetaObject;
using Qt.Quick;

namespace DeskAlert;

[QmlElement]
public class AlertManager
{
    private static AlertManager? _instance;
    private readonly NWSProvider _nwsProvider = new();
    private readonly EcccProvider _ecccProvider = new();
    private readonly HashSet<string> _shownAlerts = new();
    private readonly ConcurrentQueue<NwsAlertItem> _pendingAlerts = new();
    private readonly DateTime _startupTime = DateTime.UtcNow;
    private System.Threading.Timer? _timer;

    [QProperty] public string AlertTitle { get; set; } = "";
    [QProperty] public string AlertDescription { get; set; } = "";
    [QProperty] public string AlertColor { get; set; } = "#FF0000";
    [QProperty] public string AlertExpiry { get; set; } = "";
    [QProperty] public string AlertSoundPath { get; set; } = "";
    [QProperty] public string AlertSeverity { get; set; } = "";
    [QProperty] public bool AlertVisible { get; set; }
    [QProperty] public string AlertType { get; set; } = "";

    public AlertManager()
    {
        _instance = this;
    }

    public void StartPolling()
    {
        _timer = new System.Threading.Timer(_ => Poll(), null, TimeSpan.Zero, TimeSpan.FromSeconds(30));
    }

    public void StopPolling()
    {
        _timer?.Dispose();
        _timer = null;
    }

    public static void PollNow()
    {
        _instance?.Poll();
    }

    private void Poll()
    {
        var alerts = new List<NwsAlertItem>();

        try
        {
            alerts.AddRange(_nwsProvider.GetMatchingAlerts());
        }
        catch (Exception ex)
        {
            Console.WriteLine($"NWS poll error: {ex.Message}");
        }

        try
        {
            alerts.AddRange(_ecccProvider.GetMatchingAlerts());
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ECCC poll error: {ex.Message}");
        }

        foreach (var alert in alerts)
        {
            var id = alert.Link ?? alert.Title ?? "";
            if (!_shownAlerts.Add(id))
                continue;

            if (Config.currentConfig.other.ignoreFirstScan
                && DateTime.TryParse(alert.Updated, out var updatedTime)
                && updatedTime < _startupTime)
            {
                continue;
            }

            _pendingAlerts.Enqueue(alert);
        }
    }

    public bool CheckForNewAlerts()
    {
        if (!_pendingAlerts.TryDequeue(out var alert))
            return false;

        AlertTitle = alert.Title ?? "";
        AlertDescription = alert.Description ?? "";
        AlertExpiry = alert.Expires ?? "";
        AlertSeverity = alert.Severity ?? "Unknown";
        AlertType = alert.EventType ?? "";
        
        Console.WriteLine(alert.Severity);

        var cfg = Config.currentConfig;
        var sev = AlertSeverity.ToLowerInvariant();

        bool enabled;
        if (sev.Contains("extreme") || sev.Contains("severe"))
        {
            enabled = cfg.severities.severe;
            AlertColor = cfg.alertColors.severe;
            AlertSoundPath = cfg.alertSound.severePath;
        }
        else if (sev.Contains("moderate"))
        {
            enabled = cfg.severities.moderate;
            AlertColor = cfg.alertColors.moderate;
            AlertSoundPath = cfg.alertSound.moderatePath;
        }
        else
        {
            enabled = cfg.severities.minor;
            AlertColor = cfg.alertColors.minor;
            AlertSoundPath = cfg.alertSound.minorPath;
        }

        if (!cfg.alertSound.enabled)
        {
            AlertSoundPath = "";
        }

        if (!enabled)
            return false;

        AlertVisible = true;
        return true;
    }

    public void DismissAlert()
    {
        AlertVisible = false;
    }
}
