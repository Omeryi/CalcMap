using System;
using System.Collections.Generic;

namespace ns_ThreatAnalyzer
{
    public enum ThreatAnalysisMode
    {
        Unoptimized = 0,
        PathChunkBoundingBoxes = 1
    }

    public class Threat
    {
        public Guid Id { get; set; }
        public double CenterX { get; set; }
        public double CenterY { get; set; }
        public double Radius { get; set; }
        public double Resolution { get; set; }
        public float[][] Image { get; set; }
    }

    public class ThreatResult
    {
        public Guid Id { get; set; }
        public double Grade { get; set; }
        public int PointsAboveThresholdCount { get; set; }
    }

    public class Point
    {
        public double X { get; set; }
        public double Y { get; set; }
    }

    public class ThreatAnalyzer
    {
        // Path points are grouped into coarse bounding boxes so optimized mode can skip
        // large stretches of the path for threats that are obviously far away.
        private const int DefaultTargetPathChunkCount = 10;
        // Count how many processed path points meaningfully contribute to each threat.
        private const float ThreatValueCountThreshold = 0.2f;

        // Caches values derived from a Threat once so the hot point loop can reuse them cheaply.
        private sealed class ThreatMeta
        {
            public Guid Id;
            public double CenterX;
            public double CenterY;
            public double RadiusSquared;
            public double BoundsMinX;
            public double BoundsMaxX;
            public double BoundsMinY;
            public double BoundsMaxY;
            public double ImageOriginX;
            public double ImageOriginY;
            public double Resolution;
            public double InvResolution;
            public float[][] Image;
            public int ImageWidth;

            public ThreatMeta(Threat threat)
            {
                ValidateThreat(threat);
                Id = threat.Id;
                CenterX = threat.CenterX;
                CenterY = threat.CenterY;
                double radius = threat.Radius;
                RadiusSquared = radius * radius;
                BoundsMinX = CenterX - radius;
                BoundsMaxX = CenterX + radius;
                BoundsMinY = CenterY - radius;
                BoundsMaxY = CenterY + radius;

                Resolution = threat.Resolution;
                // Cache 1 / resolution so the hot loop can multiply instead of divide.
                InvResolution = 1.0 / Resolution;
                ImageOriginX = BoundsMinX;
                ImageOriginY = BoundsMinY;

                Image = threat.Image;
                ImageWidth = Image.Length;
            }
        }

        private struct BoundingBox
        {
            public double MinX;
            public double MaxX;
            public double MinY;
            public double MaxY;
        }

        private struct PathChunk
        {
            public int StartIndex;
            public int EndIndex;
            public BoundingBox Bounds;
        }

        public ThreatAnalyzer() { }

        public ThreatAnalysisMode Mode { get; set; } = ThreatAnalysisMode.Unoptimized;
        public int TargetPathChunkCount { get; set; } = DefaultTargetPathChunkCount;
        public int ProcessedPathPointCount { get; private set; }

        public List<ThreatResult> Analyze(List<Threat> threats, List<Point> path)
        {
            ThreatMeta[] metas = BuildThreatMetas(threats);
            // Normalize the path once up front so both modes operate on the same effective input.
            Point[] processedPath = BuildProcessedPath(path);
            ProcessedPathPointCount = processedPath.Length;
            double[] grades = new double[metas.Length];
            int[] pointsAboveThresholdCounts = new int[metas.Length];

            switch (Mode)
            {
                case ThreatAnalysisMode.Unoptimized:
                    AnalyzeUnoptimized(metas, processedPath, grades, pointsAboveThresholdCounts);
                    break;
                case ThreatAnalysisMode.PathChunkBoundingBoxes:
                    AnalyzeWithPathChunkBoundingBoxes(metas, processedPath, grades, pointsAboveThresholdCounts, TargetPathChunkCount);
                    break;
                default:
                    throw new ArgumentOutOfRangeException(nameof(Mode), Mode, "Unsupported threat analysis mode.");
            }

            return BuildResults(metas, grades, pointsAboveThresholdCounts);
        }

        private static List<ThreatResult> BuildResults(ThreatMeta[] metas, double[] grades, int[] pointsAboveThresholdCounts)
        {
            List<ThreatResult> results = new List<ThreatResult>(metas.Length);
            for (int i = 0; i < metas.Length; i++)
            {
                results.Add(new ThreatResult
                {
                    Id = metas[i].Id,
                    Grade = grades[i],
                    PointsAboveThresholdCount = pointsAboveThresholdCounts[i]
                });
            }

            return results;
        }

        private static void AnalyzeUnoptimized(ThreatMeta[] metas, Point[] processedPath, double[] grades, int[] pointsAboveThresholdCounts)
        {
            for (int pointIndex = 0; pointIndex < processedPath.Length; pointIndex++)
            {
                Point pathPoint = processedPath[pointIndex];
                AccumulateThreatGrades(metas, grades, pointsAboveThresholdCounts, pathPoint.X, pathPoint.Y);
            }
        }

