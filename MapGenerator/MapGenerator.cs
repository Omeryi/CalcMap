using ns_ThreatAnalyzer;
using System;
using System.Collections.Generic;
using System.Security.Cryptography;

namespace MapGenerator
{
    public class MapGenerator
    {
        private readonly Random rand = CreateRandom();

        private struct CellBounds
        {
            public double MinX;
            public double MaxX;
            public double MinY;
            public double MaxY;
        }

        public Map Generate(MapParameters parameters)
        {
            Map map = new Map
            {
                MapId = Guid.NewGuid(),
                Parameters = parameters,
                Threats = new List<Threat>()
            };

            List<CellBounds> cells = BuildStratifiedCells(parameters, parameters.RegionCount);
            for (int i = 0; i < parameters.RegionCount; i++)
            {
                CellBounds? cell = i < cells.Count ? (CellBounds?)cells[i] : null;
                map.Threats.Add(GenerateThreat(parameters, cell));
            }

            return map;
        }

        private Threat GenerateThreat(MapParameters parameters, CellBounds? centerCell)
        {
            double x;
            double y;
            if (centerCell.HasValue)
            {
                CellBounds cell = centerCell.Value;
                x = RandomBetween(cell.MinX, cell.MaxX);
                y = RandomBetween(cell.MinY, cell.MaxY);
            }
            else
            {
                x = RandomBetween(parameters.XMin, parameters.XMax);
                y = RandomBetween(parameters.YMin, parameters.YMax);
            }

            double r = RandomBetween(parameters.RadiusMin, parameters.RadiusMax);

            return new Threat
            {
                Id = Guid.NewGuid(),
                CenterX = x,
                CenterY = y,
                Radius = r,
                Image = GenerateImage(r)
            };
        }

        private float[][] GenerateImage(double radius)
        {
            // Compute the size of the image grid.
            // Each pixel represents Threat.resolution units in the map.
            // The image covers a square that contains the whole circular threat.
            int size = (int)Math.Ceiling((2 * radius) / Threat.resolution);

            // Create the jagged array that will hold the threat intensity values.
            float[][] image = new float[size][];
            for (int i = 0; i < size; i++)
                image[i] = new float[size];

            // Pixel index corresponding to the threat center.
            double center = size / 2.0;

            // Standard deviation of the Gaussian.
            // Choosing radius / 3 ensures that most of the Gaussian mass
            // lies inside the threat radius (~99% within 3 sigma).
            double sigma = radius / 3.0;
            double twoSigmaSq = 2 * sigma * sigma;

            for (int i = 0; i < size; i++)
            {
                for (int j = 0; j < size; j++)
                {
                    // Convert pixel coordinates to map coordinates relative to the center.
                    // Multiplying by resolution converts pixel distance into map units.
                    double x = (i - center) * Threat.resolution;
                    double y = (j - center) * Threat.resolution;

                    double dist = Math.Sqrt(x * x + y * y);

                    // If the point lies outside the threat radius,
                    // we force the value to be exactly zero.
                    // This keeps the threat compact and avoids Gaussian tails.
                    if (dist > radius)
                    {
                        image[i][j] = 0f;
                        continue;
                    }

                    // Gaussian decay based on distance from the center.
                    // Value ranges roughly between 0 and 1.
                    double distSq = dist * dist;
                    double value = Math.Exp(-distSq / twoSigmaSq);

                    // Add a small random perturbation so that the threat
                    // is not perfectly symmetric. This produces more realistic maps
                    // and prevents algorithms from exploiting artificial symmetry.
                    value += 0.03 * rand.NextDouble();

                    // Clamp to ensure the value never exceeds 1.
                    if (value > 1)
                        value = 1;

                    image[i][j] = (float)value;
                }
            }

            return image;
        }

        private List<CellBounds> BuildStratifiedCells(MapParameters parameters, int count)
        {
            List<CellBounds> cells = new List<CellBounds>();
            if (count <= 0)
            {
                return cells;
            }

            double width = parameters.XMax - parameters.XMin;
            double height = parameters.YMax - parameters.YMin;
            if (width <= 0 || height <= 0)
            {
                return cells;
            }

            // Stratified random placement keeps threats random but avoids heavy clustering.
            double aspect = width / height;
            int cols = Math.Max(1, (int)Math.Ceiling(Math.Sqrt(count * aspect)));
            int rows = Math.Max(1, (int)Math.Ceiling((double)count / cols));
            while (rows * cols < count)
            {
                rows++;
            }

            double cellWidth = width / cols;
            double cellHeight = height / rows;
            cells = new List<CellBounds>(rows * cols);

            for (int row = 0; row < rows; row++)
            {
                for (int col = 0; col < cols; col++)
                {
                    double minX = parameters.XMin + col * cellWidth;
                    double maxX = col == cols - 1 ? parameters.XMax : minX + cellWidth;
                    double minY = parameters.YMin + row * cellHeight;
                    double maxY = row == rows - 1 ? parameters.YMax : minY + cellHeight;

                    cells.Add(new CellBounds
                    {
                        MinX = minX,
                        MaxX = maxX,
                        MinY = minY,
                        MaxY = maxY
                    });
                }
            }

            Shuffle(cells);
            if (cells.Count > count)
            {
                cells.RemoveRange(count, cells.Count - count);
            }

            return cells;
        }

        private void Shuffle(List<CellBounds> cells)
        {
            for (int i = cells.Count - 1; i > 0; i--)
            {
                int j = rand.Next(i + 1);
                CellBounds temp = cells[i];
                cells[i] = cells[j];
                cells[j] = temp;
            }
        }

        private double RandomBetween(double min, double max)
        {
            return min + rand.NextDouble() * (max - min);
        }

        private static Random CreateRandom()
        {
            byte[] seedBytes = new byte[4];
            using (RandomNumberGenerator rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(seedBytes);
            }

            int seed = BitConverter.ToInt32(seedBytes, 0);
            return new Random(seed);
        }
    }
}
