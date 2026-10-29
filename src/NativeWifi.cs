using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace WifiClashGuard
{
    // Only queries the current association; does not scan nearby access points.
    internal sealed class NativeWifi : IDisposable
    {
        private IntPtr handle;
        [DllImport("wlanapi.dll")]
        private static extern uint WlanOpenHandle(uint version, IntPtr reserved, out uint negotiated, out IntPtr handle);
        [DllImport("wlanapi.dll")]
        private static extern uint WlanCloseHandle(IntPtr handle, IntPtr reserved);
        [DllImport("wlanapi.dll")]
        private static extern uint WlanEnumInterfaces(IntPtr handle, IntPtr reserved, out IntPtr list);
        [DllImport("wlanapi.dll")]
        private static extern uint WlanQueryInterface(IntPtr handle, ref Guid id, int opcode, IntPtr reserved, out uint size, out IntPtr data, out int type);
        [DllImport("wlanapi.dll")]
        private static extern void WlanFreeMemory(IntPtr memory);
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct InterfaceInfo
        {
            public Guid Id;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
            public string Description;
            public int State;
        }
        public NativeWifi()
        {
            uint version;
            uint code = WlanOpenHandle(2, IntPtr.Zero, out version, out handle);
            if (code != 0) { handle = IntPtr.Zero; throw new Win32Exception((int)code); }
        }
        internal static string DecodeSsid(byte[] bytes)
        {
            // WLAN_CONNECTION_ATTRIBUTES: DWORD state/mode, WCHAR profile[256], DOT11_SSID.
            if (bytes.Length < 556 || BitConverter.ToInt32(bytes, 0) != 1) return null;
            uint length = BitConverter.ToUInt32(bytes, 520);
            if (length > 32) return null;
            return Encoding.UTF8.GetString(bytes, 524, (int)length);
        }
        public string[] GetConnectedSsids()
        {
            IntPtr list;
            uint code = WlanEnumInterfaces(handle, IntPtr.Zero, out list);
            if (code != 0) throw new Win32Exception((int)code);
            try
            {
                int count = Marshal.ReadInt32(list);
                int stride = Marshal.SizeOf(typeof(InterfaceInfo));
                var result = new List<string>();
                for (int i = 0; i < count; i++)
                {
                    var info = (InterfaceInfo)Marshal.PtrToStructure(IntPtr.Add(list, 8 + i * stride), typeof(InterfaceInfo));
                    if (info.State != 1) continue;
                    uint size;
                    int type;
                    IntPtr data;
                    code = WlanQueryInterface(handle, ref info.Id, 7, IntPtr.Zero, out size, out data, out type);
                    if (code == 5023) continue; // Association ended between enumeration and query.
                    if (code != 0) throw new Win32Exception((int)code);
                    try
                    {
                        if (size < 556) continue;
                        byte[] bytes = new byte[556];
                        Marshal.Copy(data, bytes, 0, bytes.Length);
                        string ssid = DecodeSsid(bytes);
                        if (ssid != null) result.Add(ssid);
                    }
                    finally { WlanFreeMemory(data); }
                }
                return result.ToArray();
            }
            finally { WlanFreeMemory(list); }
        }
        public void Dispose()
        {
            if (handle != IntPtr.Zero) { WlanCloseHandle(handle, IntPtr.Zero); handle = IntPtr.Zero; }
        }
    }
}
