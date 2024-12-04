function feat_data = calc_bw(peaks, onsets, fs)

% eliminate any nans (which represent ectopics which have been removed)
peaks.t = peaks.t(~isnan(peaks.t));
peaks.v = peaks.v(~isnan(peaks.v));
onsets.t = onsets.t(~isnan(onsets.t));
onsets.v = onsets.v(~isnan(onsets.v));

% Find bw
bw.v = mean([onsets.v, peaks.v], 2);
bw.t = mean([onsets.t, peaks.t], 2);

% Find am
am.t = mean([onsets.t, peaks.t], 2);
am.v = [peaks.v - onsets.v];

% Normalise
feat_data.v = bw.v./nanmean(am.v);
feat_data.t = bw.t;
feat_data.fs = fs;

end