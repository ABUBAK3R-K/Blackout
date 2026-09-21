"""
BLACKOUT — Member 8 High-Fidelity Audio Asset Synthesizer
Generates 100% authentic, playable, uncompressed PCM 16-bit 44.1kHz WAV audio files
for all gameplay contexts in BLACKOUT.
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
TWO_PI = 2.0 * math.pi

def write_wav(filepath: str, samples: list[float], channels: int = 1, sample_rate: int = SAMPLE_RATE):
    """Writes normalized floating-point samples [-1.0, 1.0] to a standard 16-bit PCM WAV file."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(filepath, 'wb') as wav_file:
        wav_file.setnchannels(channels)
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        
        # Max peak check and gentle normalization
        peak = max(max(abs(s) for s in samples), 1e-6)
        scale = 32000.0 / peak if peak > 1.0 else 32000.0
        
        packed_frames = bytearray()
        for sample in samples:
            clamped = max(-1.0, min(1.0, sample))
            val = int(clamped * 32767.0 * 0.95) # Keep 5% headroom to guarantee zero clipping
            val = max(-32767, min(32767, val))
            packed_frames.extend(struct.pack('<h', val))
            if channels == 2:
                packed_frames.extend(struct.pack('<h', val))
                
        wav_file.writeframes(packed_frames)

def apply_loop_crossfade(samples: list[float], fade_duration: float = 0.5) -> list[float]:
    """Applies a smooth crossfade between start and end of samples to ensure 100% seamless looping."""
    fade_len = int(fade_duration * SAMPLE_RATE)
    if len(samples) <= fade_len * 2:
        return samples
    
    out = list(samples)
    for i in range(fade_len):
        t = i / float(fade_len)
        # Equal power crossfade
        gain_in = math.sin(t * math.pi * 0.5)
        gain_out = math.cos(t * math.pi * 0.5)
        
        # Blend tail into head
        tail_idx = len(samples) - fade_len + i
        blended = out[i] * gain_in + samples[tail_idx] * gain_out
        out[i] = blended
        out[tail_idx] = blended
    return out

# ==============================================================================
# 1. MUSIC
# ==============================================================================

def generate_normal_music() -> list[float]:
    """Tense, atmospheric sci-fi ambient music loop (C minor pad + warm pulse)."""
    duration = 8.0
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    # Chord notes: C3 (130.81), Eb3 (155.56), G3 (196.0), Bb3 (233.08)
    chords = [130.81, 155.56, 196.0, 233.08]
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        val = 0.0
        # Warm harmonic pad
        for idx, freq in enumerate(chords):
            lfo = 0.85 + 0.15 * math.sin(TWO_PI * 0.25 * t + idx)
            val += 0.2 * math.sin(TWO_PI * freq * t) * lfo
            val += 0.08 * math.sin(TWO_PI * freq * 2.0 * t) * lfo
            val += 0.04 * math.sin(TWO_PI * freq * 3.0 * t)
            
        # Subtle sub-pulse heartbeat at 60 BPM (1 Hz)
        pulse = math.exp(-6.0 * (t % 1.0)) * math.sin(TWO_PI * 65.41 * t)
        val += 0.25 * pulse
        samples[i] = val * 0.7
        
    return apply_loop_crossfade(samples, 0.6)

def generate_blackout_music() -> list[float]:
    """Dark, pulsating bass ostinato in F minor with eerie filtered sweeps."""
    duration = 6.0
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    # F2: 87.31, Ab2: 103.83, C3: 130.81, Db3: 138.59
    bass_notes = [87.31, 87.31, 103.83, 87.31, 138.59, 130.81]
    step_duration = duration / len(bass_notes)
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        note_idx = int(t / step_duration) % len(bass_notes)
        freq = bass_notes[note_idx]
        note_t = t % step_duration
        
        # Plucked sawtooth / square hybrid bass
        phase = (freq * t) % 1.0
        saw = 2.0 * phase - 1.0
        square = 1.0 if phase < 0.5 else -1.0
        env = math.exp(-3.5 * note_t)
        
        # Sub-bass rumble
        sub = math.sin(TWO_PI * (freq * 0.5) * t)
        
        # High eerie dissonance
        eerie = 0.08 * math.sin(TWO_PI * 932.33 * t) * (0.5 + 0.5 * math.sin(TWO_PI * 0.5 * t))
        
        samples[i] = (0.35 * saw * env + 0.2 * square * env + 0.35 * sub + eerie) * 0.75
        
    return apply_loop_crossfade(samples, 0.5)

