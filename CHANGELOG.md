# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to semantic versioning.

## [0.5.1] — 2026-08-22

### Changed — 全面审查与迭代修正

#### 版本一致性修正
- `moon.mod`：版本号从 `0.1.2` 更新至 `0.5.0`，与 CHANGELOG 和 roadmap 对齐
- `README.md`：测试徽章从 `420 passed` 更新至 `497 passed`，Phase 徽章从 `Phase 5` 更新至 `Phase 8`
- `README.md`：Phase 状态表新增 Phase 6/7/8/9 行，反映当前进展
- `roadmap.md`：状态快照更新（版本 v0.5.0、497 测试、7 CI job），版本规划表对齐
- `自查报告.md`：全面更新（8000 行代码、497 测试、21 Demo、Phase 1-8 完成）

#### 代码质量改进
- `embit-control/safety.mbt`：`joint_name_to_index` 从 `name.length() % count` 改为多项式滚动哈希（乘子 31），大幅降低关节名哈希碰撞概率
- `.github/workflows/ci.yml`：`moon test` 显式指定 `--target native`，与 `preferred_target` 一致

#### 技术债务清理
- `roadmap.md`：技术债务清单新增 TD-11（哈希碰撞修复）和 TD-12（CI target 修正），均标记已完成

### 验证
- 代码审查：133 个文件全量审查，无 TODO/FIXME/unwrap/panic 等问题
- 测试覆盖：471 白盒测试 + 26 docstring 测试 = 497 总测试
- 版本一致性：moon.mod / README / CHANGELOG / roadmap / 自查报告 全部对齐

## [0.5.0] — 2026-08-16

### Added — Phase 5 生产硬化

#### 性能调优（embit-control）
- `ControlLoopBenchmark`：控制环路延迟 / 抖动 / P99 / 频率测量，`LoopBenchmarkResult` 结果结构
- `benchmark.mbt`：基准测试工具，支持单次 / 批量采样 + 统计聚合

#### 监控告警（embit-control）
- `AlertSystem`：多级告警（Info / Warning / Error / Critical）+ 关节速度检测 + 通信超时检测 + 推理延迟检测
- `alert.mbt`：告警历史记录 + 告警回调 + 告警过滤

#### 安全认证（embit-control）
- `CollisionDetector`：自碰撞检测 + 环境碰撞检测 + 障碍物管理（添加 / 移除 / 查询）
- `SafetyCertification`：ISO 10218 合规检查（速度 / 力矩 / 保护停止 / 碰撞检测 / 关节限位）+ `CertificationReport` 报告结构
- `safety_cert.mbt`：认证报告生成 + 合规项逐条检查 + 总体合规判定

#### 生产 Demo（embit-examples）
- `performance_tuning_demo`：控制环路基准测试 + 批量推理性能分析
- `monitoring_alert_demo`：AlertSystem 多级告警 + Selene 面板实时监控 + 数据录制
- `safety_certification_demo`：ISO 10218 合规报告生成 + 碰撞检测验证

### 验证
- `moon check --warn-list +all --deny-warn`：0 错误，0 警告
- `moon test --target native`：420 个测试全部通过
- `moon fmt --check`：格式化通过
- `moon info` + `git diff --exit-code`：接口一致性通过

## [0.4.0] — 2026-08-16

### Added — Phase 4.2 真机联调

#### 真机硬件抽象（embit-core）
- `RealRobot`：实现 `Robot` trait 的真机硬件抽象层
  - `connect` / `disconnect` / `emergency_stop` / `is_connected` / `is_emergency_stopped`
  - `execute_actions` / `get_sensor_readings` / `get_model_info`
  - 指令记录追踪（`command_log` / `total_commands`）

#### 安全联锁（embit-control）
- `SafetyController`：综合安全控制器
  - 关节限位检查（`check_joint_limits`）
  - 速度限制检查（`check_velocity_limits`）
  - 力矩限制检查（`check_torque_limits`）
  - 碰撞检测（`check_collision`）
  - 紧急停止协议（`emergency_stop` / `reset` / `is_emergency_stopped`）
  - 综合检查（`check_all`）

