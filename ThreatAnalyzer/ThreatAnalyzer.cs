using System;
using System.Collections.Generic;

namespace ns_ThreatAnalyzer
{
    public class Threat
    {
        public const double resolution = 0.1; // Not serializable
        public Guid Id { get; set; }
        public double CenterX { get; set; }
        public double CenterY { get; set; }
        public double Radius { get; set; }
        public double Resolution { get { return resolution; } }
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
        private sealed class ThreatMeta
        {
            public Guid Id;
            public double CenterX;
            public double CenterY;
            public double RadiusSquared;
            public double MinX;
            public double MaxX;
            public double MinY;
            public double MaxY;
            public double OriginX;
            public double OriginY;
            public double Resolution;
            public double InvResolution;
            public float[][] Image;
            public int Width;
            public bool HasImage;

            public ThreatMeta(Threat threat)
            {
                if (threat == null)
                {
                    Id = Guid.Empty;
                    Resolution = Threat.resolution;
                    InvResolution = 1.0 / Threat.resolution;
                    return;
                }

                Id = threat.Id;
                CenterX = threat.CenterX;
                CenterY = threat.CenterY;
                double radius = threat.Radius;
                RadiusSquared = radius * radius;
                MinX = CenterX - radius;
                MaxX = CenterX + radius;
                MinY = CenterY - radius;
                MaxY = CenterY + radius;

                Resolution = threat.Resolution > 0 ? threat.Resolution : Threat.resolution;
                InvResolution = 1.0 / Resolution;
                OriginX = MinX;
                OriginY = MinY;

                Image = threat.Image;
                Width = Image == null ? 0 : Image.Length;
                HasImage = Width > 0;
            }
        }

        public ThreatAnalyzer() { }