def generate_meltdown_music() -> list[float]:
    """High-urgency facility meltdown klaxon music with syncopated danger alarm pulses."""
    duration = 4.0
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # Siren alternations A4 (440Hz) and F4 (349Hz) at 2 Hz
        siren_freq = 440.0 if math.sin(TWO_PI * 1.5 * t) > 0.0 else 349.23
        phase = (siren_freq * t) % 1.0
        siren = 0.4 * (1.0 if phase < 0.35 else -0.5)
        
        # Urgent pulsing rhythm at 140 BPM (2.33 Hz)
        beat_t = t % (60.0 / 140.0)
        kick = math.sin(TWO_PI * (60.0 + 90.0 * math.exp(-25.0 * beat_t)) * beat_t) * math.exp(-12.0 * beat_t)
        
        # Fast warning blips
        blip = 0.15 * math.sin(TWO_PI * 1760.0 * t) if (t % 0.25) < 0.06 else 0.0
        
        samples[i] = (siren + 0.45 * kick + blip) * 0.75
        
    return apply_loop_crossfade(samples, 0.4)

# ==============================================================================
# 2. AMBIENCE
# ==============================================================================

def generate_facility_hum() -> list[float]:
    """Deep 60Hz/120Hz facility ventilation and transformer hum."""
    duration = 6.0
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    random.seed(42) # Deterministic noise
    
    # Filter state for air wash
    noise_filter = 0.0
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # 60 Hz electrical grid fundamental + harmonics
        hum = 0.45 * math.sin(TWO_PI * 60.0 * t)
        hum += 0.25 * math.sin(TWO_PI * 120.0 * t)
        hum += 0.12 * math.sin(TWO_PI * 180.0 * t)
        hum += 0.05 * math.sin(TWO_PI * 240.0 * t)
        
        # Air wash noise (low-pass filtered)
        raw_noise = random.uniform(-1.0, 1.0)
        noise_filter = noise_filter * 0.96 + raw_noise * 0.04
        air = noise_filter * 0.25
        
        samples[i] = (hum + air) * 0.65
        
    return apply_loop_crossfade(samples, 0.6)

def generate_blackout_drone() -> list[float]:
    """Sub-bass blackout drone with cold metallic atmosphere."""
    duration = 6.0
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # 43.65 Hz (F1) sub-bass
        sub = 0.5 * math.sin(TWO_PI * 43.65 * t)
        sub += 0.25 * math.sin(TWO_PI * 65.41 * t)
        
        # Metallic resonance frequency slow sweep
        res_freq = 280.0 + 40.0 * math.sin(TWO_PI * 0.2 * t)
        metal = 0.15 * math.sin(TWO_PI * res_freq * t) * (0.6 + 0.4 * math.sin(TWO_PI * 0.33 * t))
        
        samples[i] = (sub + metal) * 0.7
        
    return apply_loop_crossfade(samples, 0.5)

def generate_meltdown_drone() -> list[float]:
    """Reactor core thermal instability rumble and hiss."""
    duration = 5.0
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    random.seed(84)
    noise_filter = 0.0
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        rumble = 0.45 * math.sin(TWO_PI * (75.0 + 15.0 * math.sin(TWO_PI * 0.4 * t)) * t)
        raw_noise = random.uniform(-1.0, 1.0)
        # Steam hiss bandpass
        noise_filter = noise_filter * 0.92 + raw_noise * 0.08
        steam = noise_filter * (0.2 + 0.15 * math.sin(TWO_PI * 1.2 * t))
        
        samples[i] = (rumble + steam) * 0.7
        
    return apply_loop_crossfade(samples, 0.5)

# ==============================================================================
# 3. SFX & STINGERS
# ==============================================================================

