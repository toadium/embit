// ggml_stub.c — Embit ggml FFI 桥接（条件编译 wrapper）
//
// 架构：条件编译切换真实 ggml/VLA API 与占位回退实现。
//   - EMBIT_HAS_GGML 定义时：调用 ggml_native.h 声明的 C 接口
//     （由 ggml_native_wrapper.c 实现，通过 link.native 链接）
//   - 未定义时：占位回退（仅记录推理计数），动作序列由 MoonBit 侧
//     parse_instruction_to_actions 生成，用于无库环境编译与单元测试
//
// 真实 API 启用方式：
//   1. 安装 ggml/llama.cpp + VLA 推理扩展
//   2. 运行 python scripts/prepare.py --with-ggml
//   3. prepare.py 编译 ggml_native_wrapper.c 为静态库
//   4. prepare.py 更新 moon.pkg 添加 link(native(...)) 配置
//
// 编译：由 MoonBit native-stub 机制自动编译并链接。

#include <moonbit.h>
#include <stdint.h>
#include <string.h>

#ifdef EMBIT_HAS_GGML
#include "ggml_native.h"
#endif

// ggml 推理上下文
typedef struct {
  int32_t loaded;       // 模型加载状态（1=已加载, 0=未加载）
  int32_t backend;      // 当前推理后端（0=CPU, 1=CUDA, 2=Metal）
  int32_t infer_count;  // 推理调用计数（用于测试验证 FFI 通道）
  int32_t context_size; // 上下文窗口大小（token 数）
  int32_t param_count;  // 模型参数量（百万参数）
  int32_t quant_type;   // 量化类型（0=fp16, 1=q8, 2=q4, 3=q2）
#ifdef EMBIT_HAS_GGML
  void *native_ctx;     // 真实 ggml/VLA 模型句柄
  // 上次推理的动作序列（每个动作 7 个 double：6 关节 + 1 gripper）
  double *last_actions;      // 动作数组，长度 = last_action_count * 7
  int32_t last_action_count; // 动作数量
  // 上次 tokenize 的 token ID 序列
  int32_t *last_tokens;      // token ID 数组
  int32_t last_token_count;  // token 数量
#endif
} embit_ggml_ctx_t;

// finalizer：释放真实模型资源（占位模式为 no-op）
static void embit_ggml_ctx_finalize(void *ptr) {
  if (ptr == NULL) return;
#ifdef EMBIT_HAS_GGML
  embit_ggml_ctx_t *ctx = (embit_ggml_ctx_t *)ptr;
  if (ctx->native_ctx != NULL) {
    embit_ggml_native_free(ctx->native_ctx);
    ctx->native_ctx = NULL;
  }
  if (ctx->last_actions != NULL) {
    free(ctx->last_actions);
    ctx->last_actions = NULL;
  }
  if (ctx->last_tokens != NULL) {
    free(ctx->last_tokens);
    ctx->last_tokens = NULL;
  }
#endif
}

// ===== 模型加载与释放 =====

MOONBIT_FFI_EXPORT
embit_ggml_ctx_t *embit_ggml_load(moonbit_bytes_t path) {
  embit_ggml_ctx_t *ctx = (embit_ggml_ctx_t *)moonbit_make_external_object(
    embit_ggml_ctx_finalize,
    sizeof(embit_ggml_ctx_t)
  );
  ctx->infer_count = 0;

#ifdef EMBIT_HAS_GGML
  // 真实 ggml 模型加载
  const char *model_path = (const char *)path;
  ctx->native_ctx = embit_ggml_native_load(model_path);
  ctx->last_actions = NULL;
  ctx->last_action_count = 0;
  ctx->last_tokens = NULL;
  ctx->last_token_count = 0;
  if (ctx->native_ctx != NULL) {
    ctx->loaded = 1;
    ctx->backend = embit_ggml_native_get_backend(ctx->native_ctx);
    ctx->context_size = embit_ggml_native_get_context_size(ctx->native_ctx);
    ctx->param_count = embit_ggml_native_get_param_count(ctx->native_ctx);
    ctx->quant_type = embit_ggml_native_get_quant_type(ctx->native_ctx);
  } else {
    ctx->loaded = 0;
    ctx->backend = 0;
    ctx->context_size = 0;
    ctx->param_count = 0;
    ctx->quant_type = 0;
  }
#else
  // 占位回退：返回固定默认值
  (void)path;
  ctx->loaded = 1;
  ctx->backend = 0;
  ctx->context_size = 4096;
  ctx->param_count = 7000;
  ctx->quant_type = 2;
#endif
  return ctx;
}