#### Sim2Real Demo（embit-examples）
- `real_robot_demo`：真机控制（RealRobot + SafetyController + 轨迹执行）
- `sim2real_consistency_demo`：Sim2Real 一致性验证（相同轨迹在仿真与真机执行对比）
- `safety_interlock_demo`：安全联锁（速度超限检测 + 紧急停止 + 重置恢复）
- `emergency_stop_demo`：紧急停止协议（触发→拒绝→重置→恢复）

### Added — Phase 4.1 仿真集成测试

#### 仿真集成 Demo（embit-examples）
- `sim_scene_setup_demo`：Gazebo 场景搭建（URDF 加载 + 多模型 spawn + 传感器订阅）
- `sim_closed_loop_demo`：100 步仿真闭环（传感器→状态估计→PID→轨迹规划→动作发布→步进→录制）
- `vla_sim_execution_demo`：VLA 推理集成（相机图像→ggml 推理→动作序列→仿真执行）
- `multi_robot_scenario_demo`：多机型场景管理（动态加载/卸载 + 多机器人协调）

### 验证
- `moon check --warn-list +all --deny-warn`：0 错误，0 警告
- `moon test --target native`：413 个测试全部通过
- `moon fmt --check`：格式化通过

## [0.3.0] — 2026-08-15

### Added — Phase 3.1 Selene 可视化引擎 FFI 接入

#### FFI 条件编译（embit-view）
- `selene.h`：Selene 引擎 C 接口声明（25 个函数：引擎 / 场景 / 机器人 / 视图 / 录制 / 回放 / 参数调优）
- `selene_wrapper.c`：真实 Selene API wrapper（`#ifdef EMBIT_HAS_SELENE` 启用）
- `view_stub.c`：条件编译 FFI 入口（无库环境返回占位，有库环境调用真实 API）
- `ffi.mbt`：extern "c" 声明（21 个 FFI 函数）
- `scripts/prepare.py`：Selene 库检测 + 编译 + moon.pkg 配置自动化

#### 可视化能力增强（embit-view）
- `ViewContext` 新增字段：`selene_engine` / `selene_scene` / `selene_robot` / `selene_view`
- `render` / `record` / `playback` / `stop_recording` / `tune_parameter` 接入 FFI
- 12 个查询方法：`is_recording` / `is_playing` / `get_recording_duration` / `get_playback_progress` / `get_engine_fps` / `get_engine_frame_count` / `get_scene_robot_count` / `get_view_width` / `get_view_height` / `get_view_camera_pos` / `get_view_camera_target` / `get_tunable_parameters`

#### CI 集成
- `.github/workflows/ci.yml`：新增 `ffi-view` 集成测试 job

### 验证
- `moon check --warn-list +all --deny-warn`：0 错误，0 警告
- `moon test --target native`：401 个测试全部通过
- `moon fmt --check`：格式化通过

## [0.2.0] — 2026-08-15

### Added — Phase 2 FFI 真实接入与条件编译架构

#### 条件编译 wrapper 模式
- 所有 FFI 包采用 C 层条件编译（`#ifdef EMBIT_HAS_IGNITION` / `EMBIT_HAS_GGML`），MoonBit 层无感知
- 无库环境可编译通过（占位 stub 返回默认值），有库环境启用真实 API
- `scripts/prepare.py`：统一库检测 + 编译 + moon.pkg 配置自动化

#### embit-gazebo FFI 真实接入
- `ignition_transport.h`：Ignition Transport C++ 接口声明
- `gazebo_wrapper.cpp`：真实 Ignition Transport API wrapper（C++ → C 桥接）
- `gazebo_stub.c`：条件编译 FFI 入口
- 真实 API 填充：`connect` / `publish` / `subscribe` / `service_call` / 世界控制 / 场景管理

