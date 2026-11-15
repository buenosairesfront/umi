// Engine_Mar.sc - Motor de Síntesis Audiovisual v5.4
// Cadena de señal: cada nota sale a su propio bus -> pasa por SU filtro
// persistente -> se suma en mixBus -> pasa por la etapa "fx" (No /
// Bit Crusher, una sola corre a la vez) -> pasa por la etapa
// "out mode" (Normal / Tape, una sola corre a la vez) ->
// salida de hardware. El viento va aparte, directo a la salida.
// Tucker tiene una voz persistente de legato (portamento real): cuando
// está activa, en vez de disparar una nota nueva por evento, se desliza
// la frecuencia de esa voz sostenida. El solo de Lea (K2) usa su propia
// voz sostenida Blip, por birdBus.
Engine_Mar : CroneEngine {
    var <windSynth;
    var <windGroup, <noteGroup, <filterGroup, <fxTypeGroup, <outModeGroup;

    var boatSynthNames;
    var whaleSynthNames;
    var boatLegatoSustainNames;
    var fxTypeSynthNames;
    var outModeSynthNames;

    var boatBus, whaleBus, birdBus, mixBus, fxStageBus;
    var filterCutoffBus;
    var crushBitsBus, crushRateBus;
    var fxAmountBus;
    var boatLegatoFreqBus;
    var leaSoloFreqBus;

    var currentFxTypeSynth;
    var currentOutModeSynth;
    var boatLegatoSynth;
    var leaSoloSynth;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        noteGroup = Group.new(context.xg);
        filterGroup = Group.after(noteGroup);
        fxTypeGroup = Group.after(filterGroup);
        outModeGroup = Group.after(fxTypeGroup);
        windGroup = Group.after(outModeGroup);

        boatSynthNames = [\boatLFSaw, \boatFM, \boatLFGauss, \boatDream];
        whaleSynthNames = [\whalePulse, \whaleSaw, \whaleSinOsc];
        boatLegatoSustainNames = [\boatLFSawSustain, \boatFMSustain, \boatLFGaussSustain, \boatDreamSustain];
        fxTypeSynthNames = [\fxNone, \fxBitCrusher];
        outModeSynthNames = [\outNormal, \marTape];

        boatBus = Bus.audio(context.server, 2);
        whaleBus = Bus.audio(context.server, 2);
        birdBus = Bus.audio(context.server, 2);
        mixBus = Bus.audio(context.server, 2);
        fxStageBus = Bus.audio(context.server, 2);

        filterCutoffBus = Bus.control(context.server, 1);
        crushBitsBus = Bus.control(context.server, 1);
        crushRateBus = Bus.control(context.server, 1);
        fxAmountBus = Bus.control(context.server, 1);
        boatLegatoFreqBus = Bus.control(context.server, 1);
        leaSoloFreqBus = Bus.control(context.server, 1);

        filterCutoffBus.set(3000);
        crushBitsBus.set(16);
        crushRateBus.set(48000);
        fxAmountBus.set(0.3);
        boatLegatoFreqBus.set(440);
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
        // TUCKER (barco): LFSaw / FM Bell / LFGauss — versión de un
        // solo disparo (arp/gen normal)
        // ============================================================
        SynthDef(\boatLFSaw, {
            arg out=0, freq=440, amp=0.3, release=0.4;
            var env, sig;
            env = EnvGen.kr(Env.perc(0.01, release), doneAction: 2);
            sig = LFSaw.ar(freq, 0, 0.3);
            sig = LPF.ar(sig, freq * 3);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        SynthDef(\boatFM, {
            arg out=0, freq=440, amp=0.3, release=0.4;
            var env, idxEnv, sig, modFreq;
            env = EnvGen.kr(Env.perc(0.01, release), doneAction: 2);
            // el índice de modulación decae más rápido que la
            // amplitud: da el clásico brillo-que-se-apaga de una
            // campana FM, distinto del carácter de LFSaw/LFGauss.
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

        // "Dream": el barco del primer Mar (VarSaw angosta, filtro que
        // sigue a la nota), tal cual sonaba en el motor original.
        SynthDef(\boatDream, {
            arg out=0, freq=440, amp=0.3, release=0.4;
            var env, sig;
            env = EnvGen.kr(Env.perc(0.01, release), doneAction: 2);
            sig = VarSaw.ar(freq, 0, 0.2);
            sig = LPF.ar(sig, freq * 3);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        // --- TUCKER: versiones sostenidas para legato (portamento) ---
        SynthDef(\boatDreamSustain, {
            arg out=0, freqBus=0, amp=0.22, glideTime=0.12, gate=1, release=0.3;
            var env, freq, sig;
            freq = Lag.kr(In.kr(freqBus), glideTime);
            env = EnvGen.kr(Env.asr(0.05, 1, release), gate, doneAction: 2);
            sig = VarSaw.ar(freq, 0, 0.2);
            sig = LPF.ar(sig, freq * 3);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        SynthDef(\boatLFSawSustain, {
            arg out=0, freqBus=0, amp=0.22, glideTime=0.12, gate=1, release=0.3;
            var env, freq, sig;
            freq = Lag.kr(In.kr(freqBus), glideTime);
            env = EnvGen.kr(Env.asr(0.05, 1, release), gate, doneAction: 2);
            sig = LFSaw.ar(freq, 0, 0.3);
            sig = LPF.ar(sig, freq * 3);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        SynthDef(\boatFMSustain, {
            arg out=0, freqBus=0, amp=0.16, glideTime=0.12, gate=1, release=0.3;
            var env, freq, sig, modFreq;
            freq = Lag.kr(In.kr(freqBus), glideTime);
            env = EnvGen.kr(Env.asr(0.05, 1, release), gate, doneAction: 2);
            modFreq = freq * 1.4;
            sig = SinOsc.ar(freq + (SinOsc.ar(modFreq) * modFreq * 2));
            Out.ar(out, (sig * env * amp * 0.7) ! 2);
        }).add;

        SynthDef(\boatLFGaussSustain, {
            arg out=0, freqBus=0, amp=0.22, glideTime=0.12, gate=1, release=0.3;
            var env, freq, sig, dur;
            freq = Lag.kr(In.kr(freqBus), glideTime);
            env = EnvGen.kr(Env.asr(0.05, 1, release), gate, doneAction: 2);
            dur = (1 / freq).clip(0.0001, 1);
            sig = LFGauss.ar(dur, 0.15, 0, 1, 0, loop: 1);
            sig = HPF.ar(sig, 20);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        // ============================================================
        // MOBBA (ballena): Pulse / Saw / SinOsc — sin legato
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

        SynthDef(\whaleSaw, {
            arg out=0, freq=110, amp=0.5, release=0.8;
            var env, sig, sub;
            env = EnvGen.kr(Env.perc(0.05, release), doneAction: 2);
            sig = Saw.ar(freq);
            sub = SinOsc.ar(freq / 2) * 0.5;
            sig = LPF.ar(sig + sub, freq * 1.5);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        SynthDef(\whaleSinOsc, {
            arg out=0, freq=110, amp=0.5, release=0.8;
            var env, sig, sub;
            env = EnvGen.kr(Env.perc(0.05, release), doneAction: 2);
            sig = SinOsc.ar(freq);
            sub = SinOsc.ar(freq / 2) * 0.5;
            sig = LPF.ar(sig + sub, freq * 1.5);
            Out.ar(out, (sig * env * amp) ! 2);
        }).add;

        // ============================================================
        // LEA (solo de K2): voz Blip sostenida, propia
        // ============================================================
        SynthDef(\birdBlipSustain, {
            arg out=0, freqBus=0, amp=0.18, glideTime=0.1, gate=1, release=0.2;
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

        // ============================================================
        // ETAPA "FX": No / Bit Crusher (una sola corre a la vez)
        // ============================================================
        SynthDef(\fxNone, {
            arg inBus=0, out=0;
            Out.ar(out, In.ar(inBus, 2));
        }).add;

        SynthDef(\fxBitCrusher, {
            arg inBus=0, out=0, bitsBus=0, rateBus=0;
            var sig;
            sig = In.ar(inBus, 2);
            sig = Decimator.ar(sig, In.kr(rateBus).lag(0.05), In.kr(bitsBus).lag(0.05));
            Out.ar(out, sig);
        }).add;

        // ============================================================
        // ETAPA "OUT MODE": Normal / Tape (una sola corre)
        // ============================================================
        SynthDef(\outNormal, {
            arg inBus=0, out=0;
            Out.ar(out, In.ar(inBus, 2));
        }).add;

        SynthDef(\marTape, {
            arg inBus=0, out=0, amountBus=0;
            var dry, wobble, tapeSig, amount;
            dry = In.ar(inBus, 2);
            amount = In.kr(amountBus).lag(0.05);
            wobble = SinOsc.kr(0.6).range(0.001, 0.004);
            tapeSig = DelayC.ar(dry, 0.02, wobble);
            tapeSig = (tapeSig * (1 + (amount * 2))).tanh;
            Out.ar(out, dry + ((tapeSig - dry) * amount));
        }).add;

        context.server.sync;

        windSynth = Synth(\marWind, [\amp, 0.015, \freq, 300], target: windGroup);

        // Filtros persistentes, uno por personaje, todos leyendo el
        // mismo cutoffBus, escribiendo en mixBus.
        Synth(\entityFilter, [\inBus, boatBus, \outBus, mixBus, \cutoffBus, filterCutoffBus], target: filterGroup);
        Synth(\entityFilter, [\inBus, whaleBus, \outBus, mixBus, \cutoffBus, filterCutoffBus], target: filterGroup);
        Synth(\entityFilter, [\inBus, birdBus, \outBus, mixBus, \cutoffBus, filterCutoffBus], target: filterGroup);

        // fx inicial: "No" (índice 1). mixBus -> fxStageBus
        currentFxTypeSynth = Synth(fxTypeSynthNames[0], [
            \inBus, mixBus, \out, fxStageBus,
            \bitsBus, crushBitsBus, \rateBus, crushRateBus
        ], target: fxTypeGroup);

        // out mode inicial: "Normal" (índice 1). fxStageBus -> hardware out
        currentOutModeSynth = Synth(outModeSynthNames[0], [
            \inBus, fxStageBus, \out, 0, \amountBus, fxAmountBus
        ], target: outModeGroup);

        // --- COMANDOS DE NOTA: freq, amp, synth_idx (1-3), release ---
        this.addCommand("boat_note", "ffff", { arg msg;
            var freq = msg[1].clip(20, 20000);
            var amp = msg[2].clip(0, 1);
            var idx = msg[3].round.asInteger.clip(1, boatSynthNames.size);
            var release = msg[4].clip(0.02, 4.0);
            Synth(boatSynthNames[idx - 1], [\out, boatBus, \freq, freq, \amp, amp, \release, release], target: noteGroup);
        });

        this.addCommand("whale_note", "ffff", { arg msg;
            var freq = msg[1].clip(20, 20000);
            var amp = msg[2].clip(0, 1);
            var idx = msg[3].round.asInteger.clip(1, whaleSynthNames.size);
            var release = msg[4].clip(0.02, 4.0);
            Synth(whaleSynthNames[idx - 1], [\out, whaleBus, \freq, freq, \amp, amp, \release, release], target: noteGroup);
        });

        this.addCommand("set_wind", "ff", { arg msg;
            var amp = msg[1].clip(0, 1);
            var freq = msg[2].clip(20, 20000);
            windSynth.set(\amp, amp, \freq, freq);
        });

        // --- COMANDOS DE LEGATO (Tucker y Lea) ---
        this.addCommand("set_boat_legato", "fff", { arg msg;
            var onOff = msg[1] > 0;
            var idx = msg[2].round.asInteger.clip(1, boatLegatoSustainNames.size);
            var release = msg[3].clip(0.02, 4.0);
            if (onOff) {
                if (boatLegatoSynth.notNil) { boatLegatoSynth.set(\gate, 0); };
                boatLegatoSynth = Synth(boatLegatoSustainNames[idx - 1], [\out, boatBus, \freqBus, boatLegatoFreqBus, \release, release], target: noteGroup);
            } {
                if (boatLegatoSynth.notNil) {
                    boatLegatoSynth.set(\gate, 0);
                    boatLegatoSynth = nil;
                };
            };
        });

        this.addCommand("boat_legato_freq", "f", { arg msg;
            boatLegatoFreqBus.set(msg[1].clip(20, 20000));
        });

        this.addCommand("boat_legato_release", "f", { arg msg;
            if (boatLegatoSynth.notNil) { boatLegatoSynth.set(\release, msg[1].clip(0.02, 4.0)); };
        });

        // --- MODO SOLO DE LEA (K2 en la página Mar): voz Blip sostenida
        // propia, enrutada a birdBus.
        this.addCommand("set_lea_solo", "ff", { arg msg;
            var onOff = msg[1] > 0;
            var release = msg[2].clip(0.05, 6.0);
            if (onOff) {
                if (leaSoloSynth.notNil) { leaSoloSynth.set(\gate, 0); };
                // Blip propio (no el LFSaw de Tucker): así Lea nunca
                // comparte timbre con él sin importar qué synth tenga
                // Tucker seleccionado.
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

        // --- COMANDOS DE LA PÁGINA SEAN ---
        this.addCommand("set_filter_cutoff", "f", { arg msg;
            filterCutoffBus.set(msg[1].clip(100, 5000));
        });

        this.addCommand("set_fx_type", "f", { arg msg;
            var idx = msg[1].round.asInteger.clip(1, fxTypeSynthNames.size);
            var old = currentFxTypeSynth;
            currentFxTypeSynth = Synth(fxTypeSynthNames[idx - 1], [
                \inBus, mixBus, \out, fxStageBus,
                \bitsBus, crushBitsBus, \rateBus, crushRateBus
            ], target: fxTypeGroup);
            old.free;
        });

        this.addCommand("set_crush", "ff", { arg msg;
            crushBitsBus.set(msg[1].clip(1, 16));
            crushRateBus.set(msg[2].clip(800, 48000));
        });

        this.addCommand("set_out_mode", "f", { arg msg;
            var idx = msg[1].round.asInteger.clip(1, outModeSynthNames.size);
            var old = currentOutModeSynth;
            currentOutModeSynth = Synth(outModeSynthNames[idx - 1], [
                \inBus, fxStageBus, \out, 0, \amountBus, fxAmountBus
            ], target: outModeGroup);
            old.free;
        });

        this.addCommand("set_fx_amount", "f", { arg msg;
            fxAmountBus.set(msg[1].clip(0, 1));
        });
    }

    free {
        noteGroup.free;
        filterGroup.free;
        fxTypeGroup.free;
        outModeGroup.free;
        windGroup.free;
        boatBus.free;
        whaleBus.free;
        birdBus.free;
        mixBus.free;
        fxStageBus.free;
        filterCutoffBus.free;
        crushBitsBus.free;
        crushRateBus.free;
        fxAmountBus.free;
        boatLegatoFreqBus.free;
        leaSoloFreqBus.free;
    }
}