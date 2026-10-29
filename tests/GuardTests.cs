using System;
using System.IO;
using System.Text;

namespace WifiClashGuard
{
    internal sealed class FakeProcesses : IProcessController
    {
        public int Calls;
        public StopResult StopTargets() { Calls++; return new StopResult { Stopped = 2 }; }
    }
    internal static class GuardTests
    {
        private static int assertions;
        private static void Assert(bool condition, string name)
        {
            assertions++;
            if (!condition) throw new Exception(name);
        }
        private static void Reject(string json)
        {
            bool rejected = false;
            try { Settings.Parse(json); } catch { rejected = true; }
            Assert(rejected, "invalid config must be rejected");
        }
        private static int Main()
        {
            try
            {
                var config = Settings.Parse("{\"wifiName\":\"Campus\"}");
                var fake = new FakeProcesses();
                Assert(!Guard.Check(config, new string[] { "Home" }, fake).Matched && fake.Calls == 0, "non-target network must not stop processes");
                Assert(!Guard.Check(config, new string[0], fake).Matched && fake.Calls == 0, "disconnected must not stop processes");
                var result = Guard.Check(config, new string[] { "Home", "campus_guest" }, fake);
                Assert(result.Matched && fake.Calls == 1 && result.Processes.Stopped == 2, "case-insensitive prefix and multiple adapters");
                Assert(!config.Matches(new string[] { "MyCampus" }), "prefix only");
                Assert(Settings.Parse("{\"wifiName\":\"A*\"}").Matches(new string[] { "A*B" }), "wildcards are literal");
                Assert(!Settings.Parse("{\"wifiName\":\"A*\"}").Matches(new string[] { "ABC" }), "no wildcard expansion");
                Assert(Settings.Parse("{\"wifiName\":\"校园\"}").Matches(new string[] { "校园访客" }), "Unicode name");
                Assert(Settings.Parse("{\"wifiName\":\"" + new string('A', 32) + "\"}").WifiName.Length == 32, "32 byte SSID");
                Reject("{}"); Reject("null"); Reject("{"); Reject("{\"wifiName\":false}");
                Reject("{\"wifiName\":\"\"}"); Reject("{\"wifiName\":\"   \"}");
                Reject("{\"wifiName\":\"YOUR_WIFI_NAME\"}");
                Reject("{\"wifiName\":\"" + new string('A', 33) + "\"}");
                Reject("{\"wifiName\":\"" + new string('校', 11) + "\"}");
                Reject("{\"wifiName\":\"Campus\",\"unknown\":true}");
                byte[] attributes = new byte[556];
                BitConverter.GetBytes(1).CopyTo(attributes, 0);
                byte[] ssid = Encoding.UTF8.GetBytes("校园_WiFi");
                BitConverter.GetBytes(ssid.Length).CopyTo(attributes, 520);
                ssid.CopyTo(attributes, 524);
                Assert(NativeWifi.DecodeSsid(attributes) == "校园_WiFi", "native layout must decode Unicode SSID");
                BitConverter.GetBytes(33).CopyTo(attributes, 520);
                Assert(NativeWifi.DecodeSsid(attributes) == null, "invalid SSID length");
                Assert(NativeWifi.DecodeSsid(new byte[16]) == null, "truncated native struct");
                attributes[0] = 0;
                Assert(NativeWifi.DecodeSsid(attributes) == null, "only connected interfaces");
                Assert(Array.IndexOf(WindowsProcesses.Names, "Clash Verge") >= 0 && Array.IndexOf(WindowsProcesses.Names, "verge-mihomo") >= 0, "common Clash Verge process names");
                Assert(Program.SafeError(new IOException("PRIVATE_PATH_TEST")) == "IOException", "logs must not expose exception paths");
                Console.WriteLine("PASS: " + assertions + " assertions; no Wi-Fi changes or process termination.");
                return 0;
            }
            catch (Exception ex) { Console.Error.WriteLine("FAIL: " + ex.Message); return 1; }
        }
    }
}
