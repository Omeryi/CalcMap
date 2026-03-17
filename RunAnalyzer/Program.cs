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
            List<ThreatResult> results = threatAnalyzer.Analyze(map.Threats, path);

            List<AnalysisResultRow> outputRows = BuildOutputRows(threatAnalyzer, map.Threats, path, results);
            AnalysisOutput output = new AnalysisOutput
            {
                TotalElapsedMilliseconds = SumElapsedMilliseconds(outputRows),
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

            return points;
        }

        private static List<AnalysisResultRow> BuildOutputRows(
            ThreatAnalyzer threatAnalyzer,
            List<Threat> threats,
            List<Point> path,
            List<ThreatResult> results)
        {
            List<AnalysisResultRow> rows = new List<AnalysisResultRow>(results.Count);

            for (int i = 0; i < results.Count; i++)
            {
                Threat threat = threats[i];
                Stopwatch stopwatch = Stopwatch.StartNew();
                threatAnalyzer.Analyze(new List<Threat> { threat }, path);
                stopwatch.Stop();

                rows.Add(new AnalysisResultRow
                {
                    Id = results[i].Id,
                    Grade = results[i].Grade,
                    ElapsedMilliseconds = stopwatch.Elapsed.TotalMilliseconds
                });
            }

            return rows;
        }

        private static double SumElapsedMilliseconds(List<AnalysisResultRow> rows)
        {
            double total = 0;
            for (int i = 0; i < rows.Count; i++)
            {
                total += rows[i].ElapsedMilliseconds;
            }

            return total;
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
