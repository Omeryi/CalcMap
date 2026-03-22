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
        // Caches values derived from a Threat once so the edge/sample loops can reuse them cheaply.
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
                if (threat == null)
                {
                    throw new ArgumentNullException(nameof(threat), "Threat entries cannot be null.");
                }

                Id = threat.Id;
                CenterX = threat.CenterX;
                CenterY = threat.CenterY;
                double radius = threat.Radius;
                RadiusSquared = radius * radius;
                BoundsMinX = CenterX - radius;
                BoundsMaxX = CenterX + radius;
                BoundsMinY = CenterY - radius;
                BoundsMaxY = CenterY + radius;

                if (threat.Resolution <= 0)
                {
                    throw new ArgumentException(
                        $"Threat {Id} must have a positive resolution.",
                        nameof(threat));
                }

                Resolution = threat.Resolution;
                // Cache 1 / resolution so the hot sampling loop can multiply instead of divide.
                InvResolution = 1.0 / Resolution;
                ImageOriginX = BoundsMinX;
                ImageOriginY = BoundsMinY;

                Image = threat.Image;
                if (Image == null || Image.Length == 0)
                {
                    throw new ArgumentException(
                        $"Threat {Id} must contain image data.",
                        nameof(threat));
                }

                ImageWidth = Image.Length;
                for (int rowIndex = 0; rowIndex < ImageWidth; rowIndex++)
                {
                    float[] row = Image[rowIndex];
                    if (row == null || row.Length == 0)
                    {
                        throw new ArgumentException(
                            $"Threat {Id} contains an empty image row at index {rowIndex}.",
                            nameof(threat));
                    }
                }
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

            for (int edgeIndex = 0; edgeIndex < path.Count - 1; edgeIndex++)
            {
                Point p0 = path[edgeIndex];
                Point p1 = path[edgeIndex + 1];

                double p0x = p0.X;
                double p0y = p0.Y;
                double dx = p1.X - p0x;
                double dy = p1.Y - p0y;
                double edgeLenSquared = dx * dx + dy * dy;
                if (edgeLenSquared == 0.0)
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
                    // Two-stage relevance check:
                    // 1. Bounding boxes overlap (cheap broad phase)  2. squared segment-center distance <= r^2.
                    if (!BoundingBoxesOverlap(
                        edgeMinX, edgeMaxX, edgeMinY, edgeMaxY,
                        meta.BoundsMinX, meta.BoundsMaxX, meta.BoundsMinY, meta.BoundsMaxY))
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
                    if (!TryGetSegmentRangeInsideCircle(
                        p0x, p0y, dx, dy,
                        meta.CenterX, meta.CenterY, meta.RadiusSquared,
                        out tStart, out tEnd))
                    {
                        continue;
                    }

                    double tRange = tEnd - tStart;
                    double insideLength = tRange * edgeLength;
                    int sampleCount = (int)Math.Ceiling(insideLength / meta.Resolution);
                    sampleCount = Math.Max(sampleCount, 1);

                    // Parameter-space step between adjacent samples along the clipped segment.
                    double dt = tRange / sampleCount;
                    // Real distance covered by each sample step along the portion inside the map.
                    double stepLength = insideLength / sampleCount;

                    // Start at the beginning of the clipped interval and then advance incrementally
                    // instead of recomputing p0 + t*(p1-p0) for every sample.
                    double sampleT = tStart;
                    double sampleX = p0x + (sampleT * dx);
                    double sampleY = p0y + (sampleT * dy);
                    double stepX = dx * dt;
                    double stepY = dy * dt;

                    double sampleSum = 0.0;
                    for (int sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++)
                    {
                        // Convert the current sample position from map coordinates into the
                        // nearest threat cell index using the image origin and resolution.
                        int ix = (int)Math.Round((sampleX - meta.ImageOriginX) * meta.InvResolution);
                        int iy = (int)Math.Round((sampleY - meta.ImageOriginY) * meta.InvResolution);

                        // Clamp x into the valid image column range.
                        ix = Math.Max(ix, 0);
                        ix = Math.Min(ix, meta.ImageWidth - 1);

                        // Each x column stores its y samples in a jagged row array.
                        float[] row = meta.Image[ix];
                        // Clamp y into the valid range for this column.
                        iy = Math.Max(iy, 0);
                        iy = Math.Min(iy, row.Length - 1);

                        // Accumulate the threat value at this sampled cell.
                        sampleSum += row[iy];

                        // Advance to the next sample point along the segment.
                        sampleX += stepX;
                        sampleY += stepY;
                    }

                    double edgeCost = (sampleSum / sampleCount) * edgeLength;
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

        private static bool BoundingBoxesOverlap(
            double minX1, double maxX1, double minY1, double maxY1,
            double minX2, double maxX2, double minY2, double maxY2)
        {
            return minX1 <= maxX2 && maxX1 >= minX2 && minY1 <= maxY2 && maxY1 >= minY2;
        }

        private static double SquaredDistancePointToSegment(
            double pointX, double pointY,
            double segmentStartX, double segmentStartY,
            double segmentDeltaX, double segmentDeltaY,
            double segmentLengthSquared)
        {
            // Degenerate segment: both endpoints are the same point.
            if (segmentLengthSquared == 0.0)
            {
                double deltaToStartX = pointX - segmentStartX;
                double deltaToStartY = pointY - segmentStartY;
                return deltaToStartX * deltaToStartX + deltaToStartY * deltaToStartY;
            }

            // Project onto the infinite line, then clamp to the finite segment [0, 1].
            double t = ((pointX - segmentStartX) * segmentDeltaX + (pointY - segmentStartY) * segmentDeltaY)
                / segmentLengthSquared;
            t = Clamp01(t);

            double closestPointX = segmentStartX + t * segmentDeltaX;
            double closestPointY = segmentStartY + t * segmentDeltaY;
            double distanceX = pointX - closestPointX;
            double distanceY = pointY - closestPointY;
            return distanceX * distanceX + distanceY * distanceY;
        }

        // Returns the [tStart, tEnd] portion of the segment that lies inside the circle.
        private static bool TryGetSegmentRangeInsideCircle(
            double segmentStartX, double segmentStartY,
            double segmentDeltaX, double segmentDeltaY,
            double circleCenterX, double circleCenterY,
            double circleRadiusSquared,
            out double rangeStartT,
            out double rangeEndT)
        {
            rangeStartT = 0.0;
            rangeEndT = 0.0;

            double startOffsetX = segmentStartX - circleCenterX;
            double startOffsetY = segmentStartY - circleCenterY;
            double segmentLengthSquared = segmentDeltaX * segmentDeltaX + segmentDeltaY * segmentDeltaY;
            if (segmentLengthSquared == 0.0)
            {
                return false;
            }

            // Check whether each segment endpoint already lies inside the circle.
            bool startInside = (startOffsetX * startOffsetX + startOffsetY * startOffsetY) <= circleRadiusSquared;
            double segmentEndX = segmentStartX + segmentDeltaX;
            double segmentEndY = segmentStartY + segmentDeltaY;
            double endOffsetX = segmentEndX - circleCenterX;
            double endOffsetY = segmentEndY - circleCenterY;
            bool endInside = (endOffsetX * endOffsetX + endOffsetY * endOffsetY) <= circleRadiusSquared;
            if (startInside && endInside)
            {
                // If both endpoints are inside then the whole segment is inside.
                rangeStartT = 0.0;
                rangeEndT = 1.0;
                return true;
            }

            // Solve the line-circle intersection quadratic in segment parameter t.
            double quadraticB = 2.0 * (startOffsetX * segmentDeltaX + startOffsetY * segmentDeltaY);
            double quadraticC = (startOffsetX * startOffsetX + startOffsetY * startOffsetY) - circleRadiusSquared;
            // Discriminant of a*t^2 + b*t + c = 0:
            // < 0 means no real line-circle intersection, 0 means tangent, > 0 means two intersections.
            double discriminant = quadraticB * quadraticB - 4.0 * segmentLengthSquared * quadraticC;
            // Allow tiny negative values caused by floating-point roundoff and treat them as tangent.
            if (discriminant < 0.0 && discriminant > -1e-12)
            {
                discriminant = 0.0;
            }

            if (discriminant < 0.0)
            {
                // No line-circle intersection, and we already ruled out the fully-inside case above.
                return false;
            }

            double sqrtDiscriminant = Math.Sqrt(discriminant);
            double inverseTwoA = 0.5 / segmentLengthSquared;
            double intersectionT1 = (-quadraticB - sqrtDiscriminant) * inverseTwoA;
            double intersectionT2 = (-quadraticB + sqrtDiscriminant) * inverseTwoA;
            // Order the two line-circle intersection parameters from entry to exit.
            if (intersectionT1 > intersectionT2)
            {
                double temp = intersectionT1;
                intersectionT1 = intersectionT2;
                intersectionT2 = temp;
            }

            // If an endpoint is already inside, use that endpoint as the corresponding range bound.
            // Otherwise clamp the entry/exit intersection to the finite segment [0, 1].
            rangeStartT = startInside ? 0.0 : Clamp01(intersectionT1);
            rangeEndT = endInside ? 1.0 : Clamp01(intersectionT2);
            return rangeEndT > rangeStartT;
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
