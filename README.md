# Embit

> 轻量内核，全栈具身 —— 基于 MoonBit 的下一代通用具身机器人开发框架

[![License](https://img.shields.io/badge/license-Apache--2.0-green)](LICENSE)
[![MoonBit](https://img.shields.io/badge/MoonBit-%3E%3D0.1.20260807-blue)](https://www.moonbitlang.com/)
[![Tests](https://img.shields.io/badge/tests-497%20passed-brightgreen)]()
[![Phase](https://img.shields.io/badge/Phase-8%20complete-success)](roadmap.md)

## 项目简介

Embit 是基于 MoonBit 的通用具身智能机器人全栈开发框架，打通「动力学仿真—多模态感知—VLA推理—运动控制—真机部署」完整技术链路，为机器人研发提供一套无 Python 依赖、高实时性、内存安全、跨硬件部署的新一代技术底座。

框架采用分层解耦设计，既具备端侧轻量化部署的核心优势，也完全兼容中大规模具身大模型的工作站级训练与推理，可快速适配人形机器人、四足机器人、协作机械臂、轮式移动机器人等全品类形态。

## 项目状态

| Phase | 内容 | 状态 |
|-------|------|------|
| Phase 1 | 核心实现（Robot trait / 仿真 / 推理 / 控制 / 可视化） | ✅ 完成 |
| Phase 2 | FFI 真实接入（Gazebo + ggml + Tokenizer 条件编译） | ✅ 完成 |
| Phase 3 | 可视化引擎接入（Selene FFI）+ IK 机型覆盖 | ✅ 完成 |
| Phase 4 | Sim2Real 集成验证（仿真闭环 + 真机联调） | ✅ 完成 |
| Phase 5 | 生产硬化（性能调优 + 监控告警 + 安全认证） | ✅ 完成 |
| Phase 6 | 覆盖率治理（83→29 行未覆盖，+47 白盒测试） | ✅ 完成 |
| Phase 7 | 文档测试与 API 文档（docstring tests） | ✅ 完成 |
| Phase 8 | 性能基准实测（PID/FK/Safety 热点 + 环路基准） | ✅ 完成 |
| Phase 9 | 真实库集成验证（Gazebo + ggml + Selene） | ⏳ 待验证 |

详见 [roadmap.md](roadmap.md)。

## 核心特性

- 🚀 **全链路原生 MoonBit 实现**：从仿真交互、推理调度到运动控制统一基于 MoonBit 开发，静态编译单文件部署，彻底摆脱 Python 依赖，运行性能接近原生 C
- 🤖 **通用机器人抽象层**：基于 URDF 标准设计，配置化适配多形态机器人，一次开发跨机型复用
- 🧠 **全尺度 VLA 推理兼容**：基于 ggml/vla.cpp 构建，支持从 1B 端侧轻量模型到 70B+ 通用具身大模型，覆盖 INT4~FP16 全精度
- ⚡ **高实时性控制运行时**：依托 MoonBit 结构化并发与内存安全特性，实现微秒级控制环路抖动
- 📐 **DH 参数运动学**：标准 DH 约定正运动学 + 阻尼最小二乘逆运动学，支持 6-DOF 工业机械臂
- 📊 **卡尔曼滤波状态估计**：常速度模型 1D 卡尔曼滤波，逐关节独立 [位置, 速度] 估计
- 🔌 **仿真与真机无缝切换**：统一硬件抽象接口（`GazeboRobot` / `RealRobot`），Sim2Real 迁移成本极低
- 🎛️ **内置可视化调试工具**：基于 Selene 引擎打造监控面板，支持实时状态观测、数据回放、参数在线调优
- 🛡️ **全面安全联锁**：关节限位 / 速度限制 / 力矩限制 / 碰撞检测 / 紧急停止 / ISO 10218 合规检查
- 📈 **性能基准与监控告警**：控制环路抖动测量 + 多级告警系统（Info/Warning/Error/Critical）

## FFI 条件编译架构

所有 FFI 包采用条件编译 wrapper 模式，无库环境可编译通过，有库环境启用真实 API：

| 包 | 条件编译宏 | 真实库 | 启用方式 |
|----|-----------|--------|---------|
| `embit-gazebo` | `EMBIT_HAS_IGNITION` | Ignition Transport (C++) | `python scripts/prepare.py --with-ignition` |
| `embit-ggml` | `EMBIT_HAS_GGML` | ggml/llama.cpp (C) | `python scripts/prepare.py --with-ggml` |
| `embit-view` | `EMBIT_HAS_SELENE` | Selene 可视化引擎 (C) | `python scripts/prepare.py --with-selene` |

## 快速开始

### 环境要求

- MoonBit 工具链 >= 0.1.20260807（`preferred_target = "native"`）
- C 编译器（FFI native-stub 编译必需，Windows 下随 MoonBit 附带 TCC）
- Ignition Gazebo Fortress / Harmonic（仿真模式，可选）
- ggml/llama.cpp（VLA 推理，可选）
- Selene SDK（可视化引擎，可选）
- （可选）支持 CUDA / Metal 的 GPU 设备

### 安装

```bash
moon add walkzzz/embit/embit-core
moon add walkzzz/embit/embit-gazebo
moon add walkzzz/embit/embit-ggml
moon add walkzzz/embit/embit-control
moon add walkzzz/embit/embit-view
moon add walkzzz/embit/embit-examples
```

### 最小示例

```moonbit
/// 人形机器人行走 Demo：仿真 → VLA 推理 → 轨迹规划 → 执行 → 监控
fn main raise @core.RobotError {
  // 1. 连接仿真环境
  let sim = @gazebo.GazeboClient::connect("localhost:9000")
  // 2. 加载 VLA 模型（.gguf 格式）
  let model = @ggml.VlaModel::load("models/smolvla-7b-q4.gguf")
  // 3. VLA 推理：图像 + 语言指令 → 动作序列
  let _ = model.infer(b"camera_image", "walk forward 2 meters")
  // 4. 构建运动控制器并规划轨迹
  let ctrl = @control.MotionController::new(robot_model)
  let traj = ctrl.compute_trajectory(start, goal, constraints)
  // 5. 发布轨迹到仿真
  for wp in traj.waypoints {
    sim.publish("/joint_commands", b"waypoint")
  }
  // 6. 清理
  model.free()
  sim.disconnect()
}
```

### 内置 Demo

```moonbit
fn main raise @core.RobotError {
  // Phase 1 具身任务
  @examples.humanoid_walk()           // 人形行走
  @examples.quadruped_avoid()         // 四足避障
  @examples.arm_grasp()               // 机械臂抓取
  // Phase 2 管线
  @examples.vla_pipeline_demo()       // VLA 推理管线
  @examples.impedance_control_demo()  // 阻抗控制
  @examples.sensor_fusion_demo()      // 传感器融合
  @examples.batch_inference_demo()    // 批量推理
  // Phase 3-4 高级
  @examples.multi_robot_scene_demo()  // 多机型场景管理
  @examples.cartesian_control_demo()  // 笛卡尔空间控制
  @examples.full_stack_demo()         // 全栈综合 Demo
  // Phase 4 仿真集成
  @examples.sim_scene_setup_demo()    // 仿真场景搭建
  @examples.sim_closed_loop_demo()    // 仿真闭环（100 步）
  @examples.vla_sim_execution_demo()  // VLA 仿真执行
  @examples.multi_robot_scenario_demo() // 多机型协调
  // Phase 4 真机联调
  @examples.real_robot_demo()         // 真机控制
  @examples.sim2real_consistency_demo() // Sim2Real 一致性
  @examples.safety_interlock_demo()   // 安全联锁
  @examples.emergency_stop_demo()     // 紧急停止
  // Phase 5 生产硬化
  @examples.performance_tuning_demo() // 性能调优
  @examples.monitoring_alert_demo()   // 监控告警
  @examples.safety_certification_demo() // 安全认证
}
```

## 文档链接

- [技术文档（完整架构与设计）](./docs/02-技术文档.md)
- [性能基准报告](./docs/04-性能基准报告.md)
- [项目申报书](./docs/01-项目申报书.md)
- [品牌故事与命名体系](./docs/03-品牌故事.md)
- [迭代路线图](./roadmap.md)
- [变更日志](./CHANGELOG.md)

## 文件结构

```
embit/
├── embit-core/          # 核心基础库：RobotError / JointState / RobotModel / Robot trait / RobotBuilder / RealRobot
├── embit-gazebo/        # 仿真通信 SDK：GazeboClient + GazeboRobot + 世界控制 + 场景管理 + FFI(Ignition Transport)
├── embit-ggml/          # VLA 推理 SDK：VlaModel + Tensor + Tokenizer + Backend + FFI(ggml/llama.cpp)
├── embit-control/       # 运动控制：轨迹规划 + DH运动学(IK/FK) + 卡尔曼滤波 + PID + 阻抗 + 笛卡尔控制
│                        #   + SafetyController + AlertSystem + CollisionDetector + SafetyCertification + ControlLoopBenchmark
├── embit-view/          # 可视化面板：Widget / 录制回放 / 实时监控 / DataSeries + FFI(Selene)
├── embit-examples/      # 示例工程：21 个 Demo（具身任务/管线/高级/仿真集成/真机联调/生产硬化）
├── docs/                # 项目文档
│   ├── 01-项目申报书.md
│   ├── 02-技术文档.md
│   ├── 03-品牌故事.md
│   └── 04-性能基准报告.md
├── .github/             # CI/CD（check/test/fmt/info + FFI 集成测试）+ Issue/PR 模板
├── moon.mod             # 模块元数据（walkzzz/embit, native target）
├── CONTRIBUTING.md      # 贡献指南
├── CHANGELOG.md         # 变更日志
├── roadmap.md           # 迭代路线图
└── LICENSE              # Apache 2.0
```

## 贡献指南

详见 [CONTRIBUTING.md](CONTRIBUTING.md)。简要流程：

1. Fork 本仓库
2. 创建特性分支（`git checkout -b feature/xxx`）
3. 提交变更（`git commit -m "feat: xxx"`）
4. 推送到分支（`git push origin feature/xxx`）
5. 提交 Pull Request

代码规范：遵循 MoonBit 官方风格指南，所有 PR 需通过 `moon check --warn-list +all --deny-warn` 与 `moon test --target native`。

## 许可证

本项目采用 **Apache License 2.0** 协议开源。详见 [LICENSE](LICENSE)。

## 致谢

- [MoonBit](https://www.moonbitlang.com/) — 国产新一代系统编程语言
- [Mooncakes](https://mooncakes.io/) — MoonBit 包管理仓库
- [Ignition Gazebo](https://gazebosim.org/) — 开源机器人仿真引擎
- [ggml](https://github.com/ggerganov/ggml) — 轻量级推理引擎
- [Selene](https://github.com/selenesim/selene) — MoonBit 生态可视化监控工具
