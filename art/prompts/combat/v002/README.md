# 第一批战斗概念图提示词 v002

本批四个独立对象：W01 星辉弹、W02 环刃、E01 苔影追击者、E02 裂隙疾行者。四张概念图均已真实生成并目视检查，执行状态、实际尺寸和 SHA-256 见 [manifest.json](manifest.json)。

[查看概念图](../../../../output/imagegen/combat-v002/index.html) · [四图对照](../../../../output/imagegen/combat-v002/combat-concept-board.png) · [评审意见](../../../../output/imagegen/combat-v002/REVIEW.md)。

v001 仍保留八份初始设计提示词；本版本在首批四份提示词前明确追加两张参考图的职责，然后保存为实际提交文本，不覆盖 v001。

## 参考图职责

1. 霁月 v001：绘画笔触、边缘、暖中性背景与光线参考；不是要出现在新图中的人物。
2. 螺灯 v001：青铜/陶瓷材质与同世界画风参考；不是要复刻的机器人外形。

两张图均是用户已经认可的图，路径和 SHA-256 在 manifest 中留存。请求沿用本机既有图片服务，通过 imagegen 技能自带 CLI `edit`，两次 `--image` 指定参考；请求模型 gpt-image-2、high、1024×1024、PNG、`--no-augment`。

| ID | 对象 | 实际提交提示词 |
|---|---|---|
| W01 | 星辉弹 | [weapon-pulse.prompt.txt](weapon-pulse.prompt.txt) |
| W02 | 环刃 | [weapon-orbit.prompt.txt](weapon-orbit.prompt.txt) |
| E01 | 苔影追击者 | [enemy-chaser.prompt.txt](enemy-chaser.prompt.txt) |
| E02 | 裂隙疾行者 | [enemy-runner.prompt.txt](enemy-runner.prompt.txt) |

输出放在 `output/imagegen/combat-v002/`。这些是单物件/单怪物概念图，主要检查轮廓、材质和风格；不是包含透明首帧、动作图集或实际攻击逻辑的最终游戏资产。

后续对照 [战斗资产制作规格](../../../../docs/COMBAT_ASSET_BRIEF.md) 再进行俯视首帧、透明处理、移动/攻击/死亡和技能纹理。不要从一张混合概念海报直接宣称动画完成。

实际返回为三张 1536×1024 RGB 和一张 1312×1199 RGBA，与请求的方形尺寸不同；原图全部保留。环刃有单独的透明噪点清理预览。详细概念偏差已记录，未宣称四张都是生产可用资产。
