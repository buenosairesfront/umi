[English](README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [日本語](README.ja.md) · **中文** · [हिन्दी](README.hi.md)

# umi

一片会自己演奏的海，用于 [monome norns](https://monome.org/docs/norns/)。
*Umi*（海）在日语里就是“海”。屏幕上住着三个角色，每个都是一个声部：
海浪决定音符，你来掌控天气。

![umi，全部画面](docs/sheet.png)

- **Tucker** 是帆船，在海面上航行：他身下浪的高度就是他的音
- **Mobba** 是鲸鱼，在水下游着自己更慢的旋律线，按 K3 她会唱歌并带回声
- **Lea** 是鸟，只在按住 K2 时出现：一段滑翔般的连奏独奏
- **Sean** 就是大海本身：音阶、主音，以及所有声部共用的一个滤波器
- 每个声部演奏跟随海浪的**琶音**，或在音阶中**生成式**漫步；把角色向两侧
  移动就会移调
- 浪的大小决定步数：风平浪静 = 2 个音，大浪 = 16 个音
- 一层持续的风声，随浪增强
- 跟随 norns 时钟（内部、MIDI、Link 或 crow）；所有设置都是参数（可 MIDI
  映射，可存入 PSET），并会自动记住上次的状态

## 需求

- norns（shield、standard 或 fates 均可）
- 不需要别的：umi 一加载就会自己响起来

## 安装

在 maiden 中输入：

```
;install https://github.com/buenosairesfront/umi
```

然后**重启 norns**（SYSTEM > RESTART）以编译新的引擎 `Mar`，再从 SELECT
加载 **umi**。

> 如果装过一个名为 **mar** 的旧脚本，请先删除它（`dust/code/mar`）：两者都
> 带有名为 `Mar` 的引擎，SuperCollider 无法编译两个同名的类。

## 操作

按任意按键或旋钮可跳过开场动画。

### 大海

![大海](docs/1_sea.png)

| 控制 | 作用 |
|---|---|
| E1 | 风：从风平浪静到大浪（不改变音符的速度：速度由时钟决定） |
| E2 | 左右移动 Tucker（把他的旋律线在音阶上移调 −8…+8 级） |
| E3 | 左右移动 Mobba（同上，对她生效） |
| 按住 K2 | Lea 飞进来演奏独奏；E2 移动她；松开后她慢慢飞走 |
| K3 | Mobba 在她附近的音高上唱一个音，半秒后大海把它作为低五度的回声送回来 |
| 按住 K1 | 打开面板（见下文） |

![大浪](docs/2_waves.png)

![Lea 的独奏](docs/3_lea.png)

![Mobba 在唱歌](docs/4_mobba_sings.png)

### 面板（按住 K1）

按住 K1 时会滑入唯一的一个面板：一份包含六项设置的列表。

| 控制 | 动作 |
|---|---|
| E2 | 选择设置 |
| E3 | 修改它 |

面板打开时 E1 仍然控制风。

| 设置 | 取值 |
|---|---|
| tucker | off / Dream / Bell / Gauss（他的音色） |
| mobba | off / on |
| modo | arp / gen，两者共用 |
| escala | 大调、各种小调、调式、五声音阶、全音音阶、布鲁斯、吉普赛小调 |
| root | C … B |
| filter | 100–5000 Hz |

速度和时钟源使用 norns 自身的设置（PARAMETERS > CLOCK）。

### 保存

这六项设置也在 PARAMETERS > UMI 中，因此可以映射到 MIDI 并保存为 PSET。
退出脚本时当前状态会写入 `~/dust/data/umi/umi_estado.pset`，下次自动恢复。

<!-- u-ma:more -->
**更多 U-MA 作品：** 所有乐器和工具汇集一处 → [U-MA 作品集](https://github.com/buenosairesfront/U-ma/blob/main/README.zh.md)
<!-- /u-ma:more -->

## 致谢

由 [Buenos Aires Front](https://github.com/buenosairesfront) / U-MA 制作。
以 MIT 许可证发布。
