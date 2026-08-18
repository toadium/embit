///|
/// 面板组件类型。
///
/// 定义可视化面板中可添加的组件类别，
/// 由 `ViewPanel::add_widget` 使用。
pub(all) enum WidgetType {
  JointPlot // 关节轨迹图
  SensorDisplay // 传感器数据表
  View3D // 3D 可视化视图
  LogPanel // 日志面板
  ParameterTuner // 参数在线调优面板
} derive(Eq, Debug)

///|
pub extend WidgetType with Eq::{not_equal, equal}

///|
pub extend WidgetType with @debug.Debug::{to_repr}

///|
/// 面板组件描述。
///
/// `widget_type` 标识组件类别，`title` 为面板标题，`topic` 为数据源话题。
pub(all) struct Widget {
  widget_type : WidgetType
  title : String
  topic : String
} derive(Eq, Debug)

///|
pub extend Widget with Eq::{not_equal, equal}

///|
pub extend Widget with @debug.Debug::{to_repr}

///|
/// 录制会话句柄。
///
/// 由 `ViewPanel::record` 创建，传递给 `ViewPanel::playback` 回放数据。
pub(all) struct RecordingHandle {
  session_id : String
  mut frame_count : Int
  mut is_recording : Bool
}

///|
/// 回放数据流。
///
/// 由 `ViewPanel::playback` 创建，提供逐帧回放接口。
pub(all) struct PlaybackStream {
  session_id : String
  total_frames : Int
  mut current_frame : Int
}

///|
/// 创建录制句柄。
pub fn RecordingHandle::new(session_id : String) -> RecordingHandle {
  { session_id, frame_count: 0, is_recording: true }
}

///|
/// 停止录制。
pub fn RecordingHandle::stop(self : RecordingHandle) -> Unit {
  self.is_recording = false
}

///|
/// 增加帧计数。
pub fn RecordingHandle::add_frame(self : RecordingHandle) -> Unit {
  if self.is_recording {
    self.frame_count = self.frame_count + 1
  }
}

///|
/// 查询是否正在录制。
pub fn RecordingHandle::is_active(self : RecordingHandle) -> Bool {
  self.is_recording
}

///|
/// 获取已录制帧数。
pub fn RecordingHandle::frames(self : RecordingHandle) -> Int {
  self.frame_count
}

///|
/// 回放是否已结束。
pub fn PlaybackStream::is_finished(self : PlaybackStream) -> Bool {
  self.current_frame >= self.total_frames
}

///|
/// 前进一帧，返回当前帧序号。
pub fn PlaybackStream::next_frame(self : PlaybackStream) -> Int {
  if !self.is_finished() {
    self.current_frame = self.current_frame + 1
  }
  self.current_frame
}

///|
/// 回放进度（0.0 ~ 1.0）。
pub fn PlaybackStream::progress(self : PlaybackStream) -> Double {
  if self.total_frames == 0 {
    1.0
  } else {
    self.current_frame.to_double() / self.total_frames.to_double()
  }
}

///|
/// WidgetType 转 FFI 整数编码。
///
/// 0=JointPlot, 1=SensorDisplay, 2=View3D, 3=LogPanel, 4=ParameterTuner。
fn widget_type_to_int(t : WidgetType) -> Int {
  match t {
    JointPlot => 0
    SensorDisplay => 1
    View3D => 2
    LogPanel => 3
    ParameterTuner => 4
  }
}

///|
/// 监控面板：实时状态观测、数据回放与参数在线调优。
///
/// 通过 FFI 绑定 Selene 可视化引擎，提供 GUI 渲染、数据录制与回放。
/// 条件编译：EMBIT_HAS_SELENE 启用真实 Selene 引擎，否则占位回退（仅记录计数）。
///
/// # Example
/// ```mbt check
/// test {
///   let panel = @embit-view.ViewPanel::new()
///   inspect(panel.widget_count(), content="0")
/// }
/// ```
pub struct ViewPanel {
  model_info : @core.RobotModelInfo
  widgets : Array[Widget]
  mut current_recording : RecordingHandle?
  parameters : Map[String, Double]
  view_ctx : ViewContext
}

///|
/// 创建监控面板。
pub fn ViewPanel::new() -> ViewPanel {
  let view_ctx = embit_view_create(@utf8.encode(""), 0)
  {
    model_info: { name: "", version: "", dof: 0, urdf_path: "" },
    widgets: [],
    current_recording: None,
    parameters: Map([]),
    view_ctx,
  }
}

