using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows.Forms;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Text;
using Microsoft.DirectX.DirectInput;

namespace DeviceLister
{
    static class Program
    {
        class IniFile   // revision 11
        {
            string Path;
            string EXE = Assembly.GetExecutingAssembly().GetName().Name;

            [DllImport("kernel32", CharSet = CharSet.Unicode)]
            static extern long WritePrivateProfileString(string Section, string Key, string Value, string FilePath);

            [DllImport("kernel32", CharSet = CharSet.Unicode)]
            static extern int GetPrivateProfileString(string Section, string Key, string Default, StringBuilder RetVal, int Size, string FilePath);

            public IniFile(string IniPath = null)
            {
                Path = new FileInfo(IniPath ?? EXE + ".ini").FullName;
            }

            public string Read(string Key, string Section = null)
            {
                var RetVal = new StringBuilder(255);
                GetPrivateProfileString(Section ?? EXE, Key, "", RetVal, 255, Path);
                return RetVal.ToString();
            }

            public void Write(string Key, string Value, string Section = null)
            {
                WritePrivateProfileString(Section ?? EXE, Key, Value, Path);
            }

            public void DeleteKey(string Key, string Section = null)
            {
                Write(Key, null, Section ?? EXE);
            }

            public void DeleteSection(string Section = null)
            {
                Write(null, null, Section ?? EXE);
            }

            public bool KeyExists(string Key, string Section = null)
            {
                return Read(Key, Section).Length > 0;
            }
        }

        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            var MyIni = new IniFile("devreorder.ini");
            
            string deviceData = "";
            string devEnum = "";
            int devnum = 0;

            List<string> list = new List<string>();
            IDictionary<string, int> NameNum = new Dictionary<string, int>();
            foreach (DeviceInstance di in Manager.GetDevices(DeviceClass.GameControl, EnumDevicesFlags.AttachedOnly))
            {

                list.Add(di.ProductName);

            }

            String[] str = list.ToArray();

            var duplicates = str.GroupBy(x => x)
            .Where(g => g.Count() > 1)
            .ToDictionary(x => x.Key, y => y.Count());

            MyIni.DeleteSection("ALL");
            foreach (DeviceInstance di in Manager.GetDevices(DeviceClass.GameControl, EnumDevicesFlags.AttachedOnly))
            {

                if (NameNum.ContainsKey("" + di.ProductName + ""))
                {
                    devnum = NameNum["" + di.ProductName + ""];
                    if (duplicates["" + di.ProductName + ""] > 1)
                    {
                        int newdevnum = devnum + 1;
                        NameNum["" + di.ProductName + ""] = newdevnum;
                        devEnum = "(" + newdevnum + ")";
                    }
                }
                else
                {
                    NameNum.Add("" + di.ProductName + "", 1);
                    if (duplicates.ContainsKey("" + di.ProductName + ""))
                    {
                        devEnum = "(1)";
                    }
                    else
                    {
                        devEnum = "";
                    }


                }


                MyIni.Write("\"" + di.ProductName + "\"" + devEnum + "", "{" + di.InstanceGuid + "}", "ALL");

            }
            
            string[] args = Environment.GetCommandLineArgs();

            if (args.Length > 1)
            {
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new DeviceListerForm());
            }
        }
    }
}
