// view_stub.c — Embit View FFI 桥接（条件编译 wrapper）
//
// 架构：条件编译切换真实 Selene 引擎 API 与占位回退实现。
//   - EMBIT_HAS_SELENE 定义时：调用 selene.h 声明的 C 接口
//     （由 selene_wrapper.c 实现，通过 link.native 链接）
//   - 未定义时：占位回退（仅记录操作计数与状态），用于无库环境编译与单元测试
//
// 真实 API 启用方式：
//   1. 安装 Selene 可视化引擎 SDK
//   2. 运行 python scripts/prepare.py --with-selene
//   3. prepare.py 编译 selene_wrapper.c 为静态库
//   4. prepare.py 更新 moon.pkg 添加 link(native(...)) 配置
//
// 编译：由 MoonBit native-stub 机制自动编译并链接。

#include <moonbit.h>
#include <stdint.h>
#include <string.h>

#ifdef EMBIT_HAS_SELENE
#include "selene.h"
#endif

// View 面板上下文结构体
typedef struct {
  int32_t active;              // 上下文是否活跃（1=活跃, 0=已销毁）
  int32_t widget_count;        // 已添加 Widget 数量
  int32_t render_count;        // 渲染调用计数（用于测试验证 FFI 通道）
  int32_t recording;           // 录制状态（1=录制中, 0=未录制）
  int32_t recorded_frames;     // 已录制帧数
  int32_t playback_total;      // 回放总帧数
  int32_t playback_current;    // 回放当前帧
  int32_t parameter_count;     // 参数数量
  int32_t data_point_count;    // 数据点总数
  int32_t joint_count;         // 已更新的关节数量（当前帧）
#ifdef EMBIT_HAS_SELENE
  void *selene_ctx;            // 真实 Selene 引擎上下文句柄
#endif
} embit_view_ctx_t;

// finalizer：释放真实 Selene 资源（占位模式为 no-op）
static void embit_view_ctx_finalize(void *ptr) {
  if (ptr == NULL) return;
#ifdef EMBIT_HAS_SELENE
  embit_view_ctx_t *ctx = (embit_view_ctx_t *)ptr;
  if (ctx->selene_ctx != NULL) {
    embit_selene_destroy(ctx->selene_ctx);
    ctx->selene_ctx = NULL;
  }
#endif
}

// ===== 上下文管理 =====

MOONBIT_FFI_EXPORT
embit_view_ctx_t *embit_view_create(
  moonbit_bytes_t model_name, int32_t dof
) {
  embit_view_ctx_t *ctx = (embit_view_ctx_t *)moonbit_make_external_object(
    embit_view_ctx_finalize,
    sizeof(embit_view_ctx_t)
  );
  ctx->widget_count = 0;
  ctx->render_count = 0;
  ctx->recording = 0;
  ctx->recorded_frames = 0;
  ctx->playback_total = 0;
  ctx->playback_current = 0;
  ctx->parameter_count = 0;
  ctx->data_point_count = 0;
  ctx->joint_count = 0;

#ifdef EMBIT_HAS_SELENE
  // 真实 Selene 引擎上下文创建
  const char *title = (const char *)model_name;
  int32_t width = 1280;
  int32_t height = 720;
  (void)dof;
  ctx->selene_ctx = embit_selene_create(title, width, height);
  ctx->active = (ctx->selene_ctx != NULL) ? 1 : 0;
#else
  // 占位回退：始终创建成功
  (void)model_name; (void)dof;
  ctx->active = 1;
#endif
  return ctx;
}

