///|
/// embit-gazebo GazeboRobot 白盒测试。

///|
/// connect 应创建已连接的 GazeboRobot。
test "GazeboRobot - connect creates connected robot" {
  let info = @core.RobotModelInfo::{
    name: "humanoid",
    version: "1.0",
    dof: 12,
    urdf_path: "models/humanoid.urdf",
  }
  let robot = GazeboRobot::connect("localhost:9000", info)
  assert_true(robot.is_connected())
  robot.disconnect()
  assert_false(robot.is_connected())
}

///|
/// get_model_info 应返回构造时绑定的信息。
test "GazeboRobot - get_model_info" {
  let info = @core.RobotModelInfo::{
    name: "quadruped",
    version: "2.0",
    dof: 12,
    urdf_path: "models/quadruped.urdf",
  }
  let robot = GazeboRobot::connect("localhost:9001", info)
  let retrieved = robot.get_model_info()
  assert_eq(retrieved.name, "quadruped")
  assert_eq(retrieved.version, "2.0")
  assert_eq(retrieved.dof, 12)
  robot.disconnect()
}

///|
/// get_sensor_readings 初始应为空。
test "GazeboRobot - get_sensor_readings initial empty" {
  let info = @core.RobotModelInfo::{
    name: "arm",
    version: "1.0",
    dof: 6,
    urdf_path: "",
  }
  let robot = GazeboRobot::connect("localhost:9002", info)
  let readings = robot.get_sensor_readings()
  assert_eq(readings.length(), 0)
  robot.disconnect()
}

///|
/// update_sensors 应注入传感器读数。
test "GazeboRobot - update_sensors injects readings" {
  let info = @core.RobotModelInfo::{
    name: "arm",
    version: "1.0",
    dof: 6,
    urdf_path: "",
  }
  let robot = GazeboRobot::connect("localhost:9003", info)
  let readings : Array[@core.SensorReading] = [
    { kind: Imu, timestamp: 1.0, data: b"imu" },
    { kind: Camera, timestamp: 1.0, data: b"cam" },
  ]
  robot.update_sensors(readings)
  let retrieved = robot.get_sensor_readings()
  assert_eq(retrieved.length(), 2)
  robot.disconnect()
}

///|
/// execute_actions 应通过仿真客户端发布指令。
test "GazeboRobot - execute_actions publishes to sim" {
  let info = @core.RobotModelInfo::{
    name: "arm",
    version: "1.0",
    dof: 6,
    urdf_path: "",
  }
  let robot = GazeboRobot::connect("localhost:9004", info)
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j1", 0.5)], timestamp: 0.1 },
    { joint_commands: [("j1", 1.0)], timestamp: 0.2 },
  ]
  robot.execute_actions(commands)
  // 内部 client 应有 3 次发布
  assert_eq(robot.client().topic_count(), 3)
  robot.disconnect()
}

///|
/// from_client 从已有客户端创建。
test "GazeboRobot - from_client" {
  let client = GazeboClient::connect("localhost:9005")
  let info = @core.RobotModelInfo::{
    name: "test",
    version: "1.0",
    dof: 1,
    urdf_path: "",
  }
  let robot = GazeboRobot::from_client(client, info)
  assert_true(robot.is_connected())
  robot.disconnect()
}
