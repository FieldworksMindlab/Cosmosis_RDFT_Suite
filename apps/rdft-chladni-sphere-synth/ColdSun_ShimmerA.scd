/*
Recursive Differentiation Framework - EXPRESSIVE FIELD VOICES
Field voices evolve dynamically with the RDF model
CORRECTED VERSION: glass delay fix, ocean cooldown guards,
staggered trigger thresholds, choir OSC receivers added.
*/

s.options.memSize = 262144;   // 4x headroom; prevents pool exhaustion if a transient burst stacks
s.options.numWireBufs = 1024;
s.options.maxNodes = 4096;
s.options.blockSize = 128;
s.options.hardwareBufferSize = 512;

s.waitForBoot({

	// HARD RESET: clear stale OSC responders and nodes from previous evaluations.
	OSCdef.freeAll;
	s.defaultGroup.freeAll;
	s.sync;

	// ========== GLOBAL PARAMETERS ==========
	~depth = 6;
	~alpha = 2.0;
	~gridSize = 16;
	~serialPort = nil;
	~serialReader = nil;
	~connected = false;
	~lastOrbSpeed = 0.5;
	~lastOrbPhi = 1.0;
	~rootFreq = 55;
	~orbSensitivity = 1.0;
	~lastModSource = 0;
	~finest = 0.5;
	~lastBrightness = 0.0;
	~rhythmComplexity = 0.5;
	~rhythmSwing = 0.0;

	// Quantitative mode receiver state from Processing.
	~quantMode = 0;
	~quantModeName = "Brightness";
	~metricEntropy = 0.0;
	~metricFractalDim = 0.0;
	~metricLyapunov = 0.0;
	~metricKLDivergence = 0.0;
	~metricMutualInfo = 0.0;

	// CTC Channel Mode from Processing (/rdf/ctcState).
	~ctcProximity = 0.0;
	~ctcProximityRaw = 0.0;
	~ctcZone = 0;
	~ctcFloquetAsymmetry = 1.0;
	~ctcClosed = 0;
	~ctcClosureMetric = 0.0;
	~ctcClosureFreq = 55.0;
	~ctcChannelActive = 0;
	~ctcVaidyaAtten = 1.0;
	~ghostNotesEnabled = true;
	~ghostTriggerCount = 0;
	~actualGlassTriggerCount = 0;
	~processingDiagAddr = NetAddr("127.0.0.1", 12000);
	~lastAudioDiagSend = 0.0;
	~audioLogBar = 0;
	~loggingEnabled = false;
	~projectDir = PathName(thisProcess.nowExecutingPath).pathOnly;
	~audioLogDir = ~projectDir ++ "logs/";
	File.mkdir(~audioLogDir);
	~audioLogPath = ~audioLogDir ++ "audio_params_" ++ Date.getDate.stamp ++ ".csv";
	~audioLogFile = File(~audioLogPath, "w");
	if(~audioLogFile.isOpen, {
		~audioLogFile.write("timestamp,barCount,beatPhase,droneFreq,droneAmp,arpFreq,arpAmp,glassFreq,glassAmp,choirFreq,choirAmp,dynamicBPM,swingOffset,mutationAmount,changeEnergy,densityAmount,scaleName\n");
		~audioLogFile.flush;
		("Audio log ready: " ++ ~audioLogPath).postln;
	}, {
		~audioLogFile = nil;
		("Audio logging disabled; could not open: " ++ ~audioLogPath).postln;
	});

	// Environmental cross-excitation shared by ocean and galaxy packet drives.
	~excArpDrive = 0.0;
	~excGlassDrive = 0.0;

	// Ocean/tidal sensing layer. Processing interprets NOAA tide/current/temperature
	// into these musical field drives before SuperCollider resonates them.
	~oceanLive = 0.0;
	~oceanExcite = 0.0;
	~oceanColor = 0.0;
	~oceanBurst = 0.0;
	~oceanPersistence = 0.0;
	~oceanDepthBias = 0.0;
	~oceanCurvature = 0.0;
	~oceanArpDrive = 0.0;
	~oceanGlassDrive = 0.0;
	~oceanReverbDrive = 0.0;
	~oceanTideM = 0.0;
	~oceanTempC = 12.0;
	~oceanCurrent = 0.0;
	~oceanPhase = 0.5;
	~oceanThermal = 0.5;
	~oceanSwellDepth = 0.5;
	~oceanRangeM = 0.0;
	~oceanVelocity = 0.0;
	~oceanAccel = 0.0;
	~oceanEnergy = 0.0;
	~oceanMemory = 0.0;
	~oceanVolume = 0.006;
	~oceanAudioEnabled = true;
	~oceanArpExcite = 0.0;
	~oceanGlassExcite = 0.0;
	~oceanColorFreq = 900;
	~oceanSwellSynth = nil;
	~oceanSurgeSynth = nil;
	~lastOceanSwellSpawn = 0.0;
	~lastOceanGranuleTrig = 0.0;
	~lastOceanBloomSpawn = 0.0;
	~lastOceanMembraneSpawn = 0.0;
	~oceanBloomCooldown = 6.0;
	~oceanMembraneCooldown = 8.0;
	~lastWatchdogFire = 0.0;
	~watchdogEnabled = false;              // heavy heartbeat-recovery OFF by default (measurement-safe)
	~watchdogHeartbeatTimeout = 45.0;      // s of heartbeat silence before recovery
	~watchdogRefractory = 60.0;            // s minimum between recoveries
	// Ocean ecology partition
	~oceanPrevTideM = 0.0;
	~oceanTideDir = 0;
	~oceanRegime = \slack;
	~oceanTurnUntil = 0.0;
	~lastOceanChop = 0.0;
	~lastOceanSpray = 0.0;
	~lastOceanUndertow = 0.0;
	~lastOceanSurgeEvent = 0.0;
	~oceanSurgeEventCooldown = 25.0;
	~oceanPrevCurrent = 0.0;

	// Solar recursive forcing layer.
	~solarEnabled = true;
	~solarVolume = 0.25;
	~solarXray = 0.0;
	~solarWind = 0.0;
	~solarBz = 0.5;
	~solarKp = 0.0;
	~solarFlare = 0.0;
	~solarSynth = 0.0;
	~solarBreath = 0.0;
	~solarPhaseRate = 0.08;
	~solarAudioEnabled = true;

	// Foundational Field Layer from Processing (/rdf/foundational).
	~foundDivE = 0.0;
	~foundCurlB = 0.0;
	~foundPsiDensity = 0.0;
	~foundUncertainty = 0.0;
	~foundPlanckGate = 0.0;
	~foundCoherence = 0.0;
	~foundCoupling = 0.0;

	~emPressure = ~foundDivE;
	~emRotation = ~foundCurlB;
	~emEnergy = (
		(~foundDivE * 0.30) +
		(~foundCurlB * 0.45) +
		(~foundCoupling * 0.25)
	).clip(0, 1);

	~psiGhostProb = ((~foundUncertainty * 0.55) + (~foundPsiDensity * 0.25) - (~foundCoherence * 0.15)).clip(0.0, 0.75);

	~lastSolarFlareTrig = 0.0;
	~lastArpTrigTime = 0.0;
	~lastGlassTrigTime = 0.0;
	~lastGhostTrigTime = 0.0;
	~lastEcoChirpTime = 0.0;
	~lastEcoCallTime = 0.0;
	~lastEcoGrowthTime = 0.0;
	~lastEcoFissureTime = 0.0;
	~lastEcoThunderTime = 0.0;
	~lastEcoInsectTime = 0.0;
	~nextEcoChirpTime = 0.0;
	~nextEcoCallTime = 0.0;
	~nextEcoGrowthTime = 0.0;
	~nextEcoFissureTime = 0.0;
	~nextEcoThunderTime = 0.0;
	~nextEcoInsectTime = 0.0;
	~ecoChirpTriggerCount = 0;
	~ecoCallTriggerCount = 0;
	~ecoGrowthTriggerCount = 0;
	~ecoFissureTriggerCount = 0;
	~ecoThunderTriggerCount = 0;
	~ecoInsectTriggerCount = 0;
	~arpStep = 0;

	// Cosmic timing ecology
	~goldenRatio = 1.61803398875;
	~pythagoreanRatios = [1.0, 1.125, 1.25, 1.333, 1.5, 1.666, 2.0];
	~lastArpActualTime = 0.0;
	~nextArpTrigTime = 0.0;
	~arpWalkDegree = 0;
	~arpWalkDir = 1;
	~nextGlassAllowedTime = 0.0;
	~arpBurstInflight = 0;

	// FIX: reduced glass lockout windows so glass can fire alongside arp
	~glassDelayMin = 0.3;
	~glassDelayMax = 1.5;
	~glassCooldown = 0.30;
	~arpTimingWander = 0.12;
	~lastCosmicPingTime = 0.0;

	// Rhythm state variables
	~rhythmComplexity = 0.5;
	~rhythmSwing      = 0.0;
	~orbSensitivity   = 1.0;

	// Synth volume controls (0-1 range)
	~droneVolume = 0.20;
	~arpVolume = 0.20;
	~glassVolume = 0.20;
	~choirVolume = 0.20;


	// Synth reference variables
	~droneSynth = nil;
	~currentDroneOn = false;
	~droneManualArmed = false;
	~droneSpawnedOnce = false;
	~pendingDroneFreq = 111;
	~pendingDroneAmp = 0.0;
	~pendingDroneRev = 0.25;
	~manualDroneFreq = 111;
	~manualDroneVol = 0.0;

	// Choir persistent node state.
	~choirSynth = nil;
	~choirGroup = nil;
	~choirLastFreq = 0.0;
	~choirLastSpawnTime = 0.0;
	~choirLastUpdateTime = 0.0;
	~choirMinRespawn = 8.0;
	~choirMinUpdateGap = 0.18;
	~choirMaxAmp = 0.105;

	// MIDI poly field layer: independent from Floquet drone, but restrained by
	// Planck/release pressure so held chords can inhabit the field without latching.
	~midiPolyVoices = Dictionary.new;
	~midiPolyMaxVoices = 8;
	~midiPolyVolume = 0.55;
	~midiPolyMemory = 0.0;
	~midiPolyReleasePressure = 0.0;
	~midiPolyDensity = 0.0;
	~midiPolyChordSpread = 0.0;
	~egProbeEnabled = false;
	~egProbeActive = false;
	~egProbeDepth = 0.0;
	~egProbeGateScore = 0.0;
	~egProbeFactor = 1.0;

	~estimatedVoiceLoad = {
		var voiceCount;
		voiceCount = 0;
		if(~droneSynth.notNil and: { ~droneSynth.isPlaying }, { voiceCount = voiceCount + 1; });
		if(~floquetDroneSynth.notNil and: { ~floquetDroneSynth.isPlaying }, { voiceCount = voiceCount + 1; });
		if(~choirSynth.notNil and: { ~choirSynth.isPlaying }, { voiceCount = voiceCount + 1; });
		if(~oceanSwellSynth.notNil and: { ~oceanSwellSynth.isPlaying }, { voiceCount = voiceCount + 1; });
		if(~oceanSurgeSynth.notNil and: { ~oceanSurgeSynth.isPlaying }, { voiceCount = voiceCount + 1; });
		if(~solarSynth.notNil and: { ~solarSynth.isPlaying }, { voiceCount = voiceCount + 1; });
		(voiceCount + (~midiPolyVoices.size ? 0)).clip(0, 99);
	};

	// CHANGE THIS FOR YOUR SYSTEM:
	~portName = "COM10";
	~oscPort = 60001;

	// ===== SC SAFETY HELPERS =====
	~safeFloat = { |x, fallback = 0.0|
		var y;
		if(x.isNil, { fallback }, {
			y = x.asFloat;
			if(y.isNaN or: { y.abs > 1.0e12 }, { fallback }, { y });
		});
	};
	~safeInt = { |x, fallback = 0|
		var y;
		if(x.isNil, { fallback }, {
			y = x.asInteger;
			if(y.isNil, { fallback }, { y });
		});
	};
	~msgFloat = { |msg, i, fallback = 0.0|
		var x = msg.at(i);
		~safeFloat.(x, fallback);
	};
	~msgInt = { |msg, i, fallback = 0|
		var x = msg.at(i);
		~safeInt.(x, fallback);
	};
	~safeRound = { |x, step = 0.001, fallback = 0.0|
		var y = ~safeFloat.(x, fallback);
		y.round(step ? 0.001);
	};

	// Shared layer gain curve: 0 is truly silent, then small positive slider
	// values take off audibly so every voice can emerge from the same baseline.
	~voiceGain = { |raw = 0.0, floorGain = 0.18, curve = 0.82|
		var x = ~safeFloat.(raw, 0.0).clip(0, 1);
		if(x <= 0.0001, {
			0.0
		}, {
			(floorGain + ((1.0 - floorGain) * (x ** curve))).clip(0, 1)
		});
	};
	~droneGain = { ~voiceGain.(~droneVolume ? 0.0, 0.18, 0.82) };
	~arpGain = { ~voiceGain.(~arpVolume ? 0.0, 0.16, 0.84) };
	~glassGain = { ~voiceGain.(~glassVolume ? 0.0, 0.16, 0.84) };
	~choirGain = { ~voiceGain.(~choirVolume ? 0.0, 0.20, 0.80) };

	~lastOSCHeartbeat = Process.elapsedTime;
	~lastOrbitEvent = "ORBIT_STABLE_DRIFT";
	~orbitEventEnergy = 0.0;
	~orbitLockStrength = 0.0;
	~orbitLobes = 1;
	~orbitEccentricity = 0.0;
	~orbitPeriapsis = 0.0;
	~orbitResonance = 0.0;

	// ========== MUSICAL SCALE ==========
	~pentatonic = [0, 2, 4, 7, 9];
	~lydian = [0, 2, 4, 6, 7, 9, 11];
	~wholeTone = [0, 2, 4, 6, 8, 10];
	~major = [0, 2, 4, 5, 7, 9, 11];
	~minor = [0, 2, 3, 5, 7, 8, 10];
	~dorian = [0, 2, 3, 5, 7, 9, 10];
	~phrygian = [0, 1, 3, 5, 7, 8, 10];
	~mixolydian = [0, 2, 4, 5, 7, 9, 10];
	~minorPentatonic = [0, 3, 5, 7, 10];
	~blues = [0, 3, 5, 6, 7, 10];
	~harmonicMinor = [0, 2, 3, 5, 7, 8, 11];
	~melodicMinor = [0, 2, 3, 5, 7, 9, 11];
	~chromatic = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
	~currentScale = ~lydian;

	// Harmonics for layered texture
	~harmonics = [
		1.0, 2.0, 1.5, 1.25, 1.333, 1.666,
		3.0, 2.25, 2.75, 4.0,
		1.125, 1.2, 1.375, 1.414, 1.618, 1.732,
		2.125, 2.333, 2.5, 2.666, 2.875, 3.125, 3.333, 3.5, 3.75,
		4.125, 4.5, 4.75, 5.0, 5.333, 5.75, 6.0,
		0.875, 0.9375, 1.781, 2.918, 3.1415, 6.283,
		7.0, 8.0, 9.0, 10.0
	];

	~harmonicZone = ~harmonics;
	~arpHarmonic  = 1.0;
	~harmonicComplexity = 0.0;

	~getHarmonic = { |baseFreq, index|
		(baseFreq * ~harmonics[index % ~harmonics.size]).clip(50, 5000);
	};

	~scaleToFreq = { |degree, octave = 3|
		var semitones = degree + (octave * 12);
		~rootFreq * (2 ** (semitones / 12));
	};

	~getScaleNote = { |minFreq = 100, maxFreq = 2000|
		var attempts = 0;
		var freq = 0;
		var octave, degree;
		while({ (freq < minFreq or: { freq > maxFreq }) and: { attempts < 20 } }, {
			octave = rrand(2, 8);
			degree = ~currentScale.choose;
			freq = ~scaleToFreq.(degree, octave);
			attempts = attempts + 1;
		});
		freq.clip(minFreq, maxFreq);
	};

	~quantizeToScale = { |freq|
		var f = ~safeFloat.(freq, ~rootFreq ? 55).clip(20, 8000);
		var root = ~safeFloat.(~rootFreq, 55).clip(20, 880);
		var scale = if(~currentScale.isNil, { ~lydian }, { ~currentScale });
		var semitones = 12 * log2((f / root).max(0.001));
		var bestMatch = 0;
		var bestDiff = inf;
		5.do { |octave|
			scale.do { |degree|
				var candidate = (octave * 12) + degree;
				var diff = abs(candidate - semitones);
				if(diff < bestDiff, {
					bestDiff = diff;
					bestMatch = candidate;
				});
			};
		};
		(root * (2 ** (bestMatch / 12))).clip(20, 8000);
	};

	// ========== SYNTH DEFS ==========
	SynthDef(\drone, { |out = 0, gate = 1, amp = 0.5, freq = 220, revMix = 0.45|
		var sig, env, f, a;
		env = EnvGen.kr(Env.asr(3.5, 1, 5), gate, doneAction: 2);
		f = Lag.kr(freq.clip(45, 900), 0.25);
		a = Lag.kr(amp.clip(0, 0.22), 0.20);
		sig = SinOsc.ar(f, 0, a);
		sig = sig + SinOsc.ar(f * 2.0, 0.1, a * 0.28);
		sig = sig + SinOsc.ar(f * 3.0, 0.2, a * 0.10);
		sig = HPF.ar(sig, 55);
		sig = LPF.ar(sig, 1400);
		sig = LeakDC.ar(sig * env);
		sig = FreeVerb.ar(sig, revMix.clip(0.05, 0.28), 0.45, 0.22);
		sig = Limiter.ar(sig, 0.52, 0.04);
		Out.ar(out, sig ! 2);
	}).add;

	SynthDef(\solarDrone, { |out = 0, gate = 1, amp = 0.18, freq = 55, xray = 0.0, wind = 0.0, bz = 0.5, kp = 0.0, revMix = 0.25|
		var env, drive, xr, wn, bzn, kpn, lfo, sig, shimmerFreq;
		env = EnvGen.kr(Env.asr(3, 1, 4), gate, doneAction: 2);
		drive = Lag.kr(amp.clip(0, 0.055), 2.0);
		xr = Lag.kr(xray.clip(0, 1), 4.0);
		wn = Lag.kr(wind.clip(0, 1), 4.0);
		bzn = Lag.kr(bz.clip(0, 1), 4.0);
		kpn = Lag.kr(kp.clip(0, 1), 4.0);
		lfo = SinOsc.kr(0.015 + (wn * 0.035)).range(0.25, 1.0);
		shimmerFreq = (900 + (xr * 2200) + (kpn * 800)).clip(600, 4200);
		sig = PinkNoise.ar(drive * 0.45);
		sig = BPF.ar(sig, shimmerFreq * (1 + (bzn - 0.5 * 0.08)), 0.18 + (kpn * 0.10));
		sig = sig * lfo * env;
		sig = HPF.ar(sig, 400);
		sig = LeakDC.ar(sig);
		sig = FreeVerb.ar(sig, revMix.clip(0.04, 0.16), 0.55, 0.22);
		sig = Limiter.ar(sig, 0.16, 0.05);
		Out.ar(out, sig ! 2);
	}).add;

	SynthDef(\solarFlarePing, { |out = 0, amp = 0.035, freq = 880, dur = 1.2, pan = 0|
		var env, sig;
		env = EnvGen.kr(Env.perc(0.01, dur), doneAction: 2);
		sig = SinOsc.ar(freq * [1, 1.618, 2.414], 0, amp * [1, 0.5, 0.25]).sum * env;
		sig = sig + (BPF.ar(WhiteNoise.ar(amp * 0.35), freq * 2, 0.12) * env);
		Out.ar(out, Pan2.ar(FreeVerb.ar(sig, 0.7, 0.8, 0.4), pan));
	}).add;

	SynthDef(\orbitMarker, { |out = 0, amp = 0.018, freq = 330, dur = 0.25, mode = 0|
		var env, sig, noise;
		env = EnvGen.kr(Env.perc(0.005, dur.clip(0.05, 1.8)), doneAction: 2);
		noise = BPF.ar(WhiteNoise.ar(amp * 0.35), freq * (2 + mode.clip(0, 5)), 0.18);
		sig = SinOsc.ar(freq * [1, 1.005 + (mode * 0.002)], 0, amp) + noise;
		sig = LeakDC.ar(sig * env);
		sig = Limiter.ar(sig, 0.18);
		Out.ar(out, sig ! 2);
	}).add;

	SynthDef(\arpVoice, { |out = 0, amp = 0.1, freq = 880, dur = 0.5, revMix = 0.3, pan = 0, softness = 0.5|
		var env, f, hiTame, body, reed, noise, sig, cutoff;
		f = freq.clip(70, 4200);
		hiTame = f.linexp(320, 4200, 1.0, 0.26).clip(0.22, 1.0);
		env = EnvGen.kr(Env([0, 0.72, 1.0, 0.72, 0], [0.020, dur * 0.22, dur * 0.46, dur * 0.32], [2, 1, -1, -4]), doneAction: 2);
		body = SinOsc.ar(f * LFNoise2.kr(1.4).range(0.997, 1.003), 0, 0.42);
		body = body + SinOsc.ar(f * 0.5, 0.5, 0.15 * (1.0 - f.linlin(80, 1800, 0, 1).clip(0, 1)));
		reed = VarSaw.ar(f * [1.0, 1.005], 0, 0.38 + (softness.clip(0, 1) * 0.18), [0.070, 0.046]).sum;
		noise = BPF.ar(PinkNoise.ar(0.040), (f * 1.35).clip(180, 3600), 0.22 + (softness.clip(0, 1) * 0.20));
		cutoff = (f * (2.0 + (softness.clip(0, 1) * 2.4))).clip(520, 5200);
		sig = LPF.ar((body + reed + noise) * env, cutoff);
		sig = HPF.ar(sig, 45);
		sig = FreeVerb.ar(LeakDC.ar(sig), revMix.clip(0.04, 0.32), 0.46, 0.22);
		sig = Limiter.ar(sig * amp * hiTame, 0.20, 0.045);
		Out.ar(out, Pan2.ar(sig, pan.clip(-0.65, 0.65)));
	}).add;

	SynthDef(\choir, { |out = 0, gate = 1, amp = 0.04, freq = 330, revMix = 0.22|
		var env, sig, detune1, detune2, laggedFreq, laggedAmp, formants, hiTame, drift;
		env = EnvGen.kr(Env.asr(0.65, 1.0, 1.8), gate, doneAction: 2);
		laggedFreq = Lag.kr(freq.clip(55, 440), 0.45);
		laggedAmp  = Lag.kr(amp.clip(0, 0.055), 0.28);
		hiTame = laggedFreq.linexp(110, 440, 0.92, 0.36).clip(0.30, 0.92);
		drift = LFNoise2.kr(0.16).range(0.996, 1.004);
		detune1 = SinOsc.ar(laggedFreq * 1.003 * drift, 0, laggedAmp * 0.20 * env);
		detune2 = SinOsc.ar(laggedFreq * 0.997 / drift, pi, laggedAmp * 0.20 * env);
		sig = SinOsc.ar(laggedFreq * drift, 0, laggedAmp * 0.30 * env);
		sig = sig + detune1 + detune2;
		formants = (BPF.ar(sig, 360, 0.92) * 0.42) + (BPF.ar(sig, 760, 0.96) * 0.20) + (BPF.ar(sig, 1250, 0.82) * 0.06);
		sig = HPF.ar(formants * hiTame, 65);
		sig = LPF.ar(sig, laggedFreq.linlin(55, 440, 1050, 2400).clip(900, 2600));
		sig = FreeVerb.ar(sig, revMix.clip(0.04, 0.22), 0.55, 0.22);
		sig = LeakDC.ar(sig);
		sig = Limiter.ar(sig, 0.16, 0.06);
		Out.ar(out, sig ! 2);
	}).add;

	SynthDef(\midi_poly_voice, { |out = 0, gate = 1, freq = 220, vel = 0.7, polyVol = 0.56, memory = 0.0, pressure = 0.0, density = 0.0, oceanDrive = 0.0, solarDrive = 0.0, pan = 0, egArp = 0, egDepth = 0.0, egGateScore = 0.0, egArpPhase = 0.0, tone = 0.45|
		var env, f, v, release, mem, dens, ocean, solar, fieldMotion, restraint, sig, body, saw, sub, tonalBody, chorus, warmth, cutoff, width, drive;
		var arpOn, arpDepth, arpScore, arpRate, arpPulse, arpMask;
		env = EnvGen.kr(Env.asr(0.018, 1.0, 0.48, curve: -3), gate, doneAction: 2);
		f = Lag.kr(freq.clip(24, 620), 0.022);
		v = Lag.kr(vel.clip(0, 1).linlin(0, 1, 0.34, 1.0), 0.025);
		release = Lag.kr(pressure.clip(0, 1), 0.18);
		mem = Lag.kr(memory.clip(0, 0.45), 0.30);
		dens = Lag.kr(density.clip(0, 1), 0.20);
		warmth = Lag.kr(tone.clip(0, 1), 0.16);
		ocean = Lag.kr(oceanDrive.clip(0, 1), 1.8);
		solar = Lag.kr(solarDrive.clip(0, 1), 1.2);
		arpOn = Lag.kr(egArp.clip(0, 1), 0.08);
		arpDepth = Lag.kr(egDepth.clip(0, 1), 0.18);
		arpScore = Lag.kr(egGateScore.clip(0, 1), 0.25);
		arpRate = (2.4 + (arpDepth * 5.8) + (arpScore * 2.2)).clip(1.8, 11.0);
		arpPulse = Decay2.kr(Dust.kr((arpRate * (0.38 + (arpDepth * 0.42) + (arpScore * 0.28))).clip(0.3, 12.0)), 0.006, 0.070 + (arpDepth * 0.070));
		arpMask = (1.0 + (arpOn * arpPulse * (0.25 + (arpDepth * 0.55) + (arpScore * 0.20)))).clip(1.0, 1.65);
		fieldMotion = SinOsc.kr(0.06 + (ocean * 0.12) + (solar * 0.08), 0, 0.003 + (ocean * 0.006) + (solar * 0.003), 1);
		restraint = (1.0 - (release * 0.68)).clip(0.18, 1.0);
		width = (0.30 + (warmth * 0.12) + (ocean * 0.05)).clip(0.24, 0.48);
		saw = VarSaw.ar(f * [0.997, 1.003] * fieldMotion, 0, width, 0.20).sum * 0.30;
		sub = SinOsc.ar(f * 0.5 * (1.0 - (ocean * 0.002)), 0.3, 0.30 + (ocean * 0.012));
		tonalBody = SinOsc.ar(f * [1.0, 1.005], [0, 0.4], [0.26, 0.16]).sum;
		body = (saw + sub + tonalBody) * (1.0 + (mem * 0.05));
		chorus = DelayC.ar(body, 0.026, LFNoise1.kr([0.16, 0.21]).range(0.006, 0.019)).sum * 0.16;
		drive = 1.0 + (ocean * 0.045) + (solar * 0.030) + (dens * 0.035);
		sig = (body + chorus) * env * v * polyVol.clip(0, 1) * 0.30 * restraint * drive * arpMask;
		sig = HPF.ar(sig, 28);
		cutoff = (640 + (warmth * 1020) + (dens * 220) + (solar * 160) + (ocean * 110) - (release * 170)).clip(420, 2300);
		sig = RLPF.ar(sig, cutoff, 0.58);
		sig = BLowShelf.ar(sig, 135, 0.7, 2.4);
		sig = BHiShelf.ar(sig, 1800, 0.7, -3.5 + (warmth * 1.5));
		sig = FreeVerb.ar(sig, 0.08 + (mem * 0.025) + (ocean * 0.030), 0.42 + (ocean * 0.05), 0.12 + (solar * 0.012));
		sig = Pan2.ar(Limiter.ar(LeakDC.ar(sig), 0.42, 0.04), pan.clip(-0.75, 0.75));
		Out.ar(out, sig);
	}).add;

	SynthDef(\glass, { |out = 0, amp = 0.08, freq = 1200, dur = 0.3, revMix = 0.4, pan = 0, color = 0.5|
		var env, f, hiTame, strike, bloom, body, sig;
		f = freq.clip(160, 2200);
		hiTame = f.linexp(480, 2200, 0.92, 0.12).clip(0.10, 0.92);
		env = EnvGen.kr(Env([0, 0.95, 0.55, 0.0], [0.012, dur.clip(0.08, 1.0) * 0.30, dur.clip(0.08, 1.0) * 0.70], [3, -2, -5]), doneAction: 2);
		strike = SinOsc.ar(f * LFNoise2.kr(2.2).range(0.998, 1.002), 0, 0.24);
		bloom = SinOsc.ar(f * [1.25, 1.5, 2.0], [0.3, 1.1, 1.7], [0.080, 0.045, 0.020] * (1.0 - (color.clip(0, 1) * 0.22))).sum;
		body = BPF.ar(PinkNoise.ar(0.045), (f * 0.95).clip(180, 2600), 0.24 + (color.clip(0, 1) * 0.20));
		sig = (strike + bloom + body) * env;
		sig = LPF.ar(sig, (f * 1.55).clip(520, 2800));
		sig = FreeVerb.ar(LeakDC.ar(sig), revMix.clip(0.08, 0.42), 0.62, 0.30);
		sig = Limiter.ar(sig * amp * hiTame, 0.18, 0.045);
		Out.ar(out, Pan2.ar(sig, pan.clip(-0.7, 0.7)));
	}).add;

	SynthDef(\ocean_swell, { |out = 0, gate = 1, amp = 0.012, tidalPhase = 0.5, current = 0.2, velocity = 0.1, thermal = 0.5, energy = 0.3, memory = 0.2|
		var env, freq, bw, sig, brown, pink, tri, tia, loFreq, hiFreq;
		env = EnvGen.kr(Env.asr(8.0, 1.0, 12.0), gate, doneAction: 2);
		tia = Lag.kr(current.clip(0, 1), 6.0);
		loFreq = tidalPhase.linexp(0, 1, 38, 95);
		hiFreq = loFreq * (1.0 + (velocity * 0.55) + (energy * 0.35));
		freq = Lag.kr(loFreq + (tia * (hiFreq - loFreq)), 4.0);
		bw = Lag.kr(0.08 + (velocity * 0.38) + (tia * 0.22), 3.0);
		brown = (LFDNoise1.ar(freq * 0.5) * 0.55) + (LFDNoise1.ar(freq * 0.13) * 0.35) + (LFDNoise1.ar(freq * 0.031) * 0.22);
		brown = brown * 0.4;
		tri = LFTri.ar(freq * (1.0 + (velocity * 0.18) + LFNoise2.kr(0.04).range(-0.015, 0.015)), tidalPhase) * 0.22;
		sig = BPF.ar(brown + tri, freq, bw.clip(0.04, 0.75));
		pink = BPF.ar(PinkNoise.ar(0.12), thermal.linexp(0, 1, 120, 380), 0.12 + (thermal * 0.08)) * 0.18;
		sig = sig + pink;
		sig = HPF.ar(sig, 28);
		sig = LPF.ar(sig, 420 + (energy * 280));
		sig = LeakDC.ar(sig);
		sig = FreeVerb.ar(sig, 0.18 + (memory * 0.32), 0.82 + (memory * 0.15), 0.28);
		sig = Limiter.ar(sig * env * amp * (0.6 + (tia * 0.55)), 0.045, 0.08);
		Out.ar(out, sig ! 2);
	}).add;

	SynthDef(\ocean_surge, { |out = 0, gate = 1, amp = 0.008, current = 0.2, velocity = 0.1, accel = 0.0, energy = 0.3, phase = 0.5, pan = 0|
		var env, tia, freq, sig, pink, bw;
		env = EnvGen.kr(Env.asr(2.5, 1.0, 6.0), gate, doneAction: 2);
		tia = Lag.kr(current.clip(0, 1), 1.8);
		freq = Lag.kr((80 + (tia * 220) + (velocity * 180) + (accel * 120)).clip(65, 520), 1.2);
		bw = (0.15 + (velocity * 0.45) + (accel * 0.30)).clip(0.08, 0.65);
		pink = PinkNoise.ar(0.7);
		sig = BPF.ar(pink, freq, bw);
		sig = sig + (BPF.ar(pink, freq * 2.18, bw * 0.55) * 0.28);
		sig = sig * (1.0 + SinOsc.kr(0.008 + (velocity * 0.022)).range(-0.20, 0.20));
		sig = HPF.ar(sig, 55);
		sig = LPF.ar(sig, 680 + (energy * 420));
		sig = LeakDC.ar(sig);
		sig = FreeVerb.ar(sig, 0.22 + (current * 0.18), 0.65, 0.22);
		sig = Limiter.ar(sig * env * amp * tia, 0.030, 0.05);
		Out.ar(out, Pan2.ar(sig, pan + phase.linlin(0, 1, -0.08, 0.08)));
	}).add;

	SynthDef(\ocean_break, { |out = 0, amp = 0.014, freq = 180, dur = 1.8, accel = 0.5, velocity = 0.3, pan = 0|
		var env, sig, white, brown, crash, ring;
		env = EnvGen.kr(Env([0, 1, 0.55, 0], [0.04, dur * 0.35, dur * 0.65], [-2, -3, -4]), doneAction: 2);
		white = WhiteNoise.ar(0.55);
		brown = LFDNoise1.ar(freq * 0.8) * 0.45;
		crash = BPF.ar((white * accel.clip(0, 1)) + (brown * (1.0 - accel.clip(0, 1))), freq.clip(80, 420), 0.22 + (velocity * 0.35));
		ring = Ringz.ar(white * 0.15, freq * [1.0, 1.41, 2.0], [0.18, 0.12, 0.08]).sum;
		sig = (crash * 0.72) + (ring * 0.28);
		sig = HPF.ar(sig, 42);
		sig = LPF.ar(sig, 550 + (accel * 380));
		sig = LeakDC.ar(sig);
		sig = FreeVerb.ar(sig, 0.28, 0.72, 0.22);
		sig = Limiter.ar(sig * env * amp, 0.038, 0.04);
		Out.ar(out, Pan2.ar(sig, pan));
	}).add;

	SynthDef(\ocean_surge_event, { |out = 0, amp = 0.008, current = 0.4, velocity = 0.2, accel = 0.0, energy = 0.3, phase = 0.5, pan = 0, sustain = 28|
		var env, tia, freq, sig, pink, bw;
		env = EnvGen.kr(Env.linen(7.0, sustain, 14.0, 1, \sin), doneAction: 2);
		tia = Lag.kr(current.clip(0, 1), 1.8);
		freq = Lag.kr((80 + (tia * 220) + (velocity * 180) + (accel * 120)).clip(65, 520), 1.2);
		bw = (0.15 + (velocity * 0.45) + (accel * 0.30)).clip(0.08, 0.65);
		pink = PinkNoise.ar(0.7);
		sig = BPF.ar(pink, freq, bw);
		sig = sig + (BPF.ar(pink, freq * 2.18, bw * 0.55) * 0.28);
		sig = sig * (1.0 + SinOsc.kr(0.008 + (velocity * 0.022)).range(-0.20, 0.20));
		sig = HPF.ar(sig, 55);
		sig = LPF.ar(sig, 680 + (energy * 420));
		sig = LeakDC.ar(sig);
		sig = FreeVerb.ar(sig, 0.22 + (current * 0.18), 0.65, 0.22);
		sig = Limiter.ar(sig * env * amp * max(tia, 0.25), 0.030, 0.05);
		Out.ar(out, Pan2.ar(sig, pan + phase.linlin(0, 1, -0.08, 0.08)));
	}).add;

	SynthDef(\ocean_chop, { |out = 0, amp = 0.006, freq = 480, dur = 0.3, vel = 0.3, pan = 0|
		var env, sig;
		env = EnvGen.kr(Env.perc(0.012, dur, 1, -5), doneAction: 2);
		sig = BPF.ar(PinkNoise.ar(0.8), freq.clip(280, 900), 0.35 + (vel * 0.3));
		sig = sig + (BPF.ar(WhiteNoise.ar(0.15), freq * 1.9, 0.25) * 0.3);
		sig = HPF.ar(sig, 220);
		sig = LeakDC.ar(sig);
		Out.ar(out, Pan2.ar(sig * env * amp, pan));
	}).add;

	SynthDef(\ocean_spray, { |out = 0, amp = 0.004, freq = 3200, dur = 0.08, pan = 0|
		var env, sig;
		env = EnvGen.kr(Env.perc(0.004, dur, 1, -6), doneAction: 2);
		sig = HPF.ar(BPF.ar(WhiteNoise.ar(1.0), freq.clip(1800, 5200), 0.4), 1400);
		Out.ar(out, Pan2.ar(sig * env * amp, pan));
	}).add;

	SynthDef(\ocean_undertow, { |out = 0, amp = 0.016, freq = 38, dur = 9.0|
		var env, sig;
		env = EnvGen.kr(Env.perc(3.5, dur, 1, -3), doneAction: 2);
		sig = SinOsc.ar(freq.clip(28, 52)) * 0.7 + (LFTri.ar(freq * 0.5) * 0.3);
		sig = sig * (1.0 + SinOsc.kr(0.11).range(-0.15, 0.15));
		sig = LPF.ar(sig, 90);
		sig = LeakDC.ar(sig);
		Out.ar(out, sig * env * amp ! 2);
	}).add;

	SynthDef(\ghost_note, { |out = 0, freq = 440, amp = 0.005, dur = 0.12, detune = 0.015, pan = 0|
		var env, sig, detunedFreq, shimmer;
		env = EnvGen.kr(Env.perc(0.002, dur, curve: -5), doneAction: 2);
		detunedFreq = freq * (1 + (detune * LFNoise1.kr(6).range(-1, 1)));
		sig = SinOsc.ar(detunedFreq, 0, 0.60 * env) + SinOsc.ar(detunedFreq * (1.0 + (detune * 0.7)), 0, 0.28 * env);
		shimmer = BPF.ar(WhiteNoise.ar(0.18 * amp), freq * 1.4, 0.22) * env;
		sig = HPF.ar((sig * amp) + shimmer, 220);
		sig = LPF.ar(sig, 2200);
		sig = LeakDC.ar(sig);
		sig = Limiter.ar(sig, 0.012, 0.02);
		Out.ar(out, Pan2.ar(sig, pan));
	}).add;

	SynthDef(\eco_chirp, { |out = 0, freq = 1800, amp = 0.008, dur = 0.07, pan = 0, color = 0.5, species = 0|
		var env, sig, sweep, sweep2, chirpDir, sp, songDur, wren, finch, thrush, jay, nightBird, warble, peck, breath, oddSong;
		sp = species.clip(0, 4);
		songDur = dur * (1.0 + (sp * 0.20) + (sp.clip(2, 4).linlin(2, 4, 0.0, 0.70)));
		chirpDir = color.linlin(0, 1, 1.35, 0.72) * (1.0 - (sp * 0.035));
		env = EnvGen.kr(Env([0, 1, 0.58, 0.22, 0], [0.003, songDur * 0.22, songDur * 0.48, songDur * 0.30], [4, -2, -4, -6]), doneAction: 2);
		sweep = XLine.kr(freq.clip(850, 6000), (freq * chirpDir).clip(680, 8000), (songDur * 1.05).clip(0.04, 0.58));
		sweep2 = sweep * (1.98 + (color * 0.08));
		warble = SinOsc.kr(5 + (sp * 4.2) + (color * 14)).range(0.982 - (sp * 0.004), 1.012 + (sp * 0.010));
		peck = Decay2.kr(Dust.kr(4 + (sp * 4) + (color * 8)), 0.002, 0.026 + (sp * 0.016)).clip(0, 1);
		breath = LFNoise2.kr(1.8 + (sp * 1.1)).range(0.78, 1.14);
		oddSong = SinOsc.kr(0.7 + (sp * 0.23) + (color * 0.9)).range(0.90, 1.18);
		wren = SinOsc.ar(sweep * 1.18 * warble, 0, 0.54) + SinOsc.ar(sweep2 * 1.22, 0, 0.17) + (BPF.ar(WhiteNoise.ar(0.10), sweep * 2.20, 0.20) * (0.30 + peck));
		finch = SinOsc.ar(sweep * warble, 0, 0.64) + SinOsc.ar(sweep2 * 1.06, 0, 0.15) + (BPF.ar(WhiteNoise.ar(0.10), sweep * 1.55, 0.24) * (0.18 + color));
		thrush = SinOsc.ar(sweep * 0.58 * warble, 0, 0.50) + SinOsc.ar(sweep * 1.22, 0.5, 0.21) + (BPF.ar(PinkNoise.ar(0.16), sweep * 0.92, 0.18) * (0.44 + color));
		jay = VarSaw.ar(sweep * 0.70 * warble * oddSong, 0, 0.30, 0.25) + SinOsc.ar(sweep * 1.33 * oddSong, 1.0, 0.18) + (BPF.ar(WhiteNoise.ar(0.18), sweep * 1.02, 0.34) * (0.38 + peck));
		nightBird = SinOsc.ar(sweep * 0.52 * warble * oddSong, 0, 0.42) + SinOsc.ar(sweep * 0.91, 1.0, 0.22) + (BPF.ar(PinkNoise.ar(0.16), sweep * (0.62 + color), 0.20) * (0.42 + peck));
		sig = SelectX.ar(sp, [wren, finch, thrush, jay, nightBird]) * breath * (0.84 + (peck * 0.26));
		sig = HPF.ar(sig * env, sp.linlin(0, 4, 1050, 520));
		sig = FreeVerb.ar(sig, 0.07 + (color * 0.11), 0.22, 0.10);
		sig = Limiter.ar(LeakDC.ar(sig * amp), 0.095, 0.01);
		Out.ar(out, Pan2.ar(sig, pan));
	}).add;

	SynthDef(\eco_call, { |out = 0, freq = 280, amp = 0.012, dur = 1.2, pan = 0, curve = 0.5, depth = 0.5, species = 0|
		var env, glide, glide2, form, sig, breath, bodyAmp, breathAmp, sp, whale, monkey, chatter, whoop;
		sp = species.clip(0, 1);
		env = EnvGen.kr(Env([0, 0.6, 1.0, 0.85, 0.3, 0], [dur * 0.05, dur * 0.12, dur * 0.38, dur * 0.28, dur * 0.17], [-2, 2, -1, -2, -4]), doneAction: 2);
		glide = XLine.kr((freq * (1.0 + (depth * 0.45))).clip(60, 2200), (freq * (0.62 + (curve * 0.88)) * (1.0 - (depth * 0.35))).clip(45, 2800), dur.clip(0.25, 3.5));
		glide2 = glide * (0.5 + (depth * 0.12));
		bodyAmp = 0.60 - (depth * 0.10);
		breathAmp = 0.35 + (depth * 0.20);
		breath = BPF.ar(PinkNoise.ar(breathAmp), glide * (1.65 + depth), 0.15 + (depth * 0.14));
		form = SinOsc.ar(glide, 0, bodyAmp) + SinOsc.ar(glide * (1.48 + (depth * 0.22)), 0.5, bodyAmp * 0.32) + SinOsc.ar(glide2, pi * 0.3, bodyAmp * 0.18 * depth);
		whale = LPF.ar((form + breath) * env, 1800 + (depth * 900));
		chatter = Decay2.kr(Dust.kr(6 + (depth * 18) + (curve * 8)), 0.004, 0.055 + (depth * 0.085)).clip(0, 1);
		whoop = SinOsc.ar(glide * [1.8, 2.43, 3.1], [0, 0.7, 1.4], [0.34, 0.22, 0.12]).sum;
		monkey = ((whoop * (0.35 + chatter)) + BPF.ar(WhiteNoise.ar(0.18 + chatter), glide * (3.2 + curve), 0.25)) * env;
		sig = XFade2.ar(whale, monkey, sp.linlin(0, 1, -1, 1));
		sig = HPF.ar(sig, 35 + (depth * 12));
		sig = FreeVerb.ar(LeakDC.ar(sig), 0.22 + (depth * 0.28), 0.55 + (depth * 0.22), 0.20);
		Out.ar(out, Pan2.ar(Limiter.ar(sig * amp, 0.14, 0.05), pan));
	}).add;

	SynthDef(\eco_insect_bloom, { |out = 0, amp = 0.010, freq = 2800, dur = 4.0, pan = 0, solarDrive = 0.5, density = 0.5, color = 0.5|
		var env, rate, pulse, carrier, wing, grit, swarm, sig;
		env = EnvGen.kr(Env([0, 0.35, 1.0, 0.82, 0], [dur * 0.10, dur * 0.22, dur * 0.48, dur * 0.20], [2, 1, -1, -4]), doneAction: 2);
		rate = (18 + (solarDrive.clip(0, 1) * 42) + (density.clip(0, 1) * 28)).clip(12, 92);
		pulse = LFPulse.kr(rate * LFNoise1.kr(0.20 + (solarDrive * 0.5)).range(0.88, 1.18), 0, 0.28 + (density * 0.28)).range(0.10, 1.0);
		carrier = freq.clip(1600, 7800) * LFNoise2.kr(5 + (density * 8)).range(0.985, 1.018);
		wing = SinOsc.ar(carrier, 0, 0.32) + SinOsc.ar(carrier * 1.97, 0.4, 0.18) + VarSaw.ar(carrier * 0.52, 0, 0.38, 0.14);
		grit = HPF.ar(BPF.ar(WhiteNoise.ar(0.22 + (density * 0.28)), carrier * (1.0 + (color * 0.22)), 0.18 + (density * 0.14)), 900);
		swarm = Mix.fill(4, { |i|
			var det, trem;
			det = 1.0 + ((i - 1.5) * (0.006 + (density * 0.006)));
			trem = LFPulse.kr(rate * (1.0 + (i * 0.037)), 0, 0.22 + (color * 0.18)).range(0.12, 0.9);
			SinOsc.ar(carrier * det, 0, 0.065 * trem)
		});
		sig = (wing + grit + swarm) * env * pulse;
		sig = HPF.ar(sig, 1100);
		sig = LPF.ar(sig, 9200);
		sig = FreeVerb.ar(LeakDC.ar(sig), 0.10 + (solarDrive * 0.14), 0.35 + (density * 0.18), 0.10);
		sig = Limiter.ar(sig * amp, 0.085, 0.02);
		Out.ar(out, Pan2.ar(sig, pan.clip(-0.9, 0.9)));
	}).add;

	SynthDef(\eco_growth, { |out = 0, freq = 180, amp = 0.012, dur = 2.8, pan = 0, gelFrac = 0.5, oceanDrive = 0.3, solarDrive = 0.2|
		var gfrac, freqMode, gelEnv, rootEnv, gelBase, gelDrift, gelSig, gelBubbles, gelBody, rootBase, rootPartials, creak, fibers, flutter, rootSig, sig;
		freqMode = freq.clip(55, 680).linlin(55, 680, 0, 1).clip(0, 1);
		gfrac = Lag.kr(((gelFrac.clip(0, 1) * 0.55) + ((1.0 - freqMode) * 0.45)).clip(0, 1), 0.8);
		gelEnv = EnvGen.kr(Env([0, 0.25, 1.0, 0.85, 0.4, 0], [dur * 0.12, dur * 0.20, dur * 0.30, dur * 0.22, dur * 0.16], [-1, 2, -2, -2, -3]), doneAction: 2);
		rootEnv = EnvGen.kr(Env([0, 1.0, 0.55, 0.35, 0], [dur * 0.04, dur * 0.28, dur * 0.40, dur * 0.28], [4, -1, -1, -3]), doneAction: 0);
		gelBase = freq.clip(55, 320) * (1.0 + (oceanDrive * 0.18));
		gelDrift = LFNoise2.kr(0.08 + (oceanDrive * 0.12)).range(0.97, 1.03);
		gelBubbles = Decay2.ar(Dust.ar(1.2 + (oceanDrive * 4.5) + ((1.0 - freqMode) * 2.5)), 0.018, 0.22 + (oceanDrive * 0.18)) * BPF.ar(PinkNoise.ar(0.55), gelBase * LFNoise1.kr(2).range(1.4, 3.4), 0.18);
		gelBody = RLPF.ar(BrownNoise.ar(0.36 + (oceanDrive * 0.22)), (gelBase * LFNoise2.kr(0.2).range(0.8, 1.8)).clip(45, 520), 0.20 + (oceanDrive * 0.20));
		gelSig = SinOsc.ar(gelBase * gelDrift, 0, 0.34) + SinOsc.ar(gelBase * gelDrift * 1.31, 0.4, 0.21) + SinOsc.ar(gelBase * gelDrift * 0.505, 1.2, 0.25) + gelBody + gelBubbles;
		gelSig = LPF.ar(gelSig, 360 + (oceanDrive * 420) + ((1.0 - freqMode) * 220));
		gelSig = gelSig * gelEnv;
		gelSig = gelSig * (0.78 + SinOsc.kr(0.06 + (oceanDrive * 0.12)).range(0, 0.34));
		gelSig = FreeVerb.ar(gelSig, 0.38 + (oceanDrive * 0.22), 0.72, 0.26);
		rootBase = freq.clip(90, 500) * (1.0 + (solarDrive * 0.12));
		rootPartials = SinOsc.ar(rootBase * [1.0, 1.27, 1.83, 2.41, 3.14, 4.2], [0, 0.4, 0.8, 1.2, 1.6, 2.1], [0.25, 0.19, 0.14, 0.10, 0.07, 0.045] * (1.0 + (solarDrive * 0.35))).sum;
		creak = HPF.ar(BPF.ar(PinkNoise.ar(0.56), rootBase * LFNoise2.kr(3.5).range(2.0, 5.5), 0.18 + (freqMode * 0.16)), rootBase * 1.2);
		fibers = Decay2.ar(Dust.ar(4 + (freqMode * 18) + (solarDrive * 18)), 0.006, 0.080 + (freqMode * 0.12)) * BPF.ar(WhiteNoise.ar(0.45), rootBase * LFNoise1.kr(8).range(3.0, 9.5), 0.12 + (solarDrive * 0.12));
		flutter = LFNoise1.ar(12 + (solarDrive * 32) + (freqMode * 20)).range(0.74, 1.05);
		rootSig = (rootPartials * flutter + (creak * 0.46) + (fibers * 0.42)) * rootEnv;
		rootSig = HPF.ar(rootSig, 70 + (freqMode * 120));
		rootSig = LPF.ar(rootSig, 1500 + (solarDrive * 2600) + (freqMode * 2200));
		rootSig = FreeVerb.ar(LeakDC.ar(rootSig), 0.12 + (solarDrive * 0.10), 0.42, 0.18);
		sig = (rootSig * (1.0 - gfrac)) + (gelSig * gfrac);
		sig = Limiter.ar(sig * amp * (1.34 + (freqMode * 0.30)), 0.22, 0.06);
		Out.ar(out, Pan2.ar(sig, pan));
	}).add;

	SynthDef(\eco_fissure, { |out = 0, amp = 0.012, freq = 700, dur = 0.28, pan = 0, crack = 0.5, fractalDepth = 3, material = 0.5|
		var env, sig, burst, ring, subCracks, crackFreq, mat, grain, body;
		mat = material.clip(0, 1);
		crackFreq = freq.clip(180, 5200);
		env = EnvGen.kr(Env([0, 1, 0.34, 0.0], [0.001, dur.clip(0.04, 0.85) * 0.28, dur.clip(0.04, 0.85) * 0.72], [6, -4, -8]), doneAction: 2);
		burst = HPF.ar(WhiteNoise.ar(1.0), crackFreq * (0.62 + (crack * 1.65)));
		burst = BPF.ar(burst, crackFreq * (0.85 + (crack * 0.72)), 0.22 + (crack * 0.38) + (mat * 0.16));
			ring = Ringz.ar(burst * 0.58, crackFreq * [0.50, 0.75, 1.0, 1.414, 2.0, 2.828], [0.090, 0.064, 0.045, 0.028, 0.015, 0.008] * (1.0 - (crack * 0.46)) * (1.0 + ((1.0 - mat) * 0.75))).sum * 0.22;
			grain = HPF.ar(BPF.ar(PinkNoise.ar(0.28 + (mat * 0.22)), crackFreq * (1.8 + (mat * 1.4)), 0.20 + (crack * 0.16)), 120);
			body = LPF.ar(BrownNoise.ar(0.20 + ((1.0 - mat) * 0.18)), 120 + ((1.0 - mat) * 420) + (crack * 180));
			subCracks = Mix.fill(5, { |i|
				var subPhase, subDelay, subDecay, subAmp, subFreq, subBurst, subMask, subEnv;
				subMask = (fractalDepth - i).clip(0, 1);
				subPhase = (i + 1) * 0.13 * (1.0 - (crack * 0.18));
				subDelay = (dur * subPhase).clip(0.0, 0.46);
				subDecay = (dur * 0.28 * (1.0 - (subPhase * 0.65))).clip(0.015, 0.24);
				subAmp = (0.58 + (crack * 0.08)).pow(i + 1) * subMask;
				subFreq = crackFreq * (1.20 + (i * (0.33 + (crack * 0.25))));
				subEnv = EnvGen.kr(Env([0, 0, 1, 0], [subDelay, 0.001, subDecay], [0, 5, -5]), doneAction: 0);
				subBurst = HPF.ar(WhiteNoise.ar(subAmp * subEnv * 0.6), subFreq);
				subBurst = BPF.ar(subBurst, subFreq, 0.28);
				subBurst * 0.32
			});
		sig = ((burst + ring + (grain * 0.34) + (body * 0.20)) * env) + (subCracks * 0.42);
		sig = HPF.ar(sig, 55);
		sig = FreeVerb.ar(LeakDC.ar(sig), 0.12 + ((1.0 - crack) * 0.18) + ((1.0 - mat) * 0.10), 0.30 + ((1.0 - crack) * 0.22), 0.16);
		sig = Limiter.ar(sig * amp, 0.15, 0.025);
		Out.ar(out, Pan2.ar(sig, pan));
	}).add;

	SynthDef(\eco_thunder, { |out = 0, amp = 0.040, freq = 54, dur = 5.0, pan = 0, crack = 0.5, oceanDrive = 0.4, solarDrive = 0.2|
		var env, crackEnv, sub, roll, body, snap, air, sig;
		env = EnvGen.kr(Env([0, 1, 0.70, 0.18, 0], [0.035, dur * 0.22, dur * 0.44, dur * 0.30], [-1, -2, -3, -5]), doneAction: 2);
		crackEnv = EnvGen.kr(Env.perc(0.001, (0.12 + (crack * 0.24)).clip(0.05, 0.42), 1, -7), doneAction: 0);
		sub = SinOsc.ar(freq.clip(28, 96) * [0.5, 1.0, 1.5], [0, 0.4, 1.1], [0.45, 0.36, 0.16]).sum;
		roll = LPF.ar(BrownNoise.ar(0.78), 95 + (oceanDrive.clip(0, 1) * 260) + (solarDrive.clip(0, 1) * 120));
		body = (sub * (0.65 + (oceanDrive * 0.30))) + (roll * (0.45 + (crack * 0.35)));
		snap = HPF.ar(WhiteNoise.ar(crackEnv * (0.55 + crack)), 680 + (crack * 1800));
		snap = BPF.ar(snap, (freq * (12 + (crack * 26))).clip(700, 4200), 0.28);
		air = BPF.ar(PinkNoise.ar(0.32), (freq * (4.0 + (solarDrive * 5.0))).clip(180, 1300), 0.24 + (oceanDrive * 0.16));
		sig = ((body + air) * env) + (snap * 0.52);
		sig = HPF.ar(sig, 24);
		sig = LPF.ar(sig, 1700 + (solarDrive.clip(0, 1) * 1800));
		sig = FreeVerb.ar(LeakDC.ar(sig), 0.36 + (oceanDrive.clip(0, 1) * 0.20), 0.82, 0.30);
		sig = Limiter.ar(sig * amp, 0.24, 0.08);
		Out.ar(out, Pan2.ar(sig, pan.clip(-0.75, 0.75)));
	}).add;

	// ========== DRONE CONTROL FUNCTIONS ==========
	~startDrone = {
		~spawnDrone.();
	};

	~spawnDrone = { |freq = nil, vol = nil|
		var spawnFreq, spawnVol, spawnRev;
		spawnFreq = ~safeFloat.(freq, ~pendingDroneFreq ? 111).clip(45, 900);
		spawnVol  = ~safeFloat.(vol, ~droneVolume ? 0.0).clip(0, 1);
		spawnRev  = (~pendingDroneRev ? 0.25).clip(0.04, 0.22);
		~manualDroneFreq = spawnFreq;
		~manualDroneVol = spawnVol;
			~droneManualArmed = true;
			~currentDroneOn = true;
			if(~droneSynth.isNil or: { ~droneSynth.isPlaying.not }, {
				if(~droneSynth.notNil, {
					~droneSynth.set(\gate, 0);
				});
				~droneSynth = Synth(\drone, [
					\amp, 0,
					\freq, spawnFreq,
					\revMix, spawnRev
				]);
				~droneSynth.register;
				~droneSpawnedOnce = true;
				("Drone MANUALLY SPAWNED freq=" ++ ~safeRound.(spawnFreq, 0.01, 111) ++ " vol=" ++ ~safeRound.(spawnVol, 0.001, 0)).postln;
		}, {
			~droneSynth.set(\freq, spawnFreq, \revMix, spawnRev);
			("Drone already alive. Updated manual target freq=" ++ ~safeRound.(spawnFreq, 0.01, 111)).postln;
		});
	};

	~stopDrone = {
		if(~droneSynth.notNil and: { ~droneSynth.isPlaying }, {
			~droneSynth.set(\amp, 0, \gate, 0);
			~droneSynth = nil;
			"Drone stopped / released".postln;
		});
		~droneManualArmed = false;
		~currentDroneOn = false;
	};

	~killDrone = {
		~stopDrone.();
	};

	~cancelFloquetDissolution = {
		if(~floquetDissolutionRoutine.notNil, {
			~floquetDissolutionRoutine.stop;
			~floquetDissolutionRoutine = nil;
		});
		~floquetDissolutionActive = false;
		~floquetDissolutionCycle = 0;
		~floquetDissWarmth = nil;
	};

	~startFloquetDissolution = {
		if((~floquetDissolutionActive ? false) or: { ~floquetDissolutionRoutine.notNil }, {
			"=== Floquet dissolution: duplicate trigger ignored ===".postln;
		}, {
			~floquetDissolutionActive = true;
			~floquetDissolutionCycle = 0;
			~floquetDissWarmth = (~floquetDissWarmth ? 0.6).clip(0.10, 0.80);
			~floquetDissolutionRoutine = Routine({
				var maxCycles, stepWait;
				maxCycles = 18;
				3.0.wait;

					if(~floquetDroneSynth.isNil or: { ~floquetDroneSynth.isPlaying.not }, {
						var rootF;
						rootF = ~rootFreq ? 55;
						if(~floquetDroneSynth.notNil, {
							~floquetDroneSynth.set(\gate, 0);
						});
						~floquetDroneSynth = Synth(\floquet_drone, [
							\out, 0, \freq, rootF,
						\amp, ~droneGain.() * 0.18,
						\vol, 1.0,
						\nu0, ~fsNu[0], \nu1, ~fsNu[1],
						\nu2, ~fsNu[2], \nu3, ~fsNu[3],
						\nu4, 0.0, \nu5, 0.0,
						\nu6, 0.0, \nu7, 0.0,
						\omega, ~fsOmega ? 0.18,
						\strength, 0.06,
						\topoPhase, ~fsTopoPhase ? 0,
						\topoDepth, 0.0,
						\atk, 4.0, \sus, 1.0, \rel, 8.0,
							\harmonics, 2,
							\warmth, 0.25
						], addAction: \addToTail);
						~floquetDroneSynth.register;
						"=== Floquet dissolution: ghost tail spawned ===".postln;
				});

				maxCycles.do { |i|
					var frac, drone, targetAmp, jitterAmp, curWarmth, targetWarm, nextWarmth, targetStr, nextStr, nuBleed;
					frac = (i + 1) / maxCycles;
					drone = ~floquetDroneSynth;
					if(drone.notNil and: { drone.isPlaying }, {
						targetAmp = ~droneGain.() * 0.34 * (1.0 - frac).squared * 0.55;
						jitterAmp = targetAmp * rrand(0.85, 1.10);
						curWarmth = ~floquetDissWarmth ? 0.6;
						targetWarm = 0.15 + rrand(0.0, 0.08);
						nextWarmth = curWarmth + ((targetWarm - curWarmth) * rrand(0.15, 0.35));
						~floquetDissWarmth = nextWarmth;
						targetStr = 0.28 * (1.0 - frac).sqrt * 0.15;
						nextStr = targetStr * rrand(0.7, 1.0);
						nuBleed = (1.0 - frac).squared;
						drone.set(
							\amp, jitterAmp.clip(0, 0.08),
							\warmth, nextWarmth.clip(0.10, 0.70),
							\strength, nextStr.clip(0, 0.28),
							\harmonics, (1.0 + ((1.0 - frac) * 2.0)).clip(1.0, 3.0),
							\topoDepth, ((~fsTopoDepth ? 0) * nuBleed).clip(0, 0.20),
							\nu4, (~fsNu[4] ? 0) * nuBleed * rrand(0.3, 0.8),
							\nu5, (~fsNu[5] ? 0) * nuBleed * rrand(0.3, 0.8),
							\nu6, 0.0,
							\nu7, 0.0
						);
						if(i == (maxCycles - 2), {
							drone.set(\gate, 0);
							~floquetDroneSynth = nil;
							"=== Floquet dissolution: final gate-down ===".postln;
						});
					});
					~floquetDissolutionCycle = i + 1;
					stepWait = rrand(2.8, 5.5);
					stepWait.wait;
				};

				~floquetDissolutionRoutine = nil;
				~floquetDissolutionActive = false;
				~floquetDissolutionCycle = 0;
				"=== Floquet dissolution: complete ===".postln;
			}).play(AppClock);
		});
	};

	~updateDrone = { |freq, baseAmp, revMix|
		var finalAmp, targetFreq, safeBase;
		~pendingDroneFreq = ~safeFloat.(freq, ~pendingDroneFreq ? 111).clip(45, 900);
		~pendingDroneRev = ~safeFloat.(revMix, ~pendingDroneRev ? 0.25).clip(0.04, 0.22);
		safeBase = ~safeFloat.(baseAmp, 0).clip(0, 0.35);
		~pendingDroneAmp = (safeBase * ~droneGain.()).clip(0, 0.20);
		if(~droneManualArmed and: { ~droneSynth.notNil and: { ~droneSynth.isPlaying } }, {
			finalAmp = (safeBase * ~droneGain.()).clip(0, 0.20);
			targetFreq = ~pendingDroneFreq;
			~droneSynth.set(
				\freq, targetFreq,
				\amp, finalAmp,
				\revMix, ~pendingDroneRev
			);
		});
	};

	// ========== OSC RECEIVER ==========
	thisProcess.openUDPPort(~oscPort);
	("Listening for OSC on port: " + ~oscPort).postln;

	~choirGroup = Group.tail(s);
	s.sync;

	// ── MASTER LIMITER ─────────────────────────────────────────────────────────
	// Sits at the very tail of the tree, reads the summed mix on bus 0, soft-clips
	// it, and writes it back. This protects the output when louder voices stack,
	// which is what lets the per-voice levels run hot without digital clipping.
	SynthDef(\masterLimiter, { |amp = 1.0|
		var sig = In.ar(0, 2);
		sig = Limiter.ar(sig * amp, 0.95, 0.01);
		ReplaceOut.ar(0, sig);
	}).add;
	s.sync;
	~masterLimiterSynth = Synth.tail(s, \masterLimiter, [\amp, 1.0]);
	// keep it pinned to the tail if other tail-groups get added later
	~choirGroup.moveBefore(~masterLimiterSynth);

	// ── /rdf/field ────────────────────────────────────────────────────────────
	OSCdef(\rdfFieldReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		if(msg.size >= 9, {
			~alpha          = ~msgFloat.(msg, 1, 2.0).clip(1.05, 5.0);
			~depth          = ~msgFloat.(msg, 2, 3.0).clip(0, 12);
			~finest         = ~msgFloat.(msg, 3, 0).clip(0, 1);
			~lastBrightness = ~msgFloat.(msg, 5, 0).clip(0, 1);
			~lastOrbPhi     = ~msgFloat.(msg, 7, 0.5).clip(0, 2);
			~metricLyapunov = ~msgFloat.(msg, 8, 0).clip(-4, 4);
		});
	}, "/rdf/field", nil, ~oscPort);

	// ── /rdf/orbit ────────────────────────────────────────────────────────────
	OSCdef(\rdfOrbitReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		if(msg.size >= 6, {
			var orbSpeed, orbSensitivity;
			orbSpeed       = ~msgFloat.(msg, 1, 0.1).clip(0, 4);
			orbSensitivity = ~msgFloat.(msg, 3, 1.0).clip(0.05, 4);
			~orbSensitivity  = orbSensitivity.clip(0.1, 3.0);
			~lastOrbSpeed    = orbSpeed * ~orbSensitivity;
		});
	}, "/rdf/orbit", nil, ~oscPort);

	// ── /rdf/ctcState — CTC Channel Mode from Processing ─────────────────────
	// [1] proximity [2] raw [3] zone [4] floquetAsym [5] closed
	// [6] closureMetric [7] closureFreq [8] active [9] Vaidya attenuation
	OSCdef(\rdfCTCReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		if(msg.size >= 10, {
			~ctcProximity = ~msgFloat.(msg, 1, 0).clip(0, 1.4);
			~ctcProximityRaw = ~msgFloat.(msg, 2, 0).clip(0, 1.4);
			~ctcZone = ~msgInt.(msg, 3, 0).clip(0, 3);
			~ctcFloquetAsymmetry = ~msgFloat.(msg, 4, 1).clip(0.2, 1.0);
			~ctcClosed = ~msgInt.(msg, 5, 0).clip(0, 1);
			~ctcClosureMetric = ~msgFloat.(msg, 6, 0).clip(0, 1);
			~ctcClosureFreq = ~msgFloat.(msg, 7, ~rootFreq ? 55).clip(28, 180);
			~ctcChannelActive = ~msgInt.(msg, 8, 0).clip(0, 1);
			~ctcVaidyaAtten = ~msgFloat.(msg, 9, 1).clip(0.2, 1.0);
		});
	}, "/rdf/ctcState", nil, ~oscPort);

	// ── /rdf/mix — all audio controls ────────────────────────────────────────
	// SuperCollider msg[0] is the OSC address. Processing payload index 0 lands at msg[1].
	// msg[1] modSource  msg[2] scaleIndex  msg[3] rootFreq   msg[4] masterAmp  msg[5] reverbMix
	// msg[6] droneOn    msg[7] arpOn       msg[8] glassOn
	// msg[9] droneVol   msg[10] arpVol     msg[11] glassVol  msg[12] choirVol
	// msg[13] ghostOn   msg[14] arpRate   msg[15] effectiveD   msg[16] spectralRolloff
	// msg[17..20] eco toggles chirp/call/growth/fissure
	// msg[21..24] eco levels  chirp/call/growth/fissure
	OSCdef(\rdfMixReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		if(msg.size >= 16, {
			var avgBright, orbPhi, masterAmp, reverbMix;
			var droneOn, arpOn, glassOn;
			var freq, amp, effectiveOrbSpeed, arpFreq, glassFreq, choirFreq;
			var scaleIndex, harmonicIndex, harmonicFreq, vibrato, droneFreq, modFreq;
			var modSource, modIntensity, modeEffect, alphaVal, finestVal;
			var arpAmp, glassAmp, choirAmp;
			var oceanArpBoost, oceanGlassBoost, solarBreathNow, envLift;
			var arpRate;
			var alphaIntensity, arpInterval, arpPattern, arpGate, arpMul, nowTime, degreeOffset;
			var cosmicPhase, timingBreath, pythStep, glassDelay;
			var harmonicZone, arpHarmonic;
			var droneVol, arpVol, glassVol, choirVol;
			var droneGain, arpGain, glassGain, choirGain;
			var choirAllowed, now, freqChanged, safeChoirAmp, imprintBlend;
			var ecoChirpOn, ecoCallOn, ecoGrowthOn, ecoFissureOn;
			var ecoChirpLevel, ecoCallLevel, ecoGrowthLevel, ecoFissureLevel;
			var ecoEdge, ecoDepth, ecoInstability, ecoCoherence, ecoFreq, ecoCooldown, ecoMicroBias, ecoThunderScore, ecoInsectScore;
			var polyBusy, glassPolyDamp;

			arpRate = ~msgFloat.(msg, 14, 1.0).clip(0.25, 3.0) * 0.4;

			modSource   = ~msgInt.(msg, 1, 0).clip(0, 9);
			scaleIndex  = ~msgInt.(msg, 2, 0).clip(0, 12);
			~rootFreq   = ~msgFloat.(msg, 3, 55).clip(20, 880);
			masterAmp   = ~msgFloat.(msg, 4, 0.25).clip(0, 1);
			reverbMix   = (~msgFloat.(msg, 5, 0.25).clip(0, 1) + ((~oceanReverbDrive ? 0) * 0.10)).clip(0, 1);
			droneOn     = ~msgFloat.(msg, 6, 0) > 0.5;
			arpOn       = ~msgFloat.(msg, 7, 0) > 0.5;
			glassOn     = ~msgFloat.(msg, 8, 0) > 0.5;
			droneVol    = ~msgFloat.(msg, 9,  ~droneVolume).clip(0, 1);
			arpVol      = ~msgFloat.(msg, 10, ~arpVolume).clip(0, 1);
			glassVol    = ~msgFloat.(msg, 11, ~glassVolume).clip(0, 1);
			choirVol    = ~msgFloat.(msg, 12, ~choirVolume).clip(0, 1);
			~ghostNotesEnabled = ~msgFloat.(msg, 13, 1) > 0.5;
			ecoChirpOn = ~msgFloat.(msg, 17, 1) > 0.5;
			ecoCallOn = ~msgFloat.(msg, 18, 1) > 0.5;
			ecoGrowthOn = ~msgFloat.(msg, 19, 1) > 0.5;
			ecoFissureOn = ~msgFloat.(msg, 20, 1) > 0.5;
			ecoChirpLevel = ~msgFloat.(msg, 21, 0.58).clip(0, 1);
			ecoCallLevel = ~msgFloat.(msg, 22, 0.58).clip(0, 1);
			ecoGrowthLevel = ~msgFloat.(msg, 23, 0.64).clip(0, 1);
			ecoFissureLevel = ~msgFloat.(msg, 24, 0.64).clip(0, 1);

			avgBright         = ~lastBrightness;
			orbPhi            = ~lastOrbPhi;
			alphaVal          = ~alpha ? 2.0;
			finestVal         = ~finest ? 0.0;
			effectiveOrbSpeed = ~lastOrbSpeed;

			~droneVolume = droneVol;
			~arpVolume   = arpVol;
			~glassVolume = glassVol;
			~choirVolume = choirVol;
			droneGain = ~voiceGain.(droneVol, 0.18, 0.82);
			arpGain = ~voiceGain.(arpVol, 0.16, 0.84);
			glassGain = ~voiceGain.(glassVol, 0.16, 0.84);
			choirGain = ~voiceGain.(choirVol, 0.20, 0.80);
			polyBusy = (((~midiPolyVoices.size ? 0) > 0) or: { (~midiPolyMemory ? 0) > 0.08 });
			glassPolyDamp = if(polyBusy, { 0.18 }, { 1.0 });

				// Base drone toggle is a manual override. It should not permanently
				// disable Floquet lifecycle auto-injection.
				if(droneOn.not, {
					if(~droneManualArmed or: { ~droneSynth.notNil }, {
						~stopDrone.();
					});
				});

			// UPDATE SCALE
			switch(scaleIndex,
				0,  { ~currentScale = ~lydian; },
				1,  { ~currentScale = ~major; },
				2,  { ~currentScale = ~pentatonic; },
				3,  { ~currentScale = ~wholeTone; },
				4,  { ~currentScale = ~minor; },
				5,  { ~currentScale = ~dorian; },
				6,  { ~currentScale = ~phrygian; },
				7,  { ~currentScale = ~mixolydian; },
				8,  { ~currentScale = ~minorPentatonic; },
				9,  { ~currentScale = ~blues; },
				10, { ~currentScale = ~harmonicMinor; },
				11, { ~currentScale = ~melodicMinor; },
				12, { ~currentScale = ~chromatic; }
			);

			freq = ~rootFreq * (1 + (avgBright * 3));
			freq = ~quantizeToScale.(freq).clip(50, 2000);
			amp  = ((0.015 + (avgBright * 1.08)) * masterAmp * 1.7).clip(0.0, 0.80);

			~solarPhase = (~solarPhase ? 0) + ((~solarPhaseRate ? 0.08).clip(0.01, 0.45) * 0.18);
			solarBreathNow = sin(~solarPhase).linlin(-1, 1,
				1.0 - ((~solarBreath ? 0) * 0.18),
				1.0 + ((~solarBreath ? 0) * 0.22)
			).clip(0.75, 1.35);

			// Ocean, solar, and galaxy remain modulation/excitation layers; gain
			// staging is normalized before these multipliers so legacy voices do
			// not dominate merely because their old defaults were hotter.
			oceanArpBoost = (1.0 + (((~oceanArpExcite ? 0) + ((~excArpDrive ? 0) * 0.45)) * 0.82)).clip(1.0, 1.85);
			oceanGlassBoost = (1.0 + (((~oceanGlassExcite ? 0) + ((~excGlassDrive ? 0) * 0.45)) * 0.92)).clip(1.0, 2.05);
			imprintBlend = (~fsFieldImprint ? 0).clip(0, 1);
			envLift = (
				1.0
				+ ((~oceanEnergy ? 0) * 0.08)
				+ ((~solarBreath ? 0) * 0.10)
				+ (((~excArpDrive ? 0) + (~excGlassDrive ? 0)) * 0.055)
				+ (imprintBlend * 0.05)
			).clip(0.88, 1.32);
			amp = (amp * envLift).clip(0.0, 0.42);

			arpAmp = (~lastBrightness.max(0.08) * masterAmp * 0.42 * 1.7 * arpGain * oceanArpBoost * solarBreathNow * envLift).clip(0, 0.46);

			glassAmp = (orbPhi.max(0.12) * masterAmp * 0.34 * 1.7 * glassGain * oceanGlassBoost * solarBreathNow * envLift * glassPolyDamp).clip(0, 0.22);
			choirAmp = ((0.012 + (avgBright.max(0.05) * 0.120)) * masterAmp * 1.7 * masterAmp.linlin(0, 1, 0.75, 1.42) * choirGain * envLift).clip(0, (~choirMaxAmp ? 0.105) * 2.0);
			arpAmp = (arpAmp * (1.0 - (imprintBlend * 0.05))).clip(0, 0.44);
			glassAmp = (glassAmp * (1.0 + (imprintBlend * 0.08))).clip(0, 0.22);
			choirAmp = (choirAmp * (1.0 + (imprintBlend * 0.12))).clip(0, (~choirMaxAmp ? 0.105) * 2.0);

			harmonicIndex = (orbPhi * 3).floor % ~harmonics.size;
			harmonicFreq  = ~getHarmonic.(freq, harmonicIndex);
			vibrato       = 1 + (sin(Main.elapsedTime * effectiveOrbSpeed.linlin(0, 2, 1, 8)) * effectiveOrbSpeed.linlin(0, 2, 0.001, 0.01));
			droneFreq     = (freq * vibrato).clip(60, 2000);
			~updateDrone.(droneFreq, amp, reverbMix);

			// ALPHA-SHAPED ARP
			alphaIntensity = alphaVal.linlin(1.1, 4.5, 0, 1).clip(0, 1);
			ecoEdge = (((~foundCurlB ? 0) * 0.40) + ((~foundUncertainty ? 0) * 0.22) + (orbPhi.linlin(0.42, 1.45, 0, 1).clip(0, 1) * 0.38)).clip(0, 1);
			ecoDepth = ((alphaIntensity * 0.32) + (finestVal.clip(0, 1) * 0.28) + (imprintBlend * 0.40)).clip(0, 1);
			ecoInstability = (((~foundUncertainty ? 0) * 0.45) + ((~metricLyapunov ? 0).abs.clip(0, 2) * 0.18) + ((~foundCurlB ? 0) * 0.37)).clip(0, 1);
			ecoCoherence = (((~foundCoherence ? 0) * 0.52) + (imprintBlend * 0.28) + ((~foundCoupling ? 0) * 0.20)).clip(0, 1);

			harmonicZone = if(alphaIntensity < 0.33, {
				~harmonics[0..9]
			}, {
				if(alphaIntensity < 0.66, {
					~harmonics[0..24]
				}, {
					~harmonics
				})
			});

			nowTime = Main.elapsedTime;

			cosmicPhase = sin(nowTime / ((~goldenRatio ? 1.618) * 3.0)).linlin(-1, 1, -1, 1);
			pythStep = (~pythagoreanRatios ? [1.0]).wrapAt((~arpStep ? 0) + ((~orbitLobes ? 1) - 1));
			timingBreath = (
				1.0
				+ (cosmicPhase * (~arpTimingWander ? 0.18))
				+ (((pythStep - 1.0) * 0.045).clip(0, 0.10))
				- (((~foundCoherence ? 0) * 0.06).clip(0, 0.06))
				+ (((~foundUncertainty ? 0) * 0.055).clip(0, 0.055))
			).clip(0.78, 1.24);

			arpInterval = ((alphaIntensity.linlin(0, 1, 0.62, 0.34) / arpRate.linlin(0.25, 3.0, 0.82, 1.28)) * timingBreath).clip(0.20, 0.82);

			if(arpOn and: { arpAmp > 0.002 } and: { nowTime >= (~nextArpTrigTime ? 0.0) }, {
				~lastArpTrigTime = nowTime;
				~lastArpActualTime = nowTime;
				~nextArpTrigTime = nowTime + (arpInterval * rrand(0.86, 1.18));
				// Glass has its own independent cooldown; arp does not gate it

				glassDelay = rrand(0.32, 1.15);
				~nextGlassAllowedTime = max(~nextGlassAllowedTime ? 0.0, nowTime + glassDelay);

				~arpStep = (~arpStep + 1) % 16;

				arpPattern = if(alphaIntensity < 0.33, {
					[0, 0, 1, 0, 2, 0, 1, 3, 0, 2, 0, 1, 4, 1, 0, 2]
				}, {
					if(alphaIntensity < 0.66, {
						[0, 2, 4, 7, 4, 2, 9, 7, 0, 3, 5, 10, 5, 3, 12, 7]
					}, {
						[0, 7, 2, 12, 5, 14, 3, 10, 8, 17, 6, 15, 4, 19, 11, 21]
					})
				});

				arpHarmonic = harmonicZone.choose;
				~arpHarmonic = arpHarmonic;

				arpGate = (
					0.74
					+ (avgBright * 0.12)
					+ (alphaIntensity * 0.08)
					+ ((~oceanArpExcite ? 0) * 0.16)
					+ ((~excArpDrive ? 0) * 0.10)
				).clip(0.52, 1.0);

				if(arpGate.coin and: { (~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 12 }, {
					var walkStep, walkSpan, arpDur, arpPan, hiTrim;
					walkSpan = if(alphaIntensity < 0.33, { 7 }, { if(alphaIntensity < 0.66, { 11 }, { 15 }) });
					if((~arpWalkDegree ? 0) <= 0, { ~arpWalkDir = 1; });
					if((~arpWalkDegree ? 0) >= walkSpan, { ~arpWalkDir = -1; });
					walkStep = [1, 1, 1, 2, -1].wchoose([0.46, 0.22, 0.12, 0.12, 0.08]) * (~arpWalkDir ? 1);
					if(0.10.coin, { walkStep = 0 - walkStep; });
					~arpWalkDegree = ((~arpWalkDegree ? 0) + walkStep).clip(0, walkSpan).asInteger;

					degreeOffset = arpPattern[(~arpWalkDegree ? 0) % arpPattern.size];
					arpMul = 2 ** (degreeOffset / 12);
					arpHarmonic = [1.0, 1.0, 1.125, 1.25, 1.5, 2.0].wchoose([0.38, 0.20, 0.16, 0.13, 0.09, 0.04]);
					~arpHarmonic = arpHarmonic;
					arpFreq = ~quantizeToScale.((freq * arpMul * arpHarmonic).clip(80, 3600));
					hiTrim = arpFreq.linexp(420, 3600, 1.0, 0.34).clip(0.30, 1.0);
					arpDur = (arpInterval * rrand(1.35, 2.20)).clip(0.42, 1.65);
					arpPan = sin((~arpStep ? 0) * 0.37).clip(-0.55, 0.55);
					~arpBurstInflight = ((~arpBurstInflight ? 0) + 1).clip(0, 32);
					Synth(\arpVoice, [
						\freq, arpFreq,
						\amp, arpAmp * (0.24 + (alphaIntensity * 0.10)) * hiTrim,
						\dur, arpDur,
						\revMix, reverbMix.clip(0.06, 0.28),
						\pan, arpPan,
						\softness, (0.45 + ((~foundCoherence ? 0) * 0.30) + ((~oceanArpExcite ? 0) * 0.18)).clip(0, 1)
					]);
					AppClock.sched(arpDur + 0.10, {
						~arpBurstInflight = ((~arpBurstInflight ? 0) - 1).max(0);
						nil;
					});
				});
			});

			// GLASS SOUNDS
			// FIX: independent clock, raised threshold, smaller orbPhi gate
			~lastGlassTrigTime = ~lastGlassTrigTime ? 0.0;

if(glassOn
    and: { glassAmp > 0.004 }
    and: { polyBusy.not }
    and: { orbPhi > 0.24 }
    and: { (Main.elapsedTime - ~lastGlassTrigTime) > (~glassCooldown ? 0.30) }
    and: { Main.elapsedTime >= (~nextGlassAllowedTime ? 0.0) }, {

    ~lastGlassTrigTime = Main.elapsedTime;
				~actualGlassTriggerCount = (~actualGlassTriggerCount ? 0) + 1;

				glassFreq = ~quantizeToScale.((freq * [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].wchoose([0.18, 0.22, 0.25, 0.18, 0.12, 0.05])) * (1.0 + ((~oceanGlassExcite ? 0) * 0.06) + ((~excGlassDrive ? 0) * 0.04)));

				Synth(\glass, [
					\freq, glassFreq.clip(160, 2200),
					\amp, glassAmp * rrand(0.12, 0.36) * glassFreq.linexp(320, 2200, 0.85, 0.16).clip(0.14, 0.85),
					\dur, rrand(0.16, 0.82),
					\revMix, reverbMix.clip(0.10, 0.36),
					\pan, rrand(-0.62, 0.62),
					\color, orbPhi.clip(0, 1)
				]);
			});

			// GHOST NOTES — probabilistic, sub-threshold events from the foundational field.
			if(~ghostNotesEnabled and: { (~psiGhostProb ? 0) > 0.25 }, {
				var ghostThreshold, ghostRoll, ghostFreq;
				ghostThreshold = 0.12 + ((~foundCoherence ? 0) * 0.35);
				ghostRoll = ((~psiGhostProb ? 0) * (1.0 - ((~foundCoherence ? 0) * 0.5))).clip(0, 1);
				if((ghostRoll > ghostThreshold) and: { ghostRoll.coin } and: { (Main.elapsedTime - (~lastGhostTrigTime ? 0)) > 1.25 }, {
					~lastGhostTrigTime = Main.elapsedTime;
					~ghostTriggerCount = (~ghostTriggerCount ? 0) + 1;
					ghostFreq = ~quantizeToScale.(freq * [0.5, 0.75, 1.0, 1.25, 1.5].wchoose([0.15, 0.25, 0.35, 0.15, 0.10]));
					Synth(\ghost_note, [
						\freq, ghostFreq.clip(100, 3000),
						\amp, (0.002 + ((~psiGhostProb ? 0) * 0.008)).clip(0, 0.010),
						\dur, rrand(0.05, 0.16),
						\detune, 0.01 + ((~foundUncertainty ? 0) * 0.04),
						\pan, rrand(-0.6, 0.6)
					]);
				});
			});

			// ECO LAYERS — emergent communications/processes, with irregular due clocks
			// and clustered micro-events so they breathe instead of stepping on a grid.
			ecoMicroBias = (
				0.16
				+ (ecoEdge * 0.22)
				+ (ecoInstability * 0.22)
				+ ((~oceanEnergy ? 0) * 0.16)
				+ ((~foundUncertainty ? 0) * 0.12)
			).clip(0.10, 0.88);

			if(ecoChirpOn, {
				var voiceGate, chirpProb;
				voiceGate = (~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 15;
				if(voiceGate and: { nowTime >= (~nextEcoChirpTime ? 0.0) }, {
					ecoCooldown = (0.34 + (1.12 * (1.0 - ecoEdge))).clip(0.24, 2.2);
					chirpProb = (ecoEdge * ecoChirpLevel * (0.86 + (ecoMicroBias * 0.58))).clip(0, 0.96);
					if(chirpProb.coin, {
						var forestCount, chirpBase, chirpColor, forestMode, phraseGap, rootDrift;
						~lastEcoChirpTime = nowTime;
						~nextEcoChirpTime = nowTime + (ecoCooldown * rrand(0.62, 2.10)) + [0.0, rrand(0.08, 0.34)].wchoose([0.58, 0.42]);
						~ecoChirpTriggerCount = (~ecoChirpTriggerCount ? 0) + 1;
						forestCount = [3, 4, 4, 5].wchoose([0.24, 0.34, 0.24, 0.18]);
						rootDrift = 1.0 + ((~oceanEnergy ? 0) * 0.10) + ((~solarWind ? 0) * 0.08) - ((~foundCoherence ? 0) * 0.05);
						chirpBase = ~quantizeToScale.(freq * rootDrift * [1.25, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0].wchoose([0.05, 0.09, 0.14, 0.18, 0.22, 0.18, 0.10, 0.04]));
						chirpColor = ecoEdge.linlin(0, 1, 0.15, 0.88);
						forestMode = (
							chirpBase.linlin(1100, 7200, 0, 4)
							+ (ecoDepth * 0.85)
							+ ((~solarWind ? 0) * 0.65)
							- ((~oceanEnergy ? 0) * 0.42)
						).round(1).clip(0, 4).asInteger;
						phraseGap = rrand(0.07, 0.38) * (1.0 + ((~foundCoherence ? 0) * 0.35));
						forestCount.do { |i|
							var speciesBase, speciesSlow, phraseCount, phraseBase, phrasePan, phraseStart;
							speciesBase = (forestMode + [0, 1, 2, 3, 4, -1, -2].wrapAt(i + (~arpStep ? 0))).clip(0, 4);
							speciesSlow = if(speciesBase >= 3, { rrand(0.55, 1.20) }, { rrand(0.0, 0.28) });
							phraseCount = if(speciesBase >= 3, {
								[1, 1, 2, 2, 3].wchoose([0.30, 0.22, 0.24, 0.16, 0.08])
							}, {
								[1, 2, 2, 3].wchoose([0.22, 0.33, 0.28, 0.17])
							});
							phraseBase = (chirpBase * [0.52, 0.62, 0.78, 1.0, 1.24, 1.48, 1.82].wrapAt(i + forestMode)).clip(720, 7600);
							phrasePan = rrand(-0.92, 0.92);
							phraseStart = rrand(0.0, 0.72 + speciesSlow) + (i * phraseGap * rrand(0.46, 1.58 + speciesSlow));
							phraseCount.do { |j|
								AppClock.sched(phraseStart + (j * rrand(0.045, 0.30 + speciesSlow)) + rrand(0.0, 0.10 + (speciesSlow * 0.06)), {
									if((~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 17, {
										Synth(\eco_chirp, [
											\freq, (phraseBase * (1.0 + (j * rrand(0.015, 0.105))) * rrand(0.965, 1.045)).clip(720, 7600),
											\amp, (0.010 + ((ecoEdge * 0.032) * ecoChirpLevel)).clip(0.007, 0.058) * (1.0 - (j * 0.12)),
											\dur, rrand(0.050, 0.28 + speciesSlow) * (1.0 + (speciesBase * 0.10)),
											\pan, (phrasePan + rrand(-0.12, 0.12)).clip(-0.95, 0.95),
											\color, (chirpColor + (i * 0.055) + (j * rrand(0.015, 0.080))).clip(0, 1),
											\species, (speciesBase + [0, 0, 1, -1].wchoose([0.72, 0.12, 0.09, 0.07])).clip(0, 4)
										]);
									});
									nil;
								});
							};
						};
					}, {
						~nextEcoChirpTime = nowTime + rrand(0.14, (ecoCooldown * 0.72).max(0.20));
					});
				});
			});

			if(ecoCallOn, {
				var voiceGate, callProb;
				voiceGate = (~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 14;
				if(voiceGate and: { nowTime >= (~nextEcoCallTime ? 0.0) }, {
					ecoCooldown = (1.55 - (ecoCoherence * 0.42) + (ecoDepth * 0.35)).clip(0.72, 4.6);
					callProb = (ecoCoherence * ecoCallLevel * (0.62 + (ecoMicroBias * 0.44))).clip(0, 0.86);
					if(callProb.coin, {
						var callRepeats, callGap, callBase, callDepth, callSpecies;
						~lastEcoCallTime = nowTime;
						~nextEcoCallTime = nowTime + (ecoCooldown * rrand(0.58, 1.95));
						~ecoCallTriggerCount = (~ecoCallTriggerCount ? 0) + 1;
						callDepth = ((ecoCoherence * 0.62) + (ecoDepth * 0.38)).clip(0, 1);
						callRepeats = [1, 1, 2, 2, 3, 3, 4].wchoose([0.15, 0.13, 0.24, 0.20, 0.15, 0.09, 0.04]);
						callGap = rrand(0.13, 0.56) + (callDepth * rrand(0.02, 0.20));
						callBase = ~quantizeToScale.(freq * [0.25, 0.35, 0.5, 0.75, 1.0].wchoose([0.09, 0.18, 0.30, 0.25, 0.18]));
						callSpecies = if(callBase < 145, { 0 }, { if(ecoInstability > rrand(0.30, 0.68), { 1 }, { 0 }) });
						callRepeats.do { |i|
							AppClock.sched((i * callGap) + rrand(0.0, 0.09), {
								if((~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 15, {
									Synth(\eco_call, [
										\freq, (callBase * [0.667, 0.75, 1.0, 1.125, 1.333].wrapAt(i + (~arpStep ? 0))).clip(45, 1400),
										\amp, (0.026 + ((ecoCoherence * 0.078) * ecoCallLevel)).clip(0.018, 0.142),
										\dur, rrand(0.50, 2.30) + (callDepth * 0.85),
										\pan, rrand(-0.55, 0.55),
										\curve, rrand(0.18, 0.85),
										\depth, callDepth,
										\species, callSpecies
									]);
								});
								nil;
							});
						};
					}, {
						~nextEcoCallTime = nowTime + rrand(0.16, (ecoCooldown * 0.65).max(0.24));
					});
				});
			});

			ecoInsectScore = (
				((~solarWind ? 0) * 0.34)
				+ ((~solarBreath ? 0) * 0.22)
				+ (ecoEdge * 0.18)
				+ ((~oceanThermal ? 0.5) * 0.14)
				+ (ecoDepth * 0.12)
			).clip(0, 1);
			if((ecoChirpOn or: { ecoGrowthOn }) and: { nowTime >= (~nextEcoInsectTime ? 0.0) }, {
				var insectCooldown, insectProb, bloomCount, bloomGap, insectBase;
				insectCooldown = (4.8 - (ecoInsectScore * 2.1) - ((~solarFlare ? 0) * 0.9)).clip(1.8, 7.4);
				insectProb = (ecoInsectScore * (0.22 + (ecoChirpLevel * 0.22) + (ecoGrowthLevel * 0.14))).clip(0, 0.62);
				if(insectProb.coin and: { (~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 14 }, {
					~lastEcoInsectTime = nowTime;
					~nextEcoInsectTime = nowTime + (insectCooldown * rrand(0.62, 1.85));
					~ecoInsectTriggerCount = (~ecoInsectTriggerCount ? 0) + 1;
					bloomCount = [1, 1, 2, 2, 3].wchoose([0.30, 0.22, 0.22, 0.16, 0.10]);
					bloomGap = rrand(0.34, 1.20);
					insectBase = (1900 + (ecoInsectScore * 3100) + rrand(-260, 580)).clip(1600, 7200);
					bloomCount.do { |i|
						AppClock.sched((i * bloomGap) + rrand(0.0, 0.18), {
							if((~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 15, {
								Synth(\eco_insect_bloom, [
									\freq, (insectBase * [0.82, 1.0, 1.18, 1.41].wrapAt(i)).clip(1600, 7800),
									\amp, (0.007 + (ecoInsectScore * 0.024) + ((~solarFlare ? 0) * 0.014)).clip(0.006, 0.046) * (1.0 - (i * 0.16)),
									\dur, rrand(1.8, 6.8) * (0.82 + (ecoInsectScore * 0.42)),
									\pan, rrand(-0.82, 0.82),
									\solarDrive, ((~solarWind ? 0) + (~solarBreath ? 0)).clip(0, 1),
									\density, (ecoInsectScore + rrand(-0.10, 0.18)).clip(0, 1),
									\color, rrand(0.20, 0.92)
								]);
							});
							nil;
						});
					};
				}, {
					~nextEcoInsectTime = nowTime + rrand(0.45, (insectCooldown * 0.68).max(0.70));
				});
			});

			if(ecoGrowthOn, {
				var voiceGate, growthProb;
				voiceGate = (~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 14;
				if(voiceGate and: { nowTime >= (~nextEcoGrowthTime ? 0.0) }, {
					ecoCooldown = (1.85 - (imprintBlend * 0.88) - (ecoCoherence * 0.44)).clip(0.74, 4.6);
					growthProb = (ecoDepth * ecoGrowthLevel * (0.66 + (ecoMicroBias * 0.44))).clip(0, 0.88);
					if(growthProb.coin, {
						var growthFreq, gelFrac, oceanDrv, solarDrv, fieldRatio, growthRepeats, growthGap;
						~lastEcoGrowthTime = nowTime;
						~nextEcoGrowthTime = nowTime + (ecoCooldown * rrand(0.62, 2.20));
						~ecoGrowthTriggerCount = (~ecoGrowthTriggerCount ? 0) + 1;
						fieldRatio = ~fsAlphaNow ? 2.0;
						gelFrac = ((fieldRatio.linlin(1.1, 4.5, 0.05, 0.90) * 0.50) + ((~oceanEnergy ? 0) * 0.30) + ((1.0 - (~solarWind ? 0)) * 0.20)).clip(0, 1);
						oceanDrv = (~oceanEnergy ? 0.3).clip(0, 1);
						solarDrv = (~solarWind ? 0.2).clip(0, 1);
						growthFreq = ~quantizeToScale.(freq * [0.25, 0.333, 0.375, 0.5, 0.75].wchoose([0.16, 0.16, 0.26, 0.26, 0.16]));
						growthRepeats = [1, 1, 1, 2].wchoose([0.44, 0.28, 0.18, 0.10]);
						growthGap = rrand(0.22, 0.86);
						growthRepeats.do { |i|
							AppClock.sched((i * growthGap) + rrand(0.0, 0.11), {
								if((~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 14, {
									Synth(\eco_growth, [
										\freq, (growthFreq * [0.75, 1.0, 1.25].wrapAt(i)).clip(55, 680),
										\amp, (0.034 + ((ecoDepth * 0.110) * ecoGrowthLevel) + (((~oceanEnergy ? 0) * 0.035) * ecoGrowthLevel)).clip(0.022, 0.190) * (1.0 - (i * 0.18)),
										\dur, rrand(1.70, 6.40),
										\pan, rrand(-0.42, 0.42),
										\gelFrac, (gelFrac + rrand(-0.12, 0.12)).clip(0, 1),
										\oceanDrive, oceanDrv,
										\solarDrive, solarDrv
									]);
								});
								nil;
							});
						};
					}, {
						~nextEcoGrowthTime = nowTime + rrand(0.22, (ecoCooldown * 0.62).max(0.36));
					});
				});
			});

			if(ecoFissureOn, {
				var voiceLoad, scSaturation, minCooldown, voiceGate, fissureProb;
				voiceLoad = ~estimatedVoiceLoad.() + (~arpBurstInflight ? 0);
				scSaturation = (voiceLoad / 10.0).clip(0, 1);
				minCooldown = if(scSaturation > 0.5) { 1.0 } { 0.38 };
				voiceGate = voiceLoad < 15;
				if(voiceGate and: { nowTime >= (~nextEcoFissureTime ? 0.0) }, {
					ecoCooldown = (1.75 - (ecoInstability * 0.48)).clip(minCooldown * 1.15, 3.9);
					fissureProb = (ecoInstability * ecoFissureLevel * (0.45 + (ecoMicroBias * 0.30))).clip(0, 0.62);
					if(fissureProb.coin, {
						var fissFreq, crackChar, fracDepth, branchCount, branchGap, branchSpan, materialTone, branchDelay;
						~lastEcoFissureTime = nowTime;
						~nextEcoFissureTime = nowTime + (ecoCooldown * rrand(1.20, 2.80));
						~ecoFissureTriggerCount = (~ecoFissureTriggerCount ? 0) + 1;
						fissFreq = ~quantizeToScale.(freq * [0.5, 0.75, 1.0, 1.414, 2.0, 2.828].wchoose([0.08, 0.15, 0.22, 0.25, 0.20, 0.10]));
						crackChar = ((ecoInstability * 0.65) + ((1.0 - ecoCoherence) * 0.35)).clip(0, 1);
						fracDepth = (~metricLyapunov ? 0.5).linlin(0, 2, 1, 5).round(1).clip(1, 5).asInteger;
						branchCount = (6 + (fracDepth * 3) + (ecoInstability * 7) + ((~oceanEnergy ? 0) * 4)).round(1).clip(6, 24).asInteger;
						branchGap = rrand(0.055, 0.18) * (1.25 - (ecoInstability * 0.35));
						branchSpan = rrand(1.8, 5.8) * (1.0 + ((~oceanEnergy ? 0) * 0.45));
						materialTone = (((~oceanEnergy ? 0) * 0.30) + ((~solarWind ? 0) * 0.22) + (ecoCoherence * 0.20) + (crackChar * 0.28)).clip(0, 1);
						branchDelay = 0.0;
						branchCount.do { |i|
							var branchNorm, branchAmp, branchFreq, branchDur, branchPan, branchFan;
							branchNorm = (i / max(1, branchCount - 1)).clip(0, 1);
							branchDelay = (branchDelay + (branchGap * rrand(0.42, 1.85)) + (branchNorm * branchSpan * rrand(0.006, 0.035))).clip(0, branchSpan);
							branchAmp = (0.018 + ((ecoInstability * 0.070) * ecoFissureLevel)).clip(0.010, 0.118) * (1.0 - (branchNorm * 0.78)) * rrand(0.72, 1.12);
							branchFan = [-2, -1, -1, 0, 0, 1, 1, 2].wrapAt(i + (~arpStep ? 0));
							branchFreq = (fissFreq * (1.0 + (branchFan * (0.12 + (crackChar * 0.10)))) * (1.0 + (branchNorm * rrand(0.15, 1.35)))).clip(120, 6200);
							branchDur = rrand(0.08, 0.58) * (1.25 - (branchNorm * 0.52));
							branchPan = (rrand(-0.74, 0.74) + (branchFan * 0.055)).clip(-0.95, 0.95);
							AppClock.sched(branchDelay + rrand(0.0, 0.055), {
								if((~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 16, {
									Synth(\eco_fissure, [
										\freq, branchFreq,
										\amp, branchAmp,
										\dur, branchDur,
										\pan, branchPan,
										\crack, (crackChar + rrand(-0.08, 0.16) + (branchNorm * 0.10)).clip(0, 1),
										\fractalDepth, (fracDepth + [0, 0, 1, -1].wchoose([0.56, 0.18, 0.18, 0.08])).clip(1, 5).asInteger,
										\material, (materialTone + rrand(-0.14, 0.14)).clip(0, 1)
									]);
								});
								nil;
							});
						};
					}, {
						~nextEcoFissureTime = nowTime + rrand(0.22, (ecoCooldown * 0.82).max(0.34));
					});
				});
			});

			ecoThunderScore = (
				(ecoInstability * 0.38)
				+ ((~oceanAccel ? 0) * 0.22)
				+ ((~oceanEnergy ? 0) * 0.18)
				+ ((~foundUncertainty ? 0) * 0.14)
				+ (ecoDepth * 0.08)
			).clip(0, 1);
			if(ecoFissureOn and: { nowTime >= (~nextEcoThunderTime ? 0.0) }, {
				var thunderCooldown, thunderProb, thunderCrack;
				thunderCooldown = (5.8 - (ecoThunderScore * 2.4)).clip(2.2, 8.8);
				thunderProb = (ecoThunderScore * ecoFissureLevel * (0.30 + (ecoMicroBias * 0.30))).clip(0, 0.58);
				if(thunderProb.coin and: { (~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)) < 14 }, {
					~lastEcoThunderTime = nowTime;
					~nextEcoThunderTime = nowTime + (thunderCooldown * rrand(0.72, 2.10));
					~ecoThunderTriggerCount = (~ecoThunderTriggerCount ? 0) + 1;
					thunderCrack = ((ecoInstability * 0.68) + ((~oceanAccel ? 0) * 0.32)).clip(0, 1);
					Synth(\eco_thunder, [
						\freq, rrand(34, 72),
						\amp, (0.024 + (ecoThunderScore * 0.058) + ((~oceanEnergy ? 0) * 0.020)).clip(0.020, 0.095),
						\dur, rrand(3.2, 7.6),
						\pan, rrand(-0.48, 0.48),
						\crack, thunderCrack,
						\oceanDrive, (~oceanEnergy ? 0.3).clip(0, 1),
						\solarDrive, (~solarWind ? 0.2).clip(0, 1)
					]);
				}, {
					~nextEcoThunderTime = nowTime + rrand(0.55, (thunderCooldown * 0.72).max(0.80));
				});
			});

			// CHOIR
			choirAllowed = (
				droneOn
				and: { polyBusy.not }
				and: { ~droneSynth.notNil }
				and: { ~droneSynth.isPlaying }
				and: { ~droneGain.() > 0.001 }
				and: { ~choirGain.() > 0.001 }
				and: { avgBright > 0.12 }
			);

			if(choirAllowed, {
				choirFreq = ~quantizeToScale.(freq * [0.25, 0.333, 0.5].wchoose([0.32, 0.40, 0.28])).clip(92, 440);
				now = Main.elapsedTime;
				freqChanged = (choirFreq - (~choirLastFreq ? choirFreq)).abs > (choirFreq * 0.16);
				safeChoirAmp = (choirAmp * 0.48 * choirFreq.linexp(120, 440, 1.0, 0.62).clip(0.58, 1.0)).clip(0, 0.046);

				if(~choirGroup.isNil, { ~choirGroup = Group.tail(s); });

				if(~choirSynth.isNil or: { ~choirSynth.isPlaying.not }, {
					if((now - (~choirLastSpawnTime ? 0)) >= (~choirMinRespawn ? 12.0), {
						~choirGroup.freeAll;
						~choirSynth = Synth.tail(~choirGroup, \choir, [
							\gate, 1,
							\freq, choirFreq,
							\amp, safeChoirAmp,
							\revMix, reverbMix.clip(0.04, 0.18)
						]);
						~choirLastFreq = choirFreq;
						~choirLastSpawnTime = now;
						~choirLastUpdateTime = now;
					});
				}, {
					if((now - (~choirLastUpdateTime ? 0)) >= (~choirMinUpdateGap ? 0.35), {
						~choirSynth.set(\amp, safeChoirAmp, \revMix, reverbMix.clip(0.04, 0.18));
						if(freqChanged, {
							~choirSynth.set(\freq, choirFreq);
							~choirLastFreq = choirFreq;
						});
						~choirLastUpdateTime = now;
					});
				});
			}, {
				if(~choirSynth.notNil and: { ~choirSynth.isPlaying }, {
					~choirSynth.set(\amp, 0, \gate, 0);
					~choirSynth = nil;
					~choirLastSpawnTime = Main.elapsedTime;
				});
				if(~choirGroup.notNil, { ~choirGroup.freeAll; });
			});

			if(~processingDiagAddr.notNil and: { (Main.elapsedTime - (~lastAudioDiagSend ? 0)) > 0.35 }, {
				~lastAudioDiagSend = Main.elapsedTime;
				~processingDiagAddr.sendMsg(
					"/rdf/audioDiag",
					~psiGhostProb ? 0,
					~ghostTriggerCount ? 0,
					if((~ghostTriggerCount ? 0) > 0, { Main.elapsedTime - (~lastGhostTrigTime ? Main.elapsedTime) }, { -1 }),
					~nextGlassAllowedTime ? 0,
					~actualGlassTriggerCount ? 0,
					~fsG ? 0,
					~ecoChirpTriggerCount ? 0,
					if((~ecoChirpTriggerCount ? 0) > 0, { Main.elapsedTime - (~lastEcoChirpTime ? Main.elapsedTime) }, { -1 }),
					~ecoCallTriggerCount ? 0,
					if((~ecoCallTriggerCount ? 0) > 0, { Main.elapsedTime - (~lastEcoCallTime ? Main.elapsedTime) }, { -1 }),
					~ecoGrowthTriggerCount ? 0,
					if((~ecoGrowthTriggerCount ? 0) > 0, { Main.elapsedTime - (~lastEcoGrowthTime ? Main.elapsedTime) }, { -1 }),
					~ecoFissureTriggerCount ? 0,
					if((~ecoFissureTriggerCount ? 0) > 0, { Main.elapsedTime - (~lastEcoFissureTime ? Main.elapsedTime) }, { -1 }),
					~rootFreq ? 55,
					~droneVolume ? 0,
					~arpVolume ? 0,
					~glassVolume ? 0,
					~choirVolume ? 0,
					~dynamicBPM ? 120,
					~rhythmComplexity ? 0
				);
			});

			// MODE-BASED TRANSFORMATIONS
			modeEffect  = "QUANT/EXT";
			modIntensity = ~safeFloat.(~rhythmComplexity, 0.5).clip(0, 1);
			switch(modSource,
				0, {
					modeEffect   = "BRIGHTNESS";
					modIntensity = avgBright.linlin(0.0, 1.0, 0.0, 1.0).clip(0, 1).squared;
					if(~mainSynth.notNil, {
						~mainSynth.set(
							\amp,       modIntensity.linlin(0, 1, 0.05, 0.45),
							\cutoff,    modIntensity.linexp(0.001, 1, 300, 8000),
							\resonance, modIntensity.linlin(0, 1, 0.15, 0.75),
							\reverbMix, modIntensity.linlin(0, 1, 0.05, 0.25)
						);
					});
				},
				1, {
					modeEffect   = "DENSITY";
					modIntensity = finestVal.linlin(0.0, 1.0, 0.0, 1.0).clip(0, 1);
					if(~mainSynth.notNil, {
						~mainSynth.set(
							\amp,       0.25,
							\cutoff,    modIntensity.linexp(0.001, 1, 150, 2500),
							\resonance, modIntensity.linlin(0, 1, 0.85, 0.2),
							\lfoRate,   modIntensity.linexp(0.001, 1, 0.2, 12),
							\lfoDepth,  modIntensity.linlin(0, 1, 0.05, 0.8)
						);
					});
				},
				2, {
					modeEffect   = "SWEEP";
					modIntensity = alphaVal.linlin(1.1, 4.5, 0, 1).clip(0, 1);
					if(~mainSynth.notNil, {
						~mainSynth.set(
							\freq,      modIntensity.linexp(0.001, 1, 80, 1200),
							\cutoff,    modIntensity.linexp(0.001, 1, 200, 10000),
							\lfoRate,   3,
							\lfoDepth,  modIntensity.linlin(0, 1, 0.2, 1.0),
							\reverbMix, 0.15
						);
					});
				},
				3, {
					modeEffect   = "ORBIT";
					modIntensity = orbPhi.linlin(0.1, 2.0, 0, 1).clip(0, 1).sqrt;
					if(~mainSynth.notNil, {
						~mainSynth.set(
							\amp,       0.18,
							\freq,      modIntensity.linexp(0.001, 1, 110, 660),
							\cutoff,    modIntensity.linexp(0.001, 1, 500, 5000),
							\lfoRate,   modIntensity.linexp(0.001, 1, 0.05, 2.0),
							\lfoDepth,  modIntensity.linlin(0, 1, 0.4, 1.0),
							\reverbMix, modIntensity.linlin(0, 1, 0.35, 0.85)
						);
					});
				}
			);

			if(modSource != ~lastModSource, {
				(">>> MODE: " + (modeEffect ? "UNKNOWN") + " intensity:" + ~safeRound.(modIntensity, 0.1, 0)).postln;
				~lastModSource = modSource;
			});
		});
	}, "/rdf/mix", nil, ~oscPort);

	// ========== QUANTITATIVE MODE RECEIVER ==========
	OSCdef(\rdfModeReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		if(msg.size >= 20, {
			~quantMode = ~msgInt.(msg, 1, 0).clip(0, 10);
			~quantModeName = msg[2].asString;
			~metricEntropy = ~msgFloat.(msg, 5, 0).clip(0, 8);
			~metricFractalDim = ~msgFloat.(msg, 6, 1).clip(0, 4);
			~metricLyapunov = ~msgFloat.(msg, 7, 0).clip(-4, 4);
			~metricKLDivergence = ~msgFloat.(msg, 8, 0).clip(0, 4);
			~metricMutualInfo = ~msgFloat.(msg, 9, 0).clip(0, 4);
			~metricAdiabaticParam = ~msgFloat.(msg, 14, 0).clip(0, 20);
			~metricBerryPhase = ~msgFloat.(msg, 15, 0).clip(-100, 100);
			~metricCorrelationTau = ~msgFloat.(msg, 16, 0).clip(0, 1000);
			~floquetCoupling = ~msgFloat.(msg, 18, 0).clip(0, 1);
			~floquetQuasienergy = ~msgFloat.(msg, 19, 0).clip(0, 10);

			switch(~quantMode,
				4, { ~rhythmComplexity = (~metricEntropy / 3.0).clip(0.0, 1.0); },
				5, { ~rhythmComplexity = ((~metricFractalDim - 1.0) / 1.5).clip(0.0, 1.0); },
				6, { ~rhythmSwing = (~metricLyapunov / 2.0).clip(0.0, 0.35); },
				7, { ~rhythmComplexity = (~metricKLDivergence * 1.2).clip(0.0, 1.0); },
				8, { ~orbSensitivity = (0.5 + ~metricMutualInfo).clip(0.5, 2.5); },
				9, { ~rootFreq = ~msgFloat.(msg, 12, ~rootFreq).clip(20, 880); },
				10, {
					~rhythmComplexity = (~foundUncertainty * 0.55 + ~foundPlanckGate * 0.25 + ~foundCurlB * 0.20).clip(0.0, 1.0);
					~orbSensitivity = (0.75 + (~foundCurlB * 0.75) + (~foundCoherence * 0.45)).clip(0.5, 2.75);
				}
			);

			if(~loggingEnabled and: { ~audioLogFile.notNil and: { ~audioLogFile.isOpen } }, {
				var scaleName = if(~scaleNames.notNil, { ~scaleNames.wrapAt(~currentScaleIndex ? 0) }, { "unknown" });
				var timestamp = Main.elapsedTime;
				var line = "%,%,%,%,%,%,%,%,%,%,%,%,%,%,%,%,%,%,%,%,%,%\n".format(
					timestamp, ~audioLogBar, 0,
					~rootFreq ? 0, ~droneVolume ? 0,
					~rootFreq ? 0, ~arpVolume ? 0,
					~rootFreq ? 0, ~glassVolume ? 0,
					~rootFreq ? 0, ~choirVolume ? 0,
					0, 0, 0, 0, 0,
					~dynamicBPM ? 120, ~rhythmSwing ? 0, ~rhythmComplexity ? 0,
					~metricKLDivergence ? 0, ~rhythmComplexity ? 0, scaleName
				);
				~audioLogFile.write(line);
				~audioLogFile.flush;
				~audioLogBar = ~audioLogBar + 1;
			});
		});
	}, '/rdf/mode');

	// ── /rdf/foundational ─────────────────────────────────────────────────────
	OSCdef(\rdfFoundationalReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		if(msg.size >= 8, {
			~foundDivE       = ~msgFloat.(msg, 1, 0).clip(0, 1);
			~foundCurlB      = ~msgFloat.(msg, 2, 0).clip(0, 1);
			~foundPsiDensity = ~msgFloat.(msg, 3, 0).clip(0, 1);
			~foundUncertainty = ~msgFloat.(msg, 4, 0).clip(0, 1);
			~foundPlanckGate = ~msgFloat.(msg, 5, 0).clip(0, 1);
			~foundCoherence  = ~msgFloat.(msg, 6, 0).clip(0, 1);
			~foundCoupling   = ~msgFloat.(msg, 7, 0).clip(0, 1);
			~rhythmComplexity = (~rhythmComplexity * 0.92 + (~foundUncertainty * 0.45 + ~foundPlanckGate * 0.25) * 0.08).clip(0, 1);
			~rhythmSwing = (~rhythmSwing * 0.96 + (~foundCurlB * 0.12) * 0.04).clip(0, 0.35);
		});
	}, '/rdf/foundational');

	// /rdf/watchdog enables the heavy heartbeat recovery path; default is OFF.
	OSCdef(\watchdogReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		~watchdogEnabled = (~msgFloat.(msg, 1, 0).clip(0, 1) > 0.5);
		if(~watchdogEnabled, {
			("SC watchdog heavy recovery ENABLED timeout="
				++ ((~watchdogHeartbeatTimeout ? 45).asString) ++ "s refractory="
				++ ((~watchdogRefractory ? 60).asString) ++ "s").postln;
		}, {
			"SC watchdog heavy recovery DISABLED".postln;
		});
	}, "/rdf/watchdog", nil, ~oscPort);

	OSCdef(\midiPolyReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		if(msg.size >= 9, {
			var note, freq, vel, on, polyVol, polyGain, mem, pressure, density, synth, pan, oldKey, restraintPressure, oceanDrive, solarDrive, tone;
			var egArp, egDepth, egGateScore, egPhase;
			note = ~msgInt.(msg, 1, 0).clip(0, 127);
			freq = ~msgFloat.(msg, 2, 220).clip(20, 5000);
			vel = ~msgFloat.(msg, 3, 0.7).clip(0, 1);
			on = ~msgFloat.(msg, 4, 0) > 0.5;
			polyVol = ~msgFloat.(msg, 5, ~midiPolyVolume ? 0.55).clip(0, 1);
			mem = ~msgFloat.(msg, 6, ~midiPolyMemory ? 0).clip(0, 0.08);
			pressure = ~msgFloat.(msg, 7, ~midiPolyReleasePressure ? 0).clip(0, 1);
			density = ~msgFloat.(msg, 8, ~midiPolyDensity ? 0).clip(0, 0.35);
			tone = ~msgFloat.(msg, 9, ~midiPolyTone ? 0.45).clip(0, 1);
			if(on, { ~suppressSharedKeyStab.(); });
			~midiPolyVolume = polyVol;
			polyGain = ~voiceGain.(polyVol, 0.18, 0.82);
			~midiPolyMemory = mem;
			~midiPolyDensity = density;
			~midiPolyTone = tone;
			restraintPressure = (pressure.max(~foundPlanckGate ? 0) + ((~fsCouplingEnv ? 0) * 0.35)).clip(0, 1);
			oceanDrive = (((~oceanArpDrive ? 0) * 0.35) + ((~oceanGlassDrive ? 0) * 0.20) + ((~oceanPersistence ? 0) * 0.25) + ((~oceanDepthBias ? 0) * 0.20)).clip(0, 1);
			solarDrive = ((((~solarXray ? 0) + (~solarKp ? 0) + (~solarWind ? 0)) / 3.0) * (~solarVolume ? 0.25).linlin(0, 1, 0.35, 1.0)).clip(0, 1);
			egDepth = (~egProbeDepth ? 0).clip(0, 1);
			egGateScore = (~egProbeGateScore ? 0).clip(0, 1);
			egArp = if((~egProbeEnabled ? false), { 1.0 }, { 0.0 });

			if(on, {
				if((~midiPolyVoices.size >= (~midiPolyMaxVoices ? 8)) and: { ~midiPolyVoices.at(note).isNil }, {
					oldKey = ~midiPolyVoices.keys.asArray.sort.first;
					if(oldKey.notNil, {
						synth = ~midiPolyVoices.at(oldKey);
						if(synth.notNil, { synth.set(\gate, 0, \pressure, 1.0); });
						~midiPolyVoices.removeAt(oldKey);
					});
				});
				synth = ~midiPolyVoices.at(note);
				pan = ((note % 12) / 11.0).linlin(0, 1, -0.42, 0.42);
				egPhase = (note % 8) / 8.0;
				if(synth.notNil and: { synth.isPlaying }, {
					synth.set(\freq, freq, \vel, vel, \polyVol, polyGain, \memory, mem, \pressure, restraintPressure, \density, density, \tone, tone, \oceanDrive, oceanDrive, \solarDrive, solarDrive, \pan, pan, \egArp, egArp, \egDepth, egDepth, \egGateScore, egGateScore, \egArpPhase, egPhase);
					}, {
						synth = Synth(\midi_poly_voice, [
						\freq, freq,
						\vel, vel,
						\polyVol, polyGain,
						\memory, mem,
						\pressure, restraintPressure,
						\density, density,
						\tone, tone,
						\oceanDrive, oceanDrive,
						\solarDrive, solarDrive,
						\pan, pan,
						\egArp, egArp,
						\egDepth, egDepth,
						\egGateScore, egGateScore,
						\egArpPhase, egPhase
						]);
						synth.register;
						~midiPolyVoices.put(note, synth);
					});
			}, {
				synth = ~midiPolyVoices.at(note);
				if(synth.notNil, {
					synth.set(\gate, 0, \pressure, restraintPressure);
					~midiPolyVoices.removeAt(note);
				});
			});
		});
	}, "/rdf/midiPoly", nil, ~oscPort);

	~suppressSharedKeyStab = {
		var now;
		now = Main.elapsedTime;
		~midiPolyMemory = 0.0;
		~midiPolyDensity = 0.0;
		~midiPolyChordSpread = 0.0;
		~nextGlassAllowedTime = now + 1.25;
		~lastGlassTrigTime = now;
		~fsManualMuteUntil = now + 4.0;
		~fsGateOpen = false;
		~cancelFloquetDissolution.();
		if(~droneSynth.notNil and: { ~droneSynth.isPlaying }, {
			~droneSynth.set(\gate, 0, \amp, 0);
			~droneSynth = nil;
		});
		~droneManualArmed = false;
		~currentDroneOn = false;
		if(~floquetDroneSynth.notNil and: { ~floquetDroneSynth.isPlaying }, {
			~floquetDroneSynth.set(\gate, 0, \amp, 0);
			~floquetDroneSynth = nil;
		});
		if(~choirSynth.notNil and: { ~choirSynth.isPlaying }, {
			~choirSynth.set(\gate, 0, \amp, 0);
			~choirSynth = nil;
		});
		if(~choirGroup.notNil, { ~choirGroup.freeAll; });
	};

	OSCdef(\polyKeyIsolationReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		~suppressSharedKeyStab.();
	}, "/rdf/polyKeyIsolation", nil, ~oscPort);

	OSCdef(\midiPolyStateReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		if(msg.size >= 8, {
			var modeOn, pressure, mem, density, polyVol, polyGain, spread, held, restraintPressure, oceanDrive, solarDrive, tone;
			var egArp, egDepth, egGateScore;
			modeOn = ~msgFloat.(msg, 1, 0) > 0.5;
			held = ~msgFloat.(msg, 2, 0).clip(0, 16);
			polyVol = ~msgFloat.(msg, 3, ~midiPolyVolume ? 0.55).clip(0, 1);
			mem = ~msgFloat.(msg, 4, ~midiPolyMemory ? 0).clip(0, 0.08);
			pressure = ~msgFloat.(msg, 5, ~midiPolyReleasePressure ? 0).clip(0, 1);
			density = ~msgFloat.(msg, 6, ~midiPolyDensity ? 0).clip(0, 0.35);
			spread = ~msgFloat.(msg, 7, ~midiPolyChordSpread ? 0).clip(0, 0.25);
			tone = ~msgFloat.(msg, 8, ~midiPolyTone ? 0.45).clip(0, 1);
			~midiPolyVolume = polyVol;
			polyGain = ~voiceGain.(polyVol, 0.18, 0.82);
			~midiPolyMemory = mem;
			~midiPolyReleasePressure = pressure;
			~midiPolyDensity = density;
			~midiPolyChordSpread = spread;
			~midiPolyTone = tone;
			restraintPressure = (pressure.max(~foundPlanckGate ? 0) + ((~fsCouplingEnv ? 0) * 0.35)).clip(0, 1);
			oceanDrive = (((~oceanArpDrive ? 0) * 0.35) + ((~oceanGlassDrive ? 0) * 0.20) + ((~oceanPersistence ? 0) * 0.25) + ((~oceanDepthBias ? 0) * 0.20)).clip(0, 1);
			solarDrive = ((((~solarXray ? 0) + (~solarKp ? 0) + (~solarWind ? 0)) / 3.0) * (~solarVolume ? 0.25).linlin(0, 1, 0.35, 1.0)).clip(0, 1);
			egDepth = (~egProbeDepth ? 0).clip(0, 1);
			egGateScore = (~egProbeGateScore ? 0).clip(0, 1);
			egArp = if((~egProbeEnabled ? false), { 1.0 }, { 0.0 });
			~midiPolyVoices.keysValuesDo { |note, synth|
				if(synth.notNil and: { synth.isPlaying }, {
					synth.set(\polyVol, polyGain, \memory, mem, \pressure, restraintPressure, \density, density, \tone, tone, \oceanDrive, oceanDrive, \solarDrive, solarDrive, \egArp, egArp, \egDepth, egDepth, \egGateScore, egGateScore, \egArpPhase, (note % 8) / 8.0);
				});
			};
			if(modeOn.not or: { held <= 0 }, {
				~midiPolyVoices.keysValuesDo { |note, synth|
					if(synth.notNil, { synth.set(\gate, 0, \pressure, 1.0); });
				};
				~midiPolyVoices.clear;
			});
		});
		}, "/rdf/midiPolyState", nil, ~oscPort);

	OSCdef(\egProbeReceiver, { |msg|
		~lastOSCHeartbeat = Process.elapsedTime;
		if(msg.size >= 9, {
			var enabled, active, depth, gateScore, egFactor, arpDepth, arpOn;
			enabled = ~msgFloat.(msg, 1, 0) > 0.5;
			active = ~msgFloat.(msg, 2, 0) > 0.5;
			depth = ~msgFloat.(msg, 3, 0).clip(0, 1);
			gateScore = ~msgFloat.(msg, 4, 0).clip(0, 1);
			egFactor = ~msgFloat.(msg, 7, 1).clip(0, 1.2);
			arpDepth = if(enabled, { depth.max(0.25 + (gateScore * 0.25)).clip(0, 1) }, { 0.0 });
			arpOn = if(enabled, { 1.0 }, { 0.0 });
			~egProbeEnabled = enabled;
			~egProbeActive = active;
			~egProbeDepth = arpDepth;
			~egProbeGateScore = gateScore;
			~egProbeFactor = egFactor;
			~midiPolyVoices.keysValuesDo { |note, synth|
				if(synth.notNil and: { synth.isPlaying }, {
					synth.set(\egArp, arpOn, \egDepth, arpDepth, \egGateScore, gateScore, \egArpPhase, (note % 8) / 8.0);
				});
			};
		});
	}, "/rdf/egProbe", nil, ~oscPort);

	OSCdef(\galaxyReceiver, { |msg|
    var curvature, flqCouple, thermalEx, boundaryP, blend;
    curvature  = ~msgFloat.(msg, 1, 0.5).clip(0, 1);
    flqCouple  = ~msgFloat.(msg, 2, 0.35).clip(0, 1);
    thermalEx  = ~msgFloat.(msg, 3, 0.42).clip(0, 1);
    boundaryP  = ~msgFloat.(msg, 4, 0.81).clip(0, 1);
    blend      = ~msgFloat.(msg, 5, 0.35).clip(0, 1);

    // Only apply when blend is meaningful
    if(blend > 0.02, {
        // Field curvature steers Floquet drive strength
        if(~floquetDroneSynth.notNil and: { ~floquetDroneSynth.isPlaying }, {
            ~floquetDroneSynth.set(\strength, curvature.linlin(0, 1, 0.04, 0.22));
        });

        // Galaxy excitation keeps the field voices alive without using the retired MLX bus.
        ~excArpDrive = max(~excArpDrive ? 0, thermalEx * blend * 0.6);
        ~excGlassDrive = max(~excGlassDrive ? 0, thermalEx * boundaryP * blend * 0.35);

        // Boundary persistence reduces glass cooldown — longer tails
        ~glassCooldown = (0.48 * (1.0 - (boundaryP * blend * 0.35))).clip(0.22, 0.50);

        // Floquet coupling nudges the drone warmth
        if(~floquetDroneSynth.notNil and: { ~floquetDroneSynth.isPlaying }, {
            ~floquetDroneSynth.set(\warmth, flqCouple.linlin(0, 1, 0.35, 0.85));
        });
    });
}, "/rdf/galaxy", nil, ~oscPort);

	~stopAudioLogging = {
		~loggingEnabled = false;
		if(~audioLogFile.notNil and: { ~audioLogFile.isOpen }, { ~audioLogFile.flush; ~audioLogFile.close; });
		"Audio logging stopped.".postln;
	};

	// ── /rdf/breakdown ────────────────────────────────────────────────────────
	OSCdef(\rdfBreakdownReceiver, { |msg|
		var adiabaticParam = ~msgFloat.(msg, 1, 0).clip(0, 10);
		var entropy = ~msgFloat.(msg, 2, 0).clip(0, 8);
		var kl = ~msgFloat.(msg, 3, 0).clip(0, 8);
		var count = ~msgInt.(msg, 4, 0);
		("ADIABATIC BREAKDOWN EVENT #" ++ count ++ "  A=" ++ ~safeRound.(adiabaticParam, 0.001, 0) ++ "  entropy=" ++ ~safeRound.(entropy, 0.001, 0) ++ "  KL=" ++ ~safeRound.(kl, 0.001, 0)).postln;
		SynthDef(\rd_breakdown_ping, { |out=0, freq=720, amp=0.16, decay=0.35|
			var env = EnvGen.kr(Env.perc(0.005, decay), doneAction:2);
			var sig = SinOsc.ar(freq * [1, 1.007], 0, amp) + BPF.ar(WhiteNoise.ar(amp * 0.45), freq * 1.7, 0.2);
			sig = sig * env;
			Out.ar(out, sig);
		}).add;
		AppClock.sched(0.05, {
			Synth(\rd_breakdown_ping, [\freq, 520 + (adiabaticParam * 90) + (kl * 25), \amp, (0.08 + entropy * 0.02).clip(0.05, 0.22), \decay, 0.18 + kl.clip(0, 2) * 0.15]);
			nil;
		});
	}, '/rdf/breakdown');

	// ── /rdf/solar ────────────────────────────────────────────────────────────
	OSCdef(\solarReceiver, { |msg|
		var enabled, vol, xray, wind, bz, kp, flare;
		~lastOSCHeartbeat = Process.elapsedTime;
		enabled = ~msgFloat.(msg, 1, 0) > 0.5;
		vol   = ~msgFloat.(msg, 2, 0).clip(0, 1);
		xray  = ~msgFloat.(msg, 3, 0).clip(0, 1);
		wind  = ~msgFloat.(msg, 4, 0).clip(0, 1);
		bz    = ~msgFloat.(msg, 5, 0.5).clip(0, 1);
		kp    = ~msgFloat.(msg, 6, 0).clip(0, 1);
		flare = ~msgFloat.(msg, 7, 0).clip(0, 1);
		~solarEnabled = enabled;
		~solarVolume  = vol;
		~solarXray    = xray;
		~solarWind    = wind;
		~solarBz      = bz;
		~solarKp      = kp;
		~solarFlare   = flare;
		if(enabled, {
			~solarBreath = ((~solarBreath ? 0) * 0.94) + ((vol * (0.15 + (xray * 0.35) + (kp * 0.35) + (wind * 0.15))).clip(0, 0.85) * 0.06);
			~solarPhaseRate = ((~solarPhaseRate ? 0.08) * 0.96) + ((0.035 + (wind * 0.12) + (kp * 0.18)).clip(0.025, 0.35) * 0.04);
		}, {
			~solarBreath = ((~solarBreath ? 0) * 0.95);
			~solarPhaseRate = ((~solarPhaseRate ? 0.08) * 0.98) + (0.08 * 0.02);
		});
		if(~solarSynth.notNil and: { ~solarSynth.isPlaying }, {
			~solarSynth.set(\gate, 0);
			~solarSynth = nil;
		});
	}, "/rdf/solar", nil, ~oscPort);

	// ── /rdf/orbitEvent ───────────────────────────────────────────────────────
	OSCdef(\orbitEventReceiver, { |msg|
		var event, lock, lobes, ecc, peri, resonance, speed, radius, mode, amp, freq, now;
		~lastOSCHeartbeat = Process.elapsedTime;
		event     = if(msg.at(1).isNil, { "ORBIT_STABLE_DRIFT" }, { msg.at(1).asString });
		lock      = ~msgFloat.(msg, 2, 0).clip(0, 1);
		lobes     = ~msgInt.(msg, 3, 1).clip(1, 6);
		ecc       = ~msgFloat.(msg, 4, 0).clip(0, 1);
		peri      = ~msgFloat.(msg, 5, 0).clip(0, 1);
		resonance = ~msgFloat.(msg, 6, 0).clip(0, 1);
		speed     = ~msgFloat.(msg, 7, 0).clip(0, 5);
		radius    = ~msgFloat.(msg, 8, 1).clip(0.02, 5);
		now       = Process.elapsedTime;
		~lastOrbitEvent    = event;
		~orbitLockStrength = lock;
		~orbitLobes        = lobes;
		~orbitEccentricity = ecc;
		~orbitPeriapsis    = peri;
		~orbitResonance    = resonance;
		~orbitEventEnergy  = (lock * 0.25 + ecc * 0.2 + peri * 0.35 + resonance * 0.35).clip(0, 1);
		if((peri > 0.70) or: { resonance > 0.45 } or: { lock > 0.70 }, {
			if((~lastOrbitMarkerTime ? 0) + 3.0 < now, {
				mode = if(event == "ORBIT_RESONANCE_3", { 3 }, { if(event == "ORBIT_LOCK", { 1 }, { if(event == "PERIAPSIS_AUDIO_SURGE", { 2 }, { 0 }) }) });
				freq = (~rootFreq * (1.5 + (lobes * 0.33) + (peri * 1.2))).clip(90, 1800);
				freq = ~quantizeToScale.(freq);
				amp  = (0.008 + (~orbitEventEnergy * 0.026)).clip(0.006, 0.04);
				Synth(\orbitMarker, [\freq, freq, \amp, amp, \dur, 0.10 + (~orbitEventEnergy * 0.32), \mode, mode]);
				~lastOrbitMarkerTime = now;
			});
		});
	}, "/rdf/orbitEvent", nil, ~oscPort);

	// ── /rdf/droneSpawn / droneKill ───────────────────────────────────────────
	OSCdef(\manualDroneSpawnReceiver, { |msg|
    var f, v;
    f = ~msgFloat.(msg, 1, ~rootFreq ? 55).clip(45, 900);
    v = ~msgFloat.(msg, 2, ~droneVolume ? 0.20).clip(0, 1);
	    ~cancelFloquetDissolution.();
	    ~droneVolume = v;
	    ~fsManualKilled = false;
	    ~fsManualMuteUntil = 0.0;
	    ~fsCanSpawn = true;
    ~fsLifecycleState = 3;
    ~fsCouplingEnv = 1.0;
    ~fsLastGateMs = 0;

	    // Spawn the Floquet drone manually, using current field state
	    if(~floquetDroneSynth.isNil or: { ~floquetDroneSynth.isPlaying.not }, {
	        if(~floquetDroneSynth.notNil, {
	            ~floquetDroneSynth.set(\gate, 0);
	        });
	        ~floquetDroneSynth = Synth(\floquet_drone, [
	            \out,       0,
            \freq,      f,
            \amp,       ~droneGain.() * 0.36,
            \vol,       1.0,
            \nu0,       ~fsNu[0], \nu1, ~fsNu[1],
            \nu2,       ~fsNu[2], \nu3, ~fsNu[3],
            \nu4,       ~fsNu[4], \nu5, ~fsNu[5],
            \nu6,       ~fsNu[6], \nu7, ~fsNu[7],
            \omega,     ~fsOmega ? 0.18,
            \strength,  0.18,
            \topoPhase, ~fsTopoPhase ? 0,
            \topoDepth, ~fsTopoDepth ? 0,
            \atk,       2.5,
            \sus,       1.0,
            \rel,       4.0,
	            \harmonics, 4,
	            \warmth,    0.6
	        ], addAction: \addToTail);
	        ~floquetDroneSynth.register;
	        ~fsGateOpen = true;
	        ("=== Floquet drone MANUALLY SPAWNED freq=" ++ f ++ " vol=" ++ v).postln;
    }, {
        // Already running — just update freq and amp
        ~floquetDroneSynth.set(\freq, f, \amp, ~droneGain.() * 0.36);
        ("=== Floquet drone already live — updated freq=" ++ f).postln;
    });
}, "/rdf/droneSpawn", nil, ~oscPort);

OSCdef(\manualDroneKillReceiver, { |msg|
    ~cancelFloquetDissolution.();
    if(~floquetDroneSynth.notNil and: { ~floquetDroneSynth.isPlaying }, {
        ~floquetDroneSynth.set(\gate, 0);
        ~floquetDroneSynth = nil;
	        ~fsGateOpen = false;
	        ~fsCanSpawn = false;
	        ~fsLifecycleState = 5;
	        ~fsCouplingEnv = 0.0;
	        // Manual kill is a short mute, not a permanent conversion to manual-only.
	        ~fsManualKilled = false;
	        ~fsManualMuteUntil = Main.elapsedTime + 8.0;
	        ~fsLastGateMs = Main.elapsedTime * 1000;
	        "=== Floquet drone MANUALLY KILLED; auto-injection muted briefly ===".postln;
    }, {
        "Floquet drone already silent.".postln;
    });
}, "/rdf/droneKill", nil, ~oscPort);

	// ── /rdf/choirVol and /rdf/choirToggle — NEW choir GUI controls ───────────
	OSCdef(\choirVolumeReceiver, { |msg|
		~choirVolume = ~msgFloat.(msg, 1, 0).clip(0, 1);
		("Choir volume set to: " ++ ~choirVolume).postln;
	}, "/rdf/choirVol", nil, ~oscPort);

	OSCdef(\choirToggleReceiver, { |msg|
		var onOff = ~msgFloat.(msg, 1, 0) > 0.5;
		if(onOff, {
			~choirVolume = (~choirVolume.max(0.20));
			("Choir ON vol=" ++ ~choirVolume).postln;
		}, {
			if(~choirSynth.notNil and: { ~choirSynth.isPlaying }, {
				~choirSynth.set(\amp, 0, \gate, 0);
				~choirSynth = nil;
			});
			if(~choirGroup.notNil, { ~choirGroup.freeAll; });
			~choirVolume = 0.0;
			"Choir OFF".postln;
		});
	}, "/rdf/choirToggle", nil, ~oscPort);

	// ── /rdf/ocean ────────────────────────────────────────────────────────────
		OSCdef(\oceanReceiver, { |msg|
			var liveVal, exciteVal, colorVal, burstVal, persistenceVal, depthBiasVal, curvatureVal;
			var arpDriveVal, glassDriveVal, reverbDriveVal, tideVal, tempVal, currentVal, phaseVal;
			var thermalVal, rangeVal, velocityVal, accelVal, energyVal, memoryVal;
			var oceanVolBias, oceanCurBias, oceanSwBias;
			var now, heatFreq, spreadVal, edgeVal, domVal, vol, breakCooldown;
			var tideNow, newDir, curNow, rising;
		~lastOSCHeartbeat = Process.elapsedTime;
		now = Main.elapsedTime;
		~lastOceanUpdate = ~lastOceanUpdate ? 0.0;
		if((now - ~lastOceanUpdate) >= 0.12, {
			~lastOceanUpdate = now;
			liveVal = ~msgFloat.(msg, 1, 0).clip(0, 1);
			exciteVal = ~msgFloat.(msg, 2, 0).clip(0, 1);
			colorVal = ~msgFloat.(msg, 3, 0).clip(0, 1);
			burstVal = ~msgFloat.(msg, 4, 0).clip(0, 1);
			persistenceVal = ~msgFloat.(msg, 5, 0).clip(0, 1);
			depthBiasVal = ~msgFloat.(msg, 6, 0).clip(0, 1);
			curvatureVal = ~msgFloat.(msg, 7, 0).clip(-1, 1);
			arpDriveVal = ~msgFloat.(msg, 8, 0).clip(0, 1);
			glassDriveVal = ~msgFloat.(msg, 9, 0).clip(0, 1);
			reverbDriveVal = ~msgFloat.(msg, 10, 0).clip(0, 1);
			tideVal = ~msgFloat.(msg, 11, 0);
			tempVal = ~msgFloat.(msg, 12, 12);
			currentVal = ~msgFloat.(msg, 13, 0).clip(0, 1);
			phaseVal = ~msgFloat.(msg, 14, 0.5).clip(0, 1);
			thermalVal = ~msgFloat.(msg, 15, 0.5).clip(0, 1);
			rangeVal = ~msgFloat.(msg, 16, 0).max(0);
			velocityVal = ~msgFloat.(msg, 17, 0).clip(0, 1);
			accelVal = ~msgFloat.(msg, 18, 0).clip(0, 1);
			energyVal = ~msgFloat.(msg, 19, 0).clip(0, 1);
			memoryVal = ~msgFloat.(msg, 20, 0).clip(0, 1);
			oceanVolBias = ~msgFloat.(msg, 21, ~oceanVolume ? 0.010).clip(0, 0.05);
			oceanCurBias = ~msgFloat.(msg, 22, 0.5).clip(0, 1);
			oceanSwBias = ~msgFloat.(msg, 23, ~oceanSwellDepth ? 0.5).clip(0, 1);

			~oceanLive = ((~oceanLive ? 0) * 0.88) + (liveVal * 0.12);
			~oceanExcite = ((~oceanExcite ? 0) * 0.88) + (exciteVal * 0.12);
			~oceanColor = ((~oceanColor ? 0) * 0.90) + (colorVal * 0.10);
			~oceanBurst = burstVal;
			~oceanPersistence = ((~oceanPersistence ? 0) * 0.94) + (persistenceVal * 0.06);
			~oceanDepthBias = ((~oceanDepthBias ? 0) * 0.92) + (depthBiasVal * 0.08);
			~oceanCurvature = ((~oceanCurvature ? 0) * 0.90) + (curvatureVal * 0.10);
			~oceanArpDrive = ((~oceanArpDrive ? 0) * 0.90) + (arpDriveVal * 0.10);
			~oceanGlassDrive = ((~oceanGlassDrive ? 0) * 0.90) + (glassDriveVal * 0.10);
			~oceanReverbDrive = ((~oceanReverbDrive ? 0) * 0.96) + (reverbDriveVal * 0.04);
			~oceanTideM = tideVal;
			~oceanTempC = tempVal;
			~oceanVolume = ((~oceanVolume ? 0.006) * 0.88) + (oceanVolBias * 0.12);
			~oceanSwellDepth = ((~oceanSwellDepth ? 0.5) * 0.88) + (oceanSwBias * 0.12);
			~oceanCurrent = ((~oceanCurrent ? 0) * 0.88) + (((currentVal * (0.70 + (oceanCurBias * 0.35))) + (oceanCurBias * 0.08)).clip(0, 1) * 0.12);
			~oceanPhase = ((~oceanPhase ? 0.5) * 0.90) + (phaseVal * 0.10);
			~oceanThermal = ((~oceanThermal ? 0.5) * 0.90) + (thermalVal * 0.10);
			~oceanRangeM = rangeVal;
			~oceanVelocity = ((~oceanVelocity ? 0) * 0.88) + (velocityVal * 0.12);
			~oceanAccel = ((~oceanAccel ? 0) * 0.82) + (accelVal * 0.18);
				~oceanEnergy = ((~oceanEnergy ? 0) * 0.90) + (energyVal * 0.10);
				~oceanMemory = ((~oceanMemory ? 0) * 0.96) + (memoryVal * 0.04);

				vol = (~oceanVolume ? 0.006).clip(0, 0.05);
				tideNow = ~oceanTideM ? 0;
				if(((tideNow - (~oceanPrevTideM ? 0)).abs > 0.002), {
					newDir = if(tideNow > (~oceanPrevTideM ? 0), { 1 }, { -1 });
					if((newDir != (~oceanTideDir ? 0)) and: { (~oceanTideDir ? 0) != 0 }, {
						~oceanTurnUntil = Main.elapsedTime + 45.0;
					});
					~oceanTideDir = newDir;
					~oceanPrevTideM = tideNow;
				});
				~oceanRegime = case
					{ Main.elapsedTime < (~oceanTurnUntil ? 0) } { \turn }
					{ ((~oceanCurrent ? 0) > 0.65) or: { (~oceanVelocity ? 0) > 0.5 } } { \race }
					{ (~oceanCurrent ? 0) > 0.25 } { \flow }
					{ \slack };
				spreadVal = ((~oceanDepthBias ? 0) * 0.45 + (~oceanVelocity ? 0) * 0.30 + (~oceanCurrent ? 0) * 0.25).clip(0, 1);
				edgeVal = (((~oceanGlassDrive ? 0) * 0.48) + ((~oceanAccel ? 0) * 0.35) + ((~oceanCurvature ? 0).abs * 0.17)).clip(0, 1);
				domVal = (((~oceanColor ? 0) * 0.35) + ((~oceanEnergy ? 0) * 0.35) + ((~oceanPersistence ? 0) * 0.30)).clip(0, 1);

			heatFreq = ~quantizeToScale.((~rootFreq * (3.0 + (domVal * 7.0) + ((~oceanColor ? 0) * 4.0))).clip(360, 4600));
			~oceanColorFreq = heatFreq;
			~excArpDrive = (~excArpDrive ? 0) * 0.985;
			~excGlassDrive = (~excGlassDrive ? 0) * 0.985;

			~oceanArpExcite = ((~oceanArpExcite ? 0) * 0.90) + ((((~oceanArpDrive ? 0) * 0.50) + ((~oceanExcite ? 0) * 0.25) + (spreadVal * 0.18) + ((~excArpDrive ? 0) * 0.14)) * 0.10);
			~oceanGlassExcite = ((~oceanGlassExcite ? 0) * 0.88) + ((((~oceanGlassDrive ? 0) * 0.55) + ((~oceanBurst ? 0) * 0.25) + (edgeVal * 0.16) + ((~excGlassDrive ? 0) * 0.14)) * 0.12);
			~oceanArpExcite = ~oceanArpExcite.clip(0, 0.75);
			~oceanGlassExcite = ~oceanGlassExcite.clip(0, 0.35);

			if(((~oceanSwellSynth.isNil or: { ~oceanSwellSynth.isPlaying.not })
				and: { (~oceanLive ? 0) > 0.08 }
				and: { (Main.elapsedTime - (~lastOceanSwellSpawn ? 0.0)) > 6.0 }), {
					if(~oceanSwellSynth.notNil, { ~oceanSwellSynth.set(\gate, 0); ~oceanSwellSynth = nil; });
					~oceanSwellSynth = Synth(\ocean_swell, [
						\gate, 1,
						\amp, (~oceanVolume ? 0.006) * (1.2 + ((~oceanSwellDepth ? 0.5) * 2.0)) * (0.45 + (0.55 * (~oceanPhase ? 0.5))),
						\tidalPhase, ~oceanPhase ? 0.5,
						\current, ~oceanCurrent ? 0.2,
					\velocity, ~oceanVelocity ? 0.1,
					\thermal, ~oceanThermal ? 0.5,
						\energy, ~oceanEnergy ? 0.3,
						\memory, ~oceanMemory ? 0.2
					], addAction: \addToTail);
					~oceanSwellSynth.register;
					~lastOceanSwellSpawn = Main.elapsedTime;
					"=== Ocean swell spawned ===".postln;
				}, {
				if(~oceanSwellSynth.notNil and: { ~oceanSwellSynth.isPlaying }, {
					~oceanSwellSynth.set(
						\tidalPhase, ~oceanPhase ? 0.5,
						\current, ~oceanCurrent ? 0.2,
						\velocity, ~oceanVelocity ? 0.1,
							\thermal, ~oceanThermal ? 0.5,
							\energy, ~oceanEnergy ? 0.3,
							\memory, ~oceanMemory ? 0.2,
							\amp, (~oceanVolume ? 0.006) * (1.2 + ((~oceanSwellDepth ? 0.5) * 2.0))
								* (0.45 + (0.55 * (~oceanPhase ? 0.5)))
								* if((~oceanRegime ? \slack) == \race, { 0.55 }, { 1.0 })
						);
						if((~oceanLive ? 0) < 0.04, { ~oceanSwellSynth.set(\gate, 0); ~oceanSwellSynth = nil; });
					});
				});

				if(((~oceanRegime ? \slack) == \flow) or: { (~oceanRegime ? \slack) == \race }, {
					curNow = ~oceanCurrent ? 0;
					rising = curNow > ((~oceanPrevCurrent ? 0) + 0.04);
					if(rising and: { (Main.elapsedTime - (~lastOceanSurgeEvent ? 0)) > (~oceanSurgeEventCooldown ? 25.0) }
						and: { (~estimatedVoiceLoad.() / 10.0) < 0.7 }, {
						~lastOceanSurgeEvent = Main.elapsedTime;
						Synth(\ocean_surge_event, [
							\amp, (~oceanVolume ? 0.006) * 1.6,
							\current, curNow, \velocity, ~oceanVelocity ? 0.1,
							\accel, ~oceanAccel ? 0.0, \energy, ~oceanEnergy ? 0.3,
							\phase, ~oceanPhase ? 0.5,
							\pan, (~oceanPhase ? 0.5).linlin(0, 1, -0.45, 0.45),
							\sustain, rrand(20.0, 40.0) * (1.0 + ((~oceanMemory ? 0) * 0.5))
						], addAction: \addToTail);
						"=== Ocean surge passage spawned ===".postln;
					});
					~oceanPrevCurrent = curNow;
				}, {
					~oceanPrevCurrent = ~oceanCurrent ? 0;
				});
				if(~oceanSurgeSynth.notNil and: { ~oceanSurgeSynth.isPlaying }, {
					~oceanSurgeSynth.set(\gate, 0);
					~oceanSurgeSynth = nil;
				});

				~lastOceanGranuleTrig = ~lastOceanGranuleTrig ? 0.0;
				if(((~oceanAccel ? 0) > 0.15) or: { ((~oceanVelocity ? 0) > 0.25) and: { (~oceanCurrent ? 0) > 0.20 } }
					or: { ((~oceanRegime ? \slack) == \turn) and: { (~oceanVelocity ? 0) > 0.15 } }, {
					breakCooldown = 3.5 - ((~oceanAccel ? 0) * 1.8) - ((~oceanVelocity ? 0) * 0.8);
					if((now - ~lastOceanGranuleTrig) > breakCooldown.clip(1.2, 4.0), {
						if((0.08 + ((~oceanAccel ? 0) * 0.28) + ((~oceanVelocity ? 0) * 0.18)).coin, {
							~lastOceanGranuleTrig = now;
							Synth(\ocean_break, [
								\amp, (~oceanVolume ? 0.006) * 2.8,
								\freq, (65 + ((~oceanCurrent ? 0) * 180) + ((~oceanAccel ? 0) * 120)).clip(55, 380),
								\dur, rrand(0.9, 2.8) * (1.0 + (~oceanMemory ? 0)) * if((~oceanRegime ? \slack) == \turn, { rrand(1.2, 1.7) }, { 1.0 }),
								\accel, ~oceanAccel ? 0.5,
								\velocity, ~oceanVelocity ? 0.3,
								\pan, rrand(-0.6, 0.6)
						]);
						});
					});
				});
				if(((~oceanRegime ? \slack) == \flow) or: { (~oceanRegime ? \slack) == \race }, {
					if((Main.elapsedTime - (~lastOceanChop ? 0)) > rrand(2.0, 6.0)
						and: { (~estimatedVoiceLoad.() / 10.0) < 0.7 }
						and: { (0.20 + ((~oceanVelocity ? 0) * 0.35)).coin }, {
						~lastOceanChop = Main.elapsedTime;
						Synth(\ocean_chop, [
							\amp, (~oceanVolume ? 0.006) * rrand(0.7, 1.3),
							\freq, (300 + ((~oceanCurrent ? 0) * 450) + rrand(-60, 60)).clip(280, 900),
							\dur, rrand(0.15, 0.5), \vel, ~oceanVelocity ? 0.3,
							\pan, rrand(-0.7, 0.7)
						]);
					});
				});
				if(((~oceanRegime ? \slack) == \race) and: { (~oceanAccel ? 0) > 0.10 }, {
					if((Main.elapsedTime - (~lastOceanSpray ? 0)) > rrand(0.8, 2.5)
						and: { (0.15 + ((~oceanAccel ? 0) * 0.40)).coin }, {
						~lastOceanSpray = Main.elapsedTime;
						Synth(\ocean_spray, [
							\amp, (~oceanVolume ? 0.006) * rrand(0.4, 0.8),
							\freq, rrand(2000, 4800), \dur, rrand(0.05, 0.13),
							\pan, rrand(-0.8, 0.8)
						]);
					});
				});
				if(((~oceanRegime ? \slack) == \turn)
					and: { (Main.elapsedTime - (~lastOceanUndertow ? 0)) > 60.0 }, {
					~lastOceanUndertow = Main.elapsedTime;
					Synth(\ocean_undertow, [
						\amp, (~oceanVolume ? 0.006) * 2.6,
						\freq, rrand(32, 46), \dur, rrand(7.0, 11.0)
					]);
					"=== Ocean undertow (tide reversal) ===".postln;
				});
			});
		}, "/rdf/ocean", nil, ~oscPort);

	// ========== RHYTHM GENERATOR INIT ==========
	~lastBrightness   = ~lastBrightness ? 0;
	~lastOrbSpeed     = ~lastOrbSpeed ? 0.5;
	~lastOrbPhi       = ~lastOrbPhi ? 1.0;
	~alpha            = ~alpha ? 2.0;
	~rhythmComplexity = ~rhythmComplexity ? 0.5;
	~rhythmSwing      = ~rhythmSwing ? 0.0;

	// ========== VISUAL PATTERN for Arduino ==========
	~visualPlayer = {
		Routine({
			var field8, x, y, intensity, spread, xoff, yoff, xoff1, xoff2, yoff1, yoff2;
			loop {
				field8 = Array.fill(8, { Array.fill(8, 0) });
				intensity = ((~safeFloat.(~lastBrightness, 0) + ~safeFloat.(~rhythmComplexity, 0.5)) / 2).clip(0, 1);
				x = ((~safeFloat.(~lastOrbPhi, 0.5).clip(0, 1) * 7).round).clip(0, 7);
				y = ((~safeFloat.(~lastOrbSpeed, 0.1).clip(0, 1) * 7).round).clip(0, 7);
				field8[y][x] = 1.0;
				spread = ((intensity * 2).round).clip(1, 3);
				for(0, spread, { |offset|
					xoff = x + offset; if(xoff < 8, { field8[y][xoff] = max(field8[y][xoff], 0.7 - (offset * 0.2)) });
					xoff = x - offset; if(xoff >= 0, { field8[y][xoff] = max(field8[y][xoff], 0.7 - (offset * 0.2)) });
					yoff = y + offset; if(yoff < 8, { field8[yoff][x] = max(field8[yoff][x], 0.7 - (offset * 0.2)) });
					yoff = y - offset; if(yoff >= 0, { field8[yoff][x] = max(field8[yoff][x], 0.7 - (offset * 0.2)) });
				});
				for(1, spread-1, { |offset|
					xoff1 = x + offset; xoff2 = x - offset; yoff1 = y + offset; yoff2 = y - offset;
					if(xoff1 < 8 and: { yoff1 < 8 }, { field8[yoff1][xoff1] = max(field8[yoff1][xoff1], 0.5 - (offset * 0.15)) });
					if(xoff1 < 8 and: { yoff2 >= 0 }, { field8[yoff2][xoff1] = max(field8[yoff2][xoff1], 0.5 - (offset * 0.15)) });
					if(xoff2 >= 0 and: { yoff1 < 8 }, { field8[yoff1][xoff2] = max(field8[yoff1][xoff2], 0.5 - (offset * 0.15)) });
					if(xoff2 >= 0 and: { yoff2 >= 0 }, { field8[yoff2][xoff2] = max(field8[yoff2][xoff2], 0.5 - (offset * 0.15)) });
				});
				if(~connected, { ~sendFrame.(field8); });
				0.05.wait;
			};
		}).play;
	};

	// ========== SERIAL SETUP ==========
	~connectSerial = {
		if(~serialPort.notNil, { ~serialPort.close; ~serialPort = nil; });
		try {
			~serialPort = SerialPort(~portName, baudrate: 115200, crtscts: false);
			~connected = true;
			"Connected to Arduino!".postln;
		} { |error| ("Could not connect: " ++ error).postln; ~connected = false; };
	};

	~sendFrame = { |frame2D|
		var line, val;
		if(~connected and: { ~serialPort.notNil }, {
			~serialPort.putAll("MODE:3\n".ascii);
			8.do { |row|
				line = "";
				8.do { |col|
					val = ((~safeFloat.(frame2D[row][col], 0).clip(0, 1) * 255).round(1)).clip(0, 255);
					line = line ++ val.asString;
					if(col < 7, { line = line ++ ","; });
				};
				line = line ++ "\n";
				~serialPort.putAll(line.ascii);
			};
		});
	};

	// ========== AUDIO WATCHDOG ==========
	~softRecoverAudio = {
		"SC watchdog: soft audio recovery".postln;
		if(~solarSynth.notNil, { ~solarSynth.set(\gate, 0); ~solarSynth = nil; });
		~solarBreath = 0.0;
		~solarPhaseRate = 0.08;
		~solarAudioEnabled = true;
		if(~oceanSwellSynth.notNil, { ~oceanSwellSynth.set(\gate, 0); ~oceanSwellSynth = nil; });
		if(~oceanSurgeSynth.notNil, { ~oceanSurgeSynth.set(\gate, 0); ~oceanSurgeSynth = nil; });
			if(~droneSynth.notNil, { ~droneSynth.set(\amp, 0); ~droneSynth = nil; ~currentDroneOn = true; });
			if(~choirSynth.notNil, { ~choirSynth.set(\gate, 0); ~choirSynth = nil; });
				if(~floquetDroneSynth.notNil, {
					~floquetDroneSynth.set(\amp, 0, \strength, 0, \gate, 0);
					~floquetDroneSynth = nil;
				});
				~fsGateOpen = false;
				~fsLastSpawnTime = Main.elapsedTime;
				~fsCanSpawn = false;
				~fsManualKilled = false;
				~fsManualMuteUntil = Main.elapsedTime + 8.0;
				~fsCouplingEnv = 0.0;
			};

	Routine({
		loop {
				4.wait;
				// Heartbeat may legitimately stall during a heavy holonomy sweep.
				// Heavy recovery is measurement-safe OFF by default; nil-cleanup still runs.
				if((~watchdogEnabled ? false)
					and: { (Process.elapsedTime - (~lastOSCHeartbeat ? 0)) > (~watchdogHeartbeatTimeout ? 45) }
					and: { (Process.elapsedTime - (~lastWatchdogFire ? 0)) > (~watchdogRefractory ? 60) }, {
						~lastWatchdogFire = Process.elapsedTime;
						~softRecoverAudio.();
					}, {
				if(~solarSynth.notNil and: { ~solarSynth.isPlaying.not }, {
					~solarSynth = nil;
					~solarBreath = 0.0;
					~solarPhaseRate = 0.08;
					~solarAudioEnabled = true;
				});
				if(~choirSynth.notNil and: { ~choirSynth.isPlaying.not }, {
					~choirSynth = nil;
				});
				if(~oceanSwellSynth.notNil and: { ~oceanSwellSynth.isPlaying.not }, {
					~oceanSwellSynth = nil;
				});
				if(~oceanSurgeSynth.notNil and: { ~oceanSurgeSynth.isPlaying.not }, {
					~oceanSurgeSynth = nil;
				});
			});
		};
	}).play(AppClock);

	if(~loadWatchdogRoutine.notNil, { ~loadWatchdogRoutine.stop; });
	~loadWatchdogRoutine = Routine({
		loop {
			var avgCpu, peakCpu, voiceLoad;
			1.5.wait;
			avgCpu = s.avgCPU ? 0.0;
			peakCpu = s.peakCPU ? 0.0;
			voiceLoad = (~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)).clip(0, 99);
			if((avgCpu > 65) or: { peakCpu > 82 } or: { voiceLoad > 14 }, {
				~glassCooldown = (~glassCooldown ? 0.30).max(0.50);
				~oceanBloomCooldown = (~oceanBloomCooldown ? 6.0).max(10.0);
				~oceanMembraneCooldown = (~oceanMembraneCooldown ? 8.0).max(12.0);
				if((avgCpu > 78) or: { peakCpu > 92 } or: { voiceLoad > 18 }, {
					if(~choirSynth.notNil and: { ~choirSynth.isPlaying }, {
						~choirSynth.set(\gate, 0);
						~choirSynth = nil;
					});
				});
			}, {
				if((avgCpu < 45) and: { peakCpu < 70 } and: { voiceLoad < 10 }, {
					if((~glassCooldown ? 0.30) > 0.36, { ~glassCooldown = 0.30; });
					if((~oceanBloomCooldown ? 6.0) > 7.0, { ~oceanBloomCooldown = 6.0; });
					if((~oceanMembraneCooldown ? 8.0) > 9.0, { ~oceanMembraneCooldown = 8.0; });
				});
			});
		};
	}).play(AppClock);

	// ========== FLOQUET DRONE SYSTEM ==========
	~fsOmega        = 0.18;
	~fsPeriod       = 5.5;
	~fsPhase        = 0.0;
	~fsCycle        = 0;
	~fsGateOpen     = false;
	~fsDriveNow     = 0.0;
	~fsAlphaNow     = 2.0;
	~fsHoldStrength = 0.0;
	~fsG            = 0.0;
	~fsTopoPhase    = 0.0;
	~fsTopoDepth    = 0.0;
	~fsNu           = Array.fill(8, { 0.0 });
	~fsLastGateMs   = 0;
	~fsGateCooldownMs = 400;
		~fsLastSpawnTime = 0.0;
			~fsMinRespawn = 6.0;
		~fsLifecycleState = 1;  // 0 IDLE, 1 ARMED, 2 LOCKING, 3 INJECTING, 4 RELEASING, 5 COOLDOWN, 6 INTEGRATED
		~fsCanSpawn = true;
		~fsAutoInjectEnabled = false;
		~fsManualKilled = false;
		~fsManualMuteUntil = 0.0;
		~fsCouplingEnv = 0.0;
	~fsLockAge = 0.0;
	~fsInjectionAge = 0.0;
	~fsIntegratedAge = 0.0;
	~fsFieldImprint = 0.0;
	~fsCrossingGamma = 0.0;
	~fsCrossingArea = 0.0;
	~fsReleaseAge = 0.0;
	~fsCooldownRemaining = 0.0;
	~fsLockScoreRaw = 0.0;
	~fsLockScoreGated = 0.0;
	~fsReleaseCommand = false;
	~floquetDissolutionRoutine = nil;
	~floquetDissolutionActive = false;
	~floquetDissolutionCycle = 0;
	~floquetDissWarmth = 0.6;

	SynthDef(\floquet_drone, {
		|out=0, freq=110, amp=0.12, vol=0.3,
		 nu0=0, nu1=0, nu2=0, nu3=0, nu4=0, nu5=0, nu6=0, nu7=0,
		 omega=0.18, strength=0.18,
		 topoPhase=0, topoDepth=0,
		 atk=2.5, sus=1.0, rel=4.0,
		 detune=0.003, harmonics=4, warmth=0.6,
		 gate=1|
		var drive, topoFactor, drivenFreq;
		var sig, env, t;
		t = Phasor.ar(0, omega * SampleDur.ir, 0, 1);
		drive = (nu0 * SinOsc.kr(omega * 1, pi/2)
		       + nu1 * SinOsc.kr(omega * 1, 0)
		       + nu2 * SinOsc.kr(omega * 2, pi/2)
		       + nu3 * SinOsc.kr(omega * 2, 0)
		       + nu4 * SinOsc.kr(omega * 3, pi/2)
		       + nu5 * SinOsc.kr(omega * 3, 0)
		       + nu6 * SinOsc.kr(omega * 4, pi/2)
	             + nu7 * SinOsc.kr(omega * 4, 0));
		topoFactor = 1.0 + (0.22 * cos(topoPhase) * topoDepth);
		drive = drive * topoFactor.clip(0.65, 1.45);
		drive = (drive * 0.7).tanh * 1.5;
		drivenFreq = freq * (1.0 + (Lag.kr(strength, 0.8) * drive * 0.08));
		drivenFreq = Lag.kr(drivenFreq, 0.012);
		drivenFreq = drivenFreq.clip(20, 4000);
		sig = Mix.fill(4, { |i|
			var n = i + 1;
			var detuneFactor = 1.0 + (detune * (i - 2.0));
			var harmonicMask = (harmonics - n + 1).clip(0, 1);
			SinOsc.ar(drivenFreq * n * detuneFactor) * (warmth / n) * harmonicMask
		});
		sig = sig.tanh * 0.42;
		sig = LPF.ar(sig, 5200);
		env = EnvGen.kr(Env.asr(atk, sus, rel), gate, doneAction: 2);
		sig = sig * env * amp * vol;
		Out.ar(out, [sig, sig * LFNoise2.kr(0.08).range(0.96, 1.04)]);
	}).add;

		"=== Floquet drone SynthDef added ===".postln;
		s.sync;

		~spawnFloquetDroneFromLifecycle = { |env = 0.0|
			var nowSec, rootF, spawnAmp;
			nowSec = Main.elapsedTime;
			rootF = ~rootFreq ? 55;
			if((~fsAutoInjectEnabled ? true)
				and: { Main.elapsedTime >= (~fsManualMuteUntil ? 0.0) }
				and: { ~fsCanSpawn ? true }
					and: { ~floquetDroneSynth.isNil or: { ~floquetDroneSynth.isPlaying.not } }
		and: { (nowSec - (~fsLastSpawnTime ? 0)) >= (~fsMinRespawn ? 6.0) }, {
						~cancelFloquetDissolution.();
						if(~floquetDroneSynth.notNil, {
							~floquetDroneSynth.set(\gate, 0);
							~floquetDroneSynth = nil;
						});
					spawnAmp = (~droneGain.() * 0.36 * max(env, 0.12)).clip(0, 0.060);
					~floquetDroneSynth = Synth(\floquet_drone, [
					\out, 0, \freq, rootF,
					\amp, spawnAmp, \vol, 1.0,
					\nu0, ~fsNu[0], \nu1, ~fsNu[1],
					\nu2, ~fsNu[2], \nu3, ~fsNu[3],
					\nu4, ~fsNu[4], \nu5, ~fsNu[5],
					\nu6, ~fsNu[6], \nu7, ~fsNu[7],
					\omega, ~fsOmega, \strength, 0.18 * max(env, 0.05),
					\topoPhase, ~fsTopoPhase, \topoDepth, ~fsTopoDepth,
						\atk, 1.2, \sus, 1.0, \rel, 4.0,
						\harmonics, 4, \warmth, 0.6
					], addAction: \addToTail);
					~floquetDroneSynth.register;
					~fsLastSpawnTime = nowSec;
					("=== Floquet drone lifecycle-spawned: state=" ++ (~fsLifecycleState ? -1) ++ " env=" ++ env.round(0.001) ++ " rootFreq=" ++ rootF).postln;
			});
		};

		OSCdef(\floquetDrive, { |msg|
			~fsOmega     = msg[1].clip(0.05, 1.0);
		~fsNu        = [msg[3], msg[4], msg[5], msg[6], msg[7], msg[8], msg[9], msg[10]];
		~fsDriveNow  = msg[11] ? 0;
		~fsAlphaNow  = msg[12] ? 2.0;
		~fsTopoPhase = msg[14] ? 0;
		~fsTopoDepth = msg[15] ? 0;
		~fsPeriod    = 2pi / max(0.05, ~fsOmega);
		if(~floquetDroneSynth.notNil && ~floquetDroneSynth.isPlaying, {
			if(~floquetDissolutionRoutine.notNil, {
				~floquetDroneSynth.set(
					\nu0, ~fsNu[0], \nu1, ~fsNu[1],
					\nu2, ~fsNu[2], \nu3, ~fsNu[3],
					\nu4, 0.0, \nu5, 0.0,
					\nu6, 0.0, \nu7, 0.0,
					\omega, ~fsOmega,
					\strength, 0.04,
					\harmonics, 2,
					\topoPhase, ~fsTopoPhase,
					\topoDepth, 0.0
				);
			}, {
				~floquetDroneSynth.set(
					\nu0, ~fsNu[0], \nu1, ~fsNu[1],
					\nu2, ~fsNu[2], \nu3, ~fsNu[3],
					\nu4, ~fsNu[4], \nu5, ~fsNu[5],
					\nu6, ~fsNu[6], \nu7, ~fsNu[7],
					\omega, ~fsOmega,
					\strength, 0.18 * (~fsCouplingEnv ? 0.0),
					\topoPhase, ~fsTopoPhase,
					\topoDepth, ~fsTopoDepth
				);
			});
		});
	}, '/rdf/floquet_drive');

	OSCdef(\floquetClock, { |msg|
		var phase    = msg[1];
		var period   = msg[2];
		var cycle    = msg[3].asInteger;
		var gateOpen = msg[4] > 0.5;
		var phaseLock = msg[5];
		var nowMs    = Main.elapsedTime * 1000;
		var nowSec   = Main.elapsedTime;
		var rootF    = ~rootFreq ? 55;
		~fsPhase  = phase;
		~fsPeriod = period;
		~fsCycle  = cycle;
			// Spawn is now commanded by the Processing lifecycle, not by a self-latching detector.
			if(gateOpen
				and: { ~fsAutoInjectEnabled ? true }
				and: { Main.elapsedTime >= (~fsManualMuteUntil ? 0.0) }
				and: { ~fsCanSpawn ? true }
				and: { ((~fsLifecycleState ? 1) == 2) or: { (~fsLifecycleState ? 1) == 3 } }, {
			~fsGateOpen   = true;
			~fsLastGateMs = nowMs;
			if(~floquetDroneSynth.notNil and: { ~floquetDroneSynth.isPlaying }, {
				~cancelFloquetDissolution.();
				~floquetDroneSynth.set(
					\freq, ~rootFreq ? 55,
					\amp, ~droneGain.() * 0.36 * max(~fsCouplingEnv ? 0.0, 0.05),
					\strength, 0.18 * (~fsCouplingEnv ? 0.0),
					\omega, ~fsOmega
				);
			}, {
					if(((nowSec - (~fsLastSpawnTime ? 0)) < (~fsMinRespawn ? 6.0))
						or: { nowSec < (~fsManualMuteUntil ? 0) }
						or: { (~fsCanSpawn ? true).not }, {
						~fsGateOpen = false;
					}, {
					~cancelFloquetDissolution.();
					if(~floquetDroneSynth.notNil, {
						~floquetDroneSynth.set(\gate, 0);
					});
					~floquetDroneSynth = Synth(\floquet_drone, [
						\out, 0, \freq, rootF,
					\amp, ~droneGain.() * 0.36, \vol, 1.0,
					\nu0, ~fsNu[0], \nu1, ~fsNu[1],
					\nu2, ~fsNu[2], \nu3, ~fsNu[3],
					\nu4, ~fsNu[4], \nu5, ~fsNu[5],
					\nu6, ~fsNu[6], \nu7, ~fsNu[7],
					\omega, ~fsOmega, \strength, 0.18 * (~fsCouplingEnv ? 0.0),
					\topoPhase, ~fsTopoPhase, \topoDepth, ~fsTopoDepth,
						\atk, 2.5, \sus, 1.0, \rel, 4.0,
						\harmonics, 4, \warmth, 0.6
					], addAction: \addToTail);
						~floquetDroneSynth.register;
						~fsLastSpawnTime = nowSec;
						("=== Floquet drone spawned: rootFreq=" ++ rootF ++ " Ω=" ++ ~fsOmega).postln;
				});
			});
		});
		if(gateOpen.not, { ~fsGateOpen = false; });
	}, '/rdf/floquet_clock');

	OSCdef(\floquetOrb, { |msg|
		~fsHoldStrength = msg[1].clip(0, 1);
		~fsG            = msg[2].clip(-1, 1);
		// Hold strength is now diagnostic only. Lifecycle release prevents self-latching.
	}, '/rdf/floquet_orb');

	OSCdef(\floquetLifecycle, { |msg|
		var state, env, releaseCmd, imprint, integratedAmp;
		state = msg[1].asInteger;
		env = (msg[2] ? 0).clip(0, 1);
		releaseCmd = msg[9].notNil and: { msg[9] > 0.5 };
			~fsLifecycleState = state;
			~fsCouplingEnv = env;
			if((~fsCanSpawn ? true).not and: { Main.elapsedTime > (~fsManualMuteUntil ? 0) }, {
				~fsCanSpawn = true;
			});
			~fsLockAge = msg[3] ? 0;
		~fsInjectionAge = msg[4] ? 0;
		~fsReleaseAge = msg[5] ? 0;
		~fsCooldownRemaining = msg[6] ? 0;
		~fsLockScoreRaw = (msg[7] ? 0).clip(0, 1);
		~fsLockScoreGated = (msg[8] ? 0).clip(0, 1);
		~fsReleaseCommand = releaseCmd;
			~fsIntegratedAge = msg[10] ? 0;
			~fsFieldImprint = (msg[11] ? 0).clip(0, 1);
			imprint = ~fsFieldImprint;
			~fsCrossingGamma = msg[12] ? 0;
			~fsCrossingArea = msg[13] ? 0;

			// RELEASING or COOLDOWN: ignore lock detector and force the drone down.
			if(((state == 4) or: { state == 5 }) and: { state > 0 }, {
				~fsCanSpawn = false;
				~fsGateOpen = false;
				if(~floquetDroneSynth.notNil and: { ~floquetDroneSynth.isPlaying }, {
					if(~floquetDissolutionRoutine.isNil and: { (~floquetDissolutionActive ? false).not }, {
						("=== Floquet lifecycle release -> dissolution: state=" ++ state ++ " env=" ++ env.round(0.001)).postln;
						~startFloquetDissolution.();
					});
				}, {
					if(~floquetDissolutionRoutine.isNil and: { (~floquetDissolutionActive ? false).not }, {
						("=== Floquet lifecycle release -> ghost dissolution: state=" ++ state).postln;
						~startFloquetDissolution.();
					});
				});
			}, {
					~fsCanSpawn = ((state == 2) or: { state == 3 } or: { state == 6 });
					if((state == 2) or: { state == 3 }, {
						~spawnFloquetDroneFromLifecycle.(env);
					});
					if((state == 6) and: { ~floquetDroneSynth.isNil or: { ~floquetDroneSynth.isPlaying.not } }, {
						"=== Crossing arrival with no live drone: spawning interior voice ===".postln;
						~spawnFloquetDroneFromLifecycle.(max(env, 0.4));
					});
					if(~floquetDroneSynth.notNil and: { ~floquetDroneSynth.isPlaying }, {
						if((state == 2) or: { state == 3 }, { ~cancelFloquetDissolution.(); });
						if(state == 6, {
							if(~floquetDissolutionRoutine.isNil, {
								var g, gMag, gPos;
								g = ~fsCrossingGamma ? 0;
								gMag = (g.abs.min(pi)) / pi;
								gPos = if(g >= 0, { 1.0 }, { 0.0 });
								integratedAmp = (~droneGain.() * (0.060 + (0.080 * gMag))).clip(0, 0.065);
								~floquetDroneSynth.set(
									\strength, 0.045 + (0.085 * gMag),
									\amp, integratedAmp,
									\warmth, 0.55 + (0.30 * gMag),
									\detune, 0.0012 + (0.0035 * gMag * (0.4 + (0.6 * gPos))),
									\harmonics, (2 + (2 * gMag)).clip(2, 4),
									\topoDepth, ((~fsTopoDepth ? 0) * (0.5 + (0.5 * gMag))).clip(0, 0.35)
								);
							});
					}, {
						if(~floquetDissolutionRoutine.isNil, {
							~floquetDroneSynth.set(\strength, 0.18 * env, \amp, ~droneGain.() * 0.36 * max(env, 0.05));
						});
					});
				});
			});
	}, '/rdf/floquet_lifecycle');

	OSCdef(\floquetMixSync, { |msg|
		var rootFreq = msg[3];
		if(~floquetDroneSynth.notNil && ~floquetDroneSynth.isPlaying, {
			~floquetDroneSynth.set(\freq, rootFreq);
		});
	}, '/rdf/mix');

	~shutdownFloquetDrone = {
		~cancelFloquetDissolution.();
		OSCdef(\floquetDrive).free;
		OSCdef(\floquetClock).free;
		OSCdef(\floquetOrb).free;
		OSCdef(\floquetLifecycle).free;
		OSCdef(\floquetMixSync).free;
		if(~floquetDroneSynth.notNil, {
			~floquetDroneSynth.set(\gate, 0);
			~floquetDroneSynth = nil;
		});
		"=== Floquet drone system shut down ===".postln;
	};

	"=== Floquet drone OSC receivers active ===".postln;
	"    /rdf/floquet_drive  — receives Fourier coefficients".postln;
	"    /rdf/floquet_clock  — Floquet clock + spawn gate".postln;
	"    /rdf/floquet_orb    — orb stability metrics".postln;
	"    /rdf/floquet_lifecycle — lock/inject/release/cooldown commands".postln;
	"    /rdf/choirVol       — set choir volume 0.0-1.0".postln;
	"    /rdf/choirToggle    — 1=choir on, 0=choir off".postln;
	"    Call ~shutdownFloquetDrone.value to cleanly remove".postln;

	// ========== START ==========
	// ========== SC → PROCESSING STATUS BROADCAST ==========
	~processingAddr = NetAddr("127.0.0.1", 12000);
	if(~scStatusRoutine.notNil, { ~scStatusRoutine.stop; });
	~scStatusRoutine = Routine({
		loop({
			var voiceCount, glassAge, droneAlive, saturation, holdStr, lifecycleState;
			voiceCount = (~estimatedVoiceLoad.() + (~arpBurstInflight ? 0)).clip(0, 99);
			glassAge = (Main.elapsedTime - (~lastGlassTrigTime ? 0)).clip(0, 60).round(0.1);
			droneAlive = if(~floquetDroneSynth.notNil and: { ~floquetDroneSynth.isPlaying }, { 1.0 }, { 0.0 });
			saturation = (voiceCount / 10.0).clip(0, 1);
			holdStr = (~fsHoldStrength ? 0.0).clip(0, 1);
			lifecycleState = (~fsLifecycleState ? 1).asInteger;
			~processingAddr.sendMsg('/sc/state',
				voiceCount.asFloat,
				droneAlive,
				glassAge,
				saturation,
				holdStr,
				lifecycleState.asFloat
			);
			2.5.wait;
		});
	}).play(AppClock);
	"=== SC status broadcast active: /sc/state -> Processing :12000 every 2.5s ===".postln;

	~visualPlayer.();
	//~startDrone.();
	"=== RDF System: separated field architecture build ===".postln;
	"Base field = Drone / Arp / Glass / Choir. Ocean = sensed water/current resonance. Solar = light shimmer/breath.".postln;
	"Make sure Processing is using port: ".post; ~oscPort.postln;
		"Floquet lifecycle auto-injects on lock/inject states; /rdf/droneSpawn and /rdf/droneKill are manual overrides.".postln;
	"Choir: ~choirOn.value / ~choirOff.value or send /rdf/choirToggle 1/0".postln;
});


