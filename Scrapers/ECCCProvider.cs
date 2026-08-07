using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text.Json;
using DeskAlert;

public class EcccProvider
{
    private const string AlertApiUrl =
        "https://api.weather.gc.ca/collections/weather-alerts/items?f=json&lang=en&limit=500";

    private readonly Dictionary<string, CityResolveResult> _cityCache = new();

    public List<NwsAlertItem> GetMatchingAlerts()
    {
        var cityBoxes = GetCityBoxes();

        List<NwsAlertItem> results = new();

        using var doc = JsonDocument.Parse(DownloadString(AlertApiUrl));
        if (!doc.RootElement.TryGetProperty("features", out JsonElement features))
            return results;

        foreach (JsonElement feature in features.EnumerateArray())
        {
            if (!feature.TryGetProperty("properties", out JsonElement props))
                continue;

            if (cityBoxes.Count > 0)
            {
                var alertBbox = GetFeatureBbox(feature);
                if (alertBbox == null || !OverlapsAnyCity(alertBbox.Value, cityBoxes))
                    continue;
            }

            string? status = GetString(props, "status_en");
            if (string.Equals(status, "ended", StringComparison.OrdinalIgnoreCase))
                continue;

            string? alertName = GetString(props, "alert_name_en");
            if (string.IsNullOrWhiteSpace(alertName))
                continue;

            results.Add(new NwsAlertItem
            {
                Title = alertName,
                Updated = GetString(props, "publication_datetime"),
                Link = GetAlertId(feature),
                EventType = alertName,
                Description = GetString(props, "alert_text_en"),
                Severity = MapSeverity(GetString(props, "alert_type")),
                Expires = GetString(props, "expiration_datetime") ?? "",
                RawAtomEntry = feature.GetRawText()
            });
        }

        return results;
    }

    private static string? GetString(JsonElement obj, string name)
    {
        return obj.TryGetProperty(name, out JsonElement el) ? el.GetString() : null;
    }

    private List<CityResolveResult> GetCityBoxes()
    {
        var boxes = new List<CityResolveResult>();
        foreach (var city in Config.currentConfig.locations?.Cities ?? Enumerable.Empty<string>())
        {
            var name = city?.Trim();
            if (string.IsNullOrWhiteSpace(name))
                continue;

            if (!_cityCache.TryGetValue(name, out var resolved))
            {
                resolved = EcccCityGeocoder.Resolve(name);
                if (resolved.Success)
                    _cityCache[name] = resolved;
            }

            if (resolved.Success)
                boxes.Add(resolved);
        }
        return boxes;
    }

    private static (double MinLon, double MinLat, double MaxLon, double MaxLat)? GetFeatureBbox(JsonElement feature)
    {
        if (!feature.TryGetProperty("geometry", out JsonElement geom) ||
            !geom.TryGetProperty("coordinates", out JsonElement coords))
            return null;

        double minLon = double.MaxValue, minLat = double.MaxValue;
        double maxLon = double.MinValue, maxLat = double.MinValue;

        if (!CollectCoords(coords, ref minLon, ref minLat, ref maxLon, ref maxLat))
            return null;

        return (minLon, minLat, maxLon, maxLat);
    }

    private static bool CollectCoords(JsonElement element, ref double minLon, ref double minLat, ref double maxLon, ref double maxLat)
    {
        if (element.ValueKind == JsonValueKind.Array)
        {
            if (element.GetArrayLength() == 2 &&
                element[0].ValueKind == JsonValueKind.Number &&
                element[1].ValueKind == JsonValueKind.Number)
            {
                double lon = element[0].GetDouble();
                double lat = element[1].GetDouble();
                minLon = Math.Min(minLon, lon);
                maxLon = Math.Max(maxLon, lon);
                minLat = Math.Min(minLat, lat);
                maxLat = Math.Max(maxLat, lat);
                return true;
            }

            bool any = false;
            foreach (JsonElement child in element.EnumerateArray())
                any |= CollectCoords(child, ref minLon, ref minLat, ref maxLon, ref maxLat);
            return any;
        }

        return false;
    }

    private static bool OverlapsAnyCity(
        (double MinLon, double MinLat, double MaxLon, double MaxLat) alertBbox,
        List<CityResolveResult> cityBoxes)
    {
        foreach (var city in cityBoxes)
        {
            if (!(alertBbox.MaxLon < city.MinLon || alertBbox.MinLon > city.MaxLon ||
                  alertBbox.MaxLat < city.MinLat || alertBbox.MinLat > city.MaxLat))
                return true;
        }
        return false;
    }

    private static string GetAlertId(JsonElement feature)
    {
        string? id = feature.TryGetProperty("id", out JsonElement el) ? el.GetString() : null;
        if (string.IsNullOrEmpty(id))
            return Guid.NewGuid().ToString();

        int separator = id.IndexOf("_fea", StringComparison.Ordinal);
        return separator > 0 ? id.Substring(0, separator) : id;
    }

    private static string MapSeverity(string? alertType)
    {
        return alertType?.ToLowerInvariant() switch
        {
            "warning" => "Severe",
            "watch" => "Moderate",
            "advisory" => "Minor",
            "statement" => "Minor",
            _ => "Minor"
        };
    }

    private static string DownloadString(string url)
    {
        using var client = new WebClient();
        client.Headers.Add("User-Agent", "DeskAlert/1.0 (contact: lapiscodes@gmail.com)");
        return client.DownloadString(url);
    }
}
