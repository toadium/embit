///|
/// ggml 推理上下文句柄。
///
/// 不透明类型，由 C 侧 `embit_ggml_load` 创建，
/// 封装为 GC 管理的外部对象（external object）。
/// Phase 1 后续将绑定真实 `ggml_context_t`。
type GgmlContext

///|
/// 加载 VLA 模型。
///
/// `path` 为 UTF-8 编码的模型文件路径（如 `b"models/smolvla-7b-q4.gguf"`）。
#borrow(path)
extern "c" fn embit_ggml_load(path : Bytes) -> GgmlContext = "embit_ggml_load"

///|
/// 执行多模态推理：图像 + 语言指令 → 动作序列。
///
/// `image_data` 为原始图像字节流，`instruction` 为 UTF-8 编码的语言指令。
/// 返回：0=成功, -1=失败（未加载或空指针）。
#borrow(ctx, image_data, instruction)
extern "c" fn embit_ggml_infer(
  ctx : GgmlContext,
  image_data : Bytes,
  instruction : Bytes,
) -> Int = "embit_ggml_infer"

///|
/// 设置推理后端（0=CPU, 1=CUDA, 2=Metal）。
/// 返回：0=成功, -1=失败。
#borrow(ctx)
extern "c" fn embit_ggml_set_backend(ctx : GgmlContext, backend : Int) -> Int = "embit_ggml_set_backend"

///|
/// 查询当前推理后端（0=CPU, 1=CUDA, 2=Metal, -1=失败）。
#borrow(ctx)
extern "c" fn embit_ggml_get_backend(ctx : GgmlContext) -> Int = "embit_ggml_get_backend"

///|
/// 查询模型加载状态（1=已加载, 0=未加载, -1=失败）。
#borrow(ctx)
extern "c" fn embit_ggml_is_loaded(ctx : GgmlContext) -> Int = "embit_ggml_is_loaded"

///|
/// 获取推理调用计数（占位统计，用于测试验证 FFI 通道）。
#borrow(ctx)
extern "c" fn embit_ggml_infer_count(ctx : GgmlContext) -> Int = "embit_ggml_infer_count"

///|
/// 释放模型资源。
#borrow(ctx)
extern "c" fn embit_ggml_free(ctx : GgmlContext) -> Unit = "embit_ggml_free"

// ===== 模型元信息查询 =====

///|
/// 获取上下文窗口大小。
#borrow(ctx)
extern "c" fn embit_ggml_get_context_size(ctx : GgmlContext) -> Int = "embit_ggml_get_context_size"

///|
/// 获取模型参数量（百万参数）。
#borrow(ctx)
extern "c" fn embit_ggml_get_param_count(ctx : GgmlContext) -> Int = "embit_ggml_get_param_count"

///|
/// 获取量化类型编号。
#borrow(ctx)
extern "c" fn embit_ggml_get_quant_type(ctx : GgmlContext) -> Int = "embit_ggml_get_quant_type"
