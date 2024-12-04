function resampled_data = lin(feat_data, fs)

if length(feat_data.t) <2
    resampled_data.t = nan;
    resampled_data.v = nan;
    return
end

resampled_data.t = feat_data.t(1):(1/fs):feat_data.t(end);
resampled_data.v = interp1(feat_data.t, feat_data.v, resampled_data.t, 'linear');

end