using System;
using System.Net;
using System.Text.Json;

public class EcccCityGeocoder
{
    private const double BboxDelta = 0.3;
    private const string BaseUrl =
        "https://api.weather.gc.ca/collections/citypageweather-realtime/items?f=json&lang=en&limit=10";

    public static CityResolveResult Resolve(string? cityName)
    {
        string query = cityName?.Trim() ?? "";
        if (query.Length == 0)
            return CityResolveResult.Error("Enter a city name.");

        try
        {
            string url = BaseUrl + "&name.en=" + Uri.EscapeDataString(query);
            using var doc = JsonDocument.Parse(DownloadString(url));

            if (!doc.RootElement.TryGetProperty("features", out JsonElement features))
                return CityResolveResult.Error("No results from the weather service.");

            JsonElement? best = null;
            string? bestName = null;
            int bestScore = int.MaxValue;

            foreach (JsonElement feature in features.EnumerateArray())
            {
                if (!feature.TryGetProperty("properties", out JsonElement props))
                    continue;
                if (!props.TryGetProperty("name", out JsonElement nameEl) ||
                    !nameEl.TryGetProperty("en", out JsonElement enEl))
                    continue;

                string? name = enEl.GetString();
                if (string.IsNullOrWhiteSpace(name))
                    continue;

                string baseName = name.Split('(')[0].Trim();
                int score;
                if (string.Equals(name, query, StringComparison.OrdinalIgnoreCase))
                    score = 0;
                else if (string.Equals(baseName, query, StringComparison.OrdinalIgnoreCase))
                    score = 1 + name.Length;
                else if (name.Contains(query, StringComparison.OrdinalIgnoreCase))
                    score = 100 + name.Length;
                else
                    continue;

                if (score < bestScore)
                {
                    bestScore = score;
                    best = feature;
                    bestName = name;
                }
            }

            if (best == null)
                return CityResolveResult.Error($"Could not find a city named \"{query}\".");

            if (!best.Value.TryGetProperty("geometry", out JsonElement geom) ||
                !geom.TryGetProperty("coordinates", out JsonElement coords) ||
                coords.GetArrayLength() < 2)
                return CityResolveResult.Error($"No coordinates found for \"{bestName}\".");

            double lon = coords[0].GetDouble();
            double lat = coords[1].GetDouble();

            return new CityResolveResult
            {
                Success = true,
                Name = bestName ?? query,
                Lon = lon,
                Lat = lat,
                MinLon = lon - BboxDelta,
                MinLat = lat - BboxDelta,
                MaxLon = lon + BboxDelta,
                MaxLat = lat + BboxDelta
            };
        }
        catch (Exception ex)
        {
            return CityResolveResult.Error($"Request failed: {ex.Message}");
        }
    }

    private static string DownloadString(string url)
    {
        using var client = new WebClient();
        client.Headers.Add("User-Agent", "DeskAlert/1.0 (contact: lapiscodes@gmail.com)");
        return client.DownloadString(url);
    }
}

public class CityResolveResult
{
    public bool Success { get; set; }
    public string Message { get; set; } = "";
    public string? Name { get; set; }
    public double Lon { get; set; }
    public double Lat { get; set; }
    public double MinLon { get; set; }
    public double MinLat { get; set; }
    public double MaxLon { get; set; }
    public double MaxLat { get; set; }

    public static CityResolveResult Error(string message) =>
        new() { Success = false, Message = message };
}
