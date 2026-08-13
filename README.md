# Embit

> 轻量内核，全栈具身 —— 基于 MoonBit 的下一代通用具身机器人开发框架

[![License](https://img.shields.io/badge/license-Apache--2.0-green)](LICENSE)

## 项目简介

Embit 是基于 MoonBit 的通用具身智能机器人全栈开发框架，打通「动力学仿真—多模态感知—VLA推理—运动控制—真机部署」完整技术链路，为机器人研发提供一套无 Python 依赖、高实时性、内存安全、跨硬件部署的新一代技术底座。

框架采用分层解耦设计，既具备端侧轻量化部署的核心优势，也完全兼容中大规模具身大模型的工作站级训练与推理，可快速适配人形机器人、四足机器人、协作机械臂、轮式移动机器人等全品类形态。

## 核心特性

- 🚀 **全链路原生 MoonBit 实现**：从仿真交互、推理调度到运动控制统一基于 MoonBit 开发，静态编译单文件部署，彻底摆脱 Python 依赖，运行性能接近原生 C
- 🤖 **通用机器人抽象层**：基于 URDF 标准设计，配置化适配多形态机器人，一次开发跨机型复用
- 🧠 **全尺度 VLA 推理兼容**：基于 ggml/vla.cpp 构建，支持从 1B 端侧轻量模型到 70B+ 通用具身大模型，覆盖 INT4~FP16 全精度
- ⚡ **高实时性控制运行时**：依托 MoonBit 结构化并发与内存安全特性，实现微秒级控制环路抖动
- 🔌 **仿真与真机无缝切换**：统一硬件抽象接口，Sim2Real 迁移成本极低
- 🎛️ **内置可视化调试工具**：基于 Selene 引擎打造监控面板，支持实时状态观测、数据回放、参数在线调优

## 快速开始

### 环境要求

- MoonBit 工具链 >= 0.1.20260713（`preferred_target = "native"`）
- C 编译器（FFI native-stub 编译必需，Windows 下随 MoonBit 附带 TCC）
- Ignition Gazebo Fortress / Harmonic（仿真模式）
- （可选）支持 CUDA / Metal 的 GPU 设备

### 安装

```bash
moon add toadium/embit/embit-core
moon add toadium/embit/embit-gazebo
moon add toadium/embit/embit-ggml
moon add toadium/embit/embit-control
moon add toadium/embit/embit-view
moon add toadium/embit/embit-examples
```

### 最小示例

```moonbit
/// 人形机器人行走 Demo：仿真 → VLA 推理 → 轨迹规划 → 执行 → 监控
fn main() -> Unit raise @core.RobotError {
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

也可直接调用内置 Demo：

```moonbit
fn main() -> Unit raise @core.RobotError {
  @examples.humanoid_walk()           // 人形行走
  @examples.quadruped_avoid()         // 四足避障
  @examples.arm_grasp()               // 机械臂抓取
  @examples.vla_pipeline_demo()       // VLA 推理管线
  @examples.impedance_control_demo()  // 阻抗控制
  @examples.sensor_fusion_demo()      // 传感器融合
  @examples.batch_inference_demo()    // 批量推理
  @examples.multi_robot_scene_demo()  // 多机型场景管理
  @examples.cartesian_control_demo()  // 笛卡尔空间控制
  @examples.full_stack_demo()         // 全栈综合 Demo
}
```

## 文档链接

- [技术文档（完整架构与设计）](./docs/02-技术文档.md)
- [性能基准报告](./docs/04-性能基准报告.md)
- [项目申报书](./docs/01-项目申报书.md)
- [品牌故事与命名体系](./docs/03-品牌故事.md)

## 文件结构

```
embit/
├── embit-core/          # 核心基础库：RobotError / JointState / RobotModel / Robot trait / RobotBuilder
├── embit-gazebo/        # 仿真通信 SDK：GazeboClient + GazeboRobot + 世界控制 + 场景管理1
├── embit-ggml/          # VLA 推理 SDK：VlaModel + Tensor + Tokenizer + Backend
├── embit-control/       # 运动控制：轨迹规划 + IK/FK + PID + 阻抗 + 笛卡尔控制 + 关节组
├── embit-view/          # 可视化面板：Widget / 录制回放 / 实时监控 / DataSeries
├── embit-examples/      # 示例工程：11 个 Demo（人形/四足/机械臂/VLA/阻抗/融合/批量/多机型/笛卡尔/全栈）
├── docs/                # 项目文档
│   ├── 01-项目申报书.md
│   ├── 02-技术文档.md
│   ├── 03-品牌故事.md
│   └── 04-性能基准报告.md
├── moon.mod             # 模块元数据（toadium/embit v1.0.0, native target）
├── CONTRIBUTING.md      # 贡献指南
├── .github/             # CI/CD + Issue/PR 模板
└── LICENSE
```

## 贡献指南

详见 [CONTRIBUTING.md](CONTRIBUTING.md)。简要流程：

1. Fork 本仓库
2. 创建特性分支（`git checkout -b feature/xxx`）
3. 提交变更（`git commit -m "feat: xxx"`）
4. 推送到分支（`git push origin feature/xxx`）
5. 提交 Pull Request

代码规范：遵循 MoonBit 官方风格指南，所有 PR 需通过 `moon check` 与 `moon test`。

## 许可证

本项目采用 **Apache License 2.0** 协议开源。详见 [LICENSE](LICENSE)。

## 致谢

- [MoonBit](https://www.moonbitlang.com/) — 国产新一代系统编程语言
- [Mooncakes](https://mooncakes.io/) — MoonBit 包管理仓库
- [Ignition Gazebo](https://gazebosim.org/) — 开源机器人仿真引擎
- [ggml](https://github.com/ggerganov/ggml) — 轻量级推理引擎
- [Selene](https://github.com/selenesim/selene) — MoonBit 生态可视化监控工具
