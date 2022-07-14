using System;
using System.IO;
using System.Reflection;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using Microsoft.DirectX.DirectInput;



namespace DeviceLister
{
    public partial class DeviceListerForm : Form
    {
        public DeviceListerForm()
        {
            InitializeComponent();
        }
        private void DeviceListerForm_Load(object sender, EventArgs e)
        {
            
            
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


                deviceData += "\"" + di.ProductName + "\"" + devEnum + "={" + di.InstanceGuid + "}" + System.Environment.NewLine;
               

            }

             textBox.Text = deviceData;
             textBox.Select(0, 0);
        }
        
    }
    
}

