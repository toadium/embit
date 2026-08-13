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
/// 面板组件描述。
///
/// `widget_type` 标识组件类别，`title` 为面板标题，`topic` 为数据源话题。
pub(all) struct Widget {
  widget_type : WidgetType
  title : String
  topic : String
} derive(Eq, Debug)

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
/// 监控面板：实时状态观测、数据回放与参数在线调优。
///
/// Phase 1 为占位实现，Phase 2 将集成 Selene 可视化引擎。
pub struct ViewPanel {
  model_info : @core.RobotModelInfo
  widgets : Array[Widget]
  mut current_recording : RecordingHandle?
  parameters : Map[String, Double]
}

///|
/// 创建监控面板。
pub fn ViewPanel::new() -> ViewPanel {
  {
    model_info: { name: "", version: "", dof: 0, urdf_path: "" },
    widgets: [],
    current_recording: None,
    parameters: Map([]),
  }
}

///|
/// 创建监控面板并绑定机器人模型信息。
pub fn ViewPanel::with_model(model_info : @core.RobotModelInfo) -> ViewPanel {
  { model_info, widgets: [], current_recording: None, parameters: Map([]) }
}

///|
/// 添加组件到面板。
pub fn ViewPanel::add_widget(self : ViewPanel, widget : Widget) -> Unit {
  self.widgets.push(widget)
}

///|
/// 渲染面板：根据机器人状态更新所有组件。
///
/// Phase 1 占位实现：仅验证组件列表非空。
/// 真实实现将调用 Selene 引擎渲染 GUI。
pub fn ViewPanel::render(
  self : ViewPanel,
  robot_state : Array[@core.JointState],
) -> Unit raise @core.RobotError {
  if self.widgets.length() == 0 {
    raise SensorReadError("no widgets to render")
  }
  ignore(robot_state)
}

///|
/// 开始录制会话。
///
/// `session_id` 为会话标识，用于后续回放检索。
pub fn ViewPanel::record(
  self : ViewPanel,
  session_id : String,
) -> RecordingHandle {
  let handle = RecordingHandle::new(session_id)
  self.current_recording = Some(handle)
  handle
}

///|
/// 回放录制会话。
///
/// 失败时抛出 `RobotError::SensorReadError`。
pub fn ViewPanel::playback(
  self : ViewPanel,
  handle : RecordingHandle,
) -> PlaybackStream raise @core.RobotError {
  ignore(self)
  if handle.frames() == 0 {
    raise SensorReadError("no frames recorded for session \{handle.session_id}")
  }
  {
    session_id: handle.session_id,
    total_frames: handle.frames(),
    current_frame: 0,
  }
}

///|
/// 停止当前录制。
pub fn ViewPanel::stop_recording(self : ViewPanel) -> Unit {
  match self.current_recording {
    Some(handle) => handle.stop()
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
pub fn ViewPanel::tune_parameter(
  self : ViewPanel,
  name : String,
  value : Double,
) -> Unit {
  self.parameters[name] = value
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