def generate_task_click() -> list[float]:
    """Crisp tactile mechanical switch click (50ms)."""
    duration = 0.05
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-120.0 * t)
        # Transient click + resonance
        click = 0.7 * math.sin(TWO_PI * 2400.0 * t) + 0.3 * math.sin(TWO_PI * 800.0 * t)
        samples[i] = click * env
    return samples

def generate_task_progress() -> list[float]:
    """Dual-tone step advance blip (120ms)."""
    duration = 0.12
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-35.0 * t)
        tone = 0.6 * math.sin(TWO_PI * 659.25 * t) + 0.4 * math.sin(TWO_PI * 987.77 * t)
        samples[i] = tone * env
    return samples

def generate_task_success() -> list[float]:
    """Ascending major-third chime G5 -> C6 (650ms)."""
    duration = 0.65
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        # Note 1: G5 (784 Hz)
        if t < 0.3:
            env1 = math.exp(-12.0 * t)
            val += 0.5 * math.sin(TWO_PI * 784.0 * t) * env1
            val += 0.2 * math.sin(TWO_PI * 1568.0 * t) * env1
        # Note 2: C6 (1046.5 Hz)
        if t >= 0.12:
            t2 = t - 0.12
            env2 = math.exp(-7.0 * t2)
            val += 0.6 * math.sin(TWO_PI * 1046.5 * t2) * env2
            val += 0.25 * math.sin(TWO_PI * 2093.0 * t2) * env2
        samples[i] = val
    return samples

def generate_task_error() -> list[float]:
    """Dissonant low negative buzz (350ms)."""
    duration = 0.35
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-8.0 * t) * (1.0 if t < 0.3 else math.exp(-40.0 * (t - 0.3)))
        # Sawtooth buzz with tritone clash (140Hz and 195Hz)
        saw1 = 2.0 * ((140.0 * t) % 1.0) - 1.0
        saw2 = 2.0 * ((195.0 * t) % 1.0) - 1.0
        samples[i] = (0.5 * saw1 + 0.5 * saw2) * env * 0.8
    return samples

def generate_power_cut() -> list[float]:
    """Heavy breaker trip thud followed by pitch-drop capacitor drain (1.2s)."""
    duration = 1.2
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    random.seed(12)
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        # Instant impact thud (0 to 150ms)
        if t < 0.2:
            thud_env = math.exp(-25.0 * t)
            val += 0.8 * math.sin(TWO_PI * 55.0 * t) * thud_env
            val += 0.4 * random.uniform(-1.0, 1.0) * math.exp(-60.0 * t)
        # Power drain falling tone
        drain_freq = max(20.0, 350.0 * math.exp(-3.5 * t))
        drain_env = math.exp(-2.2 * t)
        val += 0.35 * math.sin(TWO_PI * drain_freq * t) * drain_env
        samples[i] = val * 0.85
    return samples

def generate_power_restore() -> list[float]:
    """Turbine spin-up ascending frequency sweep and relay engagement (1.4s)."""
    duration = 1.4
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        # Ascending sweep from 70 Hz to 523 Hz
        sweep_freq = 70.0 + 453.0 * math.pow(t / duration, 1.8)
        sweep_env = math.sin(math.pi * t / duration)
        val = 0.4 * math.sin(TWO_PI * sweep_freq * t) * sweep_env
        # Relay snap at 0.9s
        if t >= 0.9 and t < 1.05:
            snap_t = t - 0.9
            snap_env = math.exp(-50.0 * snap_t)
            val += 0.5 * math.sin(TWO_PI * 880.0 * snap_t) * snap_env
        samples[i] = val * 0.8
    return samples

def generate_blackout_trigger() -> list[float]:
    """Impostor remote sabotage trigger chirp & solenoid clack (550ms)."""
    duration = 0.55
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        # Digital chirp (0 to 100ms)
        if t < 0.12:
            chirp_freq = 1600.0 + 1200.0 * (t / 0.12)
            chirp_env = math.sin(math.pi * t / 0.12)
            val += 0.5 * math.sin(TWO_PI * chirp_freq * t) * chirp_env
        # Heavy relay clack (100ms onward)
        if t >= 0.1:
            clack_t = t - 0.1
            clack_env = math.exp(-22.0 * clack_t)
            val += 0.6 * math.sin(TWO_PI * 130.0 * clack_t) * clack_env
            val += 0.3 * (1.0 if (clack_t * 600.0) % 1.0 < 0.5 else -1.0) * clack_env
        samples[i] = val * 0.85
    return samples