///|
/// 创建监控面板并绑定机器人模型信息。
pub fn ViewPanel::with_model(model_info : @core.RobotModelInfo) -> ViewPanel {
  let view_ctx = embit_view_create(
    @utf8.encode(model_info.name),
    model_info.dof,
  )
  {
    model_info,
    widgets: [],
    current_recording: None,
    parameters: Map([]),
    view_ctx,
  }
}

///|
/// 添加组件到面板。
///
/// 同步将 Widget 注册到 Selene 引擎（真实模式）或记录计数（占位模式）。
pub fn ViewPanel::add_widget(self : ViewPanel, widget : Widget) -> Unit {
  self.widgets.push(widget)
  ignore(
    embit_view_add_widget(
      self.view_ctx,
      widget_type_to_int(widget.widget_type),
      @utf8.encode(widget.title),
      @utf8.encode(widget.topic),
    ),
  )
}

///|
/// 渲染面板：根据机器人状态更新所有组件。
///
/// 真实模式调用 Selene 引擎渲染 GUI 帧；
/// 占位模式仅更新渲染计数。
/// 若当前正在录制，自动将帧推送到录制缓冲区。
pub fn ViewPanel::render(
  self : ViewPanel,
  robot_state : Array[@core.JointState],
) -> Unit raise @core.RobotError {
  if self.widgets.length() == 0 {
    raise SensorReadError("no widgets to render")
  }
  // 逐关节更新状态到 Selene 引擎
  for i, js in robot_state {
    ignore(
      embit_view_update_joint(
        self.view_ctx,
        i,
        js.position,
        js.velocity,
        js.effort,
      ),
    )
  }
  // 渲染一帧
  ignore(embit_view_render_frame(self.view_ctx))
  // 若正在录制，自动捕获帧
  match self.current_recording {
    Some(handle) =>
      if handle.is_active() {
        handle.add_frame()
        ignore(embit_view_record_add_frame(self.view_ctx))
      }
    None => ()
  }
}

///|
/// 开始录制会话。
///
/// `session_id` 为会话标识，用于后续回放检索。
/// 真实模式通过 FFI 通知 Selene 引擎开始录制。
pub fn ViewPanel::record(
  self : ViewPanel,
  session_id : String,
) -> RecordingHandle {
  ignore(embit_view_record_start(self.view_ctx, @utf8.encode(session_id)))
  let handle = RecordingHandle::new(session_id)
  self.current_recording = Some(handle)
  handle
}

///|
/// 回放录制会话。
///
/// 失败时抛出 `RobotError::SensorReadError`。
/// 真实模式通过 FFI 打开 Selene 回放流。
pub fn ViewPanel::playback(
  self : ViewPanel,
  handle : RecordingHandle,
) -> PlaybackStream raise @core.RobotError {
  if handle.frames() == 0 {
    raise SensorReadError("no frames recorded for session \{handle.session_id}")
  }
  ignore(
    embit_view_playback_open(
      self.view_ctx,
      @utf8.encode(handle.session_id),
      handle.frames(),
    ),
  )
  {
    session_id: handle.session_id,
    total_frames: handle.frames(),
    current_frame: 0,
  }
}

///|
/// 停止当前录制。
///
/// 真实模式通过 FFI 通知 Selene 引擎停止录制。
pub fn ViewPanel::stop_recording(self : ViewPanel) -> Unit {
  match self.current_recording {
    Some(handle) => {
      handle.stop()
      ignore(embit_view_record_stop(self.view_ctx))
    }
    None => ()
  }
}

///|
/// 获取面板组件数。
pub fn ViewPanel::widget_count(self : ViewPanel) -> Int {
  self.widgets.length()
}

///|
/// 获取机器人模型信息。
pub fn ViewPanel::get_model_info(self : ViewPanel) -> @core.RobotModelInfo {
  self.model_info
}

///|
/// 在线调优参数：设置参数值。
///
/// `name` 为参数名（如 `"kp"` / `"kd"` / `"max_velocity"`），`value` 为新值。
/// 参数变更实时生效，无需重启面板。
/// 真实模式通过 FFI 将参数推送到 Selene 调优面板。
pub fn ViewPanel::tune_parameter(
  self : ViewPanel,
  name : String,
  value : Double,
) -> Unit {
  self.parameters[name] = value
  ignore(embit_view_set_parameter(self.view_ctx, @utf8.encode(name), value))
}

