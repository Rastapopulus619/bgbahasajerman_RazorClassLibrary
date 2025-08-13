using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace bgbahasajerman_RazorClassLibrary.Models
{
    public class LessonCardTableDataModel
    {
        public DateTime Date { get; set; }
        public bool Attended { get; set; }
        public bool Replaced { get; set; }
        public DateTime? ReplacementDate { get; set; }
    }
}
