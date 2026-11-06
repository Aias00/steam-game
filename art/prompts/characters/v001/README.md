# 两位角色生图提示词 · v001

状态：两张概念图已真实生成并完成文件与目视检查。旧 SVG 没有作为本次参考图，也不是本轮生图结果。

[查看图片预览](../../../../output/imagegen/characters-v001/index.html) · [双角色对照图](../../../../output/imagegen/characters-v001/character-pair-v001.png) · [生成评审记录](../../../../output/imagegen/characters-v001/REVIEW.md)。

## 本轮目标

先生成两张独立的全身三分之四视角角色概念图，确认美术方向。霁月强调成年女性的表情、自然姿态、象牙白与雾紫服装、铜制星盘；螺灯强调椭圆陶瓷机身、机械重量、温暖胸灯和友好表情。两者统一为精致手绘奇幻冒险风，避免再生成平面几何占位图。

- [霁月完整执行提示词](jiyue.prompt.txt)
- [螺灯完整执行提示词](luodeng.prompt.txt)
- [执行清单与 SHA-256](manifest.json)

英文文件是完整、自包含的提交文本，包含共同风格、构图、具体角色与排除项；没有依赖未保存的口头指令。使用 `--no-augment` 时不再由 CLI 补写提示词。

## 计划生成参数

- 生成类型：generate；两位角色各一张，不把两位角色塞进同一张图。
- CLI 备选模型：gpt-image-2；质量 high；1024×1536；PNG。
- 使用简洁不透明背景，暂不要求透明抠图，避免改变模型。
- 输入参考图：无；明确不沿用已被否定的 SVG。
- 本轮不同时制作三视图、头像、动画或战斗精灵，先确认单角色美术质量。

## 已生成文件

```
output/imagegen/characters-v001/jiyue-v001.png
output/imagegen/characters-v001/luodeng-v001.png
```

两者保留原始 PNG。霁月实际 1024×1536，螺灯实际 1230×1278；螺灯画幅与请求不同，原图未拉伸或裁切。实际尺寸、文件 SHA-256 与执行日志索引见 manifest.json。

## 验收

1. 女性角色是成年比例，面部有神态，双手和脚完整，服装有体积与材质。
2. 女性的侧束发、短肩披、偏置星盘形成独立轮廓。
3. 机器人结构有重量和关节连接，陶瓷、青铜、灯光能区分，不像塑料积木。
4. 两张图的画法、光线与背景统一；不要求完全一致的笔触，但必须像同一游戏的角色。
5. 没有多余肢体、文字、水印或已知 IP 的直接复刻。
6. 若不合格，保留原图与原提示词，另存 v002 提示词，记录具体问题再重新生成，不覆盖旧版本。

## 实际使用的 CLI 命令

当前会话未提供内置 image_gen；用户要求继续直接生图后，已采用本机既有 OpenAI 兼容模型服务的图片接口，经技能自带 CLI 执行。认证从既有服务配置仅在进程环境内传入，未写入提示词、清单或日志。请求模型为 gpt-image-2，未降级模型。

实际执行使用已安装的官方技能脚本，不另写 SDK 调用器。以下命令需要同样的已配置服务认证环境：

```bash
python3 /Users/aias/.codex/skills/.system/imagegen/scripts/image_gen.py generate \
  --model gpt-image-2 \
  --prompt-file art/prompts/characters/v001/jiyue.prompt.txt \
  --no-augment --quality high --size 1024x1536 --output-format png \
  --out output/imagegen/characters-v001/jiyue-v001.png

python3 /Users/aias/.codex/skills/.system/imagegen/scripts/image_gen.py generate \
  --model gpt-image-2 \
  --prompt-file art/prompts/characters/v001/luodeng.prompt.txt \
  --no-augment --quality high --size 1024x1536 --output-format png \
  --out output/imagegen/characters-v001/luodeng-v001.png
```

## 当前执行条件

最初执行环境未导出 OPENAI_API_KEY；后来验证本机既有模型服务的认证与图片端点可用。GEMINI_API_KEY 虽然存在，但 Google API 返回 API_KEY_INVALID，因此没有使用该通道生成图片。

已保存两次 CLI dry-run，用于校验提示词、请求参数和输出路径；真实请求另存执行日志。霁月真实生成成功；螺灯首个真实请求返回 HTTP 502，已保留失败记录，使用同一提示词重试后成功。原始提示词 SHA-256 未改变。图像生成未暴露随机种子，保留文本与参数不代表可以逐像素复现。
