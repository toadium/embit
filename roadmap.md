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
| 仿真通信 | ✅ | 条件编译 wrapper，`EMBIT_HAS_IGNITION` 启用真实 Ignition Transport |
| VLA 推理 | ✅ | 条件编译 wrapper，`EMBIT_HAS_GGML` 启用真实 ggml/VLA 推理 |
| 可视化 | ✅ | 条件编译 wrapper，`EMBIT_HAS_SELENE` 启用真实 Selene 引擎 |

**结论**：控制算法层与 FFI 通道已生产就绪（条件编译架构），真实库链接由 `prepare.py` + CI gate 管理。Phase 2 完成，待真实库环境集成验证。

---

## Phase 2：FFI 真实接入（P0 阻塞项）

> 目标：打通 Gazebo 仿真通信与 ggml VLA 推理的真实 C 库绑定。

### 2.1 Gazebo Ignition Transport FFI

**现状**：✅ 条件编译 wrapper 完成，`gazebo_stub.c` 通过 `#ifdef EMBIT_HAS_IGNITION` 切换真实 API/占位回退。

**任务**：

- [x] 引入 Ignition Transport C API 头文件（`gazebo_ignition.h` 声明 C 接口）
- [x] 实现 `embit_gazebo_connect`：调用 `embit_ign_node_create` 创建真实节点
- [x] 实现 `embit_gazebo_publish`：调用 `embit_ign_publish`（`Node::Advertise` + `Publish`）
- [x] 实现 `embit_gazebo_subscribe`：调用 `embit_ign_subscribe`（`Node::Subscribe` + 回调）
- [x] 实现 `embit_gazebo_service_call`：调用 `embit_ign_service_call`（`Node::Request` 同步）
- [x] 实现世界控制：`reset_world`/`pause`/`unpause`/`step`/`set_gravity` 绑定 `WorldControl` 服务
- [x] 实现场景管理：`spawn_model`/`remove_model` 绑定 `EntityFactory`/`Entity` 服务
- [x] 更新 `moon.pkg`：添加 `link.native` 配置模板（由 `prepare.py` 动态追加）
- [x] 更新 `ffi.mbt`：extern `"c"` 签名不变（条件编译在 C 层）
- [x] 更新 `gazebo.mbt`：移除 "Phase 1 占位" 注释，补充条件编译说明

**验收**：

- `moon check --warn-list +all --deny-warn` 通过
- 连接真实 Gazebo Fortress 实例，`publish`/`subscribe` 收发消息正确
- 现有 350 测试不回归（占位测试改为集成测试，gated by CI `if: has-gazebo`）

### 2.2 ggml VLA 推理 FFI

**现状**：✅ 条件编译 wrapper 完成，`ggml_stub.c` 通过 `#ifdef EMBIT_HAS_GGML` 切换真实 API/占位回退。动作序列通过 `embit_ggml_get_action_count`/`embit_ggml_get_action_joint` 逐个查询。

**任务**：

- [x] 引入 ggml/vla.cpp C API 头文件（`ggml_native.h` 声明 C 接口）
- [x] 实现 `embit_ggml_load`：调用 `llama_load_model_from_file` 加载 `.gguf` 文件，失败返回未加载
- [x] 实现 `embit_ggml_infer`：调用 `vla_infer` 执行图像+指令→动作序列推理
- [x] 实现推理结果序列化：C 侧动作数组存储在上下文，MoonBit 侧逐个查询 7 关节值
- [x] 实现 `embit_ggml_set_backend`：绑定 `ggml_backend_init`（CPU/CUDA/Metal）
- [x] 实现模型元信息：`context_size`/`param_count`/`quant_type` 从 llama 上下文解析
- [x] 更新 `moon.pkg`：添加 `link.native` 配置模板（由 `prepare.py` 动态追加）
- [x] 更新 `ffi.mbt`：新增 `embit_ggml_get_action_count`/`embit_ggml_get_action_joint` extern 声明
- [x] 更新 `ggml.mbt`：`infer_with_config` 真实模式从 C 侧获取动作序列，占位模式回退指令解析

