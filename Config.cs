using System.Text.Json;
using Qt.MetaObject;
using Qt.Quick;

namespace DeskAlert;

public class Config
{
    public static ConfigDTO currentConfig { get; private set; } = new ConfigDTO();
    public static bool IsFirstRun { get; private set; }
    
    public static string configPath = "config.json";
    public static string defaultConfigPath = "qrc:/assemblies/DeskAlert/defaultconfig.json";
    
    public static void LoadConfig()
    {
        if (!File.Exists(configPath))
        {
            IsFirstRun = true;
            string defaultJson = Qt.Resources.ReadAllText(defaultConfigPath);
        
            currentConfig = JsonSerializer.Deserialize<ConfigDTO>(defaultJson, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            }) ?? new ConfigDTO();
            
            EnsureDefaults();
            SaveConfig();
            
            Qml.LoadFromRootModule("SettingsWindow");
            
            return;
        }
        
        string json = File.ReadAllText(configPath);
        
        currentConfig = JsonSerializer.Deserialize<ConfigDTO>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        }) ?? new ConfigDTO();
        
        EnsureDefaults();
    }
    
    private static void EnsureDefaults()
    {
        currentConfig.alertSound ??= new AlertSound();
        currentConfig.alertColors ??= new AlertColors();
        currentConfig.severities ??= new Severities();
        currentConfig.locations ??= new Locations();
        currentConfig.locations.SAMECodes ??= new List<string>();
        currentConfig.locations.CAPCPCodes ??= new List<string>();
    }

    public static void SaveConfig()
    {
        
        Console.WriteLine("saved");
        
        string json = JsonSerializer.Serialize(currentConfig, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
        
        File.WriteAllText(configPath, json);
    }
}

[QmlElement]
public class ConfigDTO
{
    [QProperty] public AlertSound alertSound { get; set; }
    [QProperty] public AlertColors alertColors { get; set; }
    [QProperty] public Severities severities { get; set; }
    [QProperty] public Locations locations { get; set; }
}

[QmlElement]
public class AlertSound
{
    [QProperty] public bool enabled { get; set; }
    [QProperty] public string minorPath { get; set; }
    [QProperty] public string moderatePath { get; set; }
    [QProperty] public string severePath { get; set; }
}

[QmlElement]
public class Locations
{
    [QProperty] public List<string> SAMECodes { get; set; }
    [QProperty] public List<string> CAPCPCodes { get; set; }
}

[QmlElement]
public class AlertColors
{
    [QProperty] public string minor { get; set; }
    [QProperty] public string moderate { get; set; }
    [QProperty] public string severe { get; set; }
}

[QmlElement]
public class Severities
{
    [QProperty] public bool minor { get; set; }
    [QProperty] public bool moderate { get; set; }
    [QProperty] public bool severe { get; set; }
}

[QmlElement]
public class ConfigService
{
    [QProperty]
    public ConfigDTO AppConfig => Config.currentConfig;

    public bool IsFirstRun => Config.IsFirstRun;

    public void Save()
    {
        Config.SaveConfig();
        AlertManager.PollNow();
    }

    public string GetSameCodes()
    {
        var codes = Config.currentConfig.locations?.SAMECodes;
        if (codes == null || codes.Count == 0) return "";
        return string.Join(",", codes);
    }

    public void SetSameCodes(string csv)
    {
        Config.currentConfig.locations.SAMECodes = ParseCsv(csv);
    }

    public string GetCapcpCodes()
    {
        var codes = Config.currentConfig.locations?.CAPCPCodes;
        if (codes == null || codes.Count == 0) return "";
        return string.Join(",", codes);
    }

    public void SetCapcpCodes(string csv)
    {
        Config.currentConfig.locations.CAPCPCodes = ParseCsv(csv);
    }

    private static List<string> ParseCsv(string csv)
    {
        var list = new List<string>();
        foreach (var part in csv.Split(',', StringSplitOptions.RemoveEmptyEntries))
        {
            var trimmed = part.Trim();
            if (trimmed.Length > 0)
                list.Add(trimmed);
        }
        return list;
    }
}
