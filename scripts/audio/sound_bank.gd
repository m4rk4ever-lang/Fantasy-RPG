class_name SoundBank
extends RefCounted
## Procedural sound bank: every sound in the game is synthesized here at startup
## into 16-bit mono AudioStreamWAV buffers. No audio files, no AudioStreamGenerator
## (unreliable in single-threaded web builds).
##
## One-shots render at 22050 Hz; long loops (music, sea, wind) at 11025 Hz to keep
## startup short.

const SR_HI: int = 22050
const SR_LO: int = 11025
const TABLE: int = 2048
## Base pitch of the harp pluck sample (A3, rounded so the delay line is whole samples).
const PLUCK_HZ: float = 220.5

var streams: Dictionary = {}  ## name -> AudioStreamWAV
var pad_chords: Array[AudioStreamWAV] = []
var generation_ms: int = 0

var _sr: int = SR_HI
var _noise: PackedFloat32Array = PackedFloat32Array()
var _ni: int = 0
var _sine: PackedFloat32Array = PackedFloat32Array()
var _strings: PackedFloat32Array = PackedFloat32Array()


func generate() -> void:
	var t0: int = Time.get_ticks_msec()
	_build_tables()
	_gen_sfx()
	_gen_ambience()
	_gen_music()
	generation_ms = Time.get_ticks_msec() - t0


func get_stream(id: String) -> AudioStreamWAV:
	return streams.get(id) as AudioStreamWAV


# --- Primitives ---------------------------------------------------------------

func _build_tables() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8128
	_noise.resize(32768)
	for i: int in 32768:
		_noise[i] = rng.randf() * 2.0 - 1.0
	_sine.resize(TABLE)
	_strings.resize(TABLE)
	for i: int in TABLE:
		var p: float = TAU * float(i) / float(TABLE)
		_sine[i] = sin(p)
		# Soft saw: a handful of harmonics with a steep roll-off (lowpassed strings).
		_strings[i] = (sin(p) + 0.42 * sin(2.0 * p) + 0.2 * sin(3.0 * p) + 0.1 * sin(4.0 * p) + 0.05 * sin(5.0 * p)) * 0.6


func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * float(_sr)))
	return b


## Adds band-limited noise: lowpass sweeps lp0->lp1 Hz, highpass sweeps hp0->hp1 Hz.
## Envelope: linear attack, then (1 - t)^decay.
func _nb(buf: PackedFloat32Array, start: float, dur: float, lp0: float, lp1: float, hp0: float, hp1: float, amp: float, attack: float, decay: float) -> void:
	var s0: int = int(start * float(_sr))
	var n: int = mini(int(dur * float(_sr)), buf.size() - s0)
	if n <= 0:
		return
	var k: float = TAU / float(_sr)
	var lp: float = 0.0
	var hp: float = 0.0
	var atk_n: float = maxf(attack * float(_sr), 1.0)
	var inv_n: float = 1.0 / float(n)
	var ni: int = _ni
	for i: int in n:
		var u: float = float(i) * inv_n
		var x: float = _noise[ni & 32767]
		ni += 1
		lp += (x - lp) * minf((lp0 + (lp1 - lp0) * u) * k, 1.0)
		hp += (lp - hp) * minf((hp0 + (hp1 - hp0) * u) * k, 1.0)
		var env: float = minf(float(i) / atk_n, 1.0) * pow(1.0 - u, decay)
		buf[s0 + i] += (lp - hp) * env * amp
	_ni = ni + 977


## Adds a sine (table) sweep f0->f1 with an exponential decay to `tail` of its level at the end.
func _tone(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float, tail: float = 0.01, attack: float = 0.003, table: PackedFloat32Array = _sine) -> void:
	var s0: int = int(start * float(_sr))
	var n: int = mini(int(dur * float(_sr)), buf.size() - s0)
	if n <= 0:
		return
	var step0: float = f0 * float(TABLE) / float(_sr)
	var dstep: float = (f1 - f0) * float(TABLE) / float(_sr) / float(n)
	var ph: float = 0.0
	var env: float = amp
	var kd: float = pow(tail, 1.0 / float(n))
	var atk_n: int = maxi(int(attack * float(_sr)), 1)
	var fade_n: int = mini(64, n)
	for i: int in n:
		var e: float = env
		if i < atk_n:
			e *= float(i) / float(atk_n)
		if i >= n - fade_n:
			e *= float(n - i) / float(fade_n)
		buf[s0 + i] += table[int(ph) & 2047] * e
		ph += step0 + dstep * float(i)
		env *= kd