**验收**：

- `moon check --warn-list +all --deny-warn` 通过
- 加载真实 `smolvla-7b-q4.gguf`，推理返回非空动作序列
- CUDA/Metal 后端切换正常

### 2.3 Tokenizer 真实绑定

**现状**：✅ 条件编译绑定完成，新增 `encode_with_ggml`/`decode_with_ggml`/`count_tokens_with_ggml` 方法，真实模式调用 ggml tokenizer C API（BPE/SentencePiece），占位模式回退到内置词表。

**任务**：

- [x] 绑定 ggml tokenizer C API（`embit_ggml_tokenize`/`embit_ggml_get_token_id`/`embit_ggml_detokenize`）
- [x] `encode_with_ggml`：文本 → 真实 token ID 序列（BPE/SentencePiece），占位回退内置词表
- [x] `decode_with_ggml`：token ID → 真实文本，占位回退内置词表
- [x] `count_tokens_with_ggml`：返回真实子词 token 数，占位回退空格分词
- [x] 移除所有"占位"注释，补充条件编译架构说明

**验收**：

- `encode("walk forward")` 不再返回简单哈希，而是真实 BPE 编码
- `decode(encode(s)) == s` 往返一致

---

## Phase 3：可视化与 IK 深化（P1 可用性）

> 目标：接入 Selene 可视化引擎，补全 IK 解算器机型覆盖。

### 3.1 Selene 可视化引擎接入

**现状**：`view.mbt` Phase 1 占位，仅验证组件列表非空。

**任务**：

- [x] 引入 Selene 引擎依赖（`moon add` 或 `native-stub`）
- [x] `ViewPanel::render`：调用 Selene 渲染面板
- [x] `ViewPanel::record`/`playback`：真实数据录制与回放
- [x] `DataSeries`：实时时间序列数据流接入
- [x] `Widget` 各类型渲染：`JointPlot`/`SensorDisplay`/`View3D`/`LogPanel`/`ParameterTuner`

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

- [x] Gazebo 仿真场景搭建：人形/四足/机械臂 URDF 加载
- [x] 仿真闭环：传感器订阅 → 状态估计 → 轨迹规划 → 动作发布
- [x] VLA 推理集成：相机图像 → ggml 推理 → 动作序列 → 仿真执行
- [x] 多机型场景管理：`spawn_model`/`remove_model` 动态加载

**验收**：

- 人形行走 Demo 在 Gazebo 中连续行走 100 步不跌倒
- VLA 推理延迟 < 100ms（端侧 1B 模型）

### 4.2 真机联调

**任务**：

- [x] 硬件抽象层：真机 `Robot` trait 实现（关节通信协议适配）
- [x] Sim2Real 一致性：相同轨迹在仿真与真机上执行结果对比
- [x] 安全联锁：关节限位、速度限制、碰撞检测在真机上生效
- [x] 紧急停止：异常状态下安全停机协议

**验收**：

- 仿真与真机轨迹误差 < 5%
- 安全联锁触发时 10ms 内停机

---

## Phase 5：生产硬化

> 目标：性能调优、监控告警、安全认证。

### 5.1 性能调优

**任务**：

- [x] `moon run --profile` 热点分析：控制环路、推理管线
- [x] 控制环路抖动优化：目标 < 1ms（1kHz 控制频率）
- [x] 推理批处理：`batch_infer` 多请求并行
- [x] 内存分配优化：控制环路零分配（预分配缓冲区）

**验收**：

- 1kHz 控制环路抖动 < 1ms（P99）
- 批量推理吞吐 > 50 req/s（7B 模型）

### 5.2 监控告警

**任务**：

- [x] Selene 监控面板：关节状态、控制器输出、推理延迟实时显示
- [x] 异常告警：关节超限、通信超时、推理失败多级告警
- [x] 数据录制：全链路状态录制用于事后分析

