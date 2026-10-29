using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;

namespace WifiClashGuard
{
    internal sealed class WindowsProcesses : IProcessController
    {
        internal static readonly string[] Names = { "clash", "clash-verge", "Clash Verge", "verge-mihomo", "verge-mihomo-alpha", "Clash for Windows", "clash-win64", "clash-meta", "mihomo", "mihomo-windows-amd64", "clash-party" };
        public StopResult StopTargets()
        {
            var result = new StopResult();
            foreach (string name in Names)
                foreach (Process process in Process.GetProcessesByName(name))
                    using (process)
                    {
                        try
                        {
                            process.Kill();
                            if (process.WaitForExit(2000)) { result.Stopped++; Program.Log("Stopped target: " + name); }
                            else { result.Failed++; Program.Log("Target did not exit: " + name); }
                        }
                        catch (InvalidOperationException) { } // Already exited.
                        catch (Exception ex) { result.Failed++; Program.Log("Stop failed: " + name + "; " + Program.SafeError(ex)); }
                    }
            return result;
        }
        internal static int Count()
        {
            int count = 0;
            foreach (string name in Names)
                foreach (Process process in Process.GetProcessesByName(name)) using (process) { count++; }
            return count;
        }
    }
    internal static class Program
    {
        internal static readonly string Root = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ".."));
        internal static string SafeError(Exception ex)
        {
            var native = ex as Win32Exception;
            return native == null ? ex.GetType().Name : "Win32 error " + native.NativeErrorCode;
        }
        internal static void Log(string message)
        {
            try
            {
                string directory = Path.Combine(Root, "runtime");
                Directory.CreateDirectory(directory);
                string path = Path.Combine(directory, "guard.log");
                if (File.Exists(path) && new FileInfo(path).Length > 262144)
                {
                    string old = Path.Combine(directory, "guard.previous.log");
                    if (File.Exists(old)) File.Delete(old);
                    File.Move(path, old);
                }
                File.AppendAllText(path, DateTime.Now.ToString("s") + " " + message + Environment.NewLine, Encoding.UTF8);
            }
            catch { } // Logging must never prevent a network check.
        }
        private static int Main(string[] args)
        {
            string mode = args.Length == 0 ? "--once" : args[0];
            if (args.Length > 1 || (mode != "--once" && mode != "--diagnose" && mode != "--validate")) return 2;
            Settings settings;
            try { settings = Settings.Parse(File.ReadAllText(Path.Combine(Root, "config.json"), Encoding.UTF8)); }
            catch (Exception ex) { Log("Invalid/missing config; edit wifiName in config.json. " + SafeError(ex)); return 2; }
            if (mode == "--validate") return 0;
            using (var mutex = new Mutex(false, @"Local\WifiClashGuard-Check"))
            {
                bool owned;
                try { owned = mutex.WaitOne(0, false); }
                catch (AbandonedMutexException) { owned = true; }
                if (!owned) return 0;
                try
                {
                    using (var wifi = new NativeWifi())
                    {
                        if (mode == "--diagnose")
                        {
                            string report = "Version: 1.0.0\r\nConfig valid: True\r\nWi-Fi query succeeded: True\r\nTarget Wi-Fi matched: " + settings.Matches(wifi.GetConnectedSsids()) + "\r\nRecognized target count: " + WindowsProcesses.Count() + "\r\nRead-only; no process stopped.\r\n";
                            Directory.CreateDirectory(Path.Combine(Root, "runtime"));
                            File.WriteAllText(Path.Combine(Root, "runtime", "diagnostics.txt"), report, Encoding.UTF8);
                            return 0;
                        }
                        Log("Check started");
                        var controller = new WindowsProcesses();
                        CheckResult result = Guard.Check(settings, wifi.GetConnectedSsids(), controller);
                        int failed = result.Processes.Failed;
                        Log(result.Matched ? "Target Wi-Fi matched" : "Target Wi-Fi not matched");
                        if (result.Matched)
                            foreach (int delay in new int[] { 2000, 3000, 5000 })
                            {
                                Thread.Sleep(delay);
                                result = Guard.Check(settings, wifi.GetConnectedSsids(), controller);
                                failed += result.Processes.Failed;
                                if (!result.Matched) break;
                            }
                        Log(failed == 0 ? "Check completed" : "Check completed with stop failures");
                        return failed == 0 ? 0 : 1;
                    }
                }
                catch (Exception ex) { Log("Check failed: " + SafeError(ex)); return 1; }
                finally { mutex.ReleaseMutex(); }
            }
        }
    }
}
