using ns_ThreatAnalyzer;
using System;
using System.Collections.Generic;

namespace MapGenerator
{
    public class MapGenerator
    {
        private readonly Random rand = new Random();

        public Map Generate(MapParameters parameters)
        {
            Map map = new Map
            {
                MapId = Guid.NewGuid(),
                Parameters = parameters,
                Threats = new List<Threat>()
            };

            for (int i = 0; i < parameters.RegionCount; i++)
            {
                map.Threats.Add(GenerateThreat(parameters));
            }

            return map;
        }

        private Threat GenerateThreat(MapParameters parameters)
        {
            double x = RandomBetween(parameters.XMin, parameters.XMax);
            double y = RandomBetween(parameters.YMin, parameters.YMax);
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
            // lies inside the threat radius (~99% within 3σ).
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

        private double RandomBetween(double min, double max)
        {
            return min + rand.NextDouble() * (max - min);
        }
    }
}