## Adds a constant looping table voice (whole number of cycles assumed by the caller).
func _voice(buf: PackedFloat32Array, freq: float, amp: float, table: PackedFloat32Array) -> void:
	var step: float = freq * float(TABLE) / float(_sr)
	var ph: float = 0.0
	for i: int in buf.size():
		buf[i] += table[int(ph) & 2047] * amp
		ph += step


## Folds the tail (samples beyond n) back over the start so a loop of n samples is seamless.
func _fold_loop(buf: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var x: int = buf.size() - n
	for i: int in x:
		var f: float = float(i) / float(x)
		buf[i] = buf[i] * f + buf[n + i] * (1.0 - f)
	return buf.slice(0, n)


func _store(id: String, buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var n: int = buf.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	# Scale down anything that would clip; quiet sounds keep their level.
	var peak: float = 0.0
	for i: int in n:
		peak = maxf(peak, absf(buf[i]))
	var gain: float = 32000.0 * minf(1.0, 0.85 / maxf(peak, 0.001))
	for i: int in n:
		bytes.encode_s16(i * 2, int(buf[i] * gain))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _sr
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	if id != "":
		streams[id] = wav
	return wav


# --- Sound effects ------------------------------------------------------------

func _gen_sfx() -> void:
	_sr = SR_HI
	var b: PackedFloat32Array

	# Footsteps: soft brush on grass, short knock on stone and wood.
	b = _buf(0.13)
	_nb(b, 0.0, 0.13, 1100.0, 450.0, 160.0, 120.0, 1.6, 0.006, 2.0)
	_store("step_grass", b)
	b = _buf(0.09)
	_nb(b, 0.0, 0.06, 3200.0, 1200.0, 500.0, 300.0, 1.3, 0.001, 3.0)
	_tone(b, 0.0, 0.08, 190.0, 95.0, 0.45, 0.02)
	_store("step_stone", b)

	# Sword swings.
	b = _buf(0.2)
	_nb(b, 0.0, 0.2, 1400.0, 4200.0, 600.0, 1700.0, 1.5, 0.07, 1.6)
	_store("swing_light", b)
	b = _buf(0.36)
	_nb(b, 0.0, 0.36, 700.0, 2800.0, 220.0, 800.0, 1.9, 0.16, 1.5)
	_store("swing_heavy", b)

	# Hit: meaty thud with a short metallic ring on top.
	b = _buf(0.36)
	_nb(b, 0.0, 0.13, 1900.0, 280.0, 70.0, 50.0, 2.2, 0.001, 2.0)
	_tone(b, 0.0, 0.16, 120.0, 52.0, 0.7, 0.02)
	_tone(b, 0.0, 0.34, 1870.0, 1862.0, 0.12, 0.01, 0.001)
	_tone(b, 0.0, 0.28, 2930.0, 2925.0, 0.08, 0.01, 0.001)
	_tone(b, 0.0, 0.2, 4110.0, 4100.0, 0.05, 0.01, 0.001)
	_store("hit", b)

	# Ground slam of the heavy attack.
	b = _buf(0.6)
	_nb(b, 0.0, 0.4, 1200.0, 150.0, 40.0, 30.0, 2.6, 0.002, 1.8)
	_tone(b, 0.0, 0.55, 95.0, 36.0, 0.85, 0.02)
	_store("slam", b)

	# Hollowed: breath through an empty shell.
	b = _buf(0.34)
	_nb(b, 0.0, 0.34, 800.0, 1300.0, 320.0, 520.0, 2.2, 0.03, 1.5)
	_tone(b, 0.0, 0.3, 233.0, 170.0, 0.14, 0.05, 0.03)
	_tone(b, 0.0, 0.3, 349.0, 262.0, 0.09, 0.05, 0.03)
	_store("hollow_hurt", b)
	b = _buf(1.0)
	_nb(b, 0.0, 1.0, 1500.0, 240.0, 240.0, 70.0, 2.4, 0.06, 1.3)
	_tone(b, 0.0, 0.95, 196.0, 58.0, 0.22, 0.03, 0.05)
	_tone(b, 0.0, 0.95, 294.0, 87.0, 0.12, 0.03, 0.05)
	_store("hollow_death", b)

	# Player hurt: dull blow and a short falling grunt.
	b = _buf(0.26)
	_nb(b, 0.0, 0.1, 1300.0, 300.0, 80.0, 60.0, 2.0, 0.001, 2.0)
	_tone(b, 0.01, 0.24, 310.0, 185.0, 0.3, 0.03, 0.01, _strings)
	_store("player_hurt", b)

	# Skills.
	b = _buf(0.42)
	_nb(b, 0.0, 0.42, 500.0, 2600.0, 150.0, 600.0, 1.8, 0.2, 1.2)
	_tone(b, 0.0, 0.4, 70.0, 150.0, 0.3, 0.3, 0.12, _strings)
	_store("cleave", b)
	b = _buf(0.5)
	_nb(b, 0.0, 0.5, 900.0, 5200.0, 320.0, 2600.0, 1.7, 0.3, 0.8)
	_tone(b, 0.0, 0.45, 280.0, 1150.0, 0.12, 0.4, 0.1)
	_store("surge", b)
	b = _buf(0.85)
	_nb(b, 0.0, 0.85, 1100.0, 2600.0, 380.0, 700.0, 2.0, 0.08, 0.9)
	for i: int in b.size():
		b[i] *= 0.45 + 0.55 * _sine[int(float(i) * 4.7 * float(TABLE) / float(SR_HI)) & 2047]
	_store("whirlwind", b)
	b = _buf(1.1)
	var shimmer: Array[float] = [587.3, 880.0, 1174.7, 1480.0, 1760.0, 2349.3]
	for i: int in shimmer.size():
		_tone(b, 0.07 * float(i), 1.1 - 0.07 * float(i), shimmer[i], shimmer[i] * 1.004, 0.13, 0.02, 0.02)
	_nb(b, 0.0, 0.9, 6000.0, 3000.0, 2500.0, 1500.0, 0.5, 0.25, 2.0)
	_store("second_wind", b)

	# Level up: rising D major fanfare that settles on a full chord.
	b = _buf(1.7)
	var fan: Array[float] = [293.7, 440.0, 587.3, 740.0]
	for i: int in fan.size():
		_tone(b, 0.11 * float(i), 1.7 - 0.11 * float(i), fan[i], fan[i], 0.2, 0.04, 0.012, _strings)
		_tone(b, 0.11 * float(i), 0.9, fan[i] * 2.0, fan[i] * 2.0, 0.05, 0.02, 0.004)
	_tone(b, 0.0, 1.6, 146.8, 146.8, 0.22, 0.05, 0.02, _strings)
	_store("level_up", b)

	# Quest complete: two bells, a fifth and the octave above.
	b = _buf(1.1)
	_bell(b, 0.0, 1.1, 880.0, 0.22)
	_bell(b, 0.16, 0.94, 1174.7, 0.24)
	_store("quest_complete", b)

	# Coins.
	b = _buf(0.28)
	_tone(b, 0.0, 0.18, 2637.0, 2630.0, 0.22, 0.01, 0.001)
	_tone(b, 0.0, 0.12, 4186.0, 4180.0, 0.1, 0.01, 0.001)
	_tone(b, 0.07, 0.2, 3136.0, 3130.0, 0.22, 0.01, 0.001)
	_tone(b, 0.07, 0.14, 5274.0, 5270.0, 0.08, 0.01, 0.001)
	_store("coin", b)

	# UI click.
	b = _buf(0.05)
	_tone(b, 0.0, 0.05, 920.0, 700.0, 0.3, 0.02, 0.001)
	_nb(b, 0.0, 0.02, 4000.0, 2000.0, 800.0, 800.0, 0.5, 0.001, 2.0)
	_store("ui_click", b)

	# Gull: three falling cries.
	b = _buf(1.0)
	for i: int in 3:
		var at: float = 0.3 * float(i)
		var a: float = 0.2 - 0.04 * float(i)
		_tone(b, at, 0.07, 1500.0, 2300.0, a, 0.9, 0.02, _strings)
		_tone(b, at + 0.07, 0.19, 2300.0, 1650.0, a, 0.15, 0.002, _strings)
	_store("gull", b)

	# Harp pluck (Karplus-Strong), pitched by the music sequencer.
	b = _buf(1.5)
	var period: int = int(round(float(SR_HI) / PLUCK_HZ))
	var prev: float = 0.0
	for i: int in period:
		# Lowpassed noise burst: a soft finger pluck instead of a bright pick.
		prev += (_noise[(i * 7 + 311) & 32767] - prev) * 0.35
		b[i] = prev * 0.9
	for i: int in range(period, b.size()):
		b[i] = (b[i - period] + b[i - period + 1]) * 0.4975
	var tail: int = SR_HI / 2
	for i: int in tail:
		b[b.size() - tail + i] *= 1.0 - float(i) / float(tail)
	_store("pluck", b)


func _bell(buf: PackedFloat32Array, start: float, dur: float, f: float, amp: float) -> void:
	_tone(buf, start, dur, f, f, amp, 0.01, 0.002)
	_tone(buf, start, dur * 0.6, f * 2.76, f * 2.76, amp * 0.35, 0.01, 0.002)
	_tone(buf, start, dur * 0.35, f * 5.4, f * 5.4, amp * 0.15, 0.01, 0.002)


# --- Ambience -----------------------------------------------------------------

func _gen_ambience() -> void:
	# Sea: one long swell per loop, the wash brightens as the wave breaks.
	_sr = SR_LO
	var n: int = SR_LO * 6
	var x: int = 1024
	var b := PackedFloat32Array()
	b.resize(n + x)
	var k: float = TAU / float(_sr)
	var lp: float = 0.0
	var lp2: float = 0.0
	for i: int in n + x:
		var u: float = float(i) / float(n)
		var swell: float = 0.5 - 0.5 * _sine[int((u + 0.75) * float(TABLE)) & 2047]
		var w: float = 0.5 - 0.5 * _sine[int((u * 2.0 + 0.4) * float(TABLE)) & 2047]
		var env: float = 0.22 + 0.6 * swell * swell + 0.18 * w
		var nz: float = _noise[(i * 3 + 17) & 32767]
		lp += (nz - lp) * minf((350.0 + 1500.0 * env) * k, 1.0)
		lp2 += (lp - lp2) * 0.6
		b[i] = lp2 * env * 1.5
	_store("sea", _fold_loop(b, n), true)

	# Wind: slow gusts of dark noise.
	n = SR_LO * 5
	b = PackedFloat32Array()
	b.resize(n + x)
	lp = 0.0
	lp2 = 0.0
	for i: int in n + x:
		var u: float = float(i) / float(n)
		var gust: float = 0.5 + 0.3 * _sine[int(u * float(TABLE)) & 2047] + 0.2 * _sine[int((u * 3.0 + 0.3) * float(TABLE)) & 2047]
		var nz: float = _noise[(i * 5 + 9001) & 32767]
		lp += (nz - lp) * (180.0 + 420.0 * gust) * k
		lp2 += (lp - lp2) * 0.35
		b[i] = lp2 * (0.45 + 0.55 * gust) * 2.6
	_store("wind", _fold_loop(b, n), true)

	# Crickets: pulsed high chirps, two insects slightly apart.
	_sr = SR_HI
	b = _buf(2.0)
	var c1: float = 4200.0 * float(TABLE) / float(SR_HI)
	var c2: float = 4750.0 * float(TABLE) / float(SR_HI)
	var pulse: float = 55.0 * float(TABLE) / float(SR_HI)
	for i: int in b.size():
		var t: float = float(i) / float(SR_HI)
		var v: float = 0.0
		var p: float = maxf(_sine[int(float(i) * pulse) & 2047], 0.0)
		if fmod(t * 2.5, 1.0) < 0.3:
			v += _sine[int(float(i) * c1) & 2047] * p * 0.16
		if fmod(t * 1.5 + 0.45, 1.0) < 0.22:
			v += _sine[int(float(i) * c2) & 2047] * p * 0.09
		b[i] = v
	_store("crickets", b, true)


# --- Music --------------------------------------------------------------------

## Chords of the exploration theme (D dorian: i - VII - IV - i), frequencies in whole Hz
## so that one-second loops close exactly. Each note gets a second voice 1 Hz higher
## for a slow ensemble beat.
const PAD_CHORDS: Array[Array] = [
	[147.0, 220.0, 349.0, 440.0],   # D minor
	[131.0, 196.0, 330.0, 392.0],   # C major
	[98.0, 196.0, 294.0, 494.0],    # G major (the bright dorian IV)
	[147.0, 220.0, 294.0, 330.0],   # D sus2, open ending
]


func _gen_music() -> void:
	_sr = SR_LO
	pad_chords.clear()
	for ci: int in PAD_CHORDS.size():
		var b: PackedFloat32Array = _buf(1.0)
		var chord: Array = PAD_CHORDS[ci]
		for ni: int in chord.size():
			var f: float = chord[ni]
			var a: float = 0.11 if ni < 2 else 0.075
			_voice(b, f, a, _strings)
			_voice(b, f + 1.0, a * 0.8, _strings if ni < 2 else _sine)
		pad_chords.append(_store("pad_%d" % ci, b, true))

	# Low drone: D with its fifth, gently beating.
	var d: PackedFloat32Array = _buf(1.0)
	_voice(d, 73.0, 0.3, _sine)
	_voice(d, 74.0, 0.2, _sine)
	_voice(d, 110.0, 0.1, _strings)
	_store("drone", d, true)

	# Combat layer: 4 s loop at 120 bpm. War drums and a low string ostinato.
	var c: PackedFloat32Array = _buf(4.0)
	var beats: Array[float] = [0.0, 0.75, 1.0, 1.5, 2.0, 2.75, 3.0, 3.25, 3.5]
	for bi: int in beats.size():
		var at: float = beats[bi]
		var strong: float = 1.0 if fmod(at, 1.0) == 0.0 else 0.6
		_tone(c, at, 0.24, 92.0, 44.0, 0.5 * strong, 0.02, 0.002)
		_nb(c, at, 0.1, 900.0, 200.0, 60.0, 60.0, 1.2 * strong, 0.001, 2.0)
	# Eighth-note ostinato on D, leaning on the minor third and the fourth.
	var ost: Array[float] = [73.4, 73.4, 87.3, 73.4, 73.4, 73.4, 98.0, 87.3, 73.4, 73.4, 87.3, 73.4, 110.0, 98.0, 87.3, 82.4]
	for oi: int in ost.size():
		var f: float = ost[oi]
		_tone(c, 0.25 * float(oi), 0.24, f * 2.0, f * 2.0, 0.17, 0.12, 0.008, _strings)
		_tone(c, 0.25 * float(oi), 0.24, f, f, 0.14, 0.2, 0.008, _strings)
	# Held tension: open fifth with a slow swell (whole cycles over 4 s).
	var hold: PackedFloat32Array = _buf(4.0)
	_voice(hold, 293.5, 0.07, _strings)
	_voice(hold, 440.0, 0.05, _strings)
	_voice(hold, 466.25, 0.022, _sine)
	for i: int in hold.size():
		var u: float = float(i) / float(hold.size())
		c[i] += hold[i] * (0.55 - 0.45 * _sine[int((u + 0.25) * float(TABLE)) & 2047])
	_store("combat", c, true)
