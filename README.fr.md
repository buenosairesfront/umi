[English](README.md) · [Español](README.es.md) · **Français** · [Deutsch](README.de.md) · [日本語](README.ja.md) · [中文](README.zh.md) · [हिन्दी](README.hi.md)

# umi

Une mer qui joue toute seule, pour [monome norns](https://monome.org/docs/norns/).
*Umi* (海) veut dire « mer » en japonais. Trois personnages vivent sur l'écran et
chacun est une voix : les vagues choisissent les notes, vous pilotez la météo.

![umi, tous les écrans](docs/sheet.png)

- **Tucker**, le voilier, glisse sur la surface : la hauteur de la vague sous
  lui est sa note
- **Mobba**, la baleine, nage en dessous avec sa propre ligne, plus lente, et
  chante avec un écho sur K3
- **Lea**, l'oiseau, n'apparaît que tant que vous maintenez K2 : un solo
  legato qui plane
- **Sean**, c'est la mer elle-même : tempo, gamme, tonique, filtre, marée
  aléatoire, bit crusher et sortie bande
- chaque voix joue un **arpège** qui suit la vague ou une promenade
  **générative** dans la gamme ; déplacer un personnage sur le côté le transpose
- la houle fixe le nombre de pas : mer calme = 2 notes, grosses vagues = 16
- une couche de vent constante qui grandit avec la houle
- suit l'horloge de norns (interne, MIDI, Link ou crow) ; chaque réglage est un
  paramètre (assignable en MIDI, sauvegardé dans les PSET) et le dernier état
  est mémorisé

## Prérequis

- norns (n'importe laquelle : shield, standard ou fates)
- rien d'autre : umi joue tout seul dès le chargement

## Installation

Depuis maiden :

```
;install https://github.com/buenosairesfront/umi
```

Ensuite **redémarrez norns** (SYSTEM > RESTART) pour compiler le nouveau
moteur `Mar`, puis chargez **umi** depuis SELECT.

> Si un ancien script nommé **mar** est installé, supprimez-le d'abord
> (`dust/code/mar`) : les deux contiennent un moteur nommé `Mar` et
> SuperCollider refuse de compiler deux classes du même nom.

## Commandes

N'importe quelle touche ou encodeur passe l'intro.

### La mer

![la mer](docs/1_sea.png)

| commande | action |
|---|---|
| E1 | vent : du calme plat aux grosses vagues (fixe aussi le nombre de pas de chaque voix) |
| E2 | déplace Tucker à gauche / à droite (transpose sa ligne de −8 à +8 degrés) |
| E3 | déplace Mobba à gauche / à droite (pareil, pour elle) |
| K2 maintenu | Lea arrive en volant et joue un solo ; E2 la déplace ; au relâchement elle repart lentement |
| K3 | Mobba chante une note proche de sa position, et une demi-seconde plus tard la mer la renvoie en écho, une quinte plus bas |
| K1 maintenu | ouvre le panneau du personnage choisi (voir plus bas) |

![grosses vagues](docs/2_waves.png)

![le solo de Lea](docs/3_lea.png)

![Mobba chante](docs/4_mobba_sings.png)

### Panneaux (K1 maintenu)

Tant que K1 est maintenu, la scène zoome sur un personnage et un panneau glisse
à l'écran.

| commande | action |
|---|---|
| E1 | choisir le personnage : Tucker, Mobba, Sean |
| E2 | choisir un élément |
| E3 | le modifier |

![Tucker](docs/5_tucker.png)

**Tucker** — on/off · mode (arp / gen) · synth (LFSaw, FM Bell, LFGauss,
Dream) · tail (durée des notes, en mode arp seulement) · legato.

![Mobba](docs/6_mobba.png)

**Mobba** — on/off · mode (arp / gen) · synth (Pulse, Saw, SinOsc) · tail.

![Sean](docs/7_sean.png)

**Sean** — tempo · sync (source d'horloge) · speed (×1/4 … ×4) · filter ·
random (une marée qui accélère et ralentit d'elle-même) · root · gamme
(majeure, mineures, modes, pentatoniques, tons entiers, blues, mineure
tzigane) · fx (aucun / bit crusher, avec bits et rate) · out mode (normal /
tape, avec amount).

### Sauvegarde

Tout ce qui est dans les panneaux se trouve aussi dans PARAMETERS > MAR : on
peut l'assigner en MIDI et le sauvegarder dans les PSET. En quittant le
script, l'état courant est enregistré dans `~/dust/data/umi/mar_estado.pset`
et revient la fois suivante.

<!-- u-ma:more -->
**Plus de U-MA :** tous les instruments et outils au même endroit → [vitrine U-MA](https://github.com/buenosairesfront/U-ma/blob/main/README.fr.md)
<!-- /u-ma:more -->

## Crédits

Réalisé par [Buenos Aires Front](https://github.com/buenosairesfront) / U-MA.
Publié sous licence MIT.
