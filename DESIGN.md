# Design

当前更新：六名角色的概念/头像/单朝向透明战斗小图已接入网页，新增刺客墨刃；64/96px、灰度与武器搭配见 [v004 六人预览](output/imagegen/characters-v004/index.html)。[战斗挂点与配件路线](docs/CHARACTER_LOADOUTS.md) · [刺客机制](docs/ASSASSIN_DESIGN.md)。历史 v001–v003 记录保留；Godot 六人机制、分层换装、多朝向动画仍待实现。


## Source of truth

- Status: Active（v0.5 后续实现的设计基线；规划内容待实现，数值待试玩校准）。
- Last refreshed: 2026-11-04。
- 界面页面规格与可点击原型：[docs/UI_DESIGN.md](docs/UI_DESIGN.md)、[artifacts/ui/index.html](artifacts/ui/index.html)。
- 新增角色与新版美术：[docs/CHARACTER_DESIGN.md](docs/CHARACTER_DESIGN.md)。HTML 已更新为六人布局，两位新增角色使用已认可 v001 概念图、v002 同源头像和透明战斗静态 PNG；原三位已更新 v003 概念图及同源头像；v004 已补齐静态战斗稿，动画待制作。多朝向动画和实际游戏被动未实现。
- 最新角色资产：[v002 头像/战斗静态首帧](output/imagegen/characters-v002/index.html)，完整提示词、参考图校验值和处理参数留存在 [v002 清单](art/prompts/characters/v002/README.md)。
- 首批战斗概念图：[星辉弹、环刃、追击者、疾行者](output/imagegen/combat-v002/index.html)。仅概念层，未接入实际战斗；生产改进意见已留存。
- 战斗专项：[docs/COMBAT_DESIGN.md](docs/COMBAT_DESIGN.md)；资产制作：[docs/COMBAT_ASSET_BRIEF.md](docs/COMBAT_ASSET_BRIEF.md)。伤害、暴击、敌方预警和表现优先级按专项执行。
- 武器定制：[升级与配件](docs/WEAPON_CUSTOMIZATION.md)，明确单武器槽与全局模块区别；维护页待实现。
- Primary product surfaces: 单机 Godot 游戏《星环余烬》的菜单、角色选择、战斗 HUD、升级/进化、营地与结算。
- 玩法与内容的主文档：[docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)。该文档拥有角色、武器、场景、进化和关卡节奏总纲；战斗细则以 COMBAT_DESIGN 为准，局部配件资格、倍率与兼容以 WEAPON_CUSTOMIZATION 为准；本文件拥有整体呈现与交互约束。实施依赖和验收清单见 [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)。战斗参数以 docs/data/combat-v001.json 和 COMBAT_DESIGN 对应说明为准，其他参数以 GAME_DESIGN 为准；修订时同步更新引用。
- Evidence reviewed: `project.godot`、`README.md`、`scripts/run.gd`、`scripts/game.gd`、`scripts/profile.gd`、`artifacts/VALIDATION.md`；本会话已检查菜单、战斗、升级与 Boss 截图。此前没有 DESIGN.md。
- 事实：当前已有三武器基础原型，未实现角色/设施/进化。假设：继续使用现有题材、2D、单局目标约十分钟（9–11 分钟）、单人离线、Windows/macOS。

## Brand

- Personality: 温暖而危险的天文遗迹；回收、修复和重新点亮。
- Trust signals: 显示精确效果、进化条件、暂停状态、存档错误与真实可用内容。
- Avoid: 直接使用知名 IP 人物、专属造型、标志与台词；不同风格素材混搭；用大量特效遮住敌弹。

## Product goals

- Goals: 角色改变打法，武器选择产生联动，场景装置让走位有目的；一次失败能给下一局提供清晰方向。
- Non-goals: 当前不做联机、云服务、开放世界、随机地牢生成、重剧情演出与装备背包管理。
- Success signals: 角色/设施/升级决策可解释；零永久等级可通关；正常玩家形成首个构筑；目标机器正常渲染负载稳定。

