using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;

namespace WifiClashGuard
{
    internal sealed class Settings
    {
        public string WifiName;
        public static Settings Parse(string json)
        {
            var value = new JavaScriptSerializer().DeserializeObject(json) as Dictionary<string, object>;
            if (value == null || value.Count != 1 || !value.ContainsKey("wifiName") || !(value["wifiName"] is string))
                throw new InvalidDataException("config must contain only wifiName (string)");
            string name = (string)value["wifiName"];
            if (String.IsNullOrWhiteSpace(name) || name == "YOUR_WIFI_NAME" || Encoding.UTF8.GetByteCount(name) > 32)
                throw new InvalidDataException("set a nonempty Wi-Fi name, at most 32 UTF-8 bytes");
            return new Settings { WifiName = name };
        }
        public bool Matches(string[] connected)
        {
            foreach (string name in connected)
                if (name != null && name.StartsWith(WifiName, StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }
    }

    internal sealed class StopResult
    {
        public int Stopped;
        public int Failed;
    }
    internal interface IProcessController { StopResult StopTargets(); }
    internal sealed class CheckResult
    {
        public bool Matched;
        public StopResult Processes;
    }
    internal static class Guard
    {
        public static CheckResult Check(Settings settings, string[] connected, IProcessController controller)
        {
            bool matched = settings.Matches(connected);
            return new CheckResult { Matched = matched, Processes = matched ? controller.StopTargets() : new StopResult() };
        }
    }
}