        private static void AnalyzeWithPathChunkBoundingBoxes(ThreatMeta[] metas, Point[] processedPath, double[] grades, int[] pointsAboveThresholdCounts, int targetPathChunkCount)
        {
            BoundingBox wholePathBounds = BuildPathChunkBounds(processedPath, 0, processedPath.Length - 1);
            int pathPointsPerChunk = GetPathPointsPerChunk(processedPath.Length, targetPathChunkCount);
            PathChunk[] pathChunks = BuildPathChunks(processedPath, pathPointsPerChunk);

            for (int threatIndex = 0; threatIndex < metas.Length; threatIndex++)
            {
                ThreatMeta meta = metas[threatIndex];
                BoundingBox threatBounds = GetThreatBounds(meta);
                // Cheap whole-path reject before walking any chunk or point range for this threat.
                if (!BoundsOverlap(threatBounds, wholePathBounds))
                {
                    continue;
                }

                for (int chunkIndex = 0; chunkIndex < pathChunks.Length; chunkIndex++)
                {
                    PathChunk pathChunk = pathChunks[chunkIndex];
                    // Only exact-check points from path chunks whose bounding boxes overlap the threat.
                    if (!BoundsOverlap(threatBounds, pathChunk.Bounds))
                    {
                        continue;
                    }

                    for (int pointIndex = pathChunk.StartIndex; pointIndex <= pathChunk.EndIndex; pointIndex++)
                    {
                        Point pathPoint = processedPath[pointIndex];
                        if (TryGetThreatValueAtPoint(meta, pathPoint.X, pathPoint.Y, out float threatValue))
                        {
                            grades[threatIndex] += threatValue;
                            if (threatValue > ThreatValueCountThreshold)
                            {
                                pointsAboveThresholdCounts[threatIndex]++;
                            }
                        }
                    }
                }
            }
        }

        private static void AccumulateThreatGrades(ThreatMeta[] metas, double[] grades, int[] pointsAboveThresholdCounts, double pointX, double pointY)
        {
            for (int threatIndex = 0; threatIndex < metas.Length; threatIndex++)
            {
                if (TryGetThreatValueAtPoint(metas[threatIndex], pointX, pointY, out float threatValue))
                {
                    grades[threatIndex] += threatValue;
                    if (threatValue > ThreatValueCountThreshold)
                    {
                        pointsAboveThresholdCounts[threatIndex]++;
                    }
                }
            }
        }

        private static ThreatMeta[] BuildThreatMetas(List<Threat> threats)
        {
            if (threats == null)
            {
                throw new ArgumentNullException(nameof(threats));
            }

            if (threats.Count == 0)
            {
                throw new ArgumentException("Threat list must contain at least one threat.", nameof(threats));
            }

            ThreatMeta[] metas = new ThreatMeta[threats.Count];
            for (int i = 0; i < threats.Count; i++)
            {
                metas[i] = new ThreatMeta(threats[i]);
            }

            return metas;
        }

        private static Point[] BuildProcessedPath(List<Point> path)
        {
            ValidatePath(path);

            List<Point> processedPath = new List<Point>(path.Count);
            bool hasPreviousPoint = false;
            double previousPointX = 0.0;
            double previousPointY = 0.0;

            for (int pointIndex = 0; pointIndex < path.Count; pointIndex++)
            {
                Point pathPoint = path[pointIndex];
                // Consecutive duplicates should not change the score, so remove them once here.
                if (hasPreviousPoint && pathPoint.X == previousPointX && pathPoint.Y == previousPointY)
                {
                    continue;
                }

                processedPath.Add(pathPoint);
                previousPointX = pathPoint.X;
                previousPointY = pathPoint.Y;
                hasPreviousPoint = true;
            }

            return processedPath.ToArray();
        }

        private static void ValidatePath(List<Point> path)
        {
            if (path == null)
            {
                throw new ArgumentNullException(nameof(path));
            }

            if (path.Count == 0)
            {
                throw new ArgumentException("Path must contain at least one point.", nameof(path));
            }

            for (int pointIndex = 0; pointIndex < path.Count; pointIndex++)
            {
                Point pathPoint = path[pointIndex];
                if (pathPoint == null)
                {
                    throw new ArgumentException($"Path point at index {pointIndex} is null.", nameof(path));
                }

                if (!IsFinite(pathPoint.X) || !IsFinite(pathPoint.Y))
                {
                    throw new ArgumentException(
                        $"Path point at index {pointIndex} must have finite X and Y values.",
                        nameof(path));
                }
            }
        }

        private static PathChunk[] BuildPathChunks(Point[] processedPath, int pathPointsPerBoundingBox)
        {
            if (pathPointsPerBoundingBox <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(pathPointsPerBoundingBox), "Path points per bounding box must be positive.");
            }

            int chunkCount = (processedPath.Length + pathPointsPerBoundingBox - 1) / pathPointsPerBoundingBox;
            PathChunk[] pathChunks = new PathChunk[chunkCount];

