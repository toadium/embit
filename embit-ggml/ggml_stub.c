// ggml_stub.c — Embit ggml FFI 桥接（功能化占位实现）
//
// 当前为自包含占位实现，不依赖 ggml/vla.cpp C 库。
// 推理调用仅记录状态，动作序列由 MoonBit 侧 parse_instruction_to_actions 生成。
// 后续将替换为真实 ggml 推理调用：
//   - ggml_init / ggml_free
//   - ggml_model_load / ggml_model_infer
//
// 编译：由 MoonBit native-stub 机制自动编译并链接。

#include <moonbit.h>
#include <stdint.h>
#include <string.h>

// 占位的 ggml 推理上下文
typedef struct {
  int32_t loaded;       // 模型加载状态（1=已加载, 0=未加载）
  int32_t backend;      // 当前推理后端（0=CPU, 1=CUDA, 2=Metal）
  int32_t infer_count;  // 推理调用计数（占位统计，用于测试验证）
  int32_t context_size; // 上下文窗口大小（token 数）
  int32_t param_count;  // 模型参数量（百万参数）
  int32_t quant_type;   // 量化类型（0=fp16, 1=q8, 2=q4, 3=q2）
} embit_ggml_ctx_t;

// no-op finalizer：上下文结构体无堆分配资源，无需释放。
// 必须提供非 NULL finalizer 以避免 GC 行为异常。
static void embit_ggml_ctx_finalize(void *ptr) {
  (void)ptr;
}

// 加载 VLA 模型
// path: UTF-8 编码的模型文件路径（如 "models/smolvla-7b-q4.gguf"）
// 返回：GC 管理的外部对象，封装 embit_ggml_ctx_t
MOONBIT_FFI_EXPORT
embit_ggml_ctx_t *embit_ggml_load(moonbit_bytes_t path) {
  (void)path; // 占位：路径参数暂未使用，真实实现将调用 ggml_model_load
  embit_ggml_ctx_t *ctx = (embit_ggml_ctx_t *)moonbit_make_external_object(
    embit_ggml_ctx_finalize,
    sizeof(embit_ggml_ctx_t)
  );
  ctx->loaded = 1;
  ctx->backend = 0; // 默认 CPU 后端
  ctx->infer_count = 0;
  ctx->context_size = 4096;   // 默认上下文窗口
  ctx->param_count = 7000;    // 7B 模型默认参数量（百万）
  ctx->quant_type = 2;        // 默认 Q4 量化
  return ctx;
}

// 执行多模态推理：图像 + 语言指令 → 动作序列
// ctx: 推理上下文
// image_data: 原始图像字节流
// instruction: UTF-8 编码的语言指令
// 返回：0=成功, -1=失败（未加载或空指针）
MOONBIT_FFI_EXPORT
int32_t embit_ggml_infer(
  embit_ggml_ctx_t *ctx,
  moonbit_bytes_t image_data,
  moonbit_bytes_t instruction
) {
  (void)image_data;   // 占位：图像数据暂未使用
  (void)instruction;  // 占位：指令暂未使用
  if (ctx == NULL || !ctx->loaded) {
    return -1;
  }
  ctx->infer_count++;
  return 0;
}

// 设置推理后端
// backend: 0=CPU, 1=CUDA, 2=Metal
// 返回：0=成功, -1=失败（空指针或后端编号无效）
MOONBIT_FFI_EXPORT
int32_t embit_ggml_set_backend(embit_ggml_ctx_t *ctx, int32_t backend) {
  if (ctx == NULL || backend < 0 || backend > 2) {
    return -1;
  }
  ctx->backend = backend;
  return 0;
}

// 查询当前推理后端
// 返回：0=CPU, 1=CUDA, 2=Metal, -1=失败（空指针）
MOONBIT_FFI_EXPORT
int32_t embit_ggml_get_backend(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) {
    return -1;
  }
  return ctx->backend;
}

// 查询模型加载状态
// 返回：1=已加载, 0=未加载, -1=失败（空指针）
MOONBIT_FFI_EXPORT
int32_t embit_ggml_is_loaded(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) {
    return -1;
  }
  return ctx->loaded;
}

// 获取推理调用计数（占位统计，用于测试验证 FFI 通道）
MOONBIT_FFI_EXPORT
int32_t embit_ggml_infer_count(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) {
    return 0;
  }
  return ctx->infer_count;
}

// 释放模型资源（占位：GC 通过 finalizer 自动回收）
MOONBIT_FFI_EXPORT
void embit_ggml_free(embit_ggml_ctx_t *ctx) {
  if (ctx != NULL) {
    ctx->loaded = 0;
  }
}

// ===== 模型元信息查询 =====

// 获取上下文窗口大小（token 数）
// 返回：上下文大小，-1=失败
MOONBIT_FFI_EXPORT
int32_t embit_ggml_get_context_size(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) {
    return -1;
  }
  return ctx->context_size;
}

// 获取模型参数量（百万参数）
// 返回：参数量，-1=失败
MOONBIT_FFI_EXPORT
int32_t embit_ggml_get_param_count(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) {
    return -1;
  }
  return ctx->param_count;
}

// 获取量化类型（0=fp16, 1=q8, 2=q4, 3=q2）
// 返回：量化类型编号，-1=失败
MOONBIT_FFI_EXPORT
int32_t embit_ggml_get_quant_type(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) {
    return -1;
  }
  return ctx->quant_type;
}