MOONBIT_FFI_EXPORT
int32_t embit_ggml_infer(
  embit_ggml_ctx_t *ctx,
  moonbit_bytes_t image_data,
  moonbit_bytes_t instruction
) {
  if (ctx == NULL || !ctx->loaded) {
    return -1;
  }
  ctx->infer_count++;
#ifdef EMBIT_HAS_GGML
  // 真实 VLA 推理
  int32_t image_len = Moonbit_array_length(image_data);
  // 释放上次动作序列
  if (ctx->last_actions != NULL) {
    free(ctx->last_actions);
    ctx->last_actions = NULL;
  }
  ctx->last_action_count = 0;
  // 分配动作缓冲区（最多 100 个动作，每个 7 个 double）
  int32_t max_actions = 100;
  double *actions = (double *)malloc(max_actions * 7 * sizeof(double));
  if (actions == NULL) return -1;
  int32_t n = embit_ggml_native_infer(
    ctx->native_ctx,
    (const void *)image_data, image_len,
    (const char *)instruction,
    actions, max_actions
  );
  if (n > 0) {
    ctx->last_actions = actions;
    ctx->last_action_count = n;
    return 0;
  }
  free(actions);
  return n < 0 ? -1 : 0;
#else
  (void)image_data; (void)instruction;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_ggml_set_backend(embit_ggml_ctx_t *ctx, int32_t backend) {
  if (ctx == NULL || backend < 0 || backend > 2) {
    return -1;
  }
#ifdef EMBIT_HAS_GGML
  int32_t r = embit_ggml_native_set_backend(ctx->native_ctx, backend);
  if (r == 0) ctx->backend = backend;
  return r;
#else
  ctx->backend = backend;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_ggml_get_backend(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) return -1;
  return ctx->backend;
}

MOONBIT_FFI_EXPORT
int32_t embit_ggml_is_loaded(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) return -1;
  return ctx->loaded;
}

MOONBIT_FFI_EXPORT
int32_t embit_ggml_infer_count(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) return 0;
  return ctx->infer_count;
}

MOONBIT_FFI_EXPORT
void embit_ggml_free(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) return;
#ifdef EMBIT_HAS_GGML
  if (ctx->native_ctx != NULL) {
    embit_ggml_native_free(ctx->native_ctx);
    ctx->native_ctx = NULL;
  }
  if (ctx->last_actions != NULL) {
    free(ctx->last_actions);
    ctx->last_actions = NULL;
  }
  if (ctx->last_tokens != NULL) {
    free(ctx->last_tokens);
    ctx->last_tokens = NULL;
  }
#endif
  ctx->loaded = 0;
}

// ===== 模型元信息查询 =====

MOONBIT_FFI_EXPORT
int32_t embit_ggml_get_context_size(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) return -1;
  return ctx->context_size;
}

MOONBIT_FFI_EXPORT
int32_t embit_ggml_get_param_count(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) return -1;
  return ctx->param_count;
}

MOONBIT_FFI_EXPORT
int32_t embit_ggml_get_quant_type(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) return -1;
  return ctx->quant_type;
}