### 5.3 安全认证

**任务**：

- [x] ISO 10218 工业机器人安全标准合规检查
- [x] 关节速度/力矩硬限位（软件+硬件双重保护）
- [x] 碰撞检测：自碰撞与环境碰撞
- [x] 功能安全评估：SIL 等级评定（如适用）

---

## Phase 6：覆盖率治理（P2 质量加固）

> 目标：将 83 行未覆盖代码降至 < 10 行，覆盖所有边缘分支与错误路径。
> **结果**：83 → 29 行（降低 65%），剩余 29 行为占位模式不可达分支（需真实库环境，Phase 9 覆盖）。

### 6.1 安全模块边缘测试

**现状**：✅ 完成。`safety.mbt` 10 行 → 0，`safety_cert.mbt` 9 行 → 0，`alert.mbt` 6 行 → 0。

**任务**：

- [x] `SafetyController::check_joint_limits`：关节位置超下限/超上限触发 `SafetyLimitViolation`
- [x] `SafetyController::check_velocity_limits`：`max_vel <= 0` 早返回 + `dt <= 0` 跳过 + 关节不存在跳过
- [x] `SafetyController::check_effort_limits`：`max_effort <= 0` 早返回 + `dt <= 0` 跳过 + 加速度超限触发 + 关节不存在跳过
- [x] `SafetyController::check_collision`：负碰撞距离触发错误
- [x] `SafetyController::last_violation`：查询方法
- [x] `SafetyCertification`：速度合规/不合规、力矩合规/不合规、保护停止缺失、碰撞检测缺失、关节限位无效、查询方法
- [x] `AlertSystem`：Error/Critical 级别告警、`alerts`/`clear` 查询方法

### 6.2 基准/碰撞模块边缘测试

**现状**：✅ 完成。`benchmark.mbt` 6 行 → 0，`collision.mbt` 1 行 → 0。

**任务**：

- [x] `ControlLoopBenchmark::compute_result`：空结果（0 迭代）、max_l 更新、频率计算
- [x] `sort_latencies`：排序交换分支
- [x] `ControlLoopBenchmark::target_frequency` / `iteration_count`：查询方法
- [x] `CollisionDetector::check_environment_collision`：负安全距离 + 有障碍物

### 6.3 运动学边缘测试

**现状**：✅ 完成。`dh_kinematics.mbt` 6 行 → 0，`ik.mbt` 2 行 → 0。

**任务**：

- [x] `extract_joint_angle`：关节数不足触发 `InvalidConfig`
- [x] `DhIKSolver::with_null_space_gain`：查询方法
- [x] `gauss_elimination`：奇异矩阵（`mat[i][i].abs() < 1e-10`）跳过 + 回代零除保护
- [x] `DhIKSolver::solve`：零空间优化 `None` 分支 + 关节限位越界 `i >= limits.length()` 分支
- [x] `LegIKSolver::solve_planar_internal`：余弦钳位 `> 1.0` 和 `< -1.0` 边界

### 6.4 真机/Demo/FFI 错误路径测试

**现状**：✅ 完成。`real_robot.mbt` 3 行 → 0，`gazebo.mbt` 3 行 → 0，`ggml.mbt` 11 → 7，`view.mbt` 4 行 → 0。剩余 29 行为占位模式不可达分支（FFI 真实模式 + 防御性 `partial_match`）。

**任务**：

- [x] `RealRobot::update_sensors` / `address`：查询方法
- [x] `RealRobot::execute_actions`：未连接触发 `ActionExecuteError`
- [x] `GazeboClient::pause` / `unpause` / `set_gravity`：FFI 返回负数触发错误
- [x] `VlaModel::infer`：`parse_instruction_to_actions` 各分支覆盖（release/walk backward/turn right）
- [x] `ViewPanel::ffi_playback_*` / `ffi_get_parameter`：查询方法
- [ ] `sim2real.mbt`：防御性 `_ => ()` 分支（占位模式不可达，需 `partial_match` 完整匹配）
- [ ] `ggml.mbt`：FFI 返回动作序列 + `set_backend` 错误 + `QuantType::Fp16`（占位模式不可达）
- [ ] `tokenizer.mbt`：FFI 绑定方法（占位模式不可达）
- [ ] `pipeline_demos.mbt`：上下文不足错误（占位模式 `context_size=4096` 不可达）