        public List<ThreatResult> Analyze(List<Threat> threats, List<Point> path)
        {
            if (threats == null || threats.Count == 0)
            {
                return new List<ThreatResult>();
            }

            int threatCount = threats.Count;
            ThreatMeta[] metas = new ThreatMeta[threatCount];
            for (int i = 0; i < threatCount; i++)
            {
                // Precompute per-threat constants once to avoid repeated work in edge/sample loops.
                metas[i] = new ThreatMeta(threats[i]);
            }

            // Flat index-aligned accumulation avoids dictionary lookups in the hot path.
            double[] grades = new double[threatCount];
            if (path == null || path.Count < 2)
            {
                return BuildResults(metas, grades);
            }

            for (int edgeIndex = 0; edgeIndex < path.Count - 1; edgeIndex++)
            {
                Point p0 = path[edgeIndex];
                Point p1 = path[edgeIndex + 1];
                if (p0 == null || p1 == null)
                {
                    continue;
                }

                double p0x = p0.X;
                double p0y = p0.Y;
                double dx = p1.X - p0x;
                double dy = p1.Y - p0y;
                double edgeLenSquared = dx * dx + dy * dy;
                if (edgeLenSquared <= 0.0)
                {
                    continue;
                }

                // Keep distance checks in squared space; sqrt is needed only once for normalization.
                double edgeLength = Math.Sqrt(edgeLenSquared);
                double edgeMinX = p0x < p1.X ? p0x : p1.X;
                double edgeMaxX = p0x > p1.X ? p0x : p1.X;
                double edgeMinY = p0y < p1.Y ? p0y : p1.Y;
                double edgeMaxY = p0y > p1.Y ? p0y : p1.Y;

                for (int threatIndex = 0; threatIndex < threatCount; threatIndex++)
                {
                    ThreatMeta meta = metas[threatIndex];
                    if (!meta.HasImage)
                    {
                        continue;
                    }

                    // Two-stage relevance:
                    // 1) AABB overlap (cheap broad phase), 2) squared segment-center distance <= r^2.
                    if (!AabbOverlaps(edgeMinX, edgeMaxX, edgeMinY, edgeMaxY, meta.MinX, meta.MaxX, meta.MinY, meta.MaxY))
                    {
                        continue;
                    }

                    double centerDistanceSquared = SquaredDistancePointToSegment(
                        meta.CenterX, meta.CenterY, p0x, p0y, dx, dy, edgeLenSquared);
                    if (centerDistanceSquared > meta.RadiusSquared)
                    {
                        continue;
                    }

                    // Sample only the exact intersecting edge range inside the circle.
                    double tStart;
                    double tEnd;
                    if (!TryGetCircleSegmentRange(p0x, p0y, dx, dy, meta.CenterX, meta.CenterY, meta.RadiusSquared, out tStart, out tEnd))
                    {
                        continue;
                    }

                    double tRange = tEnd - tStart;
                    if (tRange <= 0.0)
                    {
                        continue;
                    }

                    double insideLength = tRange * edgeLength;
                    int sampleCount = (int)Math.Ceiling(insideLength / meta.Resolution);
                    if (sampleCount < 1)
                    {
                        sampleCount = 1;
                    }

                    double dt = tRange / sampleCount;
                    double stepLength = insideLength / sampleCount;

                    // Incremental stepping avoids recomputing p0 + t*(p1-p0) for every sample.
                    double sampleT = tStart + (0.5 * dt);
                    double sampleX = p0x + (sampleT * dx);
                    double sampleY = p0y + (sampleT * dy);
                    double stepX = dx * dt;
                    double stepY = dy * dt;

                    double sampleSum = 0.0;
                    for (int sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++)
                    {
                        int ix = (int)Math.Round((sampleX - meta.OriginX) * meta.InvResolution);
                        int iy = (int)Math.Round((sampleY - meta.OriginY) * meta.InvResolution);
                        if (ix < 0)
                        {
                            ix = 0;
                        }
                        else if (ix >= meta.Width)
                        {
                            ix = meta.Width - 1;
                        }

                        float[] row = meta.Image[ix];
                        if (row != null && row.Length > 0)
                        {
                            if (iy < 0)
                            {
                                iy = 0;
                            }
                            else if (iy >= row.Length)
                            {
                                iy = row.Length - 1;
                            }

                            sampleSum += row[iy];
                        }

                        sampleX += stepX;
                        sampleY += stepY;
                    }

                    // Grade = sum of normalized edge costs.
                    double edgeCost = (sampleSum * stepLength) / edgeLength;
                    grades[threatIndex] += edgeCost;
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

        private static bool AabbOverlaps(
            double minX1, double maxX1, double minY1, double maxY1,
            double minX2, double maxX2, double minY2, double maxY2)
        {
            return minX1 <= maxX2 && maxX1 >= minX2 && minY1 <= maxY2 && maxY1 >= minY2;
        }

        private static double SquaredDistancePointToSegment(
            double px, double py,
            double p0x, double p0y,
            double dx, double dy,
            double segmentLenSquared)
        {
            if (segmentLenSquared <= 0.0)
            {
                double dpx = px - p0x;
                double dpy = py - p0y;
                return dpx * dpx + dpy * dpy;
            }

            double t = ((px - p0x) * dx + (py - p0y) * dy) / segmentLenSquared;
            if (t < 0.0)
            {
                t = 0.0;
            }
            else if (t > 1.0)
            {
                t = 1.0;
            }

            double closestX = p0x + t * dx;
            double closestY = p0y + t * dy;
            double distX = px - closestX;
            double distY = py - closestY;
            return distX * distX + distY * distY;
        }

        private static bool TryGetCircleSegmentRange(
            double p0x, double p0y,
            double dx, double dy,
            double centerX, double centerY,
            double radiusSquared,
            out double tStart,
            out double tEnd)
        {
            tStart = 0.0;
            tEnd = 0.0;

            double fx = p0x - centerX;
            double fy = p0y - centerY;
            double a = dx * dx + dy * dy;
            if (a <= 0.0)
            {
                return false;
            }

            bool startInside = (fx * fx + fy * fy) <= radiusSquared;
            double p1x = p0x + dx;
            double p1y = p0y + dy;
            double ex = p1x - centerX;
            double ey = p1y - centerY;
            bool endInside = (ex * ex + ey * ey) <= radiusSquared;

            double b = 2.0 * (fx * dx + fy * dy);
            double c = (fx * fx + fy * fy) - radiusSquared;
            double discriminant = b * b - 4.0 * a * c;
            if (discriminant < 0.0 && discriminant > -1e-12)
            {
                discriminant = 0.0;
            }

            if (discriminant < 0.0)
            {
                if (startInside && endInside)
                {
                    tStart = 0.0;
                    tEnd = 1.0;
                    return true;
                }

                return false;
            }

            double sqrtDiscriminant = Math.Sqrt(discriminant);
            double inv2a = 0.5 / a;
            double t1 = (-b - sqrtDiscriminant) * inv2a;
            double t2 = (-b + sqrtDiscriminant) * inv2a;
            if (t1 > t2)
            {
                double temp = t1;
                t1 = t2;
                t2 = temp;
            }

            if (startInside && endInside)
            {
                tStart = 0.0;
                tEnd = 1.0;
                return true;
            }

            if (startInside)
            {
                tStart = 0.0;
                tEnd = Clamp01(t2);
                return tEnd > tStart;
            }

            if (endInside)
            {
                tStart = Clamp01(t1);
                tEnd = 1.0;
                return tEnd > tStart;
            }

            tStart = Clamp01(t1);
            tEnd = Clamp01(t2);
            return tEnd > tStart;
        }

        private static double Clamp01(double value)
        {
            if (value < 0.0)
            {
                return 0.0;
            }

            if (value > 1.0)
            {
                return 1.0;
            }

            return value;
        }
    }
}
