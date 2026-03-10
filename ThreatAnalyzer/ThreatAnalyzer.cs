using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ns_ThreatAnalyzer
{

    public class Threat
    {
        public const double resolution = 0.1;
        public Guid Id { get; set; }
        public double CenterX { get; set; }
        public double CenterY { get; set; }
        public double Radius { get; set; }
        public float[][] Image { get; set; }
    }

    public class ThreatResult
    {
        public Guid Id { get; set; }
        public double Grade { get; set; }
    }

    public class Point
    {
        public double X { get; set; }
        public double Y { get; set; }
    }

    public class ThreatAnalyzer
    {
        public ThreatAnalyzer() { } 
        public List<ThreatResult> Analyze(List<Threat> threats, List<Point> path) { 
            List<ThreatResult> results = new List<ThreatResult>();
            for (int i = 0; i < threats.Count; i++)
            {
                double grade = 0.0 + i;
                
                results.Add(new ThreatResult { Id = threats[i].Id, Grade = grade });
            }
            return results;
        }
    }
}