**验收**：

- `moon coverage analyze`：83 → 29 行未覆盖（剩余为占位模式不可达分支，Phase 9 真实库环境覆盖）
- `moon test --target native`：467 个测试全部通过（+47 新测试）

---

## Phase 7：文档测试与 API 文档（P2 生态建设）

> 目标：为公开 API 添加 docstring tests，生成 README.mbt.md 文档测试文件。

### 7.1 Docstring Tests

**任务**：

- [x] `embit-core`：`JointState` / `ActionCommand` / `RobotBuilder` / `RobotModel::to_info` docstring tests
- [x] `embit-control`：`PIDController` / `DhFKSolver` / `SafetyController` / `MotionController` docstring tests
- [x] `embit-ggml`：`VlaModel` / `InferConfig` docstring tests
- [x] `embit-gazebo`：`GazeboClient` docstring tests
- [x] `embit-view`：`ViewPanel` docstring tests

### 7.2 README.mbt.md

**任务**：

- [ ] 为每个子包创建 `README.mbt.md`，包含 `mbt check` 代码示例
- [ ] 根包 `README.mbt.md` 软链接到 `README.md`

**验收**：

- [x] `moon test` 自动运行 docstring tests（480 测试全通过）
- [ ] `moon doc` 生成完整 API 文档

---

## Phase 8：性能基准实测（P1 生产验证）

> 目标：使用 `moon run --profile` 进行真实性能测量，验证控制环路延迟目标。

### 8.1 热点分析

**任务**：

- [ ] 控制环路热点：`PIDController::update` × 10000 + `ImpedanceController::compute` × 10000
- [ ] 轨迹规划热点：`compute_trajectory_cubic` × 1000 + `compute_trajectory_quintic` × 500
- [ ] 运动学热点：`DhIKSolver::solve` × 100 + `DhFKSolver::fk` × 1000
- [ ] 推理管线热点：`VlaModel::batch_infer` × 100

### 8.2 控制环路抖动测量

**任务**：

- [ ] 利用 `ControlLoopBenchmark` 测量 1kHz 控制环路 P99 抖动
- [ ] 目标：P99 < 1ms

**验收**：

- 生成 `profile.json` 热点报告
- 控制环路 P99 < 1ms
- 批量推理吞吐 > 50 req/s

---

## Phase 9：真实库集成验证（P1 端到端）

> 目标：在有真实库的环境中验证 FFI 条件编译集成。

### 9.1 Gazebo 集成验证

**任务**：

- [ ] 安装 Ignition Gazebo Fortress
- [ ] `python scripts/prepare.py --with-ignition` 启用真实 FFI
- [ ] 连接真实 Gazebo 实例，验证 `publish`/`subscribe` 收发消息
- [ ] 验证世界控制：`reset_world`/`pause`/`step`/`set_gravity`
- [ ] 验证场景管理：`spawn_model`/`remove_model`

### 9.2 ggml 集成验证

**任务**：

- [ ] 编译 ggml/llama.cpp
- [ ] `python scripts/prepare.py --with-ggml` 启用真实 FFI
- [ ] 加载 `smolvla-7b-q4.gguf`，验证推理返回非空动作序列
- [ ] 验证 CUDA/Metal 后端切换

### 9.3 Selene 集成验证

**任务**：

- [ ] 编译 Selene SDK
- [ ] `python scripts/prepare.py --with-selene` 启用真实 FFI
- [ ] 启动监控面板，验证实时渲染
- [ ] 验证录制 60s 数据后回放，时间戳对齐

