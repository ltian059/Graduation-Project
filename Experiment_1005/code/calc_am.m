function feat_data = calc_am(peaks, onsets, fs, sig_data, up)

% eliminate any nans (which represent ectopics which have been removed)
peaks.t = peaks.t(~isnan(peaks.t));
peaks.v = peaks.v(~isnan(peaks.v));
onsets.t = onsets.t(~isnan(onsets.t));
onsets.v = onsets.v(~isnan(onsets.v));

% Find am
am.t = mean([onsets.t, peaks.t], 2);
am.v = [peaks.v - onsets.v];

% Normalise
feat_data.v = am.v./nanmean(am.v);
feat_data.t = am.t;
feat_data.fs = fs;

end