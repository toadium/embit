# Embit 迭代路线图

> 基于 2026-08-14 全面审查制定 · 当前版本 v0.1.2 · Phase 1 框架阶段

## 当前状态快照

| 维度 | 状态 | 数据 |
|------|------|------|
| 类型检查 | ✅ | 0 警告（`--warn-list +all --deny-warn`） |
| 测试 | ✅ | 350/350 passed，跨 ubuntu/macos/windows |
| CI/CD | ✅ | 4 job 全绿（check/test/fmt/info），`actions/checkout@v5` |
| API 稳定性 | ✅ | 7 个 `pkg.generated.mbti` 版本控制 |
| 控制算法 | ✅ | DH/FK/IK/Kalman/PID/轨迹规划真实实现 |
| 仿真通信 | ❌ | `gazebo_stub.c` 占位，不连接 Ignition Transport |
| VLA 推理 | ❌ | `ggml_stub.c` 占位，推理返回空数组 |
| 可视化 | ❌ | `view.mbt` 占位，不连接 Selene 引擎 |

**结论**：控制算法层已生产就绪，"感知→推理→执行" IO 通道未接入真实后端。

---

## Phase 2：FFI 真实接入（P0 阻塞项）

> 目标：打通 Gazebo 仿真通信与 ggml VLA 推理的真实 C 库绑定。

### 2.1 Gazebo Ignition Transport FFI

**现状**：`gazebo_stub.c` 自包含占位，`publish`/`subscribe`/`service_call` 仅增计数器。

**任务**：

- [ ] 引入 Ignition Transport C API 头文件（`ign_transport_node.h`）
- [ ] 实现 `embit_gazebo_connect`：调用 `ign_transport_node_create` 创建真实节点
- [ ] 实现 `embit_gazebo_publish`：调用 `ign_transport_advertise` + `ign_transport_publish`
- [ ] 实现 `embit_gazebo_subscribe`：调用 `ign_transport_subscribe` + 回调注册
- [ ] 实现 `embit_gazebo_service_call`：调用 `ign_transport_service` 同步请求
- [ ] 实现世界控制：`reset_world`/`pause`/`unpause`/`step`/`set_gravity` 绑定 `ign_world_control`
- [ ] 实现场景管理：`spawn_model`/`remove_model` 绑定 `ign_spawn`/`ign_remove`
- [ ] 更新 `moon.pkg`：`native-stub` 添加 `link.native` 配置 Ignition 库链接
- [ ] 更新 `ffi.mbt`：extern `"c"` 声明对齐真实 C API 签名
- [ ] 更新 `gazebo.mbt`：移除 "Phase 1 占位" 注释，补充真实错误处理

**验收**：

- `moon check --warn-list +all --deny-warn` 通过
- 连接真实 Gazebo Fortress 实例，`publish`/`subscribe` 收发消息正确
- 现有 350 测试不回归（占位测试改为集成测试，gated by CI `if: has-gazebo`）

### 2.2 ggml VLA 推理 FFI

**现状**：`ggml_stub.c` 忽略 `image_data` 和 `instruction`，`infer` 只增计数。

**任务**：

- [ ] 引入 ggml/vla.cpp C API 头文件（`ggml.h` + `vla.h`）
- [ ] 实现 `embit_ggml_load`：调用 `ggml_model_load` 加载 `.gguf` 文件，失败返回 `NULL`
- [ ] 实现 `embit_ggml_infer`：调用 `vla_infer` 执行图像+指令→动作序列推理
- [ ] 实现推理结果序列化：C 侧动作数组 → MoonBit `Bytes` 编码
- [ ] 实现 `embit_ggml_set_backend`：绑定 `ggml_backend_init`（CPU/CUDA/Metal）
- [ ] 实现模型元信息：`context_size`/`param_count`/`quant_type` 从 `.gguf` 头解析
- [ ] 更新 `moon.pkg`：`native-stub` 添加 `link.native` 配置 ggml 库链接
- [ ] 更新 `ffi.mbt`：extern `"c"` 声明对齐真实 C API 签名
- [ ] 更新 `ggml.mbt`：`infer` 返回真实动作序列，移除"占位返回空数组"

