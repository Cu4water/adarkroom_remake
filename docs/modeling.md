# 建模规范

本文档规定 3D 模型和 2D 纸片人物怎么做、怎么组织、怎么导出进 Godot。画面应该是什么样见 `docs/art.md`。

标注：**已定**是制作人确认过的或已经在用的约定；**建议**是 AI 提出、还没确认的；**待定**需要制作人决定。

---

## 1. 单位与坐标（已定）

- 公制：**1 Blender 单位 = 1 Godot 单位 = 1 米**。
- Blender 是 Z 轴向上，Godot 是 Y 轴向上，glTF 导出时自动转换，不要手动旋转模型去"纠正"。
- 导出前应用所有物体的旋转和缩放（`Ctrl+A`），导出结果里不能有非 1 的缩放。
- 基准参考（暗室 `Art/scenes/firelit_room.blend`）：
  - 室内净空间约 `5.6m（宽 X）× 4.8m（深 Y）× 2.85m（高 Z）`
  - 门高 `2.12m`，建造者身高 `1.66m`
  - 第一人称观察机位高度约 `1.24m ~ 1.35m`，焦距 `18.5mm ~ 24mm`

新场景的尺度都以人物身高 `1.66m` 和门高 `2.12m` 为参照。

---

## 2. 几何（已定）

### 2.1 剪影与拓扑

- 中等面数（Mid-Poly），带有机的不完美。
- **不要完全笔直的工业直角**：木梁、门框、木板、家具边缘统一加轻微倒角（`Bevel` `0.004m ~ 0.015m`），允许细微的位置和角度错落。
- **大块面优先，细节靠贴图**：中远景不雕超高面数的细节；破损、木纹、刷痕靠笔触贴图和低频凹凸表现。

### 2.2 法线与着色

- **平面结构**（墙面、地板木板、桌面、隔板、地垫）：平直着色，或者 `Edge Split` 约 `32°`。平面网格内部不加随机法线抖动，否则火光低角度照射时会出现三角形和棋盘格阴影。
- **有机物体**（石块、原木、毛皮、围裙、麻袋、火焰、书页）：平滑着色，带手捏感的轮廓起伏。

### 2.3 面数预算（建议）

| 类别 | 三角面上限 |
| --- | --- |
| 一个完整的室内场景 | 30 万 |
| 主要道具（火塘、工作台） | 1 万 |
| 小道具（杯子、工具） | 2000 |
| 副本模块（一块墙、一段走廊） | 5000 |

超出时在交付说明里写明原因。实际预算以 Godot 里的性能测试为准，确定后改成已定。

---

## 3. Blender 文件组织

### 3.1 文件位置（已定）

```
Art/
  scenes/<场景名>.blend              场景源文件
  scenes/<场景名>_preview.png        已确认的参考渲染
  characters/<人物名>_2d.glb          2D 纸片人物
  characters/<人物名>_2d_standee.png  人物立绘（透明 PNG）
  scripts/export_<名字>.py            导出脚本
  common/                             logo 等通用素材
```

### 3.2 集合（已定，以暗室为例）

| 集合 | 内容 |
| --- | --- |
| `01_Architecture` | 地板、墙面、屋顶木梁、门窗、露砖补丁、窗外远景剪影 |
| `02_Fire_Hearth` | 核心交互和光源区：石炉膛、炭床、燃烧的木柴、分层火焰、火星、柴堆。火塘是开放的，不做烟罩和烟道 |
| `03_Builder_Corner` | 角色叙事区：窗下木凳、角落毛皮铺垫、毯子、行囊 |
| `04_Workbench_And_Stores` | 功能与库存表现区：围裙架、工作台、正在造的东西（如陷阱）、货架、麻袋、货箱 |
| `05_Foreground_Desk` | 前景桌和贴身道具 |
| `06_Lighting_And_Camera` | 光源、体积雾、相机，只用于预览，不导出 |
| `07_Builder` | 建造者的 3D 风格化模型与 65 根标准人形骨架，由 `export_builder_glb.py` 打包开源 CC0 骨骼动画导出到 `remake/assets/builder/builder.glb` |
| `07_Builder_2D` | 旧版 2D 纸片建造者存档，不导出 |
| `08_Chair` | 建造者搬到火边坐的木椅，`Chair_Root` 空物体下 13 个倒角方块零件，全部用 `Mat_Wood_Desk`。由 `Art/scripts/build_chair_model.py` 生成，`export_chair_glb.py` 合并成一个 `Chair` 节点导出到 `remake/assets/chair/chair.glb`；`export_hut_glb.py` 跳过这个集合 |
| `90_Later_Reveals` | 还没到揭示时机的东西，默认不导出 |