// ========== CONVENIENCE FUNCTIONS ==========
~setDroneVolume = { |vol|
	~droneVolume = vol.clip(0, 1);
	~manualDroneVol = ~droneVolume;
	if(~droneManualArmed and: { ~droneSynth.notNil }, {
		~droneSynth.set(\amp, (~pendingDroneAmp ? 0).clip(0, 0.20));
	});
	"Drone volume target: ".post; ~droneVolume.postln;
};
~setArpVolume   = { |vol| ~arpVolume   = vol.clip(0, 1); "Arp volume: ".post;   ~arpVolume.postln; };
~setGlassVolume = { |vol| ~glassVolume = vol.clip(0, 1); "Glass volume: ".post; ~glassVolume.postln; };
~setChoirVolume = { |vol| ~choirVolume = vol.clip(0, 1); "Choir volume: ".post; ~choirVolume.postln; };

~choirOn = {
	~choirVolume = (~choirVolume.max(0.20));
	"Choir ON vol=".post; ~choirVolume.postln;
};

~choirOff = {
	if(~choirSynth.notNil and: { ~choirSynth.isPlaying }, {
		~choirSynth.set(\amp, 0, \gate, 0);
		~choirSynth = nil;
	});
	if(~choirGroup.notNil, { ~choirGroup.freeAll; });
	~choirVolume = 0.0;
	"Choir OFF".postln;
};
