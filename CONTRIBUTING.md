# 贡献指南

感谢你对 Embit 的关注！欢迎任何形式的贡献。

## 开发环境

### 必要工具

- [MoonBit 工具链](https://www.moonbitlang.com/) >= 0.1.20260713
- C 编译器（FFI native-stub 编译必需，Windows 下随 MoonBit 附带 TCC）

### 可选工具

- Ignition Gazebo Fortress / Harmonic（仿真模式）
- 支持 CUDA / Metal 的 GPU 设备（推理加速）

### 环境搭建

```bash
# 克隆仓库
git clone https://github.com/toadium/embit.git
cd embit

# 验证环境
moon check
moon test
```

## 项目结构

```
embit/
├── embit-core/       # 核心基础库（RobotError / JointState / RobotModel / Robot trait）
├── embit-gazebo/     # 仿真通信 SDK（GazeboClient + GazeboRobot + 场景管理）
├── embit-ggml/       # VLA 推理 SDK（VlaModel + Tensor + Tokenizer）
├── embit-control/    # 运动控制（轨迹规划 + IK/FK + PID + 阻抗 + 笛卡尔控制）
├── embit-view/       # 可视化面板（Widget / 录制回放 / DataSeries）
├── embit-examples/   # 示例工程（11 个 Demo）
└── docs/             # 项目文档
```

## 开发流程

### 1. Fork & Branch

```bash
git checkout -b feature/your-feature
```

### 2. 编码

- 遵循 MoonBit 官方风格指南
- 文件名使用 `snake_case`，类型名使用 `PascalCase`
- 为新功能编写白盒测试（`*_wbtest.mbt`）
- 为新模块编写集成测试

### 3. 验证

提交前必须通过以下检查：

```bash
moon check    # 编译检查（0 错误）
moon test     # 全量测试（全部通过）
moon fmt      # 代码格式化
```

### 4. 提交

提交信息格式：

```
<type>: <description>

[optional body]
```

类型：
- `feat`: 新功能
- `fix`: Bug 修复
- `refactor`: 重构
- `docs`: 文档
- `test`: 测试
- `perf`: 性能优化

### 5. Pull Request

- 填写 PR 模板中的检查清单
- 关联相关 Issue（`Closes #N`）
- 等待 CI 检查通过

## 代码规范

### MoonBit 风格

- 使用 `pub(open) trait` 允许跨包实现
- FFI 包设置 `supported_targets = "native"`
- struct 字面量使用 `{ field: value, }` 语法
- 泛型函数使用 `fn[T : Trait] func_name(...)` 新语法
- `extend` 声明用于 trait 方法的直接调用

### 文档注释

所有公开 API 使用 `///|` 文档注释：

```moonbit
///|
/// 简要描述函数功能。
///
/// 参数说明与返回值说明。
pub fn my_function(x : Double) -> Double {
  x * 2.0
}
```

### 测试规范

- 白盒测试：`*_wbtest.mbt`（包内，可直接使用类型名）
- 测试名称：`"Module - behavior description"`
- 使用 `assert_true` / `assert_eq` / `assert_false`
- 错误测试使用 `try ... catch { ... } noraise { ... }`

## 模块依赖

```
embit-examples → embit-view → embit-control → embit-gazebo → embit-core
                                  ↓
                              embit-ggml → embit-core
```

- `embit-core` 无外部依赖（仅 MoonBit 标准库）
- `embit-gazebo` / `embit-ggml` 依赖 FFI（native-only）
- 上层模块依赖下层模块，不可反向依赖

## 许可证

贡献的代码遵循 [Apache License 2.0](LICENSE)。