**验收**：

- `moon check --warn-list +all --deny-warn` 通过
- 加载真实 `smolvla-7b-q4.gguf`，推理返回非空动作序列
- CUDA/Metal 后端切换正常

### 2.3 Tokenizer 真实绑定

**现状**：`tokenizer.mbt` 空格分词，`decode` 返回固定占位字符串。

**任务**：

- [ ] 绑定 ggml tokenizer C API（`ggml_tokenizer_encode`/`ggml_tokenizer_decode`）
- [ ] `encode`：文本 → 真实 token ID 序列（BPE/SentencePiece）
- [ ] `decode`：token ID → 真实文本
- [ ] `count_tokens`：返回真实 token 数
- [ ] 移除所有"占位"注释

**验收**：

- `encode("walk forward")` 不再返回简单哈希，而是真实 BPE 编码
- `decode(encode(s)) == s` 往返一致

---

## Phase 3：可视化与 IK 深化（P1 可用性）

> 目标：接入 Selene 可视化引擎，补全 IK 解算器机型覆盖。

### 3.1 Selene 可视化引擎接入

**现状**：`view.mbt` Phase 1 占位，仅验证组件列表非空。

**任务**：

- [ ] 引入 Selene 引擎依赖（`moon add` 或 `native-stub`）
- [ ] `ViewPanel::render`：调用 Selene 渲染面板
- [ ] `ViewPanel::record`/`playback`：真实数据录制与回放
- [ ] `DataSeries`：实时时间序列数据流接入
- [ ] `Widget` 各类型渲染：`JointPlot`/`SensorDisplay`/`View3D`/`LogPanel`/`ParameterTuner`

**验收**：

- 启动监控面板，实时显示关节轨迹与传感器数据
- 录制 60s 数据后回放，时间戳对齐

### 3.2 IK 解算器机型覆盖

**现状**：已完成 6-DOF DLS、7-DOF 零空间优化、人形腿解析 IK、种子多解选择。

**任务**：

- [x] 实现 6-DOF 工业臂 DLS（阻尼最小二乘）逆运动学
- [x] 实现 7-DOF 冗余臂逆运动学（零空间优化）
- [x] 实现人形腿逆运动学（2-DOF 平面 + 4-DOF 空间）
- [x] IK 数值稳定性：雅可比奇异点处理、关节限位约束
- [x] 多解选择：基于种子选择最近解

**验收**：

- 6-DOF 臂 FK(IK(pose)) == pose（精度 < 1e-6 rad）
- 奇异构型不崩溃，DLS 阻尼项生效

---

## Phase 4：Sim2Real 集成验证

> 目标：仿真→真机迁移闭环，验证全链路一致性。

### 4.1 仿真集成测试

**任务**：

- [ ] Gazebo 仿真场景搭建：人形/四足/机械臂 URDF 加载
- [ ] 仿真闭环：传感器订阅 → 状态估计 → 轨迹规划 → 动作发布
- [ ] VLA 推理集成：相机图像 → ggml 推理 → 动作序列 → 仿真执行
- [ ] 多机型场景管理：`spawn_model`/`remove_model` 动态加载

**验收**：

- 人形行走 Demo 在 Gazebo 中连续行走 100 步不跌倒
- VLA 推理延迟 < 100ms（端侧 1B 模型）

### 4.2 真机联调

**任务**：

- [ ] 硬件抽象层：真机 `Robot` trait 实现（关节通信协议适配）
- [ ] Sim2Real 一致性：相同轨迹在仿真与真机上执行结果对比
- [ ] 安全联锁：关节限位、速度限制、碰撞检测在真机上生效
- [ ] 紧急停止：异常状态下安全停机协议

**验收**：

