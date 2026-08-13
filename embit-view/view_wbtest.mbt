///|
/// embit-view 白盒测试：验证面板组件、录制回放与渲染行为。

///|
fn make_test_widget() -> Widget {
  { widget_type: JointPlot, title: "Joint 1", topic: "/joint_states" }
}

///|
test "Widget - construct and fields" {
  let w = make_test_widget()
  assert_eq(w.widget_type, JointPlot)
  assert_eq(w.title, "Joint 1")
  assert_eq(w.topic, "/joint_states")
}

///|
test "ViewPanel - new creates empty panel" {
  let panel = ViewPanel::new()
  assert_eq(panel.widget_count(), 0)
}

///|
test "ViewPanel - add_widget increments count" {
  let panel = ViewPanel::new()
  panel.add_widget(make_test_widget())
  panel.add_widget({ widget_type: View3D, title: "3D View", topic: "/camera" })
  assert_eq(panel.widget_count(), 2)
}

///|
test "ViewPanel - render raises on empty widgets" {
  let panel = ViewPanel::new()
  let state : Array[@core.JointState] = []
  try panel.render(state) catch {
    SensorReadError(msg) => assert_true(msg.contains("no widgets"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected SensorReadError")
  }
}

///|
test "ViewPanel - render succeeds with widgets" {
  let panel = ViewPanel::new()
  panel.add_widget(make_test_widget())
  let state : Array[@core.JointState] = [
    { name: "j1", position: 0.0, velocity: 0.0, effort: 0.0 },
  ]
  panel.render(state)
}

///|
test "ViewPanel - record creates active handle" {
  let panel = ViewPanel::new()
  let handle = panel.record("session_001")
  assert_true(handle.is_active())
  assert_eq(handle.frames(), 0)
  assert_eq(handle.session_id, "session_001")
}

///|
test "ViewPanel - record and playback" {
  let panel = ViewPanel::new()
  let handle = panel.record("session_002")
  handle.add_frame()
  handle.add_frame()
  handle.add_frame()
  assert_eq(handle.frames(), 3)
  handle.stop()
  assert_false(handle.is_active())
  let stream = panel.playback(handle)
  assert_eq(stream.total_frames, 3)
  assert_false(stream.is_finished())
}

///|
test "ViewPanel - playback raises on empty recording" {
  let panel = ViewPanel::new()
  let handle = panel.record("session_003")
  handle.stop()
  try panel.playback(handle) catch {
    SensorReadError(msg) => assert_true(msg.contains("no frames"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected SensorReadError")
  }
}

///|
test "PlaybackStream - next_frame advances and finishes" {
  let panel = ViewPanel::new()
  let handle = panel.record("session_004")
  handle.add_frame()
  handle.add_frame()
  let stream = panel.playback(handle)
  assert_eq(stream.next_frame(), 1)
  assert_eq(stream.next_frame(), 2)
  assert_true(stream.is_finished())
  // 越界不前进
  assert_eq(stream.next_frame(), 2)
}

///|
test "PlaybackStream - progress calculation" {
  let panel = ViewPanel::new()
  let handle = panel.record("session_005")
  handle.add_frame()
  handle.add_frame()
  handle.add_frame()
  handle.add_frame()
  let stream = panel.playback(handle)
  assert_eq(stream.progress(), 0.0)
  ignore(stream.next_frame())
  assert_true(stream.progress() > 0.0)
  ignore(stream.next_frame())
  ignore(stream.next_frame())
  ignore(stream.next_frame())
  assert_eq(stream.progress(), 1.0)
}

///|
test "ViewPanel - with_model sets model info" {
  let info : @core.RobotModelInfo = {
    name: "humanoid",
    version: "2.0",
    dof: 12,
    urdf_path: "models/humanoid.urdf",
  }
  let panel = ViewPanel::with_model(info)
  assert_eq(panel.get_model_info().name, "humanoid")
  assert_eq(panel.get_model_info().dof, 12)
}

///|
test "ViewPanel - stop_recording stops active session" {
  let panel = ViewPanel::new()
  let handle = panel.record("session_006")
  assert_true(handle.is_active())
  panel.stop_recording()
  assert_false(handle.is_active())
}

// ===== 参数调优测试 =====

///|
/// tune_parameter 设置参数值，get_parameter 查询。
test "ViewPanel - tune and get parameter" {
  let panel = ViewPanel::new()
  panel.tune_parameter("kp", 100.0)
  panel.tune_parameter("kd", 20.0)
  assert_eq(panel.get_parameter("kp"), Some(100.0))
  assert_eq(panel.get_parameter("kd"), Some(20.0))
}

///|
/// 查询不存在的参数返回 None。
test "ViewPanel - get_parameter nonexistent returns None" {
  let panel = ViewPanel::new()
  assert_eq(panel.get_parameter("nonexistent"), None)
}

///|
/// list_parameters 列出所有已调优参数。
test "ViewPanel - list_parameters" {
  let panel = ViewPanel::new()
  panel.tune_parameter("kp", 100.0)
  panel.tune_parameter("kd", 20.0)
  panel.tune_parameter("max_vel", 1.5)
  let names = panel.list_parameters()
  assert_eq(names.length(), 3)
}

///|
/// 重复设置同一参数应覆盖旧值。
test "ViewPanel - tune_parameter overwrites" {
  let panel = ViewPanel::new()
  panel.tune_parameter("kp", 100.0)
  panel.tune_parameter("kp", 200.0)
  assert_eq(panel.get_parameter("kp"), Some(200.0))
}

// ===== 快照导出测试 =====

///|
/// export_snapshot 包含模型信息。
test "ViewPanel - export_snapshot contains model info" {
  let panel = ViewPanel::with_model({
    name: "humanoid",
    version: "2.0",
    dof: 12,
    urdf_path: "models/humanoid.urdf",
  })
  let snapshot = panel.export_snapshot()
  assert_true(snapshot.contains("humanoid"))
  assert_true(snapshot.contains("Snapshot"))
}

///|
/// export_snapshot 包含组件信息。
test "ViewPanel - export_snapshot contains widgets" {
  let panel = ViewPanel::new()
  panel.add_widget({
    widget_type: JointPlot,
    title: "Joint Plot",
    topic: "/joints",
  })
  let snapshot = panel.export_snapshot()
  assert_true(snapshot.contains("Joint Plot"))
  assert_true(snapshot.contains("JointPlot"))
}

///|
/// export_snapshot 包含参数信息。
test "ViewPanel - export_snapshot contains parameters" {
  let panel = ViewPanel::new()
  panel.tune_parameter("kp", 100.0)
  let snapshot = panel.export_snapshot()
  assert_true(snapshot.contains("kp"))
  assert_true(snapshot.contains("100"))
}
