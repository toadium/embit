///|
/// 推理后端。
///
/// `Cpu` — CPU 推理（默认，全平台支持）。
/// `Cuda` — NVIDIA CUDA GPU 加速。
/// `Metal` — Apple Metal GPU 加速。
pub(all) enum Backend {
  Cpu
  Cuda
  Metal
} derive(Eq, Debug)

///|
pub extend Backend with Eq::{not_equal, equal}

///|
pub extend Backend with @debug.Debug::{to_repr}

///|
/// VLA（Vision-Language-Action）模型，封装多模态推理能力。
///
/// 通过 FFI 绑定 ggml/vla.cpp，支持图像 + 语言指令 → 动作序列推理。
/// 当前使用功能化占位实现，通过指令解析生成动作序列。
pub struct VlaModel {
  ctx : GgmlContext
  model_path : String
}

///|
/// 加载 VLA 模型。
///
/// `path` 指向 `.gguf` 模型文件。加载成功后默认使用 CPU 后端。
/// 占位实现始终加载成功；真实实现失败时抛出 `RobotError::ConnectError`。
pub fn VlaModel::load(path : String) -> VlaModel {
  let ctx = embit_ggml_load(@utf8.encode(path))
  { ctx, model_path: path }
}

///|
/// 推理配置参数。
///
/// 控制 VLA 模型推理的采样策略与输出约束。
pub(all) struct InferConfig {
  temperature : Double // 采样温度（>0，越高越随机，默认 1.0）
  top_k : Int // Top-K 采样候选数（>0，0 表示不限制）
  top_p : Double // Top-P 核采样阈值（0~1，1.0 表示不限制）
  max_tokens : Int // 最大输出 token 数（>0，0 表示不限制）
} derive(Eq, Debug)

///|
pub extend InferConfig with Eq::{not_equal, equal}

///|
pub extend InferConfig with @debug.Debug::{to_repr}

///|
/// 默认推理配置：temperature=1.0, top_k=0, top_p=1.0, max_tokens=0。
pub fn InferConfig::default() -> InferConfig {
  { temperature: 1.0, top_k: 0, top_p: 1.0, max_tokens: 0 }
}

///|
/// 创建推理配置。
pub fn InferConfig::new(
  temperature : Double,
  top_k : Int,
  top_p : Double,
  max_tokens : Int,
) -> InferConfig {
  { temperature, top_k, top_p, max_tokens }
}

///|
/// 执行多模态推理：图像 + 语言指令 → 动作序列。
///
/// `image` 为原始图像字节流，`instruction` 为自然语言指令。
/// 返回基于指令解析生成的动作序列。失败时抛出 `RobotError::ActionExecuteError`。
pub fn VlaModel::infer(
  self : VlaModel,
  image : Bytes,
  instruction : String,
) -> Array[@core.ActionCommand] raise @core.RobotError {
  let _ = InferConfig::default()
  self.infer_with_config(image, instruction, InferConfig::default())
}

///|
/// 带配置的多模态推理。
///
/// `config` 控制采样温度、Top-K/Top-P 与最大输出长度。
/// 当前实现通过指令解析生成动作序列，真实实现将传入 ggml 推理引擎。
pub fn VlaModel::infer_with_config(
  self : VlaModel,
  image : Bytes,
  instruction : String,
  config : InferConfig,
) -> Array[@core.ActionCommand] raise @core.RobotError {
  ignore(config)
  let status = embit_ggml_infer(self.ctx, image, @utf8.encode(instruction))
  if status < 0 {
    raise ActionExecuteError("ggml infer failed: model not loaded")
  }
  parse_instruction_to_actions(instruction)
}