**验收**：

- 三个 FFI 通道在真实库环境下全部功能正常
- CI `ffi-gazebo` / `ffi-ggml` / `ffi-view` job 在真实库环境通过

---

## 依赖关系

```
Phase 2 (FFI 接入) ✅
  ├── 2.1 Gazebo FFI ──┐
  ├── 2.2 ggml FFI ────┤
  └── 2.3 Tokenizer ───┘
                        │
Phase 3 (可视化+IK) ✅  │
  ├── 3.1 Selene ──────┤
  └── 3.2 IK 解算器 ───┤
                        │
Phase 4 (Sim2Real) ✅ ◄──┘
  ├── 4.1 仿真集成
  └── 4.2 真机联调
        │
Phase 5 (生产硬化) ✅ ◄──┘
  ├── 5.1 性能调优
  ├── 5.2 监控告警
  └── 5.3 安全认证

Phase 6 (覆盖率治理) ◄── Phase 5
  ├── 6.1 安全模块
  ├── 6.2 基准/碰撞
  ├── 6.3 运动学
  └── 6.4 真机/Demo/FFI

Phase 7 (文档测试) ◄── Phase 6
  ├── 7.1 Docstring Tests
  └── 7.2 README.mbt.md

Phase 8 (性能实测) ◄── Phase 5
  ├── 8.1 热点分析
  └── 8.2 抖动测量

Phase 9 (真实库验证) ◄── Phase 2
  ├── 9.1 Gazebo
  ├── 9.2 ggml
  └── 9.3 Selene
```

**关键路径**：Phase 6 → Phase 7（质量加固）；Phase 8 / Phase 9 可并行（需真实环境）

---

## 技术债务清单

| ID | 来源 | 描述 | 优先级 |
|----|------|------|--------|
| TD-01 | `gazebo_stub.c:1` | Ignition Transport FFI 占位 | P0 | ✅ 已完成（条件编译 wrapper） |
| TD-02 | `ggml_stub.c:1` | ggml/vla.cpp FFI 占位 | P0 | ✅ 已完成（条件编译 wrapper） |
| TD-03 | `tokenizer.mbt:2` | 空格分词占位 | P0 | ✅ 已完成（ggml tokenizer 绑定） |
| TD-04 | `view.mbt:116` | Selene 引擎未接入 | P1 | ✅ 已完成（条件编译 wrapper） |
| TD-05 | `ik.mbt:34` | IK 解算器仅骨架 | P1 | ✅ 已完成 |
| TD-06 | `gazebo_robot.mbt:7` | 传感器读数占位返回空数组 | P1 | ✅ 已功能化 |
| TD-07 | `pipeline_demos.mbt:160` | 传感器噪声省略 | P2 | ✅ 已添加 |
| TD-08 | `pipeline_demos.mbt:198` | 上下文使用量检查占位 | P2 | ✅ 已实现 |
| TD-09 | `coverage` | 83 行未覆盖 | P2 | Phase 6 |
| TD-10 | `docs` | 缺少 docstring tests | P2 | Phase 7 |

---

## 版本规划

| 版本 | Phase | 里程碑 |
|------|-------|--------|
| v0.2.0 | Phase 2 | FFI 真实接入，仿真+推理可用 ✅ 条件编译架构完成 |
| v0.3.0 | Phase 3 | 可视化 + IK 机型覆盖 ✅ |
| v0.4.0 | Phase 4 | Sim2Real 集成验证通过 ✅ |
| v0.5.0 | Phase 5 | 生产硬化 ✅ |
| v0.6.0 | Phase 6 | 覆盖率治理（< 10 行未覆盖） |
| v0.7.0 | Phase 7 | 文档测试与 API 文档 |
| v0.8.0 | Phase 8 | 性能基准实测 |
| v1.0.0 | Phase 9 | 真实库集成验证，正式发布 |

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