# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to semantic versioning.

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
- `full_stack_demo`：全栈综合 Demo，串联框架全部核心功能（RobotBuilder + GazeboRobot + 世界控制 + 场景管理 + JointGroup + CartesianController + PID + SensorFusion + Timer + DataSeries + ViewPanel + VLA + 安全联锁）

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
