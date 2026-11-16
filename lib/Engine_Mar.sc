// Engine_Mar.sc - Motor de umi v5.5 (versión simple)
// Cadena de señal: cada nota sale al bus de su personaje -> pasa por SU
// filtro persistente (los tres comparten el mismo corte) -> salida de
// hardware. El viento va aparte, directo a la salida.
// Tucker: tres timbres de un disparo (Dream / Bell / Gauss).
// Mobba: un timbre (Pulse con sub). Lea (K2): voz Blip sostenida.
// La versión anterior (legato, Bit Crusher, Tape, más timbres) quedó en
// Engine_Mar_v5.4_respaldo.sc.
Engine_Mar : CroneEngine {
    var <windSynth;
    var <windGroup, <noteGroup, <filterGroup;

    var boatSynthNames;

    var boatBus, whaleBus, birdBus;
    var filterCutoffBus;
    var leaSoloFreqBus;

    var leaSoloSynth;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        noteGroup = Group.new(context.xg);
        filterGroup = Group.after(noteGroup);
        windGroup = Group.after(filterGroup);

        boatSynthNames = [\boatDream, \boatFM, \boatLFGauss];

        boatBus = Bus.audio(context.server, 2);
        whaleBus = Bus.audio(context.server, 2);
        birdBus = Bus.audio(context.server, 2);

        filterCutoffBus = Bus.control(context.server, 1);
        leaSoloFreqBus = Bus.control(context.server, 1);

        filterCutoffBus.set(3000);
        leaSoloFreqBus.set(440);

        // --- RUIDO DE VIENTO LEVE (sin filtrar, directo a hardware) ---
        SynthDef(\marWind, {
            arg out=0, amp=0.02, freq=400;
            var noise, filtered;
            noise = WhiteNoise.ar(amp);
            filtered = BPF.ar(noise, Lag.kr(freq, 0.5), 0.3);
            Out.ar(out, filtered ! 2);
        }).add;

        // ============================================================
        // TUCKER (barco): Dream / Bell / Gauss
        // ============================================================
        // "Dream": el barco del primer Mar (VarSaw angosta, filtro que
        // sigue a la nota).
        SynthDef(\boatDream, {
            arg out=0, freq=440, amp=0.3, release=0.4;
            var env, sig;
            env = EnvGen.kr(Env.perc(0.01, release), doneAction: 2);
            sig = VarSaw.ar(freq, 0, 0.2);
            sig = LPF.ar(sig, freq * 3);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        SynthDef(\boatFM, {
            arg out=0, freq=440, amp=0.3, release=0.4;
            var env, idxEnv, sig, modFreq;
            env = EnvGen.kr(Env.perc(0.01, release), doneAction: 2);
            // el índice de modulación decae más rápido que la
            // amplitud: el brillo-que-se-apaga de una campana FM.
            idxEnv = EnvGen.kr(Env.perc(0.005, release * 0.6));
            modFreq = freq * 1.4; // ratio inarmónico, timbre de campana
            sig = SinOsc.ar(freq + (SinOsc.ar(modFreq) * modFreq * idxEnv * 3));
            Out.ar(out, (sig * env * amp * 0.7) ! 2);
        }).add;

        SynthDef(\boatLFGauss, {
            arg out=0, freq=440, amp=0.3, release=0.4;
            var env, sig, dur;
            env = EnvGen.kr(Env.perc(0.01, release), doneAction: 2);
            dur = (1 / freq).clip(0.0001, 1);
            sig = LFGauss.ar(dur, 0.15, 0, 1, 0, loop: 1);
            sig = HPF.ar(sig, 20);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        // ============================================================
        // MOBBA (ballena): Pulse con sub
        // ============================================================
        SynthDef(\whalePulse, {
            arg out=0, freq=110, amp=0.5, release=0.8;
            var env, sig, sub;
            env = EnvGen.kr(Env.perc(0.05, release), doneAction: 2);
            sig = Pulse.ar(freq, 0.4);
            sub = SinOsc.ar(freq / 2) * 0.5;
            sig = LPF.ar(sig + sub, freq * 1.5);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        // ============================================================
        // LEA (solo de K2): voz Blip sostenida, propia
        // ============================================================
        SynthDef(\birdBlipSustain, {
            arg out=0, freqBus=0, amp=0.5, glideTime=0.1, gate=1, release=0.2;
            var env, freq, sig;
            freq = Lag.kr(In.kr(freqBus), glideTime);
            env = EnvGen.kr(Env.asr(0.02, 1, release), gate, doneAction: 2);
            sig = Blip.ar(freq, 6, 0.3);
            sig = HPF.ar(sig, 500);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        // ============================================================
        // FILTRO PERSISTENTE POR PERSONAJE
        // ============================================================
        SynthDef(\entityFilter, {
            arg inBus=0, outBus=0, cutoffBus=0;
            var sig, cutoff;
            cutoff = In.kr(cutoffBus).lag(0.05).clip(100, 5000);
            sig = In.ar(inBus, 2);
            sig = RLPF.ar(sig, cutoff, 0.5);
            Out.ar(outBus, sig);
        }).add;

        context.server.sync;

        windSynth = Synth(\marWind, [\amp, 0.015, \freq, 300], target: windGroup);

        // Filtros persistentes, uno por personaje, todos leyendo el
        // mismo cutoffBus, directo a la salida de hardware.
        Synth(\entityFilter, [\inBus, boatBus, \outBus, 0, \cutoffBus, filterCutoffBus], target: filterGroup);
        Synth(\entityFilter, [\inBus, whaleBus, \outBus, 0, \cutoffBus, filterCutoffBus], target: filterGroup);
        Synth(\entityFilter, [\inBus, birdBus, \outBus, 0, \cutoffBus, filterCutoffBus], target: filterGroup);

        // --- NOTA DE TUCKER: freq, amp, synth_idx (1-3), release ---
        this.addCommand("boat_note", "ffff", { arg msg;
            var freq = msg[1].clip(20, 20000);
            var amp = msg[2].clip(0, 1);
            var idx = msg[3].round.asInteger.clip(1, boatSynthNames.size);
            var release = msg[4].clip(0.02, 4.0);
            Synth(boatSynthNames[idx - 1], [\out, boatBus, \freq, freq, \amp, amp, \release, release], target: noteGroup);
        });

        // --- NOTA DE MOBBA: freq, amp, release ---
        this.addCommand("whale_note", "fff", { arg msg;
            var freq = msg[1].clip(20, 20000);
            var amp = msg[2].clip(0, 1);
            var release = msg[3].clip(0.02, 4.0);
            Synth(\whalePulse, [\out, whaleBus, \freq, freq, \amp, amp, \release, release], target: noteGroup);
        });

        this.addCommand("set_wind", "ff", { arg msg;
            var amp = msg[1].clip(0, 1);
            var freq = msg[2].clip(20, 20000);
            windSynth.set(\amp, amp, \freq, freq);
        });

        // --- SOLO DE LEA (K2): voz Blip sostenida, enrutada a birdBus ---
        this.addCommand("set_lea_solo", "ff", { arg msg;
            var onOff = msg[1] > 0;
            var release = msg[2].clip(0.05, 6.0);
            if (onOff) {
                if (leaSoloSynth.notNil) { leaSoloSynth.set(\gate, 0); };
                leaSoloSynth = Synth(\birdBlipSustain, [\out, birdBus, \freqBus, leaSoloFreqBus, \release, release], target: noteGroup);
            } {
                if (leaSoloSynth.notNil) {
                    leaSoloSynth.set(\gate, 0);
                    leaSoloSynth = nil;
                };
            };
        });

        this.addCommand("lea_solo_freq", "f", { arg msg;
            leaSoloFreqBus.set(msg[1].clip(20, 20000));
        });

        this.addCommand("set_filter_cutoff", "f", { arg msg;
            filterCutoffBus.set(msg[1].clip(100, 5000));
        });
    }

    free {
        noteGroup.free;
        filterGroup.free;
        windGroup.free;
        boatBus.free;
        whaleBus.free;
        birdBus.free;
        filterCutoffBus.free;
        leaSoloFreqBus.free;
    }
}
