function feat_data = calc_fm(peaks, fs)

% find fm
fm.v = [peaks.t(2:end) - peaks.t(1:(end-1))]/fs;
fm.t = mean([peaks.t(2:end), peaks.t(1:(end-1))], 2);

% eliminate any nans (which represent ectopics which have been removed)
fm.t = fm.t(~isnan(fm.t));
fm.v = fm.v(~isnan(fm.v));

% Normalise
feat_data.v = fm.v./nanmean(fm.v);
feat_data.t = fm.t;
feat_data.fs = fs;

end