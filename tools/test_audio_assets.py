import wave
import os
import math
import struct
import re

def analyze_wav(path):
    if not os.path.exists(path):
        return False, "File Not Found", 0, 0, 0, 0, 0
    try:
        with wave.open(path, 'rb') as w:
            nchannels, sampwidth, framerate, nframes, comptype, compname = w.getparams()
            duration = nframes / float(framerate) if framerate > 0 else 0
            raw = w.readframes(nframes)
            if sampwidth == 2 and nframes > 0:
                fmt = f"<{nframes * nchannels}h"
                samples = struct.unpack(fmt, raw)
                max_val = max(abs(s) for s in samples) if samples else 0
                peak_db = 20 * math.log10(max_val / 32768.0) if max_val > 0 else -99.0
                sum_sq = sum(s * s for s in samples)
                rms = math.sqrt(sum_sq / len(samples)) if samples else 0
                rms_db = 20 * math.log10(rms / 32768.0) if rms > 0 else -99.0
                clipping = max_val >= 32760
            else:
                peak_db, rms_db, clipping = 0.0, 0.0, False
            return True, "Valid", duration, framerate, nchannels, peak_db, rms_db, clipping
    except Exception as e:
        return False, str(e), 0, 0, 0, 0, 0, False

def run_diagnostics():
    print("=" * 80)
    print("BLACKOUT AUDIO ASSETS DIAGNOSTICS & VERIFICATION")
    print("=" * 80)

    with open('assets/audio/audio_registry.gd', 'r') as f:
        text = f.read()

    pattern = re.compile(
        r'([A-Z0-9_]+):\s*\{\s*'
        r'"bus":\s*([A-Za-z0-9_]+),\s*'
        r'"category":\s*Category\.([A-Za-z0-9_]+),\s*'
        r'"context":\s*Context\.([A-Za-z0-9_]+),\s*'
        r'"path":\s*"res://([^"]+)"'
    )
    
    matches = pattern.findall(text)
    print(f"Total Registry Events: {len(matches)}")
    print("-" * 80)
    print(f"{'EVENT':<24} | {'CAT':<8} | {'BUS':<8} | {'DUR':<6} | {'PEAK':<7} | {'RMS':<7} | {'STATUS'}")
    print("-" * 80)

    success_count = 0
    warning_count = 0
    fail_count = 0

    for ev, bus, cat, ctx, rel_path in matches:
        ok, msg, dur, rate, ch, peak, rms, clip = analyze_wav(rel_path)
        if not ok:
            status = "MISSING/ERROR"
            fail_count += 1
        elif clip:
            status = "CLIPPING"
            warning_count += 1
        elif peak < -50.0:
            status = "TOO SILENT"
            warning_count += 1
        else:
            status = "PASS"
            success_count += 1

        print(f"{ev:<24} | {cat:<8} | {bus:<8} | {dur:5.2f}s | {peak:5.1f}dB | {rms:5.1f}dB | {status}")

    print("=" * 80)
    print(f"SUMMARY: {success_count} Passed | {warning_count} Warnings | {fail_count} Failed (Total {len(matches)})")
    print("=" * 80)

if __name__ == "__main__":
    run_diagnostics()