#### embit-ggml FFI 真实接入
- `ggml.h`：ggml/llama.cpp 接口声明
- `ggml_wrapper.c`：真实 ggml API wrapper
- `ggml_stub.c`：条件编译 FFI 入口
- 真实 API 填充：`load` / `infer` / `batch_infer` / `set_backend` / `free`

#### Tokenizer 真实实现
- `tokenizer.mbt`：BPE 分词器真实实现（替换占位 stub）
- `tokenizer_wrapper.c`：C 层分词器桥接

#### CI 集成测试
- `.github/workflows/ci.yml`：新增 `ffi-gazebo` / `ffi-ggml` 集成测试 job

### 验证
- `moon check --warn-list +all --deny-warn`：0 错误，0 警告
- `moon test --target native`：390 个测试全部通过
- `moon fmt --check`：格式化通过

## [0.1.2] — 2026-08-14

### Added — Phase 10 覆盖率治理与性能基准

#### 测试覆盖（44 → 8 行未覆盖）
- `control_wbtest.mbt`：+10 边缘测试（零速度 / 长度不匹配 / 零时长 / 安全检查空指令 / 时间戳相同 / 未知关节 / get_model）
- `estimator_wbtest.mbt`：+4 测试（空观测 / 直通模式 / 速度观测 / 除零保护）
- `fusion_wbtest.mbt`：+1 测试（dt=0 早返回）
- `dh_kinematics_wbtest.mbt`：+4 测试（FK 角度不足 / IK 初始猜测不足 / 种子补零 / 空参数雅可比）
- `simple_kinematics_wbtest.mbt`：新建 6 测试（SimpleIK/FK/Controller 全覆盖）
- `math_wbtest.mbt`：+1 测试（万向锁 pitch=90°）
- `spatial_wbtest.mbt`：+2 测试（Wrench::new / Wrench::scale）
- `data_series_wbtest.mbt`：+2 测试（min 多点 / to_string 逗号分隔）
- `view_wbtest.mbt`：+3 测试（零帧 progress / 未录制 stop / SensorDisplay+LogPanel 快照）
- `tensor_wbtest.mbt`：+1 测试（空数据 to_scalar）
- `examples_wbtest.mbt`：+1 测试（demo_skeleton）

#### 死代码清理
- `cartesian.mbt`：移除 `actual_steps == 0` 不可达分支
- `control.mbt`：移除 3 处 `actual_steps == 0` 不可达分支（compute_trajectory / cubic / quintic）
- `tokenizer.mbt`：移除 `hash < 0` 不可达检查（多项式滚动哈希恒非负）

#### 性能基准
- `bench_wbtest.mbt`：+4 基准（DH FK 1000 次 / DH IK 100 次 / Kalman 10000 次 / StateEstimator 5000 次）

### 验证
- `moon check --warn-list +unnecessary_annotation`：0 错误，0 警告
- `moon test`：350 个测试全部通过
- `moon coverage analyze`：8 行未覆盖（均为 FFI stub 恒返回 0 / try! abort / 阻尼正定不可达）
- `moon fmt`：格式化通过

## [0.1.1] — 2026-08-14

### Added — Phase 8 算法实现

#### embit-control（运动控制框架）
- `DHParam`：标准 DH 参数（a / alpha / d / theta / revolute / name）+ `revolute()` / `prismatic()` 工厂
- `DhFKSolver`：DH 参数正运动学解算器（实现 `FKSolver` trait），四元数组合旋转，`arm_6dof()` 预设
- `DhIKSolver`：数值雅可比 + 阻尼最小二乘逆运动学（实现 `IKSolver` trait），高斯消元求解 6×6 线性方程组
- `KalmanFilter1D`：一维卡尔曼滤波器，[位置, 速度] 状态估计，常速度运动模型，predict / update / step
- `StateEstimator::new_kalman()` / `update_joints()`：卡尔曼模式状态估计，逐关节独立滤波
- `StateEstimator::is_kalman_enabled()` / `get_filter()` / `reset()`：估计器查询与管理

