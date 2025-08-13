namespace bgbahasajerman_RazorClassLibrary.Models
{
    public class LessonCardTableDataModel
    {
        // if Date == default(DateTime), we treat the cell as "empty"
        public DateTime Date { get; set; }

        // did the student attend this lesson?
        public bool Attended { get; set; }

        // was this lesson replaced by another date?
        public bool Replaced { get; set; }

        // the replacement date (only meaningful when Replaced == true)
        public DateTime? ReplacementDate { get; set; }
    }
}