MOONBIT_FFI_EXPORT
int32_t embit_view_is_active(embit_view_ctx_t *ctx) {
  if (ctx == NULL) return 0;
#ifdef EMBIT_HAS_SELENE
  return embit_selene_is_active(ctx->selene_ctx);
#else
  return ctx->active;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_render_count(embit_view_ctx_t *ctx) {
  if (ctx == NULL) return 0;
  return ctx->render_count;
}

// ===== Widget 管理 =====

MOONBIT_FFI_EXPORT
int32_t embit_view_add_widget(
  embit_view_ctx_t *ctx,
  int32_t widget_type,
  moonbit_bytes_t title,
  moonbit_bytes_t topic
) {
  if (ctx == NULL || !ctx->active) return -1;
  if (widget_type < 0 || widget_type > 4) return -1;
#ifdef EMBIT_HAS_SELENE
  int32_t r = embit_selene_add_widget(
    ctx->selene_ctx, widget_type, (const char *)title, (const char *)topic
  );
  if (r == 0) ctx->widget_count++;
  return r;
#else
  (void)title; (void)topic;
  ctx->widget_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_widget_count(embit_view_ctx_t *ctx) {
  if (ctx == NULL) return 0;
#ifdef EMBIT_HAS_SELENE
  return embit_selene_widget_count(ctx->selene_ctx);
#else
  return ctx->widget_count;
#endif
}

// ===== 渲染 =====

MOONBIT_FFI_EXPORT
int32_t embit_view_update_joint(
  embit_view_ctx_t *ctx,
  int32_t index,
  double position,
  double velocity,
  double effort
) {
  if (ctx == NULL || !ctx->active || index < 0) return -1;
#ifdef EMBIT_HAS_SELENE
  return embit_selene_update_joint(ctx->selene_ctx, index, position, velocity, effort);
#else
  (void)index; (void)position; (void)velocity; (void)effort;
  ctx->joint_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_render_frame(embit_view_ctx_t *ctx) {
  if (ctx == NULL || !ctx->active) return -1;
#ifdef EMBIT_HAS_SELENE
  int32_t r = embit_selene_render_frame(ctx->selene_ctx);
  if (r == 0) ctx->render_count++;
  return r;
#else
  ctx->render_count++;
  ctx->joint_count = 0;
  return 0;
#endif
}

// ===== 录制 =====

MOONBIT_FFI_EXPORT
int32_t embit_view_record_start(
  embit_view_ctx_t *ctx,
  moonbit_bytes_t session_id
) {
  if (ctx == NULL || !ctx->active) return -1;
  if (ctx->recording) return -1;
#ifdef EMBIT_HAS_SELENE
  int32_t r = embit_selene_record_start(ctx->selene_ctx, (const char *)session_id);
  if (r == 0) ctx->recording = 1;
  return r;
#else
  (void)session_id;
  ctx->recording = 1;
  ctx->recorded_frames = 0;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_record_add_frame(embit_view_ctx_t *ctx) {
  if (ctx == NULL || !ctx->active || !ctx->recording) return -1;
#ifdef EMBIT_HAS_SELENE
  int32_t r = embit_selene_record_add_frame(ctx->selene_ctx);
  if (r == 0) ctx->recorded_frames++;
  return r;
#else
  ctx->recorded_frames++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_record_stop(embit_view_ctx_t *ctx) {
  if (ctx == NULL || !ctx->active) return -1;
  if (!ctx->recording) return 0;
#ifdef EMBIT_HAS_SELENE
  int32_t r = embit_selene_record_stop(ctx->selene_ctx);
  if (r == 0) ctx->recording = 0;
  return r;
#else
  ctx->recording = 0;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_record_frame_count(embit_view_ctx_t *ctx) {
  if (ctx == NULL) return 0;
#ifdef EMBIT_HAS_SELENE
  return embit_selene_record_frame_count(ctx->selene_ctx);
#else
  return ctx->recorded_frames;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_record_is_active(embit_view_ctx_t *ctx) {
  if (ctx == NULL) return 0;
#ifdef EMBIT_HAS_SELENE
  return embit_selene_record_is_active(ctx->selene_ctx);
#else
  return ctx->recording;
#endif
}

// ===== 回放 =====

MOONBIT_FFI_EXPORT
int32_t embit_view_playback_open(
  embit_view_ctx_t *ctx,
  moonbit_bytes_t session_id,
  int32_t total_frames
) {
  if (ctx == NULL || !ctx->active || total_frames < 0) return -1;
#ifdef EMBIT_HAS_SELENE
  int32_t r = embit_selene_playback_open(
    ctx->selene_ctx, (const char *)session_id, total_frames
  );
  if (r == 0) {
    ctx->playback_total = total_frames;
    ctx->playback_current = 0;
  }
  return r;
#else
  (void)session_id;
  ctx->playback_total = total_frames;
  ctx->playback_current = 0;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_playback_next_frame(embit_view_ctx_t *ctx) {
  if (ctx == NULL || !ctx->active) return -1;
  if (ctx->playback_current >= ctx->playback_total) return ctx->playback_current;
#ifdef EMBIT_HAS_SELENE
  int32_t r = embit_selene_playback_next_frame(ctx->selene_ctx);
  if (r >= 0) ctx->playback_current = r;
  return r;
#else
  ctx->playback_current++;
  return ctx->playback_current;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_playback_total_frames(embit_view_ctx_t *ctx) {
  if (ctx == NULL) return 0;
#ifdef EMBIT_HAS_SELENE
  return embit_selene_playback_total_frames(ctx->selene_ctx);
#else
  return ctx->playback_total;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_playback_current_frame(embit_view_ctx_t *ctx) {
  if (ctx == NULL) return 0;
#ifdef EMBIT_HAS_SELENE
  return embit_selene_playback_current_frame(ctx->selene_ctx);
#else
  return ctx->playback_current;
#endif
}

// ===== 参数调优 =====

MOONBIT_FFI_EXPORT
int32_t embit_view_set_parameter(
  embit_view_ctx_t *ctx,
  moonbit_bytes_t name,
  double value
) {
  if (ctx == NULL || !ctx->active) return -1;
#ifdef EMBIT_HAS_SELENE
  int32_t r = embit_selene_set_parameter(ctx->selene_ctx, (const char *)name, value);
  if (r == 0) ctx->parameter_count++;
  return r;
#else
  (void)name; (void)value;
  ctx->parameter_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
double embit_view_get_parameter(
  embit_view_ctx_t *ctx,
  moonbit_bytes_t name,
  double default_value
) {
  if (ctx == NULL || !ctx->active) return default_value;
#ifdef EMBIT_HAS_SELENE
  return embit_selene_get_parameter(ctx->selene_ctx, (const char *)name, default_value);
#else
  (void)name;
  return default_value;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_parameter_count(embit_view_ctx_t *ctx) {
  if (ctx == NULL) return 0;
#ifdef EMBIT_HAS_SELENE
  return embit_selene_parameter_count(ctx->selene_ctx);
#else
  return ctx->parameter_count;
#endif
}

// ===== 数据序列 =====

MOONBIT_FFI_EXPORT
int32_t embit_view_push_data(
  embit_view_ctx_t *ctx,
  moonbit_bytes_t series_name,
  double timestamp,
  double value
) {
  if (ctx == NULL || !ctx->active) return -1;
#ifdef EMBIT_HAS_SELENE
  int32_t r = embit_selene_push_data(
    ctx->selene_ctx, (const char *)series_name, timestamp, value
  );
  if (r == 0) ctx->data_point_count++;
  return r;
#else
  (void)series_name; (void)timestamp; (void)value;
  ctx->data_point_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_view_data_point_count(embit_view_ctx_t *ctx) {
  if (ctx == NULL) return 0;
#ifdef EMBIT_HAS_SELENE
  return embit_selene_data_point_count(ctx->selene_ctx);
#else
  return ctx->data_point_count;
#endif
}