// ===== 动作序列查询 =====
// embit_ggml_infer 后，动作序列存储在 C 侧上下文中。
// MoonBit 侧通过以下函数逐个查询动作关节值。
// 占位模式 last_action_count 始终为 0（动作序列由 MoonBit 侧生成）。

MOONBIT_FFI_EXPORT
int32_t embit_ggml_get_action_count(embit_ggml_ctx_t *ctx) {
  if (ctx == NULL) return 0;
#ifdef EMBIT_HAS_GGML
  return ctx->last_action_count;
#else
  return 0;
#endif
}

// 获取指定动作的指定关节值
// action_idx: 动作索引（0-based）
// joint_idx: 关节索引（0-5=关节, 6=gripper）
// 每个动作 7 个值：[joint_0, joint_1, joint_2, joint_3, joint_4, joint_5, gripper]
MOONBIT_FFI_EXPORT
double embit_ggml_get_action_joint(
  embit_ggml_ctx_t *ctx,
  int32_t action_idx,
  int32_t joint_idx
) {
  if (ctx == NULL) return 0.0;
#ifdef EMBIT_HAS_GGML
  if (ctx->last_actions == NULL || action_idx < 0 || joint_idx < 0 || joint_idx >= 7) {
    return 0.0;
  }
  if (action_idx >= ctx->last_action_count) {
    return 0.0;
  }
  return ctx->last_actions[action_idx * 7 + joint_idx];
#else
  (void)action_idx; (void)joint_idx;
  return 0.0;
#endif
}

// ===== Tokenizer =====
// 真实模式调用 ggml tokenizer C API（BPE/SentencePiece）。
// 占位模式返回 -1 或空结果，调用方回退到内置词表分词。

MOONBIT_FFI_EXPORT
int32_t embit_ggml_tokenize(
  embit_ggml_ctx_t *ctx,
  moonbit_bytes_t text
) {
  if (ctx == NULL || !ctx->loaded) return -1;
#ifdef EMBIT_HAS_GGML
  // 释放上次 token 序列
  if (ctx->last_tokens != NULL) {
    free(ctx->last_tokens);
    ctx->last_tokens = NULL;
  }
  ctx->last_token_count = 0;

  // 分配 token 缓冲区（最多 4096 个 token）
  int32_t max_tokens = 4096;
  int32_t *tokens = (int32_t *)malloc(max_tokens * sizeof(int32_t));
  if (tokens == NULL) return -1;

  int32_t n = embit_ggml_native_tokenize(
    ctx->native_ctx,
    (const char *)text,
    tokens, max_tokens
  );
  if (n > 0) {
    ctx->last_tokens = tokens;
    ctx->last_token_count = n;
    return n;
  }
  free(tokens);
  return n < 0 ? -1 : 0;
#else
  (void)text;
  return -1;  // 占位模式：调用方回退到内置词表
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_ggml_get_token_id(
  embit_ggml_ctx_t *ctx,
  int32_t index
) {
  if (ctx == NULL) return -1;
#ifdef EMBIT_HAS_GGML
  if (ctx->last_tokens == NULL || index < 0 || index >= ctx->last_token_count) {
    return -1;
  }
  return ctx->last_tokens[index];
#else
  (void)index;
  return -1;
#endif
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t embit_ggml_detokenize(
  embit_ggml_ctx_t *ctx,
  int32_t token_id
) {
  if (ctx == NULL || !ctx->loaded) {
    return moonbit_make_bytes(0, 0);
  }
#ifdef EMBIT_HAS_GGML
  // 解码 token ID 为文本片段
  char buf[256];
  int32_t n = embit_ggml_native_detokenize(
    ctx->native_ctx,
    token_id,
    buf, sizeof(buf)
  );
  if (n <= 0) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t result = moonbit_make_bytes(n, 0);
  memcpy(result, buf, n);
  return result;
#else
  (void)token_id;
  return moonbit_make_bytes(0, 0);  // 占位模式：空 Bytes
#endif
}
