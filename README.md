# ECE3141 – Psychoacoustic Masking Demo

A simplified psychoacoustic audio compression system built for ECE3141 (Information & Networks) at Monash University. Inspired by the perceptual coding ideas behind MP3.

**Authors:** Gia Le  and Hadar Flenner 

---

## What it does

The program processes a mono `.wav` file frame-by-frame, estimates what the human auditory system cannot hear, and discards those frequency components before reconstructing the signal. Two strategies are compared:

- **Strategy A – Masking-aware:** zeros out frequency bins whose SPL falls below the estimated masking threshold
- **Strategy B – Blind (above-ATH):** zeros out bins below the Absolute Threshold of Hearing only, with no tonal masking

The output is three `.wav` files and two figures showing spectral and time-domain comparisons.

---

## How it works

1. **STFT** – the input signal is windowed with a 1024-point Hann window (512-sample hop) and transformed into the frequency domain
2. **Bark scale** – frequencies are mapped to the Bark perceptual scale using the standard arctangent formula
3. **ATH** – the Absolute Threshold of Hearing is computed per-bin as a function of frequency
4. **Tonal masking** – local spectral peaks above `MASKER_DB` (default 40 dB SPL) are identified as tonal maskers; each spreads a masking skirt using asymmetric slopes (~25 dB/Bark below, ~10 dB/Bark above), loosely following the MPEG-1 psychoacoustic model
5. **Threshold** – per-frame masking threshold is the maximum of the ATH and all masker contributions
6. **Reconstruction** – ISTFT is applied to the thresholded spectrum; both strategies are reconstructed and RMS-matched to the original before saving

---

## Files

| File | Description |
|------|-------------|
| `final.m` | Main MATLAB script |
| `original.wav` | Input audio file (not included – supply your own) |

Outputs (written to `OUT_DIR`):

| File | Description |
|------|-------------|
| `original.wav` | Trimmed reference signal |
| `recon_mask.wav` | Masking-aware reconstruction |
| `recon_blind.wav` | Blind (ATH-only) reconstruction |

---

## Requirements

- MATLAB R2019b or later
- Signal Processing Toolbox (for `stft`, `istft`, `hann`)

---

## Usage

1. Place your audio file in the working directory and set `AUDIO_FILE` at the top of the script
2. Set `OUT_DIR` to a valid output path
3. Run `final.m`

Key parameters you can tweak:

| Parameter | Default | Effect |
|-----------|---------|--------|
| `FRAME_LEN` | 1024 | FFT/window length |
| `HOP` | 512 | Hop size (50% overlap) |
| `SPL_OFFSET` | 96 dB | Calibration offset converting normalised amplitude to dB SPL |
| `MASKER_DB` | 40 dB | Minimum SPL for a spectral peak to count as a tonal masker |

To test threshold sensitivity, uncomment the `T = T + 30` line to raise all thresholds by 30 dB and observe more aggressive bin removal.

---

## Output figures

**Strategy comparison plot** – Bark-domain spectrum for a single frame (default: frame 200), showing kept vs removed bins, the masking threshold, and the ATH for both strategies.

**Time-domain plot** – full-length overlay of the original and masking-aware reconstruction.

Console output reports average bins killed per frame (count and percentage) and SSE relative to the original for both strategies.

---

## Notes

- The masking model is a simplified version of the MPEG-1 Psychoacoustic Model 1 (Layer II). It does not implement the full noise masking, simultaneous masking interactions, or temporal masking found in a real MP3 encoder.
- RMS normalisation is applied before saving to ensure level-matched listening comparisons.
- Edge frames (one `FRAME_LEN` at each end) are discarded before computing statistics to avoid ISTFT boundary artefacts.