- 仿真与真机轨迹误差 < 5%
- 安全联锁触发时 10ms 内停机

---

## Phase 5：生产硬化

> 目标：性能调优、监控告警、安全认证。

### 5.1 性能调优

**任务**：

- [ ] `moon run --profile` 热点分析：控制环路、推理管线
- [ ] 控制环路抖动优化：目标 < 1ms（1kHz 控制频率）
- [ ] 推理批处理：`batch_infer` 多请求并行
- [ ] 内存分配优化：控制环路零分配（预分配缓冲区）

**验收**：

- 1kHz 控制环路抖动 < 1ms（P99）
- 批量推理吞吐 > 50 req/s（7B 模型）

### 5.2 监控告警

**任务**：

- [ ] Selene 监控面板：关节状态、控制器输出、推理延迟实时显示
- [ ] 异常告警：关节超限、通信超时、推理失败多级告警
- [ ] 数据录制：全链路状态录制用于事后分析

### 5.3 安全认证

**任务**：

- [ ] ISO 10218 工业机器人安全标准合规检查
- [ ] 关节速度/力矩硬限位（软件+硬件双重保护）
- [ ] 碰撞检测：自碰撞与环境碰撞
- [ ] 功能安全评估：SIL 等级评定（如适用）

---

## 依赖关系

```
Phase 2 (FFI 接入)
  ├── 2.1 Gazebo FFI ──┐
  ├── 2.2 ggml FFI ────┤
  └── 2.3 Tokenizer ───┘
                        │
Phase 3 (可视化+IK)     │
  ├── 3.1 Selene ──────┤
  └── 3.2 IK 解算器 ───┤
                        │
Phase 4 (Sim2Real) ◄────┘
  ├── 4.1 仿真集成
  └── 4.2 真机联调
        │
Phase 5 (生产硬化) ◄────┘
  ├── 5.1 性能调优
  ├── 5.2 监控告警
  └── 5.3 安全认证
```

**关键路径**：Phase 2 → Phase 4 → Phase 5（Phase 3 可并行）

---

## 技术债务清单

| ID | 来源 | 描述 | 优先级 |
|----|------|------|--------|
| TD-01 | `gazebo_stub.c:1` | Ignition Transport FFI 占位 | P0 |
| TD-02 | `ggml_stub.c:1` | ggml/vla.cpp FFI 占位 | P0 |
| TD-03 | `tokenizer.mbt:2` | 空格分词占位 | P0 |
| TD-04 | `view.mbt:116` | Selene 引擎未接入 | P1 |
| TD-05 | `ik.mbt:34` | IK 解算器仅骨架 | P1 | ✅ 已完成 |
| TD-06 | `gazebo_robot.mbt:7` | 传感器读数占位返回空数组 | P1 | ✅ 已功能化 |
| TD-07 | `pipeline_demos.mbt:160` | 传感器噪声省略 | P2 | ✅ 已添加 |
| TD-08 | `pipeline_demos.mbt:198` | 上下文使用量检查占位 | P2 | ✅ 已实现 |

---

## 版本规划

| 版本 | Phase | 里程碑 |
|------|-------|--------|
| v0.2.0 | Phase 2 | FFI 真实接入，仿真+推理可用 |
| v0.3.0 | Phase 3 | 可视化 + IK 机型覆盖 |
| v0.4.0 | Phase 4 | Sim2Real 集成验证通过 |
| v1.0.0 | Phase 5 | 生产硬化，正式发布 |

---

## 验收门禁（每个 Phase 必须通过）

```bash
# 1. 零警告严格检查
moon check --warn-list +all --deny-warn

# 2. 全量测试
moon test --target native

# 3. 代码格式
moon fmt --check

# 4. API 接口一致性
moon info
git diff --exit-code  # mbti 必须已提交

# 5. 跨平台 CI（自动触发）
# ubuntu-latest + macos-latest + windows-latest
```

> 任何 Phase 合并前，上述 5 项必须全绿。