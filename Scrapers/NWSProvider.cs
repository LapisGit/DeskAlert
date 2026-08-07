using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Xml.Linq;
using DeskAlert;

public class NWSProvider
{
    private const string AtomFeedUrl = "https://api.weather.gov/alerts/active.atom";

    public List<NwsAlertItem> GetMatchingAlerts()
    {
        string atomXml = DownloadString(AtomFeedUrl);

        XDocument doc = XDocument.Parse(atomXml);
        XNamespace atom = "http://www.w3.org/2005/Atom";
        XNamespace cap = "urn:oasis:names:tc:emergency:cap:1.2";

        List<NwsAlertItem> results = new();

        foreach (XElement entry in doc.Descendants(atom + "entry"))
        {
            string? title = entry.Element(atom + "title")?.Value;
            string? updated = entry.Element(atom + "updated")?.Value;
            string? link = entry.Elements(atom + "link")
                .FirstOrDefault(x => (string?)x.Attribute("rel") == "alternate")?
                .Attribute("href")?.Value;

            if (string.IsNullOrWhiteSpace(link))
                continue;

            string alertXml = DownloadString(link);
            XDocument alertDoc = XDocument.Parse(alertXml);

            var sameCodes = Config.currentConfig.locations.SAMECodes;
            if (sameCodes == null || sameCodes.Count == 0 ||
                !ContainsAnySameCode(alertDoc, sameCodes))
                continue;

            var info = alertDoc.Descendants(cap + "info").FirstOrDefault();

            var item = new NwsAlertItem
            {
                Title = title,
                Updated = updated,
                Link = link,
                EventType = alertDoc.Descendants(cap + "event").FirstOrDefault()?.Value,
                Description = info?.Element(cap + "description")?.Value,
                Severity = info?.Element(cap + "severity")?.Value ?? "Unknown",
                Expires = info?.Element(cap + "expires")?.Value ?? "",
                RawAtomEntry = entry.ToString()
            };

            results.Add(item);
        }

        return results;
    }

    private static string DownloadString(string url)
    {
        using var client = new WebClient();
        client.Headers.Add("User-Agent", "DeskAlert/1.0 (contact: lapiscodes@gmail.com)");
        return client.DownloadString(url);
    }

    private static bool ContainsAnySameCode(XDocument alertDoc, IEnumerable<string> sameCodes)
    {
        string text = string.Join(" ", alertDoc.Descendants().Select(x => x.Value));

        foreach (string code in sameCodes.Where(x => !string.IsNullOrWhiteSpace(x)))
        {
            if (text.Contains(code, StringComparison.OrdinalIgnoreCase))
                return true;
        }

        return false;
    }
}

public class NwsAlertItem
{
    public string? Title { get; set; }
    public string? Updated { get; set; }
    public string? Link { get; set; }
    public string? EventType { get; set; }
    public string? Description { get; set; }
    public string? Severity { get; set; }
    public string? Expires { get; set; }
    public string? RawAtomEntry { get; set; }
}
