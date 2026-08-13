///|
/// 测试用模拟机器人，实现 Robot trait。
struct MockRobot {
  model_info : RobotModelInfo
}

///|
impl Robot for MockRobot with fn get_sensor_readings(self) {
  ignore(self)
  [{ kind: Camera, timestamp: 0.0, data: b"" }]
}

///|
impl Robot for MockRobot with fn execute_actions(self, commands) {
  ignore(self)
  if commands.length() == 0 {
    raise ActionExecuteError("empty commands")
  }
}

///|
impl Robot for MockRobot with fn get_model_info(self) {
  self.model_info
}

///|
extend MockRobot with Robot::{
  get_sensor_readings,
  execute_actions,
  get_model_info,
}

///|
fn make_mock_robot() -> MockRobot {
  { model_info: { name: "mock", version: "1.0", dof: 1, urdf_path: "" } }
}

///|
test "Robot trait - get_sensor_readings" {
  let robot = make_mock_robot()
  let readings = robot.get_sensor_readings()
  assert_eq(readings.length(), 1)
  assert_eq(readings[0].kind, Camera)
}

///|
test "Robot trait - get_model_info" {
  let robot = make_mock_robot()
  let info = robot.get_model_info()
  assert_eq(info.name, "mock")
  assert_eq(info.dof, 1)
}

///|
test "Robot trait - execute_actions success" {
  let robot = make_mock_robot()
  robot.execute_actions([{ joint_commands: [], timestamp: 0.0 }])
}

///|
test "Robot trait - execute_actions failure on empty" {
  let robot = make_mock_robot()
  let empty : Array[ActionCommand] = []
  try robot.execute_actions(empty) catch {
    ActionExecuteError(msg) => assert_eq(msg, "empty commands")
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ActionExecuteError")
  }
}