### Added — Phase 9 质量加固

#### 工程化
- CI 多平台矩阵（ubuntu-latest / macos-latest / windows-latest）
- CI 严格警告检查（`moon check --warn-list +unnecessary_annotation`）
- CI `moon info` 接口一致性检查
- `embit-examples` 拆分：`models.mbt` / `embodied_demos.mbt` / `pipeline_demos.mbt` / `advanced_demos.mbt`

### 验证
- `moon check --warn-list +unnecessary_annotation`：0 错误，0 警告
- `moon test`：311 个测试全部通过
- `moon fmt` / `moon info`：格式化与接口一致

## [0.1.0] — 2026-08-13

### Added — Phase 1 核心实现

#### embit-core（核心基础库）
- `RobotError` suberror：7 变体（ConnectError / SensorReadError / ActionExecuteError / ModelLoadError / SafetyLimitViolation / UnsupportedRobotType / InvalidConfig）
- 核心数据类型：`JointState` / `SensorType` / `SensorReading` / `ActionCommand`
- 机器人模型描述：`JointType` / `JointSpec` / `SensorSpec` / `SafetyLimits` / `RobotModel` / `RobotModelInfo`
- `Robot` trait（`pub(open)`）：`get_sensor_readings` / `execute_actions` / `get_model_info`

#### embit-gazebo（仿真通信 SDK）
- `GazeboClient`：`connect` / `publish` / `subscribe` / `unsubscribe` / `service_call` / `disconnect` + 各类计数
- 仿真世界控制：`reset_world` / `pause` / `unpause` / `is_paused` / `step` / `set_gravity`
- `GazeboRobot`：实现 `Robot` trait 的仿真机器人封装
- FFI 绑定：`gazebo_stub.c`（自包含占位 C 桥接）+ `ffi.mbt`（IgnitionNode 不透明类型）

#### embit-ggml（VLA 推理 SDK）
- `VlaModel`：`load` / `infer` / `infer_with_config` / `batch_infer` / `batch_infer_with_config` / `set_backend` / `get_backend` / `is_loaded` / `infer_count` / `supported_backends` / `get_model_info` / `free`
- `Backend` 枚举（Cpu / Cuda / Metal）+ `QuantType` 枚举（Fp16 / Q8 / Q4 / Q2）
- `InferConfig` 推理配置 + `ModelInfo` 模型元信息
- `Tensor` 多维张量 + `DType` 数据类型 + `Tokenizer` 分词器
- FFI 绑定：`ggml_stub.c` + `ffi.mbt`（GgmlContext 不透明类型）

#### embit-control（运动控制框架）
- 轨迹类型：`TrajectoryConstraints` / `Waypoint` / `Trajectory`（+ `to_commands` / `blend` 轨迹融合）
- `MotionController`：`compute_trajectory`（线性）/ `compute_trajectory_cubic`（三次）/ `compute_trajectory_quintic`（五次）/ `execute_trajectory` / `check_safety`
- `PIDController`：P/I/D 控制 + 输出限幅 + 积分抗饱和
- `ImpedanceController`：弹簧-阻尼阻抗控制 + 临界阻尼公式
- `SensorFusion`：互补滤波器 + 零偏校准 + 低通滤波
- `StateEstimator` / `Pose` / `IKSolver` / `FKSolver` trait
- `JointGroup` / `JointGroupManager`：关节组管理

#### embit-view（可视化面板）
- `WidgetType` 枚举（5 种组件）+ `Widget` / `RecordingHandle` / `PlaybackStream`
- `ViewPanel`：`add_widget` / `render` / `record` / `playback` / `tune_parameter` / `export_snapshot`
- `DataSeries`：实时时间序列（环形缓冲 + 范围查询 + 统计）