///|
/// 解析指令文本生成动作序列。
///
/// 基于关键词匹配将自然语言指令转换为关节动作命令：
/// - `"pick up"` / `"grab"` → 夹爪闭合 + 手臂下降
/// - `"release"` / `"drop"` / `"put"` → 夹爪张开
/// - `"move to"` / `"move"` / `"go"` → 手臂移动
/// - `"walk forward"` / `"forward"` → 双腿前进
/// - `"walk backward"` / `"backward"` → 双腿后退
/// - `"turn left"` → 底盘左转
/// - `"turn right"` → 底盘右转
/// - `"stop"` → 全关节归零
/// - 默认 → 微小前进动作
fn parse_instruction_to_actions(
  instruction : String,
) -> Array[@core.ActionCommand] {
  let actions : Array[@core.ActionCommand] = []
  if instruction.contains("pick up") || instruction.contains("grab") {
    actions.push({
      joint_commands: [("gripper", -1.0), ("arm_z", -0.3)],
      timestamp: 0.0,
    })
    actions.push({ joint_commands: [("gripper", -1.0)], timestamp: 0.5 })
  } else if instruction.contains("release") ||
    instruction.contains("drop") ||
    instruction.contains("put") {
    actions.push({ joint_commands: [("gripper", 1.0)], timestamp: 0.0 })
  } else if instruction.contains("walk forward") ||
    instruction.contains("forward") {
    actions.push({
      joint_commands: [("left_hip", 0.3), ("right_hip", -0.3)],
      timestamp: 0.0,
    })
    actions.push({
      joint_commands: [("left_hip", -0.3), ("right_hip", 0.3)],
      timestamp: 0.5,
    })
  } else if instruction.contains("walk backward") ||
    instruction.contains("backward") {
    actions.push({
      joint_commands: [("left_hip", -0.3), ("right_hip", 0.3)],
      timestamp: 0.0,
    })
    actions.push({
      joint_commands: [("left_hip", 0.3), ("right_hip", -0.3)],
      timestamp: 0.5,
    })
  } else if instruction.contains("turn left") {
    actions.push({ joint_commands: [("base_yaw", -0.5)], timestamp: 0.0 })
  } else if instruction.contains("turn right") {
    actions.push({ joint_commands: [("base_yaw", 0.5)], timestamp: 0.0 })
  } else if instruction.contains("stop") {
    actions.push({ joint_commands: [("all_joints", 0.0)], timestamp: 0.0 })
  } else if instruction.contains("move to") ||
    instruction.contains("move") ||
    instruction.contains("go") {
    actions.push({
      joint_commands: [("arm_x", 0.5), ("arm_y", 0.3)],
      timestamp: 0.0,
    })
  } else {
    actions.push({ joint_commands: [("base_x", 0.1)], timestamp: 0.0 })
  }
  actions
}

///|
/// 设置推理后端。
///
/// 失败时抛出 `RobotError::ActionExecuteError`。
pub fn VlaModel::set_backend(
  self : VlaModel,
  backend : Backend,
) -> Unit raise @core.RobotError {
  let backend_id = match backend {
    Cpu => 0
    Cuda => 1
    Metal => 2
  }
  let status = embit_ggml_set_backend(self.ctx, backend_id)
  if status < 0 {
    raise ActionExecuteError(
      "ggml set_backend failed: invalid backend or context",
    )
  }
}

///|
/// 查询当前推理后端。
pub fn VlaModel::get_backend(self : VlaModel) -> Backend {
  match embit_ggml_get_backend(self.ctx) {
    1 => Cuda
    2 => Metal
    _ => Cpu
  }
}

///|
/// 查询模型加载状态。
pub fn VlaModel::is_loaded(self : VlaModel) -> Bool {
  embit_ggml_is_loaded(self.ctx) > 0
}

///|
/// 获取推理调用计数（用于测试验证 FFI 通道）。
pub fn VlaModel::infer_count(self : VlaModel) -> Int {
  embit_ggml_infer_count(self.ctx)
}

///|
/// 列出所有支持的后端。
pub fn VlaModel::supported_backends() -> Array[Backend] {
  [Cpu, Cuda, Metal]
}

///|
/// 释放模型资源。
pub fn VlaModel::free(self : VlaModel) -> Unit {
  embit_ggml_free(self.ctx)
}

///|
/// 模型量化类型。
pub(all) enum QuantType {
  Fp16 // 半精度浮点
  Q8 // 8 位整数量化
  Q4 // 4 位整数量化
  Q2 // 2 位整数量化
} derive(Eq, Debug)

///|
pub extend QuantType with Eq::{not_equal, equal}

///|
pub extend QuantType with @debug.Debug::{to_repr}

///|
/// 模型元信息。
///
/// 描述 VLA 模型的关键属性，用于模型选择与资源规划。
pub(all) struct ModelInfo {
  context_size : Int // 上下文窗口大小（token 数）
  param_count : Int // 参数量（百万参数）
  quant_type : QuantType // 量化类型
  backend : Backend // 当前推理后端
  is_loaded : Bool // 加载状态
} derive(Eq, Debug)

///|
pub extend ModelInfo with Eq::{not_equal, equal}

///|
pub extend ModelInfo with @debug.Debug::{to_repr}

///|
/// 查询模型元信息。
///
/// 返回上下文大小、参数量、量化类型、后端与加载状态。
pub fn VlaModel::get_model_info(self : VlaModel) -> ModelInfo {
  let qt = match embit_ggml_get_quant_type(self.ctx) {
    0 => QuantType::Fp16
    1 => Q8
    3 => Q2
    _ => Q4
  }
  {
    context_size: embit_ggml_get_context_size(self.ctx),
    param_count: embit_ggml_get_param_count(self.ctx),
    quant_type: qt,
    backend: self.get_backend(),
    is_loaded: self.is_loaded(),
  }
}