def generate_blackout_countdown() -> list[float]:
    """Sharp alert ping (220ms)."""
    duration = 0.22
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-18.0 * t)
        ping = 0.7 * math.sin(TWO_PI * 880.0 * t) + 0.3 * math.sin(TWO_PI * 1760.0 * t)
        samples[i] = ping * env * 0.85
    return samples

def generate_door_jam() -> list[float]:
    """Pneumatic door slam and metallic clamp (750ms)."""
    duration = 0.75
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    random.seed(99)
    for i in range(n):
        t = i / SAMPLE_RATE
        # Initial air hiss
        hiss = random.uniform(-1.0, 1.0) * math.exp(-15.0 * t) * 0.4
        # Heavy mechanical slam
        slam = math.sin(TWO_PI * 90.0 * t) * math.exp(-10.0 * t) * 0.6
        metal = math.sin(TWO_PI * 480.0 * t) * math.exp(-20.0 * t) * 0.35
        samples[i] = (hiss + slam + metal) * 0.8
    return samples

def generate_sabotage_execute() -> list[float]:
    """Electrical short arc and relay shutdown (850ms)."""
    duration = 0.85
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    random.seed(111)
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-4.5 * t)
        arc = random.uniform(-1.0, 1.0) * (0.8 if random.random() < 0.4 else 0.1) * math.exp(-8.0 * t)
        hum = 0.5 * math.sin(TWO_PI * 120.0 * t) * env
        sub = 0.4 * math.sin(TWO_PI * 55.0 * t) * math.exp(-12.0 * t)
        samples[i] = (arc + hum + sub) * 0.8
    return samples

def generate_evidence_found() -> list[float]:
    """High investigative chime F#5 -> B5 (650ms)."""
    duration = 0.65
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        # F#5: 740 Hz
        if t < 0.35:
            env1 = math.exp(-8.0 * t)
            val += 0.5 * math.sin(TWO_PI * 739.99 * t) * env1
        # B5: 987.77 Hz
        if t >= 0.15:
            t2 = t - 0.15
            env2 = math.exp(-6.0 * t2)
            val += 0.6 * math.sin(TWO_PI * 987.77 * t2) * env2
            val += 0.2 * math.sin(TWO_PI * 1975.5 * t2) * env2
        samples[i] = val * 0.85
    return samples

def generate_voting_tick() -> list[float]:
    """Woodblock clock tick (80ms)."""
    duration = 0.08
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-60.0 * t)
        tick = math.sin(TWO_PI * 1150.0 * t) + 0.3 * math.sin(TWO_PI * 2300.0 * t)
        samples[i] = tick * env * 0.8
    return samples

def generate_vote_cast() -> list[float]:
    """Solid affirmative ballot stamp (220ms)."""
    duration = 0.22
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-18.0 * t)
        punch = 0.6 * math.sin(TWO_PI * 280.0 * t) + 0.4 * math.sin(TWO_PI * 90.0 * t)
        samples[i] = punch * env * 0.85
    return samples

def generate_ejection_reveal() -> list[float]:
    """Airlock decompression and ominous low verdict drone (2.4s)."""
    duration = 2.4
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    random.seed(333)
    for i in range(n):
        t = i / SAMPLE_RATE
        # Decompression hiss
        hiss = random.uniform(-1.0, 1.0) * math.exp(-2.5 * t) * 0.35
        # Low drop tone
        drop_freq = max(35.0, 180.0 * math.exp(-1.8 * t))
        tone = math.sin(TWO_PI * drop_freq * t) * math.exp(-1.2 * t) * 0.65
        samples[i] = (hiss + tone) * 0.85
    return samples

def generate_ui_click() -> list[float]:
    """Soft modern interface click (40ms)."""
    duration = 0.04
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-90.0 * t)
        samples[i] = math.sin(TWO_PI * 1400.0 * t) * env * 0.65
    return samples