///|
/// 查询参数当前值。
///
/// 参数不存在时返回 `None`。
pub fn ViewPanel::get_parameter(self : ViewPanel, name : String) -> Double? {
  self.parameters.get(name)
}

///|
/// 列出所有已调优参数名。
pub fn ViewPanel::list_parameters(self : ViewPanel) -> Array[String] {
  let names : Array[String] = []
  self.parameters.each(fn(name, _) { names.push(name) })
  names
}

///|
/// 导出面板快照：序列化当前状态为可读字符串。
///
/// 包含模型信息、组件列表与参数表，用于调试存档与配置复现。
pub fn ViewPanel::export_snapshot(self : ViewPanel) -> String {
  let mut result = "=== Embit ViewPanel Snapshot ===\n"
  result += "Model: \{self.model_info.name} v\{self.model_info.version} (\{self.model_info.dof} DoF)\n"
  result += "Widgets (\{self.widgets.length()}):\n"
  for w in self.widgets {
    let type_str = match w.widget_type {
      JointPlot => "JointPlot"
      SensorDisplay => "SensorDisplay"
      View3D => "View3D"
      LogPanel => "LogPanel"
      ParameterTuner => "ParameterTuner"
    }
    result += "  - \{w.title} [\{type_str}] @ \{w.topic}\n"
  }
  result += "Parameters:\n"
  self.parameters.each(fn(name, value) { result += "  \{name} = \{value}\n" })
  result += "=== End Snapshot ==="
  result
}

// ===== Selene FFI 查询接口（用于测试验证 FFI 通道） =====

///|
/// 查询 Selene 上下文是否活跃。
pub fn ViewPanel::is_active(self : ViewPanel) -> Bool {
  embit_view_is_active(self.view_ctx) != 0
}

///|
/// 查询渲染调用计数（FFI 通道验证）。
pub fn ViewPanel::render_count(self : ViewPanel) -> Int {
  embit_view_render_count(self.view_ctx)
}

///|
/// 查询 FFI 侧已录制帧数。
pub fn ViewPanel::record_frame_count(self : ViewPanel) -> Int {
  embit_view_record_frame_count(self.view_ctx)
}

///|
/// 查询 FFI 侧是否正在录制。
pub fn ViewPanel::is_recording(self : ViewPanel) -> Bool {
  embit_view_record_is_active(self.view_ctx) != 0
}

///|
/// 查询 FFI 侧参数数量。
pub fn ViewPanel::parameter_count(self : ViewPanel) -> Int {
  embit_view_parameter_count(self.view_ctx)
}

///|
/// 查询 FFI 侧 Widget 数量。
pub fn ViewPanel::ffi_widget_count(self : ViewPanel) -> Int {
  embit_view_widget_count(self.view_ctx)
}

///|
/// 推送数据点到 Selene 时间序列。
///
/// `series_name` 为序列名，`timestamp`/`value` 为数据点。
/// 真实模式将数据推送到 Selene 引擎进行实时绘图。
pub fn ViewPanel::push_data(
  self : ViewPanel,
  series_name : String,
  timestamp : Double,
  value : Double,
) -> Unit {
  ignore(
    embit_view_push_data(
      self.view_ctx,
      @utf8.encode(series_name),
      timestamp,
      value,
    ),
  )
}

///|
/// 查询 FFI 侧数据点总数。
pub fn ViewPanel::data_point_count(self : ViewPanel) -> Int {
  embit_view_data_point_count(self.view_ctx)
}

///|
/// 通过 FFI 前进回放帧。返回当前帧序号。
pub fn ViewPanel::ffi_playback_next(self : ViewPanel) -> Int {
  embit_view_playback_next_frame(self.view_ctx)
}

///|
/// 通过 FFI 查询回放总帧数。
pub fn ViewPanel::ffi_playback_total(self : ViewPanel) -> Int {
  embit_view_playback_total_frames(self.view_ctx)
}

///|
/// 通过 FFI 查询回放当前帧序号。
pub fn ViewPanel::ffi_playback_current(self : ViewPanel) -> Int {
  embit_view_playback_current_frame(self.view_ctx)
}

///|
/// 通过 FFI 查询参数值。不存在时返回 `default_value`。
pub fn ViewPanel::ffi_get_parameter(
  self : ViewPanel,
  name : String,
  default_value : Double,
) -> Double {
  embit_view_get_parameter(self.view_ctx, @utf8.encode(name), default_value)
}
