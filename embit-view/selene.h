// selene.h — Selene 可视化引擎 C 接口声明
//
// 这些 C 接口由 selene_wrapper.c 实现，封装真实 Selene 引擎的渲染调用。
// view_stub.c 在 EMBIT_HAS_SELENE 定义时调用这些接口。
//
// 真实实现依赖 Selene 可视化引擎（Rust 编译的 C ABI 静态库或动态库），
// 由 scripts/prepare.py 检测并编译，通过 link.native 链接。
//
// Selene 引擎提供：GUI 窗口管理、Widget 渲染、数据录制/回放、参数调优面板。

#ifndef EMBIT_VIEW_SELENE_H
#define EMBIT_VIEW_SELENE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ===== 上下文管理 =====
// 创建 Selene 可视化上下文（GUI 窗口）。
// title: 窗口标题（UTF-8），width/height: 窗口尺寸（像素）。
// 返回：上下文句柄（void*），NULL 表示创建失败。
void *embit_selene_create(const char *title, int32_t width, int32_t height);

// 销毁上下文，释放 GUI 资源。
void embit_selene_destroy(void *ctx);

// 查询窗口是否活跃。返回：1=活跃, 0=已关闭。
int32_t embit_selene_is_active(void *ctx);

// ===== Widget 管理 =====
// 添加 Widget 到面板。
// widget_type: 0=JointPlot, 1=SensorDisplay, 2=View3D, 3=LogPanel, 4=ParameterTuner
// title/topic: UTF-8 字符串。
// 返回：0=成功, -1=失败。
int32_t embit_selene_add_widget(
  void *ctx, int32_t widget_type, const char *title, const char *topic
);

// 清除所有 Widget。返回：0=成功, -1=失败。
int32_t embit_selene_clear_widgets(void *ctx);

// 查询 Widget 数量。
int32_t embit_selene_widget_count(void *ctx);

// ===== 渲染 =====
// 更新单个关节状态（渲染前调用）。
// index: 关节索引, position/velocity/effort: 关节状态值。
// 返回：0=成功, -1=失败。
int32_t embit_selene_update_joint(
  void *ctx, int32_t index, double position, double velocity, double effort
);

// 渲染一帧（将累积的关节状态推送到 GUI）。
// 返回：0=成功, -1=失败。
int32_t embit_selene_render_frame(void *ctx);

// ===== 录制 =====
// 开始录制会话。session_id: UTF-8 会话标识。
// 返回：0=成功, -1=失败。
int32_t embit_selene_record_start(void *ctx, const char *session_id);

// 录制当前帧（将当前关节状态快照写入录制缓冲区）。
// 返回：0=成功, -1=失败。
int32_t embit_selene_record_add_frame(void *ctx);

// 停止录制。返回：0=成功, -1=失败。
int32_t embit_selene_record_stop(void *ctx);

// 查询已录制帧数。
int32_t embit_selene_record_frame_count(void *ctx);

// 查询是否正在录制。返回：1=录制中, 0=未录制。
int32_t embit_selene_record_is_active(void *ctx);

// ===== 回放 =====
// 打开回放流。session_id: 会话标识, total_frames: 总帧数。
// 返回：0=成功, -1=失败。
int32_t embit_selene_playback_open(
  void *ctx, const char *session_id, int32_t total_frames
);

// 前进一帧。返回：当前帧序号, -1=失败。
int32_t embit_selene_playback_next_frame(void *ctx);

// 查询回放总帧数。
int32_t embit_selene_playback_total_frames(void *ctx);

// 查询回放当前帧序号。
int32_t embit_selene_playback_current_frame(void *ctx);

// ===== 参数调优 =====
// 设置参数值。name: UTF-8 参数名。返回：0=成功, -1=失败。
int32_t embit_selene_set_parameter(void *ctx, const char *name, double value);

// 查询参数值。不存在时返回 default_value。
double embit_selene_get_parameter(void *ctx, const char *name, double default_value);

// 查询参数数量。
int32_t embit_selene_parameter_count(void *ctx);

// ===== 数据序列 =====
// 推送数据点到时间序列。series_name: 序列名, timestamp/value: 数据点。
// 返回：0=成功, -1=失败。
int32_t embit_selene_push_data(
  void *ctx, const char *series_name, double timestamp, double value
);

// 查询数据点总数。
int32_t embit_selene_data_point_count(void *ctx);

#ifdef __cplusplus
}
#endif

#endif // EMBIT_VIEW_SELENE_H