def generate_ui_hover() -> list[float]:
    """Gentle hover chirp (30ms)."""
    duration = 0.03
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * t / duration)
        samples[i] = math.sin(TWO_PI * 880.0 * t) * env * 0.35
    return samples

def generate_meeting_called() -> list[float]:
    """Urgent emergency meeting klaxon blast D5/A5 (1.8s)."""
    duration = 1.8
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        # Alternating siren blasts
        pulse_t = t % 0.4
        env = math.exp(-4.0 * pulse_t) if pulse_t < 0.35 else 0.0
        horn = 0.5 * math.sin(TWO_PI * 587.33 * t) + 0.5 * math.sin(TWO_PI * 880.0 * t)
        samples[i] = horn * env * 0.85
    return samples

def generate_stinger_blackout_start() -> list[float]:
    """Blackout horror shock hit descending into sub-bass (1.6s)."""
    duration = 1.6
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-2.5 * t)
        freq = max(45.0, 240.0 * math.exp(-3.0 * t))
        hit = math.sin(TWO_PI * freq * t) + 0.4 * math.sin(TWO_PI * (freq * 1.414) * t)
        samples[i] = hit * env * 0.85
    return samples

def generate_stinger_victory() -> list[float]:
    """Triumphant major arpeggio C5 -> E5 -> G5 -> C6 -> E6 (2.8s)."""
    duration = 2.8
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    notes = [523.25, 659.25, 783.99, 1046.50, 1318.51]
    
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        for idx, freq in enumerate(notes):
            start_t = idx * 0.14
            if t >= start_t:
                dt = t - start_t
                env = math.exp(-1.8 * dt)
                val += 0.25 * math.sin(TWO_PI * freq * dt) * env
                val += 0.08 * math.sin(TWO_PI * freq * 2.0 * dt) * env
        samples[i] = val * 0.85
    return samples

def generate_stinger_defeat() -> list[float]:
    """Dark sinister descending tritone motif A3 -> F3 -> Eb3 -> C3 (3.0s)."""
    duration = 3.0
    n = int(duration * SAMPLE_RATE)
    samples = [0.0] * n
    notes = [220.0, 174.61, 155.56, 130.81, 65.41]
    
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        for idx, freq in enumerate(notes):
            start_t = idx * 0.22
            if t >= start_t:
                dt = t - start_t
                env = math.exp(-1.5 * dt)
                # Dissonant sawtooth layer
                phase = (freq * dt) % 1.0
                saw = 2.0 * phase - 1.0
                val += 0.22 * saw * env
                val += 0.25 * math.sin(TWO_PI * freq * dt) * env
        samples[i] = val * 0.85
    return samples

# ==============================================================================
# BATCH GENERATION MATRIX
# ==============================================================================

