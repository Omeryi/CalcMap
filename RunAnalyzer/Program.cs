using MapGenerator;
using ns_ThreatAnalyzer;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;


namespace RunAnalyzer
{
    internal class Program
    {
        static void Main(string[] args)
        {
            // loads map, path 
            // initial
            Map map = null; // (json from args)
            List<Point> path = null; // (json from args)
            ThreatAnalyzer threatAnalyzer = new ThreatAnalyzer();
            List < ThreatResult> res = threatAnalyzer.Analyze(map.Threats, path);
            // res.ToJson - with path specified in args/folder
        }
    }
}
