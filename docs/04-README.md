# Embit

> 轻量内核，全栈具身 —— 基于 MoonBit 的下一代通用具身机器人开发框架

[![License](https://img.shields.io/badge/license-Apache--2.0-green)](#许可证)

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

- MoonBit 工具链 >= 0.1.20260807
- Ignition Gazebo Fortress / Harmonic
- CMake >= 3.20（FFI 编译必需）
- Git LFS（模型文件下载必需）
- （可选）支持 CUDA 的 GPU 设备

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
fn main() {
  let robot = GazeboRobot::connect("t800")?
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")?
  let image = robot.get_camera_image()
  let command = "走到桌子旁边拿起水杯"
  let actions = model.infer(image, command)
  robot.execute_actions(actions)
}
```

## 文档链接

- [技术文档（完整架构与设计）](./docs/02-技术文档.md)
- [项目申报书](./docs/01-项目申报书.md)
- [品牌故事](./docs/03-品牌故事.md)

## 文件结构

```
embit/
├── embit-core/          # 核心基础库：通用类型、工具、抽象接口
├── embit-gazebo/        # 仿真通信SDK：Ignition Transport FFI 绑定
├── embit-ggml/          # 全尺度VLA推理SDK：ggml/vla.cpp 封装
├── embit-control/       # 运动控制框架：机器人抽象层、运动学解算
├── embit-view/          # 可视化调试面板：基于 Selene 的实时监控工具
├── embit-examples/      # 示例工程集：人形/四足/机械臂 Demo
├── docs/                # 项目文档
│   ├── 01-项目申报书.md
│   ├── 02-技术文档.md
│   └── 03-品牌故事.md
├── docs/04-README.md
├── models/              # VLA 模型文件（.gguf）
└── LICENSE
```

## 开发路线图

| 阶段 | 时间 | 里程碑 |
|------|------|--------|
| Phase 1 | 第1个月 | 完成 Ignition Transport 与 ggml 基础 FFI 绑定 |
| Phase 2 | 第2-3个月 | 发布 embit-gazebo、embit-ggml 首个稳定版本 |
| Phase 3 | 第4个月 | 完成框架整体联调，适配人形/四足/机械臂三类标准 URDF |
| Phase 4 | 第5个月 | 完成性能验证（延迟基准测试、抖动测量） |
| Phase 5 | 第6个月 | v1.0 正式版发布，社区开源共建体系搭建 |

## 贡献指南

我们欢迎任何形式的贡献：

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