            for (int chunkIndex = 0; chunkIndex < chunkCount; chunkIndex++)
            {
                int startIndex = chunkIndex * pathPointsPerBoundingBox;
                int endIndex = Math.Min(startIndex + pathPointsPerBoundingBox, processedPath.Length) - 1;
                pathChunks[chunkIndex] = new PathChunk
                {
                    StartIndex = startIndex,
                    EndIndex = endIndex,
                    Bounds = BuildPathChunkBounds(processedPath, startIndex, endIndex)
                };
            }

            return pathChunks;
        }

        private static int GetPathPointsPerChunk(int processedPathPointCount, int targetPathChunkCount)
        {
            if (targetPathChunkCount <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(targetPathChunkCount), "Target path chunk count must be positive.");
            }

            return Math.Max(1, (processedPathPointCount + targetPathChunkCount - 1) / targetPathChunkCount);
        }

        private static BoundingBox BuildPathChunkBounds(Point[] processedPath, int startIndex, int endIndex)
        {
            Point firstPoint = processedPath[startIndex];
            BoundingBox bounds = new BoundingBox
            {
                MinX = firstPoint.X,
                MaxX = firstPoint.X,
                MinY = firstPoint.Y,
                MaxY = firstPoint.Y
            };

            for (int pointIndex = startIndex + 1; pointIndex <= endIndex; pointIndex++)
            {
                Point point = processedPath[pointIndex];
                if (point.X < bounds.MinX)
                {
                    bounds.MinX = point.X;
                }
                if (point.X > bounds.MaxX)
                {
                    bounds.MaxX = point.X;
                }
                if (point.Y < bounds.MinY)
                {
                    bounds.MinY = point.Y;
                }
                if (point.Y > bounds.MaxY)
                {
                    bounds.MaxY = point.Y;
                }
            }

            return bounds;
        }

        private static BoundingBox GetThreatBounds(ThreatMeta meta)
        {
            return new BoundingBox
            {
                MinX = meta.BoundsMinX,
                MaxX = meta.BoundsMaxX,
                MinY = meta.BoundsMinY,
                MaxY = meta.BoundsMaxY
            };
        }

        private static bool BoundsOverlap(BoundingBox a, BoundingBox b)
        {
            return a.MinX <= b.MaxX
                && a.MaxX >= b.MinX
                && a.MinY <= b.MaxY
                && a.MaxY >= b.MinY;
        }

        private static bool TryGetThreatValueAtPoint(ThreatMeta meta, double pointX, double pointY, out float threatValue)
        {
            threatValue = 0f;

            if (pointX < meta.BoundsMinX || pointX > meta.BoundsMaxX
                || pointY < meta.BoundsMinY || pointY > meta.BoundsMaxY)
            {
                return false;
            }

            double offsetX = pointX - meta.CenterX;
            double offsetY = pointY - meta.CenterY;
            double distanceSquared = offsetX * offsetX + offsetY * offsetY;
            if (distanceSquared > meta.RadiusSquared)
            {
                return false;
            }

            int ix = ClampIndex((int)Math.Round((pointX - meta.ImageOriginX) * meta.InvResolution), meta.ImageWidth);
            float[] row = meta.Image[ix];
            int iy = ClampIndex((int)Math.Round((pointY - meta.ImageOriginY) * meta.InvResolution), row.Length);
            threatValue = row[iy];
            return true;
        }

        private static int ClampIndex(int index, int length)
        {
            if (index < 0)
            {
                return 0;
            }

            if (index >= length)
            {
                return length - 1;
            }

            return index;
        }

        private static void ValidateThreat(Threat threat)
        {
            if (threat == null)
            {
                throw new ArgumentNullException(nameof(threat), "Threat entries cannot be null.");
            }

            if (!IsFinite(threat.CenterX) || !IsFinite(threat.CenterY))
            {
                throw new ArgumentException(
                    $"Threat {threat.Id} must have finite CenterX and CenterY values.",
                    nameof(threat));
            }

            if (!IsFinite(threat.Radius) || threat.Radius <= 0)
            {
                throw new ArgumentException(
                    $"Threat {threat.Id} must have a positive finite radius.",
                    nameof(threat));
            }

            if (!IsFinite(threat.Resolution) || threat.Resolution <= 0)
            {
                throw new ArgumentException(
                    $"Threat {threat.Id} must have a positive resolution.",
                    nameof(threat));
            }

            ValidateThreatImage(threat);
        }

        private static void ValidateThreatImage(Threat threat)
        {
            if (threat.Image == null || threat.Image.Length == 0)
            {
                throw new ArgumentException(
                    $"Threat {threat.Id} must contain image data.",
                    nameof(threat));
            }

            for (int rowIndex = 0; rowIndex < threat.Image.Length; rowIndex++)
            {
                float[] row = threat.Image[rowIndex];
                if (row == null || row.Length == 0)
                {
                    throw new ArgumentException(
                        $"Threat {threat.Id} contains an empty image row at index {rowIndex}.",
                        nameof(threat));
                }
            }
        }

        private static bool IsFinite(double value)
        {
            return !double.IsNaN(value) && !double.IsInfinity(value);
        }

    }
}
