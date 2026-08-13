# Embit

> 轻量内核，全栈具身 —— 基于 MoonBit 的下一代通用具身机器人开发框架

<!-- 徽章行：待接入 CI 后替换 -->
[![Build Status](https://img.shields.io/badge/build-pending-blue?label=CI)](待接入CI后替换)
[![Version](https://img.shields.io/badge/version-wip-orange?label=WIP)](待版本确定后替换)
[![License](https://img.shields.io/badge/license-Apache--2.0-green)](#许可证)

## 项目简介

Embit 是基于 MoonBit 的通用具身智能机器人全栈开发框架，打通「动力学仿真—多模态感知—VLA推理—运动控制—真机部署」完整技术链路，为机器人研发提供一套无 Python 依赖、高实时性、内存安全、跨硬件部署的新一代技术底座。

框架采用分层解耦设计，既具备端侧轻量化部署的核心优势，也完全兼容中大规模具身大模型的工作站级训练与推理，可快速适配人形机器人、四足机器人、协作机械臂、轮式移动机器人等全品类形态，兼顾科研算法迭代效率与工业落地稳定性。

## 核心特性

- 🚀 **全链路原生 MoonBit 实现**：从仿真交互、推理调度到运动控制统一基于 MoonBit 开发，静态编译单文件部署，彻底摆脱 Python 依赖地狱，运行性能接近原生 C
- 🤖 **通用机器人抽象层**：基于 URDF 标准设计，配置化适配多形态机器人，一次开发跨机型复用，无需重复造轮子
- 🧠 **全尺度 VLA 推理兼容**：基于 ggml/vla.cpp 构建，支持从 1B 端侧轻量模型到 70B+ 通用具身大模型，覆盖 INT4~FP16 全精度，CPU/GPU/嵌入式多硬件统一调度
- ⚡ **高实时性控制运行时**：依托 MoonBit 结构化并发与内存安全特性，实现微秒级控制环路抖动，满足机器人高频实时控制需求
- 🔌 **仿真与真机无缝切换**：统一硬件抽象接口，同一套控制代码可直接运行于 Ignition Gazebo 仿真环境与实体嵌入式机器人，Sim2Real 迁移成本极低
- 🎛️ **内置可视化调试工具**：基于 Selene 引擎打造监控面板，支持实时状态观测、数据回放、参数在线调优，大幅提升开发调试效率

## 快速开始

### 环境要求

- MoonBit 工具链 >= 0.10.0
- Ignition Gazebo Fortress / Harmonic
- CMake >= 3.20（FFI 编译必需）
- Git LFS（模型文件下载必需）
- （可选）支持 CUDA 的 GPU 设备，用于大模型加速推理

### 安装

```bash
# 添加核心依赖到你的 MoonBit 项目
moon add embit/embit-core
moon add embit/embit-gazebo
moon add embit/embit-ggml
moon add embit/embit-control
moon add embit/embit-view
moon add embit/embit-examples
```

### 最小示例：控制仿真机器人接收 VLA 指令

```moonbit
fn main() {
  // 1. 连接仿真环境
  let robot = GazeboRobot::connect("t800")?
  // 2. 加载VLA行动模型
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")?
  // 3. 获取视觉观测 + 语言指令
  let image = robot.get_camera_image()
  let command = "走到桌子旁边拿起水杯"
  // 4. 推理生成动作序列并执行
  let actions = model.infer(image, command)
  robot.execute_actions(actions)
}
```

## 文档链接

- [技术文档（完整架构与设计）](./docs/02-技术文档.md)
- [项目申报书](./docs/01-项目申报书.md)
- [品牌故事](./docs/03-品牌故事.md)

## 项目结构

```
embit/
├── embit-core/          # 核心基础库：通用类型、工具、抽象接口
├── embit-gazebo/        # 仿真通信SDK：Ignition Transport FFI 绑定
├── embit-ggml/          # 全尺度VLA推理SDK：ggml/vla.cpp 封装
├── embit-control/       # 运动控制框架：机器人抽象层、运动学解算、安全联锁
├── embit-view/          # 可视化调试面板：基于 Selene 的实时监控工具
├── embit-examples/      # 示例工程集：人形/四足/机械臂 Demo
├── docs/                # 项目文档
│   ├── 01-项目申报书.md
│   ├── 02-技术文档.md
│   ├── 03-品牌故事.md
│   └── 04-README.md
├── models/              # VLA 模型文件（.gguf）
├── LICENSE              # Apache License 2.0
└── README.md
```

## 开发路线图

### ✅ Phase 1：核心能力验证（第1个月）
- 完成 Ignition Transport 基础 FFI 绑定
- 完成 ggml 基础推理 FFI 绑定
- 实现最简机器人控制 Demo

### 🔄 Phase 2：SDK与框架开发（第2-3个月）
- 发布 embit-gazebo、embit-ggml 首个稳定版本
- 完成通用机器人抽象层与控制框架
- 基础可视化工具上线

### 📅 Phase 3：系统整合与多机型适配（第4个月）
- 完成框架整体联调
- 适配人形、四足、机械臂三类标准 URDF 模型
- 完善文档与示例

### 📅 Phase 4：场景Demo与性能优化（第5个月）
- 完成三类典型具身任务 Demo
- 实时性与性能优化
- 基准测试与指标发布

### 📅 Phase 5：开源发布与生态建设（第6个月）
- v1.0 正式版发布
- 全套文档上线
- 社区开源共建体系搭建

## 贡献指南

我们欢迎任何形式的贡献，包括但不限于：

- 提交 Bug 报告与功能建议
- 贡献代码、修复问题
- 完善文档与示例
- 新增机器人机型适配

贡献流程：

1. Fork 本仓库
2. 创建特性分支（`git checkout -b feature/xxx`）
3. 提交变更（`git commit -m "feat: xxx"`）
4. 推送到分支（`git push origin feature/xxx`）
5. 提交 Pull Request

代码规范：遵循 MoonBit 官方风格指南，所有 PR 需通过 `moon check` 与 `moon test`。

## 许可证

本项目采用 **Apache License 2.0** 协议开源，可自由用于个人学习、科研与商业项目。

> ⚠️ 许可证以 `LICENSE` 文件为准，发布前请最终确认。

## 致谢

- [MoonBit](https://www.moonbitlang.com/) — 国产新一代系统编程语言
- [Mooncakes](https://mooncakes.io/) — MoonBit 包管理仓库
- [Ignition Gazebo](https://gazebosim.org/) — 开源机器人仿真引擎
- [ggml](https://github.com/ggerganov/ggml) — 轻量级推理引擎
- [Selene](https://github.com/selenesim/selene) — MoonBit 生态可视化监控工具
