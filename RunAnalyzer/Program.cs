using MapGenerator;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using ns_ThreatAnalyzer;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

namespace RunAnalyzer
{
    internal class AnalysisResultRow
    {
        public Guid Id { get; set; }
        public double Grade { get; set; }
        public double ElapsedMilliseconds { get; set; }
    }

    internal class AnalysisOutput
    {
        public double TotalElapsedMilliseconds { get; set; }
        public List<AnalysisResultRow> Results { get; set; }
    }

    internal class Program
    {
        static void Main(string[] args)
        {
            if (args.Length != 2)
            {
                Console.WriteLine("Usage:");
                Console.WriteLine("RunAnalyzer.exe <map.json> <path.json>");
                Environment.ExitCode = 1;
                return;
            }

            string mapPath = Path.GetFullPath(args[0]);
            string pathPath = Path.GetFullPath(args[1]);

            ValidateInputFile(mapPath, "map");
            ValidateInputFile(pathPath, "path");

            Map map = LoadMap(mapPath);
            List<Point> path = LoadPath(pathPath);

            ThreatAnalyzer threatAnalyzer = new ThreatAnalyzer();
            Stopwatch stopwatch = Stopwatch.StartNew();
            List<ThreatResult> results = threatAnalyzer.Analyze(map.Threats, path);
            stopwatch.Stop();

            List<AnalysisResultRow> outputRows = BuildOutputRows(results, stopwatch.Elapsed.TotalMilliseconds);
            AnalysisOutput output = new AnalysisOutput
            {
                TotalElapsedMilliseconds = stopwatch.Elapsed.TotalMilliseconds,
                Results = outputRows
            };

            string outputPath = GetOutputPath(mapPath, pathPath);
            string json = JsonConvert.SerializeObject(output, Formatting.Indented);
            File.WriteAllText(outputPath, json);

            Console.WriteLine("Results saved to " + outputPath);
            Console.WriteLine("Total elapsed ms: " + output.TotalElapsedMilliseconds.ToString("F3"));
            Console.WriteLine("RESULT_FILE=" + outputPath);
        }

        private static void ValidateInputFile(string filePath, string label)
        {
            if (!File.Exists(filePath))
            {
                throw new FileNotFoundException("Could not find " + label + " file: " + filePath, filePath);
            }
        }

        private static Map LoadMap(string mapPath)
        {
            string json = File.ReadAllText(mapPath);
            Map map = JsonConvert.DeserializeObject<Map>(json);
            if (map == null || map.Threats == null || map.Threats.Count == 0)
            {
                throw new InvalidDataException("Map JSON does not contain any threats: " + mapPath);
            }

            return map;
        }

        private static List<Point> LoadPath(string pathPath)
        {
            string json = File.ReadAllText(pathPath);
            JObject pathData = JObject.Parse(json);
            JToken pointsToken = pathData["Points"];
            List<Point> points = pointsToken == null
                ? null
                : pointsToken.ToObject<List<Point>>();

            if (points == null || points.Count == 0)
            {
                throw new InvalidDataException("Path JSON does not contain any points: " + pathPath);
            }

            for (int i = 0; i < points.Count; i++)
            {
                Point point = points[i];
                if (point == null)
                {
                    throw new InvalidDataException("Path JSON contains a null point at index " + i + ": " + pathPath);
                }

                if (double.IsNaN(point.X) || double.IsInfinity(point.X)
                    || double.IsNaN(point.Y) || double.IsInfinity(point.Y))
                {
                    throw new InvalidDataException("Path JSON contains a non-finite point at index " + i + ": " + pathPath);
                }
            }

            return points;
        }

        private static List<AnalysisResultRow> BuildOutputRows(List<ThreatResult> results, double totalElapsedMilliseconds)
        {
            List<AnalysisResultRow> rows = new List<AnalysisResultRow>(results.Count);
            double averagePerThreat = results.Count > 0
                ? totalElapsedMilliseconds / results.Count
                : 0.0;

            for (int i = 0; i < results.Count; i++)
            {
                rows.Add(new AnalysisResultRow
                {
                    Id = results[i].Id,
                    Grade = results[i].Grade,
                    // Backward-compatible field for existing GUI table; this is average time, not per-threat measured time.
                    ElapsedMilliseconds = averagePerThreat
                });
            }

            return rows;
        }

        private static string GetOutputPath(string mapPath, string pathPath)
        {
            string mapFolder = Path.GetDirectoryName(mapPath);
            string pathName = Path.GetFileNameWithoutExtension(pathPath) ?? string.Empty;
            string suffix = GetResultSuffix(pathName);
            string baseFileName = "results_" + suffix;
            string outputPath = Path.Combine(mapFolder, baseFileName + ".json");
            int counter = 2;

            while (File.Exists(outputPath))
            {
                outputPath = Path.Combine(mapFolder, baseFileName + "_" + counter + ".json");
                counter++;
            }

            return outputPath;
        }

        private static string GetResultSuffix(string pathName)
        {
            if (pathName.StartsWith("path_", StringComparison.OrdinalIgnoreCase))
            {
                return pathName.Substring("path_".Length);
            }

            if (pathName.StartsWith("path", StringComparison.OrdinalIgnoreCase))
            {
                string suffix = pathName.Substring("path".Length).TrimStart('_');
                if (!string.IsNullOrWhiteSpace(suffix))
                {
                    return suffix;
                }
            }

            return string.IsNullOrWhiteSpace(pathName)
                ? DateTime.Now.ToString("yyyyMMdd_HHmm")
                : pathName;
        }
    }
}
