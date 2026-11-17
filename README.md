**English** · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [日本語](README.ja.md) · [中文](README.zh.md) · [हिन्दी](README.hi.md)

# umi

A sea that plays itself, for [monome norns](https://monome.org/docs/norns/).
*Umi* (海) means "sea" in Japanese. Three characters live on one screen and each
one is a voice: the waves decide the notes, and you steer the weather.

![umi, all screens](docs/sheet.png)

- **Tucker**, the sailboat, rides the surface: the height of the wave under
  him is his note
- **Mobba**, the whale, swims below with her own slower line and sings back
  with an echo on K3
- **Lea**, the bird, only appears while you hold K2: a gliding legato solo
- **Sean** is the sea itself: scale, root and one filter shared by every voice
- each voice plays an **arpeggio** that follows the wave or a **generative**
  walk through the scale; moving a character sideways transposes it
- the swell sets the number of steps: calm sea = 2 notes, big waves = 16
- a constant wind layer that grows with the swell
- follows the norns clock (internal, MIDI, Link or crow); every setting is a
  parameter (MIDI-mappable, saved in PSETs) and the last state is remembered

## Requirements

- norns (any: shield, standard or fates)
- nothing else: umi plays on its own as soon as it loads

## Install

From maiden:

```
;install https://github.com/buenosairesfront/umi
```

Then **restart norns** (SYSTEM > RESTART) so the new engine `Mar` is
compiled, and load **umi** from SELECT.

> If you have an older script called **mar** installed, remove it first
> (`dust/code/mar`): both ship an engine named `Mar` and SuperCollider will
> refuse to compile two classes with the same name.

## Controls

Any key or encoder skips the intro.

### The sea

![the sea](docs/1_sea.png)

| control | action |
|---|---|
| E1 | wind: from flat calm to big waves (does not change the note speed: the clock sets that) |
| E2 | move Tucker left / right (transposes his line −8…+8 scale steps) |
| E3 | move Mobba left / right (same, for her) |
| K2 held | Lea flies in and plays a solo; E2 moves her; let go and she leaves slowly |
| K3 | Mobba sings a note near where she is, and half a second later the sea returns it as an echo, a fifth lower |
| K1 held | opens the panel (see below) |

![big waves](docs/2_waves.png)

![Lea's solo](docs/3_lea.png)

![Mobba sings](docs/4_mobba_sings.png)

### Panel (K1 held)

While K1 is held a single panel slides in: one list of six settings.

| control | action |
|---|---|
| E2 | choose a setting |
| E3 | change it |

E1 is still the wind while the panel is open.

| setting | values |
|---|---|
| tucker | off / Dream / Bell / Gauss (his voice) |
| mobba | off / on |
| mode | arp / gen, for both |
| scale | major, minors, modes, pentatonics, whole tone, blues, gypsy minor |
| root | C … B |
| filter | 100–5000 Hz |

Tempo and clock source are the norns ones (PARAMETERS > CLOCK).

### Saving

The six settings are also in PARAMETERS > UMI, so they can be MIDI-mapped
and saved in a PSET. On exit the current state is written to
`~/dust/data/umi/umi_estado.pset` and comes back next time.

<!-- u-ma:more -->
**More from U-MA:** every instrument and tool in one place → [U-MA showcase](https://github.com/buenosairesfront/U-ma)
<!-- /u-ma:more -->

## Credits

Made by [Buenos Aires Front](https://github.com/buenosairesfront) / U-MA.
Released under the MIT license.
