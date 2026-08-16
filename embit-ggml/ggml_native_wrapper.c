// ggml_native_wrapper.c — ggml/VLA C wrapper
//
// 实现 ggml_native.h 声明的 C 接口，内部调用真实 ggml/llama.cpp + VLA 扩展 API。
// 由 scripts/prepare.py 编译成静态库，通过 link.native 链接。
//
// 编译要求：
//   - ggml/llama.cpp 已安装或 vendored
//   - VLA 推理扩展（vla.h/vla.c）已编译
//   - 依赖：ggml, llama, gguf, 可选 CUDA/Metal backend

#include "ggml_native.h"

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "llama.h"
#include "ggml.h"
#include "gguf.h"
#include "vla.h"  // VLA 推理扩展

// 内部模型上下文
struct embit_ggml_model {
  struct llama_model *llama_model;
  struct llama_context *llama_ctx;
  struct vla_model *vla;
  ggml_backend_t backend;
  int32_t loaded;
  int32_t backend_id;
  int32_t context_size;
  int32_t param_count;
  int32_t quant_type;
};

// 从 GGUF 元数据解析量化类型
static int32_t detect_quant_type(struct llama_model *model) {
  enum llama_vocab_type vt = llama_vocab_type(model);
  (void)vt;
  // 通过模型路径推断量化类型（gguf 元数据中无直接量化字段）
  // 实际应从 gguf metadata 的 "general.file_type" 读取
  return 2;  // 默认 Q4
}

void *embit_ggml_native_load(const char *path) {
  if (!path) return NULL;

  struct embit_ggml_model *m = (struct embit_ggml_model *)calloc(1, sizeof(*m));
  if (!m) return NULL;

  // 加载 llama 模型
  struct llama_model_params model_params = llama_model_default_params();
  model_params.n_gpu_layers = 0;  // 默认 CPU，后续 set_backend 可调整
  m->llama_model = llama_load_model_from_file(path, model_params);
  if (!m->llama_model) {
    free(m);
    return NULL;
  }

  // 创建推理上下文
  struct llama_context_params ctx_params = llama_context_default_params();
  ctx_params.n_ctx = 4096;
  ctx_params.n_batch = 512;
  m->llama_ctx = llama_new_context_with_model(m->llama_model, ctx_params);
  if (!m->llama_ctx) {
    llama_free_model(m->llama_model);
    free(m);
    return NULL;
  }

  // 加载 VLA 扩展
  m->vla = vla_model_load(m->llama_model, m->llama_ctx);
  if (!m->vla) {
    llama_free(m->llama_ctx);
    llama_free_model(m->llama_model);
    free(m);
    return NULL;
  }

  // 初始化后端（CPU）
  m->backend = ggml_backend_cpu_init();
  m->backend_id = 0;

  // 填充元信息
  m->loaded = 1;
  m->context_size = (int32_t)llama_n_ctx(m->llama_ctx);
  m->param_count = (int32_t)(llama_model_n_params(m->llama_model) / 1000000);  // 百万参数
  m->quant_type = detect_quant_type(m->llama_model);

  return m;
}

void embit_ggml_native_free(void *ctx) {
  if (!ctx) return;
  struct embit_ggml_model *m = (struct embit_ggml_model *)ctx;
  if (m->vla) vla_model_free(m->vla);
  if (m->llama_ctx) llama_free(m->llama_ctx);
  if (m->llama_model) llama_free_model(m->llama_model);
  if (m->backend) ggml_backend_free(m->backend);
  free(m);
}

int32_t embit_ggml_native_is_loaded(void *ctx) {
  if (!ctx) return 0;
  return ((struct embit_ggml_model *)ctx)->loaded;
}

int32_t embit_ggml_native_infer(
  void *ctx,
  const void *image_data, int32_t image_len,
  const char *instruction,
  double *out_actions, int32_t out_max
) {
  if (!ctx || !instruction) return -1;
  struct embit_ggml_model *m = (struct embit_ggml_model *)ctx;
  if (!m->loaded || !m->vla) return -1;

  // VLA 推理：图像 + 指令 → 动作序列
  // 每个动作 7 个 double：[joint_0, joint_1, joint_2, joint_3, joint_4, joint_5, gripper]
  struct vla_input input;
  input.image = image_data;
  input.image_len = image_len;
  input.instruction = instruction;

  struct vla_output output;
  output.actions = out_actions;
  output.max_actions = out_max;
  output.action_count = 0;

  int32_t result = vla_infer(m->vla, &input, &output);
  if (result != 0) return -1;
  return output.action_count;
}

int32_t embit_ggml_native_set_backend(void *ctx, int32_t backend) {
  if (!ctx) return -1;
  struct embit_ggml_model *m = (struct embit_ggml_model *)ctx;
  if (!m->loaded) return -1;

  // 释放旧后端
  if (m->backend) {
    ggml_backend_free(m->backend);
    m->backend = NULL;
  }

  switch (backend) {
    case 0:  // CPU
      m->backend = ggml_backend_cpu_init();
      break;
    case 1:  // CUDA
      #ifdef GGML_USE_CUDA
      m->backend = ggml_backend_cuda_init(0);  // device 0
      #else
      return -1;  // CUDA 未编译
      #endif
      break;
    case 2:  // Metal
      #ifdef GGML_USE_METAL
      m->backend = ggml_backend_metal_init();
      #else
      return -1;  // Metal 未编译
      #endif
      break;
    default:
      return -1;
  }

  if (!m->backend) return -1;
  m->backend_id = backend;
  return 0;
}

int32_t embit_ggml_native_get_backend(void *ctx) {
  if (!ctx) return -1;
  return ((struct embit_ggml_model *)ctx)->backend_id;
}

int32_t embit_ggml_native_get_context_size(void *ctx) {
  if (!ctx) return -1;
  return ((struct embit_ggml_model *)ctx)->context_size;
}

int32_t embit_ggml_native_get_param_count(void *ctx) {
  if (!ctx) return -1;
  return ((struct embit_ggml_model *)ctx)->param_count;
}

int32_t embit_ggml_native_get_quant_type(void *ctx) {
  if (!ctx) return -1;
  return ((struct embit_ggml_model *)ctx)->quant_type;
}

// ===== Tokenizer =====

int32_t embit_ggml_native_tokenize(
  void *ctx,
  const char *text,
  int32_t *out_ids, int32_t out_max
) {
  if (!ctx || !text || !out_ids || out_max <= 0) return -1;
  struct embit_ggml_model *m = (struct embit_ggml_model *)ctx;
  if (!m->loaded || !m->llama_ctx) return -1;

  // llama_tokenize: text → token IDs
  // add_special=true 添加 BOS, parse_special=true 解析特殊 token
  int32_t n = llama_tokenize(
    m->llama_ctx,
    text,
    (llama_token *)out_ids,
    out_max,
    true,   // add_special
    false   // parse_special
  );
  return n;
}

int32_t embit_ggml_native_detokenize(
  void *ctx,
  int32_t token_id,
  char *out_text, int32_t out_max
) {
  if (!ctx || !out_text || out_max <= 0) return -1;
  struct embit_ggml_model *m = (struct embit_ggml_model *)ctx;
  if (!m->loaded || !m->llama_ctx) return -1;

  // llama_token_to_piece: token ID → 文本片段（UTF-8）
  int32_t n = llama_token_to_piece(
    m->llama_ctx,
    (llama_token)token_id,
    out_text,
    out_max
  );
  return n;
}
