// ggml_native.h — ggml/VLA C 接口声明
//
// 声明真实 ggml 与 VLA 推理的 C 接口，由 ggml_native_wrapper.c 实现。
// ggml_stub.c 在 EMBIT_HAS_GGML 定义时调用这些接口。
//
// 真实实现依赖 ggml/llama.cpp C 库 + VLA 推理扩展，
// 由 scripts/prepare.py 编译成静态库后通过 link.native 链接。

#ifndef EMBIT_GGML_NATIVE_H
#define EMBIT_GGML_NATIVE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ===== 模型加载与释放 =====
// 加载 VLA 模型（.gguf 格式）。
// path: UTF-8 模型文件路径。返回：模型句柄，NULL 表示加载失败。
void *embit_ggml_native_load(const char *path);

// 释放模型资源。
void embit_ggml_native_free(void *ctx);

// 查询模型加载状态。返回：1=已加载, 0=未加载。
int32_t embit_ggml_native_is_loaded(void *ctx);

// ===== 推理 =====
// 执行多模态推理：图像 + 语言指令 → 动作序列。
// image_data/image_len: 原始图像字节流（JPEG/PNG）。
// instruction: UTF-8 语言指令。
// out_actions: 输出缓冲区，存放动作序列（每个动作为 7 个 double：6 关节+1 gripper）。
// out_max: 输出缓冲区最大动作数。
// 返回：实际写入的动作数，<0 表示失败。
int32_t embit_ggml_native_infer(
  void *ctx,
  const void *image_data, int32_t image_len,
  const char *instruction,
  double *out_actions, int32_t out_max
);

// ===== 后端管理 =====
// 设置推理后端。backend: 0=CPU, 1=CUDA, 2=Metal。返回：0=成功, -1=失败。
int32_t embit_ggml_native_set_backend(void *ctx, int32_t backend);

// 查询当前后端。返回：0/1/2, -1=失败。
int32_t embit_ggml_native_get_backend(void *ctx);

// ===== 模型元信息 =====
int32_t embit_ggml_native_get_context_size(void *ctx);  // 返回：上下文窗口 token 数, -1=失败
int32_t embit_ggml_native_get_param_count(void *ctx);   // 返回：参数量（百万）, -1=失败
int32_t embit_ggml_native_get_quant_type(void *ctx);    // 返回：0=fp16,1=q8,2=q4,3=q2, -1=失败

// ===== Tokenizer =====
// 编码文本为 token ID 序列。
// text: UTF-8 文本。out_ids: 输出 token ID 缓冲区。out_max: 缓冲区最大容量。
// 返回：实际写入的 token 数, <0 表示失败。
int32_t embit_ggml_native_tokenize(
  void *ctx,
  const char *text,
  int32_t *out_ids, int32_t out_max
);

// 解码 token ID 为文本。
// token_id: token ID。out_text: 输出文本缓冲区。out_max: 缓冲区最大字节数。
// 返回：实际写入的字节数, <0 表示失败。
int32_t embit_ggml_native_detokenize(
  void *ctx,
  int32_t token_id,
  char *out_text, int32_t out_max
);

#ifdef __cplusplus
}
#endif

#endif // EMBIT_GGML_NATIVE_H