#### embit-core 扩展
- `utils.mbt`：角度/时间/插值工具函数（15 个）
- `math.mbt`：`Quaternion`（四元数）+ `Transform`（SE(3) 变换）
- `spatial.mbt`：`Twist`（空间速度）+ `Wrench`（力旋量）+ 互易积
- `timer.mbt`：`Timer` 计时器（控制环路计时 + 频率统计）
- `config.mbt`：`EmbConfig` 配置管理 + `LogLevel` 日志级别
- `builder.mbt`：`RobotBuilder` 模型工厂（humanoid_12dof / quadruped_12dof / arm_6dof / dual_arm_14dof / mobile_base）

#### embit-examples（示例工程）
- `humanoid_walk` / `quadruped_avoid` / `arm_grasp`：三类典型任务 Demo
- `vla_pipeline_demo`：VLA 推理管线完整 Demo
- `impedance_control_demo`：阻抗控制 Demo
- `sensor_fusion_demo`：传感器融合 Demo
- `batch_inference_demo`：批量推理 Demo

### Added — Phase 3 系统整合与多机型适配

#### embit-control（运动控制框架）
- `CartesianController[IK, FK]`：泛型笛卡尔空间控制器（`move_to` / `to_joint_states` / `get_end_effector_pose` / `end_effector_name` / `dof`）
- `CartesianWaypoint` / `CartesianTrajectory`：笛卡尔空间轨迹类型
- `SimpleIKSolver` / `SimpleFKSolver`：简化运动学解算器（6-DOF，位姿↔关节角度直接映射）
- `SimpleCartesianController`：非泛型包装器（跨包使用，避免泛型 trait bound 可见性问题）

#### embit-gazebo（仿真通信 SDK）
- 场景管理：`spawn_model` / `remove_model` / `model_count`（FFI + C stub + MoonBit 封装）

#### embit-examples（示例工程）
- `multi_robot_scene_demo`：多机型场景管理 Demo（RobotBuilder + GazeboRobot + JointGroup + 场景管理）
- `cartesian_control_demo`：笛卡尔空间控制 Demo（SimpleCartesianController + 轨迹规划 + FK 一致性验证）

### Changed
- README 文档结构优化，示例代码更新为实际 API
- `Robot` trait 改为 `pub(open)` 允许跨包实现
- `GazeboRobot` 的 `extend` 声明改为 `pub extend`，使 Robot trait 方法可跨包点号调用
- 所有 FFI 包设为 `supported_targets = "native"`

### Added — Phase 4 场景 Demo 与性能优化

#### 性能基准测试
- `embit-control/bench_wbtest.mbt`：9 个基准测试
  - 轨迹规划：1000 次三次 / 500 次五次 / 1000 次轨迹融合
  - 控制环路：10000 次 PID / 10000 次阻抗控制
  - 传感器融合：10000 次互补滤波
  - 运动学解算：1000 次 IK/FK 互逆 / 500 次笛卡尔管线
  - 关节组管理：100 关节大规模批量操作

#### 文档
- `docs/04-性能基准报告.md`：性能基准报告（测试环境 / 基准结果 / 目标达成 / 复杂度分析 / 优化方向）

#### embit-examples（示例工程增强）
- 三类 Demo 增加安全联锁检查（`check_safety`）
- `full_stack_demo`：全栈综合 Demo，串联框架全部核心功能

### Added — Phase 5 开源发布与生态建设

#### 工程化
- 版本号更新至 `1.0.0`
- GitHub Actions CI/CD（`moon check` / `moon test` / `moon fmt --check`）
- Issue 模板（Bug Report / Feature Request）+ Pull Request 模板
- `CONTRIBUTING.md` 贡献指南（开发环境 / 项目结构 / 编码规范 / 测试规范 / 模块依赖）

### 验证
- `moon check`：0 错误，23 警告（均为预期）
- `moon test`：281 个测试全部通过
- `moon fmt`：格式化完成
