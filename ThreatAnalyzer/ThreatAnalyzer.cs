using System;
using System.Collections.Generic;

namespace ns_ThreatAnalyzer
{
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
    }

    public class Point
    {
        public double X { get; set; }
        public double Y { get; set; }
    }

    public class ThreatAnalyzer
    {
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

        public ThreatAnalyzer() { }

        public List<ThreatResult> Analyze(List<Threat> threats, List<Point> path)
        {
            ThreatMeta[] metas = BuildThreatMetas(threats);
            ValidatePath(path);
            double[] grades = new double[metas.Length];

            bool hasPreviousPoint = false;
            double previousPointX = 0.0;
            double previousPointY = 0.0;

            for (int pointIndex = 0; pointIndex < path.Count; pointIndex++)
            {
                Point pathPoint = path[pointIndex];
                double pointX = pathPoint.X;
                double pointY = pathPoint.Y;
                if (hasPreviousPoint && pointX == previousPointX && pointY == previousPointY)
                {
                    continue;
                }

                previousPointX = pointX;
                previousPointY = pointY;
                hasPreviousPoint = true;

                for (int threatIndex = 0; threatIndex < metas.Length; threatIndex++)
                {
                    if (TryGetThreatValueAtPoint(metas[threatIndex], pointX, pointY, out float threatValue))
                    {
                        grades[threatIndex] += threatValue;
                    }
                }
            }

            return BuildResults(metas, grades);
        }

        private static List<ThreatResult> BuildResults(ThreatMeta[] metas, double[] grades)
        {
            List<ThreatResult> results = new List<ThreatResult>(metas.Length);
            for (int i = 0; i < metas.Length; i++)
            {
                results.Add(new ThreatResult { Id = metas[i].Id, Grade = grades[i] });
            }

            return results;
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
