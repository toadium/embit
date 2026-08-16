# 贡献指南

感谢你对 Embit 的关注！欢迎任何形式的贡献。

## 开发环境

### 必要工具

- [MoonBit 工具链](https://www.moonbitlang.com/) >= 0.1.20260807（`preferred_target = "native"`）
- C 编译器（FFI native-stub 编译必需，Windows 下随 MoonBit 附带 TCC）

### 可选工具

- Ignition Gazebo Fortress / Harmonic（仿真模式）
- ggml / llama.cpp（VLA 推理加速）
- Selene SDK（可视化引擎）
- 支持 CUDA / Metal 的 GPU 设备（推理加速）

### 环境搭建

```bash
# 克隆仓库
git clone https://github.com/toadium/embit.git
cd embit

# 验证环境
moon check --warn-list +all --deny-warn
moon test --target native
```

## 项目结构

```
embit/
├── embit-core/       # 核心基础库（RobotError / JointState / RobotModel / Robot trait / RobotBuilder / RealRobot）
├── embit-gazebo/     # 仿真通信 SDK（GazeboClient + GazeboRobot + 世界控制 + 场景管理 + FFI）
├── embit-ggml/       # VLA 推理 SDK（VlaModel + Tensor + Tokenizer + FFI）
├── embit-control/    # 运动控制（轨迹规划 + IK/FK + 卡尔曼滤波 + PID + 阻抗 + 笛卡尔控制
│                     #   + SafetyController + AlertSystem + CollisionDetector + SafetyCertification + Benchmark）
├── embit-view/       # 可视化面板（Widget / 录制回放 / 实时监控 / DataSeries + FFI(Selene)）
├── embit-examples/   # 示例工程（21 个 Demo）
├── docs/             # 项目文档
└── .github/          # CI/CD + Issue/PR 模板
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

提交前必须通过以下检查（零警告策略）：

```bash
moon check --warn-list +all --deny-warn   # 编译检查（0 错误，0 警告）
moon test --target native                  # 全量测试（全部通过）
moon fmt --check                           # 代码格式化检查
moon info                                  # 接口生成
git diff --exit-code                       # 接口一致性（pkg.generated.mbti 无变更）
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
- `for` 循环不支持元组解构，需先取元素再 `let (a, b) = item`
- `raise` 是关键字，不能用作方法名
- 浮点字面量 `1e9` 不合法，需写 `1000000000.0`

### FFI 条件编译

所有 FFI 包采用 C 层条件编译 wrapper 模式：

```c
// *_stub.c
#ifdef EMBIT_HAS_XXX
  // 调用真实 API
  return real_api(args);
#else
  // 占位返回默认值
  return 0;
#endif
```

MoonBit 层无感知，extern "c" 签名不变。新增 FFI 包需：
1. 创建 `xxx.h`（C 接口声明）
2. 创建 `xxx_wrapper.c`（真实 API wrapper）
3. 创建 `*_stub.c`（条件编译入口）
4. 创建 `ffi.mbt`（extern "c" 声明）
5. 创建 `scripts/prepare.py`（库检测脚本）
6. 更新 `moon.pkg`（native-stub + supported_targets）
7. 更新 `.github/workflows/ci.yml`（FFI 集成测试 job）

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
- `assert_*` 和 `fail` 抛出 `Failure` 而非 `RobotError`，不能在 `raise RobotError` 函数中使用

## 模块依赖

```
embit-examples → embit-view → embit-control → embit-gazebo → embit-core
                                  ↓
                              embit-ggml → embit-core
```

- `embit-core` 无外部依赖（仅 MoonBit 标准库）
- `embit-gazebo` / `embit-ggml` / `embit-view` 依赖 FFI（native-only）
- 上层模块依赖下层模块，不可反向依赖

## 许可证

贡献的代码遵循 [Apache License 2.0](LICENSE)。
