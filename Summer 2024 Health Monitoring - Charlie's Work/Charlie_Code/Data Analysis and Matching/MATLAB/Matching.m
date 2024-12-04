close all
signal_belt1_ = -all_belt(:,1); % Group 1, Signal Belt
signal_radar1_ = all_radar(:,1); % Group 1, Signal Radar
signal_belt2_ = -all_belt(:,1); % Group 2, Signal Belt
signal_radar2_ = all_radar(:,1); % Group 2, Signal Radar

%Belt Signals are inverted (belt force increases on inhale, radar distance
%decreases)

% Upsample signal Belt to match the length of signal Radar
x1 = linspace(0, 1, length(signal_radar1_));
x2 = linspace(0, 1, length(signal_belt1_));
signal_belt1_upsampled = interp1(x2, signal_belt1_, x1, 'linear')'; % Linear interpolation


% Upsample signalA to match the length of signalB
x1 = linspace(0, 1, length(signal_radar2_));
x2 = linspace(0, 1, length(signal_belt2_));
signal_belt2_upsampled = interp1(x2, signal_belt2_, x1, 'linear')'; % Linear interpolation

% Normalize both signals to the range [-1, 1]
signal_belt1_normalized = 2 * (signal_belt1_upsampled - min(signal_belt1_upsampled)) / (max(signal_belt1_upsampled) - min(signal_belt1_upsampled)) - 1;
signal_belt2_normalized = 2 * (signal_belt2_upsampled - min(signal_belt2_upsampled)) / (max(signal_belt2_upsampled) - min(signal_belt2_upsampled)) - 1;
signal_radar1_normalized = 2 * (signal_radar1_ - min(signal_radar1_)) / (max(signal_radar1_) - min(signal_radar1_)) - 1;
signal_radar2_normalized = 2 * (signal_radar2_ - min(signal_radar2_)) / (max(signal_radar2_) - min(signal_radar2_)) - 1;

% Time vector used in plotting
ts=linspace(0,duration,length(signal_radar1_normalized))';

% Plot the normalized signals
figure;
hold on
plot(ts,signal_belt1_normalized,'Color','b','DisplayName','Belt');
plot(ts,signal_radar1_normalized,'Color','r','DisplayName','Radar');
legend
hold off

figure;
hold on
plot(ts,signal_belt2_normalized,'Color','b','DisplayName','Belt');
plot(ts,signal_radar2_normalized,'Color','r','DisplayName','Radar');
legend
hold off

% Calculate DTW (dynamic time warping) distances between each pair of signals from different groups
dist_belt1_radar1 = dtw(signal_belt1_normalized, signal_radar1_normalized);
figure('Name','Belt-1 Radar-1');
dtw(signal_belt1_normalized, signal_radar1_normalized);

dist_belt1_radar2 = dtw(signal_belt1_normalized, signal_radar2_normalized);
figure('Name','Belt-1 Radar-2');
dtw(signal_belt1_normalized, signal_radar2_normalized);

dist_belt2_radar1 = dtw(signal_belt2_normalized, signal_radar1_normalized);
figure('Name','Belt-2 Radar-1');
dtw(signal_belt2_normalized, signal_radar1_normalized);

dist_belt2_radar2 = dtw(signal_belt2_normalized, signal_radar2_normalized);
figure('Name','Belt-2 Radar-2');
dtw(signal_belt2_normalized, signal_radar2_normalized);

%Store distances in a matrix
distances = [dist_belt1_radar1, dist_belt1_radar2, dist_belt2_radar1, dist_belt2_radar2];
names = {'B1R1','B1R2','B2R1','B2R2'};
% Display the DTW distances close a
disp('DTW Distances:');
for i = 1:length(names)
    fprintf('%s: %d\n', names{i}, distances(i));
end
% 
% % Find the minimum distance and corresponding indices
[min_dist, min_idx] = min(distances(:));
[row, col] = ind2sub(size(distances), min_idx);
% 
% % Display the best match
disp(['Best match:', names{min_idx}]);
disp(['Minimum DTW Distance: ', num2str(min_dist)]);


num_signals = 4;

signals = zeros(num_signals, length(ts));
signals(1, :) = signal_belt1_normalized;
signals(2, :) = signal_radar1_normalized;
signals(3, :) = signal_belt2_normalized;
signals(4, :) = signal_radar2_normalized;
% Initialize a matrix to store ICA components
ica_components = zeros(num_signals, length(ts));

