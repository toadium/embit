// selene_wrapper.c — Selene 可视化引擎 C wrapper 实现
//
// 本文件封装真实 Selene 引擎的 C API 调用，实现 selene.h 声明的接口。
// 由 scripts/prepare.py 编译为静态库（libembit_selene.a / embit_selene.lib），
// 通过 link.native 链接到 view_stub.c。
//
// Selene 引擎典型实现：基于 wgpu/egui 的 Rust GUI 框架，编译为 C ABI 静态库。
// 本 wrapper 负责内存管理与线程安全，Selene 侧负责渲染管线。
//
// 编译要求：需安装 Selene SDK（headers + static lib），由 prepare.py 检测。

#include "selene.h"
#include <stdlib.h>
#include <string.h>

// 真实 Selene 上下文（对应 Selene 引擎的 App/Window 句柄）
// 这里声明外部 Selene 引擎入口点（由 Selene SDK 提供）
extern void *selene_app_create(const char *title, int32_t width, int32_t height);
extern void selene_app_destroy(void *app);
extern int32_t selene_app_is_active(void *app);
extern int32_t selene_app_add_widget(
  void *app, int32_t widget_type, const char *title, const char *topic
);
extern int32_t selene_app_clear_widgets(void *app);
extern int32_t selene_app_widget_count(void *app);
extern int32_t selene_app_update_joint(
  void *app, int32_t index, double position, double velocity, double effort
);
extern int32_t selene_app_render_frame(void *app);
extern int32_t selene_app_record_start(void *app, const char *session_id);
extern int32_t selene_app_record_add_frame(void *app);
extern int32_t selene_app_record_stop(void *app);
extern int32_t selene_app_record_frame_count(void *app);
extern int32_t selene_app_record_is_active(void *app);
extern int32_t selene_app_playback_open(
  void *app, const char *session_id, int32_t total_frames
);
extern int32_t selene_app_playback_next_frame(void *app);
extern int32_t selene_app_playback_total_frames(void *app);
extern int32_t selene_app_playback_current_frame(void *app);
extern int32_t selene_app_set_parameter(void *app, const char *name, double value);
extern double selene_app_get_parameter(void *app, const char *name, double default_value);
extern int32_t selene_app_parameter_count(void *app);
extern int32_t selene_app_push_data(
  void *app, const char *series_name, double timestamp, double value
);
extern int32_t selene_app_data_point_count(void *app);

// ===== 上下文管理 =====

void *embit_selene_create(const char *title, int32_t width, int32_t height) {
  if (title == NULL) title = "Embit ViewPanel";
  if (width <= 0) width = 1280;
  if (height <= 0) height = 720;
  return selene_app_create(title, width, height);
}

void embit_selene_destroy(void *ctx) {
  if (ctx == NULL) return;
  selene_app_destroy(ctx);
}

int32_t embit_selene_is_active(void *ctx) {
  if (ctx == NULL) return 0;
  return selene_app_is_active(ctx);
}

// ===== Widget 管理 =====

int32_t embit_selene_add_widget(
  void *ctx, int32_t widget_type, const char *title, const char *topic
) {
  if (ctx == NULL || title == NULL || topic == NULL) return -1;
  if (widget_type < 0 || widget_type > 4) return -1;
  return selene_app_add_widget(ctx, widget_type, title, topic);
}

int32_t embit_selene_clear_widgets(void *ctx) {
  if (ctx == NULL) return -1;
  return selene_app_clear_widgets(ctx);
}

int32_t embit_selene_widget_count(void *ctx) {
  if (ctx == NULL) return 0;
  return selene_app_widget_count(ctx);
}

// ===== 渲染 =====

int32_t embit_selene_update_joint(
  void *ctx, int32_t index, double position, double velocity, double effort
) {
  if (ctx == NULL || index < 0) return -1;
  return selene_app_update_joint(ctx, index, position, velocity, effort);
}

int32_t embit_selene_render_frame(void *ctx) {
  if (ctx == NULL) return -1;
  return selene_app_render_frame(ctx);
}

// ===== 录制 =====

int32_t embit_selene_record_start(void *ctx, const char *session_id) {
  if (ctx == NULL || session_id == NULL) return -1;
  return selene_app_record_start(ctx, session_id);
}

int32_t embit_selene_record_add_frame(void *ctx) {
  if (ctx == NULL) return -1;
  return selene_app_record_add_frame(ctx);
}

int32_t embit_selene_record_stop(void *ctx) {
  if (ctx == NULL) return -1;
  return selene_app_record_stop(ctx);
}

int32_t embit_selene_record_frame_count(void *ctx) {
  if (ctx == NULL) return 0;
  return selene_app_record_frame_count(ctx);
}

int32_t embit_selene_record_is_active(void *ctx) {
  if (ctx == NULL) return 0;
  return selene_app_record_is_active(ctx);
}

// ===== 回放 =====

int32_t embit_selene_playback_open(
  void *ctx, const char *session_id, int32_t total_frames
) {
  if (ctx == NULL || session_id == NULL || total_frames < 0) return -1;
  return selene_app_playback_open(ctx, session_id, total_frames);
}

int32_t embit_selene_playback_next_frame(void *ctx) {
  if (ctx == NULL) return -1;
  return selene_app_playback_next_frame(ctx);
}

int32_t embit_selene_playback_total_frames(void *ctx) {
  if (ctx == NULL) return 0;
  return selene_app_playback_total_frames(ctx);
}

int32_t embit_selene_playback_current_frame(void *ctx) {
  if (ctx == NULL) return 0;
  return selene_app_playback_current_frame(ctx);
}

// ===== 参数调优 =====

int32_t embit_selene_set_parameter(void *ctx, const char *name, double value) {
  if (ctx == NULL || name == NULL) return -1;
  return selene_app_set_parameter(ctx, name, value);
}

double embit_selene_get_parameter(void *ctx, const char *name, double default_value) {
  if (ctx == NULL || name == NULL) return default_value;
  return selene_app_get_parameter(ctx, name, default_value);
}

int32_t embit_selene_parameter_count(void *ctx) {
  if (ctx == NULL) return 0;
  return selene_app_parameter_count(ctx);
}

// ===== 数据序列 =====

int32_t embit_selene_push_data(
  void *ctx, const char *series_name, double timestamp, double value
) {
  if (ctx == NULL || series_name == NULL) return -1;
  return selene_app_push_data(ctx, series_name, timestamp, value);
}

int32_t embit_selene_data_point_count(void *ctx) {
  if (ctx == NULL) return 0;
  return selene_app_data_point_count(ctx);
}