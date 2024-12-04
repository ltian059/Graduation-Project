using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RD104ConsoleApp
{
    /// <summary>
    /// RegisterSettings class to store address and value pairs
    /// </summary>
    public class RegisterSettings
    {
        public byte[] Addresses { get; set; }
        public byte[] Values { get; set; }
    }
}