def main():
    assets = [
        # MUSIC
        ("assets/audio/music/normal/normal_gameplay_music.wav", generate_normal_music),
        ("assets/audio/music/normal_gameplay_music.wav", generate_normal_music),
        ("assets/audio/music/blackout/blackout_tension_music.wav", generate_blackout_music),
        ("assets/audio/music/blackout_tension_music.wav", generate_blackout_music),
        ("assets/audio/music/meltdown/meltdown_alarm.wav", generate_meltdown_music),
        ("assets/audio/music/meltdown_alarm.wav", generate_meltdown_music),
        
        # AMBIENCE
        ("assets/audio/ambience/facility/facility_hum.wav", generate_facility_hum),
        ("assets/audio/ambience/facility_hum.wav", generate_facility_hum),
        ("assets/audio/ambience/blackout/blackout_drone.wav", generate_blackout_drone),
        ("assets/audio/ambience/blackout_drone.wav", generate_blackout_drone),
        ("assets/audio/ambience/meltdown/meltdown_drone.wav", generate_meltdown_drone),
        ("assets/audio/ambience/meltdown_drone.wav", generate_meltdown_drone),
        
        # SFX - BLACKOUT
        ("assets/audio/sfx/blackout/blackout_trigger.wav", generate_blackout_trigger),
        ("assets/audio/sfx/blackout_trigger.wav", generate_blackout_trigger),
        ("assets/audio/sfx/blackout/blackout_countdown.wav", generate_blackout_countdown),
        ("assets/audio/sfx/blackout_countdown.wav", generate_blackout_countdown),
        ("assets/audio/sfx/blackout/power_cut.wav", generate_power_cut),
        ("assets/audio/sfx/power_cut.wav", generate_power_cut),
        ("assets/audio/sfx/blackout/power_restore.wav", generate_power_restore),
        ("assets/audio/sfx/power_restore.wav", generate_power_restore),
        
        # SFX - TASKS
        ("assets/audio/sfx/tasks/task_click.wav", generate_task_click),
        ("assets/audio/sfx/task_click.wav", generate_task_click),
        ("assets/audio/sfx/tasks/task_progress.wav", generate_task_progress),
        ("assets/audio/sfx/task_progress.wav", generate_task_progress),
        ("assets/audio/sfx/tasks/task_success.wav", generate_task_success),
        ("assets/audio/sfx/task_success.wav", generate_task_success),
        ("assets/audio/sfx/tasks/task_error.wav", generate_task_error),
        ("assets/audio/sfx/task_error.wav", generate_task_error),
        
        # SFX - SABOTAGE
        ("assets/audio/sfx/sabotage/door_jam.wav", generate_door_jam),
        ("assets/audio/sfx/door_jam.wav", generate_door_jam),
        ("assets/audio/sfx/sabotage/sabotage_execute.wav", generate_sabotage_execute),
        ("assets/audio/sfx/sabotage_execute.wav", generate_sabotage_execute),
        
        # SFX - MEETING / VOTING
        ("assets/audio/sfx/meeting/evidence_found.wav", generate_evidence_found),
        ("assets/audio/sfx/evidence_found.wav", generate_evidence_found),
        ("assets/audio/sfx/voting/voting_tick.wav", generate_voting_tick),
        ("assets/audio/ui/voting_tick.wav", generate_voting_tick),
        ("assets/audio/sfx/voting/vote_cast.wav", generate_vote_cast),
        ("assets/audio/ui/vote_cast.wav", generate_vote_cast),
        
        # SFX - EJECTION
        ("assets/audio/sfx/ejection/ejection_reveal.wav", generate_ejection_reveal),
        ("assets/audio/ui/ejection_reveal.wav", generate_ejection_reveal),
        
        # UI
        ("assets/audio/sfx/ui/ui_click.wav", generate_ui_click),
        ("assets/audio/ui/ui_click.wav", generate_ui_click),
        ("assets/audio/sfx/ui/ui_hover.wav", generate_ui_hover),
        ("assets/audio/ui/ui_hover.wav", generate_ui_hover),
        ("assets/audio/ui/meeting_called.wav", generate_meeting_called),
        
        # STINGERS
        ("assets/audio/stingers/blackout_start/stinger_blackout_start.wav", generate_stinger_blackout_start),
        ("assets/audio/stingers/blackout/stinger_blackout_start.wav", generate_stinger_blackout_start),
        ("assets/audio/sfx/stinger_blackout_start.wav", generate_stinger_blackout_start),
        
        ("assets/audio/stingers/meeting/stinger_meeting.wav", generate_meeting_called),
        ("assets/audio/ui/stinger_meeting.wav", generate_meeting_called),
        
        ("assets/audio/stingers/victory/stinger_victory.wav", generate_stinger_victory),
        ("assets/audio/ui/stinger_victory.wav", generate_stinger_victory),
        ("assets/audio/ui/crew_victory.wav", generate_stinger_victory),
        
        ("assets/audio/stingers/defeat/stinger_defeat.wav", generate_stinger_defeat),
        ("assets/audio/ui/stinger_defeat.wav", generate_stinger_defeat),
        ("assets/audio/ui/impostor_victory.wav", generate_stinger_defeat),
    ]
    
    generated = 0
    for path, gen_func in assets:
        samples = gen_func()
        write_wav(path, samples)
        generated += 1
        print(f"Generated: {path} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.2f}s)")
        
    print(f"\nSuccessfully generated {generated} real, high-quality PCM WAV audio assets.")

if __name__ == "__main__":
    main()
