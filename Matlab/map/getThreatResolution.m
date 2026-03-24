function resolution = getThreatResolution(threats)

if isempty(threats)
    error("getThreatResolution:NoThreats", "Threat list must contain at least one threat.");
end

if ~isfield(threats, "Resolution")
    error("getThreatResolution:MissingResolution", "Threat data is missing the Resolution field.");
end

resolution = double(threats(1).Resolution);
if ~isfinite(resolution) || resolution <= 0
    error("getThreatResolution:InvalidResolution", "Threat resolution must be a positive finite number.");
end

end
