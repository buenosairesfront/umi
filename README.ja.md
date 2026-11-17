[English](README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **日本語** · [中文](README.zh.md) · [हिन्दी](README.hi.md)

# umi

ひとりでに鳴る海。[monome norns](https://monome.org/docs/norns/) 用。
画面には 3 つのキャラクターが暮らしていて、それぞれがひとつの声です。
音を決めるのは波、あなたが動かすのは天気です。

![umi、全画面](docs/sheet.png)

- **Tucker**（ヨット）は海面を進みます。足もとの波の高さが彼の音
- **Mobba**（クジラ）は海中を自分のゆっくりしたラインで泳ぎ、K3 で歌うと
  こだまが返ってきます
- **Lea**（鳥）は K2 を押している間だけ現れる、滑空するレガートのソロ
- **Sean** は海そのもの：スケール、ルート、そして全声部が共有するフィルター
- 各声部は波に沿う**アルペジオ**か、スケールを歩く**ジェネレーティブ**を
  演奏。キャラクターを左右に動かすと移調します
- うねりがステップ数を決めます：凪 = 2 音、大波 = 16 音
- うねりとともに強くなる、絶えず吹く風のレイヤー
- norns のクロック（内部、MIDI、Link、crow）に追従。すべての設定はパラメーター
  （MIDI アサイン可、PSET に保存）で、最後の状態は自動で記憶されます

## 必要なもの

- norns（shield、standard、fates のどれでも）
- ほかには何もいりません。読み込むとすぐに umi は鳴り始めます

## インストール

maiden から：

```
;install https://github.com/buenosairesfront/umi
```

その後 **norns を再起動**（SYSTEM > RESTART）して新しいエンジン `Mar` を
コンパイルし、SELECT から **umi** を読み込みます。

> 以前の **mar** というスクリプトが入っている場合は、先に削除してください
> （`dust/code/mar`）。どちらも `Mar` という名前のエンジンを含んでおり、
> SuperCollider は同じ名前のクラスを 2 つコンパイルできません。

## 操作

イントロはどのキーやエンコーダーでもスキップできます。

### 海

![海](docs/1_sea.png)

| 操作 | 動作 |
|---|---|
| E1 | 風：凪から大波まで（音符の速さは変わりません。速さはクロックが決めます） |
| E2 | Tucker を左右に動かす（ラインをスケールで −8〜+8 度移調） |
| E3 | Mobba を左右に動かす（同じく彼女のライン） |
| K2 長押し | Lea が飛んできてソロを演奏。E2 で移動。離すとゆっくり去っていきます |
| K3 | Mobba が今いるあたりの音を歌い、0.5 秒後に海が 5 度下のこだまとして返します |
| K1 長押し | パネルを開く（下記） |

![大波](docs/2_waves.png)

![Lea のソロ](docs/3_lea.png)

![Mobba が歌う](docs/4_mobba_sings.png)

### パネル（K1 長押し）

K1 を押している間、パネルがひとつだけスライドして現れます。6 つの設定が
並んだ一覧です。

| 操作 | 動作 |
|---|---|
| E2 | 設定を選ぶ |
| E3 | 値を変える |

パネルを開いていても E1 は風のままです。

| 設定 | 値 |
|---|---|
| tucker | off / Dream / Bell / Gauss（声） |
| mobba | off / on |
| modo | arp / gen（ふたり共通） |
| escala | メジャー、各種マイナー、モード、ペンタトニック、全音音階、ブルース、ジプシー・マイナー |
| root | C … B |
| filter | 100〜5000 Hz |

テンポとクロックソースは norns のもの（PARAMETERS > CLOCK）を使います。

### 保存

6 つの設定は PARAMETERS > UMI にもあるので、MIDI にアサインしたり PSET に
保存したりできます。スクリプトを終了すると現在の状態が
`~/dust/data/umi/umi_estado.pset` に保存され、次回そのまま戻ります。

<!-- u-ma:more -->
**U-MA のほかの作品：** すべての楽器とツールをひとつに → [U-MA ショーケース](https://github.com/buenosairesfront/U-ma/blob/main/README.ja.md)
<!-- /u-ma:more -->

## クレジット

制作：[Buenos Aires Front](https://github.com/buenosairesfront) / U-MA。
MIT ライセンス。