## Personas and jobs

- Primary personas: 喜欢短局构筑的单机玩家；初次接触幸存者类的休闲玩家。
- User jobs: 快速开始一局、读懂自己的攻击与威胁、选择协同强化、理解死因、发现下次想尝试的流派。
- Key contexts: 键鼠桌面；Mac 开发试玩，Windows/macOS 发布目标；离线也可使用全部核心玩法。

## Information architecture

- Primary navigation: 营地 → 角色/初始武器 → 战斗 → 升级/进化 → 结算 → 营地或重开。
- Core screens: 营地、角色卡、武器/进化图鉴、战斗 HUD、设施交互提示、升级三选一、进化选择、暂停、结算。
- Content hierarchy: 生存威胁 > 当前生命/冲刺 > 战斗目标 > 经验/装备进度 > 次要统计。局外货币不占用战斗核心视野。

## Design principles

- 玩家通过轮廓、形状与预警理解危险，颜色只辅助。
- 每次关键成长必须能观察到行为改变；明确显示升级前后变化。
- 局内选项少而有意义；首版不堆多个独立技能键和资源条。
- Tradeoffs: 先做一张有空间决策的手工图，复用装置规则；先完成两套构筑，再扩展元素与场景。

## Visual language

- Color: 背景 `#071413`；场地苔绿；正文 `#E9F3F0`；次要文字 `#8DABA9`；经验/强化 `#94F3C0`；机械/进化 `#EDCA82`；危险 `#FC818D`；引力 `#BAA2F8`。这些是现有 token，先复用。
- Typography: 大标题使用宋体/衬线字体，正文使用苹方/微软雅黑/Noto；正文至少 16–18 逻辑像素，主要指标 22–34；标题可放大。正式打包若改为内置字体需单独确定字体来源和授权。
- Spacing/layout rhythm: 8 像素基础节奏；卡片内距 20–24；控件间距至少 12。
- Shape/radius/elevation: 新视觉原型以直角或 2–4 像素小倒角与细金属边框为主；卡片以边框和明度区分，不以强烈玻璃或高光抢占视线。现有 Godot 原型较大的圆角待界面落地时调整。
- Motion: 冲刺残影、短受击闪烁、明确进化轮廓；危险预警约 0.7–1 秒；减少动效模式关闭镜头震动与高频闪烁。
- Imagery/iconography: 原创手绘卡通＋奇幻遗迹，统一天文、青铜机械与植物侵蚀语言；角色与敌人先保证小尺寸剪影辨识。女性露出面部、侧束发与偏置星盘；机器人采用椭圆陶瓷机身与短机械腿，不复用蒙面斗篷人形。

## Components

- Existing components to reuse: `game.gd` 内 Button、StyleBoxFlat、panel/bar/text_at、武器图标、菜单/暂停/升级/结算布局。
- New/changed components: 角色卡、三武器/四模块槽、进化条件卡、可用进化提醒、设施标记/占点条、Boss 预警、死因摘要。
- Variants/states: 默认/悬停/焦点/禁用；已解锁/条件未满足/槽已满/满级/可进化/已进化；设施未开放/可启动/占点/暂停/完成/本局锁定。
- Token/component ownership: 本文件定义呈现；玩法参数在 GAME_DESIGN 中定义；后续按已有代码模式抽取必要配置，不额外引入 UI 框架。

## Accessibility

- Target standard: 原生游戏可读性与完整键盘操作；不宣称当前达到 WCAG 或完整读屏支持。
- Keyboard/focus behavior: Tab/方向键可导航菜单，焦点可见；升级 1/2/3；Esc 关闭当前层级或暂停，不能意外退出并丢失本局。
- Contrast/readability: 正文对实际底色检查对比度；敌弹与经验形状不同；地图对比低于角色与威胁。
- Screen-reader semantics: 可交互控件优先使用真正的 Godot Control/Button；当前自绘文本与世界没有完整读屏语义，列为后续工作。
- Reduced motion and sensory considerations: 设置静音/音量、降低特效与关闭震屏；不使用高频全屏闪烁；关键预警同时提供文字/图形。

