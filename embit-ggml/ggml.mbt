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
/// 当前为 Phase 1 占位实现，后续替换为真实 ggml 推理调用。
pub struct VlaModel {
  ctx : GgmlContext
  model_path : String
}

///|
/// 加载 VLA 模型。
///
/// `path` 指向 `.gguf` 模型文件。加载成功后默认使用 CPU 后端。
/// Phase 1 占位实现始终加载成功；真实实现失败时抛出 `RobotError::ConnectError`。
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
/// 返回占位动作序列（空数组）。失败时抛出 `RobotError::ActionExecuteError`。
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
/// Phase 1 占位实现忽略配置参数，真实实现将传入 ggml 推理引擎。
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
  []
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
/// 获取推理调用计数（占位统计，用于测试验证 FFI 通道）。
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
