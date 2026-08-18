///|
/// RealRobot::update_sensors 更新传感器读数。
test "RealRobot - update_sensors" {
  let model = RobotBuilder::arm_6dof()
  let model_info = model.to_info("arm", "1.0")
  let robot = RealRobot::connect("can0", model_info)
  let readings : Array[SensorReading] = [
    { kind: JointEncoder, timestamp: 0.0, data: b"" },
  ]
  robot.update_sensors(readings)
  let result = robot.get_sensor_readings()
  assert_eq(result.length(), 1)
}

///|
/// RealRobot::address 查询通信地址。
test "RealRobot - address query" {
  let model = RobotBuilder::arm_6dof()
  let model_info = model.to_info("arm", "1.0")
  let robot = RealRobot::connect("192.168.1.100:502", model_info)
  assert_eq(robot.address(), "192.168.1.100:502")
}

///|
/// RealRobot::execute_actions 未连接触发 ActionExecuteError。
test "RealRobot - execute_actions not connected" {
  let model = RobotBuilder::arm_6dof()
  let model_info = model.to_info("arm", "1.0")
  let robot = RealRobot::connect("can0", model_info)
  robot.disconnect()
  let commands : Array[ActionCommand] = [
    { joint_commands: [("joint1", 0.1)], timestamp: 0.0 },
  ]
  try robot.execute_actions(commands) catch {
    ActionExecuteError(msg) => assert_true(msg.contains("not connected"))
    _ => fail("expected ActionExecuteError")
  } noraise {
    _ => fail("expected ActionExecuteError")
  }
}
