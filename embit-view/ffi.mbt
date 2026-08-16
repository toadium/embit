///|
/// Selene 可视化引擎上下文句柄。
///
/// 不透明类型，由 C 侧 `embit_view_create` 创建，
/// 封装为 GC 管理的外部对象（external object）。
/// 真实模式封装 Selene 引擎 App/Window 句柄，占位模式仅记录操作计数。
type ViewContext

///|
/// 创建 Selene 可视化上下文。
///
/// `model_name` 为窗口标题（UTF-8 编码），`dof` 为机器人自由度。
/// 真实模式创建 Selene GUI 窗口，占位模式仅初始化计数器。
#borrow(model_name)
extern "c" fn embit_view_create(model_name : Bytes, dof : Int) -> ViewContext = "embit_view_create"

///|
/// 查询上下文是否活跃。
#borrow(ctx)
extern "c" fn embit_view_is_active(ctx : ViewContext) -> Int = "embit_view_is_active"

///|
/// 查询渲染调用计数（用于测试验证 FFI 通道）。
#borrow(ctx)
extern "c" fn embit_view_render_count(ctx : ViewContext) -> Int = "embit_view_render_count"

// ===== Widget 管理 =====

///|
/// 添加 Widget 到面板。
///
/// `widget_type`: 0=JointPlot, 1=SensorDisplay, 2=View3D, 3=LogPanel, 4=ParameterTuner
/// 返回：0=成功, -1=失败。
#borrow(ctx, title, topic)
extern "c" fn embit_view_add_widget(
  ctx : ViewContext,
  widget_type : Int,
  title : Bytes,
  topic : Bytes,
) -> Int = "embit_view_add_widget"

///|
/// 查询 Widget 数量。
#borrow(ctx)
extern "c" fn embit_view_widget_count(ctx : ViewContext) -> Int = "embit_view_widget_count"

// ===== 渲染 =====

///|
/// 更新单个关节状态（渲染前调用）。
///
/// `index` 为关节索引，`position`/`velocity`/`effort` 为关节状态值。
/// 返回：0=成功, -1=失败。
#borrow(ctx)
extern "c" fn embit_view_update_joint(
  ctx : ViewContext,
  index : Int,
  position : Double,
  velocity : Double,
  effort : Double,
) -> Int = "embit_view_update_joint"

///|
/// 渲染一帧（将累积的关节状态推送到 GUI）。
///
/// 返回：0=成功, -1=失败。
#borrow(ctx)
extern "c" fn embit_view_render_frame(ctx : ViewContext) -> Int = "embit_view_render_frame"

// ===== 录制 =====

///|
/// 开始录制会话。
///
/// `session_id` 为 UTF-8 编码的会话标识。
/// 返回：0=成功, -1=失败。
#borrow(ctx, session_id)
extern "c" fn embit_view_record_start(
  ctx : ViewContext,
  session_id : Bytes,
) -> Int = "embit_view_record_start"

///|
/// 录制当前帧。
///
/// 返回：0=成功, -1=失败。
#borrow(ctx)
extern "c" fn embit_view_record_add_frame(ctx : ViewContext) -> Int = "embit_view_record_add_frame"

///|
/// 停止录制。
///
/// 返回：0=成功, -1=失败。
#borrow(ctx)
extern "c" fn embit_view_record_stop(ctx : ViewContext) -> Int = "embit_view_record_stop"

///|
/// 查询已录制帧数。
#borrow(ctx)
extern "c" fn embit_view_record_frame_count(ctx : ViewContext) -> Int = "embit_view_record_frame_count"

///|
/// 查询是否正在录制。返回：1=录制中, 0=未录制。
#borrow(ctx)
extern "c" fn embit_view_record_is_active(ctx : ViewContext) -> Int = "embit_view_record_is_active"

// ===== 回放 =====

///|
/// 打开回放流。
///
/// `session_id` 为会话标识，`total_frames` 为总帧数。
/// 返回：0=成功, -1=失败。
#borrow(ctx, session_id)
extern "c" fn embit_view_playback_open(
  ctx : ViewContext,
  session_id : Bytes,
  total_frames : Int,
) -> Int = "embit_view_playback_open"

///|
/// 前进一帧。返回：当前帧序号, -1=失败。
#borrow(ctx)
extern "c" fn embit_view_playback_next_frame(ctx : ViewContext) -> Int = "embit_view_playback_next_frame"

///|
/// 查询回放总帧数。
#borrow(ctx)
extern "c" fn embit_view_playback_total_frames(ctx : ViewContext) -> Int = "embit_view_playback_total_frames"

///|
/// 查询回放当前帧序号。
#borrow(ctx)
extern "c" fn embit_view_playback_current_frame(ctx : ViewContext) -> Int = "embit_view_playback_current_frame"

// ===== 参数调优 =====

///|
/// 设置参数值。
///
/// `name` 为 UTF-8 编码的参数名。返回：0=成功, -1=失败。
#borrow(ctx, name)
extern "c" fn embit_view_set_parameter(
  ctx : ViewContext,
  name : Bytes,
  value : Double,
) -> Int = "embit_view_set_parameter"

///|
/// 查询参数值。不存在时返回 `default_value`。
#borrow(ctx, name)
extern "c" fn embit_view_get_parameter(
  ctx : ViewContext,
  name : Bytes,
  default_value : Double,
) -> Double = "embit_view_get_parameter"

///|
/// 查询参数数量。
#borrow(ctx)
extern "c" fn embit_view_parameter_count(ctx : ViewContext) -> Int = "embit_view_parameter_count"

// ===== 数据序列 =====

///|
/// 推送数据点到时间序列。
///
/// `series_name` 为序列名，`timestamp`/`value` 为数据点。
/// 返回：0=成功, -1=失败。
#borrow(ctx, series_name)
extern "c" fn embit_view_push_data(
  ctx : ViewContext,
  series_name : Bytes,
  timestamp : Double,
  value : Double,
) -> Int = "embit_view_push_data"

///|
/// 查询数据点总数。
#borrow(ctx)
extern "c" fn embit_view_data_point_count(ctx : ViewContext) -> Int = "embit_view_data_point_count"
