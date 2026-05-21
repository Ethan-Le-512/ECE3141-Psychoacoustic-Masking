% ============================================================
% ECE3141 - Psychoacoustic Masking Project
% Created by Gia Le (36378321) and Hadar Flenner (34976779)
%
% This program demonstrates a simplified psychoacoustic 
% audio compression system inspired by MP3 compression
%
% Main ideas and tests:
%   - Analyse audio in the frequency domain
%   - Estimate what sounds the ear cannot hear
%   - Remove masked frequencies
%   - Reconstruct the signal
%
% ============================================================

clear; clc; close all;

% User settings - change audio_file for various testing
AUDIO_FILE = 'original.wav';
FRAME_LEN  = 1024;
HOP        = 512;
SPL_OFFSET = 96;     % approx calibration
MASKER_DB  = 40;     % min level for a peak to count as a tonal masker
OUT_DIR    = 'C:\Users\ehudf\Downloads'; %change to any directory

% load audio, convert to mono if needed
[x, fs] = audioread(AUDIO_FILE);
if size(x,2) == 2, x = mean(x,2); end
x = x / max(abs(x));

% STFT 
win = hann(FRAME_LEN, 'periodic');
[S, F] = stft(x, fs, 'Window', win, 'OverlapLength', FRAME_LEN-HOP,'FFTLength', FRAME_LEN, 'FrequencyRange', 'onesided');
mag_dB = 20*log10(abs(S) + 1e-10) + SPL_OFFSET;

% Bark scale + Absolute Threshold of Hearing(ATH)
bark    = 13*atan(0.76*F/1000) + 3.5*atan((F/7500).^2);
T_quiet = 3.64*(F/1000+1e-6).^(-0.8) - 6.5*exp(-0.6*((F/1000)-3.3).^2) + 1e-3*(F/1000).^4;
T_quiet = min(T_quiet, 90);

% Per-frame masking threshold
T = zeros(size(mag_dB));
for k = 1:size(S,2)
    T(:,k) = mask_threshold(mag_dB(:,k), bark, T_quiet, MASKER_DB);
end

%T = T + 30; %this is for testing sensitivity
%Strategy A: masking-aware (zero bins below threshold)
keep_mask = mag_dB >= T;
S_mask    = S .* keep_mask;

%Strategy B: blind (match Strategy A's kill count, kill lowest mag)
keep_blind = mag_dB >= T_quiet;
S_blind    = S .* keep_blind;


% ISTFT both
y_mask  = istft(S_mask,  fs, 'Window', win, 'OverlapLength', FRAME_LEN-HOP,'FFTLength', FRAME_LEN, 'FrequencyRange', 'onesided');
y_blind = istft(S_blind, fs, 'Window', win, 'OverlapLength', FRAME_LEN-HOP,'FFTLength', FRAME_LEN, 'FrequencyRange', 'onesided');

% Stats 
edge = FRAME_LEN;
L = min([length(x), length(y_mask), length(y_blind)]);
x_ref   = x(edge+1 : L-edge);
y_mask  = real(y_mask(edge+1 : L-edge));
y_blind = real(y_blind(edge+1 : L-edge));

fprintf('Avg bins killed per frame: %.0f of %d (%.0f%%)\n', mean(sum(~keep_mask)), size(S,1), 100*mean(sum(~keep_mask))/size(S,1));
fprintf('SSE  Masking: %.4f \n',sum((x_ref - y_mask).^2));
fprintf('SSE  Blind  : %.4f \n',sum((x_ref - y_blind).^2));

% Save WAVs 
if ~exist(OUT_DIR,'dir'), mkdir(OUT_DIR); end
% RMS-match all reconstructions to the original
ref_rms = rms(x_ref);
y_mask  = y_mask  * (ref_rms / rms(y_mask));
y_blind = y_blind * (ref_rms / rms(y_blind));
% Then save without peak normalisation 
audiowrite(fullfile(OUT_DIR,'original.wav'),    x_ref,                          fs);
audiowrite(fullfile(OUT_DIR,'recon_mask.wav'),  min(max(y_mask,  -0.99), 0.99), fs);
audiowrite(fullfile(OUT_DIR,'recon_blind.wav'), min(max(y_blind, -0.99), 0.99), fs);
% Plot in one frame
k0 = min(200, size(S,2));
figure('Name','Strategy comparison');
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
plot_strategy(bark, mag_dB(:,k0), T(:,k0), T_quiet, ~keep_mask(:,k0),  'Masking-aware');
plot_strategy(bark, mag_dB(:,k0), T(:,k0), T_quiet, ~keep_blind(:,k0), 'Blind (above-ATH)');
sgtitle(sprintf('Visual spectral comparison'));
fprintf('Bins killed per frame:  Masking %.0f  vs  Blind %.0f  (of %d)\n', ...
        mean(sum(~keep_mask)), mean(sum(~keep_blind)), size(S,1));

%local functions 
function T = mask_threshold(mag, bark, ATH, masker_db)
% Tonal masking with SMR offset (B&G Ch.6, MPEG-1 PM1 simplification)
    is_peak = false(size(mag));
    is_peak(2:end-1) = mag(2:end-1) > mag(1:end-2) &  mag(2:end-1) > mag(3:end) & mag(2:end-1) > masker_db;
    m = find(is_peak);
    if isempty(m), T = ATH; return; end
    SMR    = 14.5 + bark(m);
    lvl    = (mag(m) - SMR).';                   % 1 x M
    dz     = bark(:) - bark(m).';                % nbins x M
    spread = lvl + 25*dz;                        % lower side: -27 dB/Bark
    above  = lvl - 10*dz;                        % upper side: -15 dB/Bark
    spread(dz >= 0) = above(dz >= 0);
    T = max(ATH, max(spread, [], 2));
end

function plot_strategy(bark, mag, T, ATH, kill, name)
    nexttile;
    kept = mag; kept(kill) = NaN;
    plot(bark, mag,  'Color', [0 0 0], 'LineWidth', 0.5, 'DisplayName', 'Removed'); hold on;
    plot(bark, kept, 'Color', [0.80 0.70 0.00], 'LineWidth', 1.2, 'DisplayName', 'Kept');
    plot(bark, T,    'r--', 'LineWidth', 1.2, 'DisplayName', 'Mask T');
    plot(bark, ATH,  'b:',  'LineWidth', 1.2, 'DisplayName', 'ATH');
    xlabel('Bark'); ylabel('dB SPL'); ylim([-20 140]); grid on;
    title(sprintf('%s - kills %d bins', name, sum(kill)));
    legend('Location','northeast');
end

%% Time-domain reconstruction comparison

t = (0:length(x_ref)-1) / fs;
figure('Name','Reconstructed Signals');
plot(t, x_ref, 'b', 'LineWidth', 1);
hold on;
plot(t, y_mask, 'r--', 'LineWidth', 0.9);
%plot(t, y_blind, 'k:', 'LineWidth', 0.9);
xlabel('Time (s)');
ylabel('Amplitude');
title('Original and Reconstructed Audio Signals');
legend('Original Signal', 'Masking-aware Reconstruction','Blind Reconstruction');
grid on;
hold off
%xlim([0 min(0.05, t(end))]);   % zoom into first 50 ms