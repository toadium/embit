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
/// 推理后动作序列存储在 C 侧上下文中，通过 `embit_ggml_get_action_count`
/// 与 `embit_ggml_get_action_joint` 逐个查询。
#borrow(ctx, image_data, instruction)
extern "c" fn embit_ggml_infer(
  ctx : GgmlContext,
  image_data : Bytes,
  instruction : Bytes,
) -> Int = "embit_ggml_infer"

///|
/// 获取上次推理的动作序列长度。
///
/// 占位模式返回 0（动作序列由 MoonBit 侧生成）；
/// 真实模式（EMBIT_HAS_GGML）返回 C 侧推理的动作数。
#borrow(ctx)
extern "c" fn embit_ggml_get_action_count(ctx : GgmlContext) -> Int = "embit_ggml_get_action_count"

///|
/// 获取指定动作的指定关节值。
///
/// `action_idx` 为动作索引（0-based），`joint_idx` 为关节索引（0-5=关节, 6=gripper）。
/// 每个动作 7 个值：[joint_0, joint_1, joint_2, joint_3, joint_4, joint_5, gripper]。
/// 越界返回 0.0。
#borrow(ctx)
extern "c" fn embit_ggml_get_action_joint(
  ctx : GgmlContext,
  action_idx : Int,
  joint_idx : Int,
) -> Double = "embit_ggml_get_action_joint"

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

// ===== Tokenizer FFI =====

///|
/// 使用 ggml tokenizer 编码文本，返回 token 数。
///
/// token ID 序列存储在 C 侧上下文中，通过 `embit_ggml_get_token_id` 逐个查询。
/// 真实模式（EMBIT_HAS_GGML）调用 ggml tokenizer C API（BPE/SentencePiece）。
/// 占位模式返回 -1（调用方应回退到内置词表分词）。
#borrow(ctx, text)
extern "c" fn embit_ggml_tokenize(ctx : GgmlContext, text : Bytes) -> Int = "embit_ggml_tokenize"

///|
/// 获取 `embit_ggml_tokenize` 后指定索引的 token ID。
///
/// 越界返回 -1。
#borrow(ctx)
extern "c" fn embit_ggml_get_token_id(ctx : GgmlContext, index : Int) -> Int = "embit_ggml_get_token_id"

///|
/// 使用 ggml tokenizer 解码单个 token ID 为文本片段（UTF-8 Bytes）。
///
/// 占位模式返回空 Bytes。
#borrow(ctx)
extern "c" fn embit_ggml_detokenize(ctx : GgmlContext, token_id : Int) -> Bytes = "embit_ggml_detokenize"
