% Normalize Each Radar Scan
function normA = Array_Normalization(Array)
    normA = Array - min(Array(:));
    normA = normA ./ max(normA(:));
end