新场景沿用"两位数字前缀 + 英文名"的集合命名。`06` 永远是灯光和相机，`90` 以后留给延后揭示的内容。

### 3.3 命名（建议）

- 物体：大驼峰英文，按功能命名，例如 `Hearth_Stone_03`、`Workbench`。
- 材质：`Mat_<名字>`，例如 `Mat_Builder_2D_Painterly`。材质名是和 Godot 的契约，见第 5 节。
- 要在游戏里单独控制的物体，按第 5.2 节的规则命名。

---

## 4. 材质与贴图

### 4.1 落地方式（已定）

Blender 里的程序化笔触节点（Noise + Voronoi + AO）只用于快速定调和预览，带不进 glTF。进 Godot 有两种方式：

- **方式 A（主体与道具，推荐）**：在 Blender 里把程序化笔触烘焙成 `BaseColor` + `Roughness` + `Normal` 贴图（1K 或 2K，低频手绘感），随 glb 导入。
- **方式 B（大面积建筑与火焰）**：在 Godot 里写着色器，例如世界坐标双色抹灰墙、风格化火焰和火星，做到零接缝并跟随火势变化。导出时只保留材质名，由表现层按名字换成游戏里的材质（参考 `presentation/room/hut_materials.gd`）。

### 4.2 顶点色（已定）

每个零件的随机值写在顶点色的 R、G 两个通道里，着色器用它让每块木板、每块石头的颜色略有不同。导出脚本负责写入，模型师不手动刷这两个通道。

### 4.3 贴图规格（建议）

- PNG，`BaseColor` 用 sRGB，`Roughness`、`Normal` 用线性。
- 命名：`<资产名>_<通道>.png`，例如 `workbench_basecolor.png`、`workbench_roughness.png`、`workbench_normal.png`。
- 尺寸用 2 的幂。主要道具 2K，小道具 1K，不用 4K。

---

## 5. 导出到 Godot

### 5.1 管线（已定）

```
Art/scenes/xxx.blend ──(Art/scripts/export_xxx.py)──> remake/assets/xxx/xxx.glb ──> Godot 场景
```

- `.blend` 不进 `remake`。运行时素材只放在 `remake/assets/<名字>/`。
- 每个进游戏的模型都有一个导出脚本，在 Blender 的脚本编辑器里运行，可以反复运行：先在临时集合里生成合并后的副本，导出，再把临时集合删掉，**不改动源场景里原有的物体**。
- 不手改导出的 glb。要改就改源文件或导出脚本，再重新导出。
- 导出脚本开头的说明写清楚：导出哪些节点、每个节点的用途、哪些东西不导出、材质怎么处理。参考 `Art/scripts/export_hut_glb.py`。

### 5.2 节点契约（已定）

glb 里的节点名是模型和表现层代码之间的契约。表现层按名字找节点，改名会让游戏出错。

| 规则 | 例子 |
| --- | --- |
| 静态的部分合并成一个节点 | `Hut`、`Exterior`、`Hearth` |
| 要单独动、单独显隐的部分单独成节点 | `Door`、`WindowGlass` |
| 成组的同类东西用序号 | `Firewood_NN`（两位数）、`Flame_*` |
| 半透明的东西单独成节点，方便排序 | `WindowGlass` |

原点规则：

- 会转动的东西，原点放在转轴上（门的原点在门轴）。
- 火焰的原点在火焰根部。
- 人物的原点在脚底，`Z = 0`。

改契约时同时改三处：导出脚本的说明、表现层代码、素材契约测试（例如 `remake/tests/test_hut_asset.gd`）。

### 5.3 不导出的东西（已定）

灯光、相机、体积雾（游戏里由 Godot 布置）、火星（游戏里用粒子）、`90_Later_Reveals` 集合。

### 5.4 可交互的区域（已定）

点击用的碰撞体（例如 `FireArea`、`DoorArea`）在 Godot 场景里做成 `Area3D`，不放在模型里。模型改了尺寸，要检查这些区域是否还对得上。

### 5.5 色调映射对齐（已定）

Blender 预览用 `AgX`（Medium High Contrast），Godot 用 `AgX`，两边看到的明暗关系应该一致。

---

## 6. 3D 人物与骨骼动画（已定，以建造者为例）