## Responsive behavior

- Supported devices: 桌面 16:9/16:10；当前逻辑尺寸 1120×760，使用现有 canvas_items 拉伸；HTML 视觉原型画板 1440×900，仅作审阅。Godot 落地需要锚点/容器适配与保持实际逻辑字号，不能只等比缩小截图。
- Layout adaptations: 非目标宽高比保留安全区或黑边；不裁剪 HUD、按钮和预警；窄窗口允许菜单滚动而非压缩字体。
- Touch/hover differences: 当前不做触屏；不把必要解释仅放在 hover 内。手柄支持后续单独做完整导航与验证。

## Interaction states

- Loading: 资源加载中禁止重复开局，失败给出重试/返回。
- Empty: 武器/角色未解锁显示条件；无进化条件时显示缺少的武器等级/模块，不消耗碎片。
- Error: 存档失败明确提示，购买与结算不重复扣/发；不显示成功动画掩盖失败。
- Success: 设施启动、升级与进化各有不同的图形/音效反馈；进化展示前后能力。
- Disabled: 明确说明槽满、资金不足、设施本局已选两处等原因；不给不可用按钮伪装成加载状态。
- Offline: Steam 不可用不阻塞菜单、战斗、进度或结算；在线状态仅作次要信息。

## Content voice

- Tone: 简洁、具体、略有探索感；实际效果优先于世界观辞藻。
- Terminology: 星砂=营地资源；经验=局内升级；星核碎片=局内进化材料；模块=被动装备；装置=地图设施。
- Microcopy rules: 写“伤害 +8%”“占点 12/18 秒”“已选定 2/2 处”，不要只写“大幅提升”；同一名词全局一致；未完成内容不伪装为已解锁。

## Implementation constraints

- Framework: Godot 4.7.2 / GodotSteam 4.23.2；GDScript；Compatibility 渲染；本地 ConfigFile 存档。
- Design-token constraints: 复用当前颜色、字体和组件；游戏规则与绘制层保持现有 run/game 分离。
- Performance constraints: 普通敌人基线约 140；对粒子/掉落/召唤数量设上限；帧率以正常图形负载实测，不用无界面模拟替代。
- Compatibility: 单人离线；Windows/macOS；平台导出使用匹配 GodotSteam 模板。Windows 目前未测试，不能标记为已验证。
- Test/screenshot expectations: 固定种子的战斗、升级与进化暂停、材料保留、设施互斥、结算幂等、旧存档迁移；菜单/五角色/战斗/升级/进化/设施/Boss/结算截图。截图中的测试场景必须标明，不能冒充正常通关。
- 本轮交付设计文档与网页视觉原型；Godot 游戏行为、存档与测试结果保持原义，网页 HUD 状态不等于已实现战斗被动。

## Open questions

- [ ] 用户偏好 / 视觉投入：目前假定继续原创天文遗迹题材；若转向国风或其他题材，需要重新命名与统一美术语言。
- [ ] 开发预算与周期 / 项目负责人：未给时间预算，因此按“五角色、四武器、一图一 Boss”划定首个版本，不承诺工期。
- [ ] 目标 Windows 配置 / 开发验证：尚未确定，影响正式性能和打包验收。
- [ ] 玩家试玩 / 开发验证：现有简单走位模拟约三分钟失败，不能据此证明难度合理；后续需真实试玩重调。

新增五人美术统一预览：[v003 概念图与头像](output/imagegen/characters-v003/index.html)。原三位新稿待确认；选择页已替换，不能把原三位战斗画面的旧占位当作已完成新精灵。
