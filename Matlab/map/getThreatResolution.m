function resolution = getThreatResolution(threats)

resolution = NaN;
if isempty(threats)
    return
end

if isfield(threats, "Resolution")
    resolution = threats(1).Resolution;
end

end
