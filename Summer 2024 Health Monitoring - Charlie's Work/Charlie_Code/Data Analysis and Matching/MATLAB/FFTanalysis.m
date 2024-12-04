function [sub,f] = FFTanalysis(y,fs)
% fs = 1/ts;
len = length(y);
NFFT = 2^nextpow2(len);
y = y-mean(y);
sub = fft(y,NFFT)/len;
sub = 2*abs(sub(1:NFFT/2+1));
f = fs/2*linspace(0,1,NFFT/2+1)*60;
end