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

        public double ThreatResolution { get; set; }
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
            if (args.Length != 8)
            {
                Console.WriteLine(
                    "Usage:\n" +
                    "MapGenerator.exe xmin xmax ymin ymax regionCount rMin rMax threatResolution"
                );
                return;
            }

            string exeDir = AppContext.BaseDirectory;
            string solutionDir = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", ".."));
            string mapsRoot = Path.Combine(solutionDir, "Maps");

            double xmin = double.Parse(args[0]);
            double xmax = double.Parse(args[1]);
            double ymin = double.Parse(args[2]);
            double ymax = double.Parse(args[3]);
            int regionCount = int.Parse(args[4]);
            double rMin = double.Parse(args[5]);
            double rMax = double.Parse(args[6]);
            double threatResolution = double.Parse(args[7]);

            MapParameters parameters = new MapParameters
            {
                XMin = xmin,
                XMax = xmax,
                YMin = ymin,
                YMax = ymax,
                RegionCount = regionCount,
                RadiusMin = rMin,
                RadiusMax = rMax,
                ThreatResolution = threatResolution
            };

            MapGenerator generator = new MapGenerator(); 
            Map map = generator.Generate(parameters);

            string mapFolder = Path.Combine(mapsRoot, map.MapId.ToString());
            Directory.CreateDirectory(mapFolder);
            string outputPath = Path.Combine(mapFolder, "map.json");
            var json = JsonConvert.SerializeObject(map, Formatting.Indented);
            File.WriteAllText(outputPath, json);

            Console.WriteLine($"Map saved to {outputPath}");
        }
    }
}