- 尺度：人物原点在脚底 `Z = 0`，导出缩放严格为 `(1, 1, 1)`，建造者头顶高约 `1.66m`（含兜帽约 `1.70m`）。
- 骨架：65 根标准 UE/Godot 人形骨骼（`root`、`pelvis`、`spine_01..03`、`neck_01`、`Head`、`upperarm_l/r`、`hand_l/r`、`thigh_l/r` 等），来自 Quaternius Universal Animation Library 2 的 `Mannequin_F`（CC0 1.0）。
- 动画：由 `export_builder_glb.py` 从 Quaternius Universal Animation Library 1 & 2（CC0 1.0 Public Domain，位于仓库外 `Art/third_party/quaternius/`）精选 11 条动作（UAL1：`idle`、`walk`、`sit_down`、`sitting`、`stand_up`；UAL2：`idle_cold`、`walk_carry`、`stagger`、`get_up`、`pickup`、`feed`），再从 `get_up`（源 `LayToIdle`）里截出 2 段：`lying`（第 0 帧静止）、`collapse`（整段倒放），共 13 条；等比缩放位置通道并清除根水平位移，随 `builder.glb` 的 NLA 轨道导出。动画名就是游戏里动画状态机的节点名，改名要同时改 `presentation/room/builder_pose.gd`。摇头是程序化叠加，不是骨骼动画。
- 坐姿：`sitting` 里骨盆在人物原点后方约 `0.31m`、高约 `0.50m`。椅子坐面高 `0.43m`，摆椅子时让坐面正中对准这个位置（`BuilderPose.SEAT_BACK`、`seat_layout`）。
- 椅子契约：`chair.glb` 里只有一个 `Chair` 节点，原点在四条腿底面正中、`Y = 0`，正面朝 Godot `+Z`（Blender `-Y`），靠背在 `-Z` 一侧，总高约 `0.9m`。`remake/tests/test_chair_asset.gd` 检查这些。
- 网格与材质：由 `Art/scripts/build_builder_model.py` 生成（共 11 个部件，含右手可显隐劈柴 `Builder_HeldLog`），烘焙几何 AO 到顶点色 `G` 通道、下摆脏旧到 `B` 通道，导出保留 `Mat_Builder_*` 材质名，进 Godot 后由 `presentation/room/builder_materials.gd` 替换为手绘水粉 PBR 着色器（`builder_surface.gdshader`）。
- 契约校验：`remake/tests/test_builder_asset.gd` 检查核心骨骼、全部 13 条动画轨道、11 个部件、脚底高度与材质名。

---

## 7. 副本模块（待定）

副本用组件拼装，每套势力风格一套模块。以下是建议，第一套风格开工前要定下来：

- 模块对齐到统一的网格，网格尺寸待定（建议 2 米）。
- 模块之间的连接口用空物体标记，命名 `Socket_<类型>_<序号>`，例如 `Socket_Door_01`。
- 每个模块一个导出节点，命名 `<风格>_<类型>_<变体>`，例如 `Utility_Corridor_A`。
- "英雄件"（远处就能看到的坠毁战舰、标志性地标）单独人工制作，不用模块拼。

---

## 8. 用 Blender MCP 工作的规则（建议）

- 动手前先查询场景的集合和物体清单，确认改的是对的东西。
- 删除或大幅修改之前，先另存一份 `<场景名>_before_<改动>.blend`。
- 只改任务卡范围内的集合，不顺手整理别的东西。
- 改完渲染预览图，按 `docs/art.md` 第 10 节的流程交给制作人审。
- 保存源文件，然后运行导出脚本，再在 Godot 里跑素材契约测试。

---

## 9. 提示词模板（已定）

做森林边缘、村庄小屋、工坊、地标等新场景时，用下面的前缀锁定画风。

### 中文

> 风格化手绘 3D 游戏场景（Stylized Painterly PBR），类似《漫漫长夜》与《双城之战》的水粉/油画笔触质感。中低面数（Mid-Poly）建筑与道具，边缘带倒角与轻微手工不规则剪影，避免完全笔直的工业直角；表面具备可见的大笔触与柔和色块过渡，缝隙带手绘 AO 压暗，整体哑光质感（Roughness 0.72~0.92）；配色以低饱和暖棕木色、暖米黄抹灰与灰蓝绿/橄榄绿对比为主；场景仅由实体光源（火堆、火把、提灯或寒夜微光）照明，呈现克制、孤独而温暖的生存叙事氛围。

### English

> Stylized painterly 3D game environment (Stylized Painterly PBR), inspired by The Long Dark and Arcane painterly art direction, hand-painted gouache brushstroke textures with soft matte roughness (0.72-0.92) and subtle painted ambient occlusion in crevices. Mid-poly geometry with beveled timber silhouettes and gentle organic imperfections, muted palette contrasting warm ochre wood and beige plaster against dusty slate-teal and olive green. Grounded diegetic lighting from practical light sources only (hearth fire, torchlight, lantern) contrasting against cold deep midnight darkness outside, atmospheric and restrained storytelling mood.
