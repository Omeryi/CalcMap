using Newtonsoft.Json;
using ns_ThreatAnalyzer;
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.Remoting.Metadata.W3cXsd2001;
using System.Xml;
using Formatting = Newtonsoft.Json.Formatting;

namespace MapGenerator
{
    public class MapParameters
    {
        public double XMin { get; set; }

        public double XMax { get; set; }

        public double YMin { get; set; }

        public double YMax { get; set; }

        public int RegionCount { get; set; }

        public double RadiusMin { get; set; }

        public double RadiusMax { get; set; }
    }

    public class Map
    {
        public Guid MapId { get; set; }
        public MapParameters Parameters { get; set; }

        public List<Threat> Threats { get; set; }
    }

    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length != 0 && args.Length != 8)
            {
                Console.WriteLine(
                    "Usage:\n" +
                    "MapGenerator.exe output.json xmin xmax ymin ymax regionCount rMin rMax"
                );
                return;
            }

            string exeDir = AppContext.BaseDirectory;
            string solutionDir = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", ".."));
            string mapsRoot = Path.Combine(solutionDir, "Maps");

            double xmin = -100, xmax = 100;
            double ymin = -100, ymax = 100;
            int regionCount = 1;
            double rMin = 10, rMax = 30;

            if (args.Length == 8)
            {
                xmin = double.Parse(args[0]);
                xmax = double.Parse(args[1]);
                ymin = double.Parse(args[2]);
                ymax = double.Parse(args[3]);
                regionCount = int.Parse(args[4]);
                rMin = double.Parse(args[5]);
                rMax = double.Parse(args[6]);
            }

            MapParameters parameters = new MapParameters
            {
                XMin = xmin,
                XMax = xmax,
                YMin = ymin,
                YMax = ymax,
                RegionCount = regionCount,
                RadiusMin = rMin,
                RadiusMax = rMax
            };

            MapGenerator generator = new MapGenerator(); 
            Map map = generator.Generate(parameters);

            string mapFolder = Path.Combine(mapsRoot, map.MapId.ToString());
            Directory.CreateDirectory(mapFolder);
            string outputPath = Path.Combine(mapFolder, "map.json");
            var json = JsonConvert.SerializeObject(outputPath, Formatting.Indented);
            File.WriteAllText(outputPath, json);

            Console.WriteLine($"Map saved to {outputPath}");
        }
    }
}