% Apply FastICA to each signal
for i = 1:num_signals
    [icasig, ~, ~] = fastica(signals(i, :), 'numOfIC', 4);
    ica_components(i, :) = icasig;
end

% Plot the original signals and their ICA components
figure;
for i = 1:num_signals
    subplot(num_signals+1, 1, i);
    plot(ts, signals(i, :));
    title(['Original Signal ' num2str(i)]);
end

subplot(num_signals+1, 1, num_signals+1);
hold on;
for i = 1:num_signals
    plot(ts, ica_components(i, :));
end
title('ICA Components');
legend(arrayfun(@(x) ['ICA Component of Signal ' num2str(x)], 1:num_signals, 'UniformOutput', false));

% Calculate and display correlations between all permutations of ICA components
for i = 1:num_signals
    for j = i+1:num_signals
        correlation = corrcoef(ica_components(i, :), ica_components(j, :));
        fprintf('Correlation between ICA Component of Signal %d and Signal %d: %f\n', i, j, correlation(1, 2));
    end
end


% Matched Filtering Script with Two Groups of Signals
% This script uses matched filtering to compare signals from two groups and calculates the scores for each combination.

numSignalsGroup1 = num_signals/2; % Number of signals in group 1
numSignalsGroup2 = numSignalsGroup1; % Number of signals in group 2

% Define a function to perform matched filtering
matchedFilter = @(x, h) conv(x, flipud(conj(h)), 'same');

% Initialize variables to store scores
scores = zeros(numSignalsGroup1, numSignalsGroup2);


signalsGroup1 = [signals(1, :)', signals(3, :)'];
signalsGroup2 = [signals(2, :)', signals(4, :)'];
% Define a threshold for RMS value
threshold = 0.5; % Example threshold, adjust as needed

% Loop through all combinations of signals from the two groups and calculate the scores
for i = 1:numSignalsGroup1
    for j = 1:numSignalsGroup2
        signal1 = signalsGroup1(:, i);
        signal2 = signalsGroup2(:, j);
        
        % Perform matched filtering
        filteredSignal = matchedFilter(signal1, signal2);
        
        % Compute the score (RMS value of the filtered signal)
        peakValue = max(abs(filteredSignal));
        energy1 = sum(signal1.^2);
        energy2 = sum(signal2.^2);
        normPeak = peakValue/sqrt(energy1*energy2);
        avgPower = mean(filteredSignal.^2);
        rms = sqrt(avgPower);
        scores(i, j) = normPeak;
    end
end

% Display the scores for each combination
disp('Scores for each combination:');
disp(scores);


% Determine which pairs match based on the threshold
matches = scores <= threshold;

% Display the matching results
disp('Matching Results (1 = Match, 0 = No Match):');
disp(matches);

% Find the best matching combination
[bestScore, bestIdx] = max(scores(:));
[bestIdx1, bestIdx2] = ind2sub(size(scores), bestIdx);
bestMatch = [bestIdx1, bestIdx2];

% Display the best matching combination and score
disp('Best Matching Pair:');
disp(['Group 1 Signal ', num2str(bestMatch(1)), ' and Group 2 Signal ', num2str(bestMatch(2))]);
disp('Best Score:');
disp(bestScore);

signal1_names = {'Belt 1', 'Belt 2'};
signal2_names = {'Radar 1', 'Radar 2'};
% Plot the original signals and the matched filter output for each combination
for i = 1:numSignalsGroup1
    for j = 1:numSignalsGroup2
        signal1 = signalsGroup1(:, i);
        signal2 = signalsGroup2(:, j);
        filteredSignal = matchedFilter(signal1, signal2);
        
        % Get signal names
        signal1_name = signal1_names{i};
        signal2_name = signal2_names{j};

        figure;
        sgtitle(['Matched Filtering between ', signal1_name, ' and ', signal2_name]);
        % sgtitle(['Group 1 Signal ', num2str(i), ' and Group 2 Signal ', num2str(j)]);
        
        subplot(3, 1, 1);
        plot(signal1);
        % title(['Original Signal from Group 1 - Signal ', num2str(i)]);
        title(['Original Signal: ', signal1_name]);

        subplot(3, 1, 2);
        plot(signal2);
        title(['Original Signal: ', signal2_name]);
        % title(['Original Signal from Group 2 - Signal ', num2str(j)]);
        
        subplot(3, 1, 3);
        plot(filteredSignal);
        title('Matched Filter Output');
        % title(['Matched Filter Output for Signals ', num2str(i), ' and ', num2str(j)]);
    end
end
