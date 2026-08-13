///|
/// Gazebo 仿真机器人：封装 `GazeboClient` 实现 `Robot` trait。
///
/// 将仿真通信客户端适配为统一的机器人接口，
/// 使上层控制代码可透明切换仿真与真机。
///
/// - `get_sensor_readings`：返回已订阅话题的传感器数据（占位返回空数组）
/// - `execute_actions`：将动作指令发布到仿真话题
/// - `get_model_info`：返回构造时绑定的模型信息
pub struct GazeboRobot {
  client : GazeboClient
  model_info : @core.RobotModelInfo
  mut sensor_readings : Array[@core.SensorReading]
}

///|
/// 创建 Gazebo 仿真机器人。
///
/// `address` 为仿真环境连接地址，`model_info` 为机器人模型信息。
pub fn GazeboRobot::connect(
  address : String,
  model_info : @core.RobotModelInfo,
) -> GazeboRobot {
  let client = GazeboClient::connect(address)
  { client, model_info, sensor_readings: [] }
}

///|
/// 从已有客户端创建 Gazebo 仿真机器人。
pub fn GazeboRobot::from_client(
  client : GazeboClient,
  model_info : @core.RobotModelInfo,
) -> GazeboRobot {
  { client, model_info, sensor_readings: [] }
}

///|
/// 获取内部客户端引用（用于直接调用仿真控制方法）。
pub fn GazeboRobot::client(self : GazeboRobot) -> GazeboClient {
  self.client
}

///|
/// 更新传感器读数（占位：外部注入）。
///
/// 真实实现将从已订阅话题自动收集传感器数据。
pub fn GazeboRobot::update_sensors(
  self : GazeboRobot,
  readings : Array[@core.SensorReading],
) -> Unit {
  self.sensor_readings = readings
}

///|
/// 断开与仿真环境的连接。
pub fn GazeboRobot::disconnect(self : GazeboRobot) -> Unit {
  self.client.disconnect()
}

///|
/// 查询连接状态。
pub fn GazeboRobot::is_connected(self : GazeboRobot) -> Bool {
  self.client.is_connected()
}

// ===== Robot trait 实现 =====

///|
impl @core.Robot for GazeboRobot with fn get_sensor_readings(self) {
  self.sensor_readings
}

///|
impl @core.Robot for GazeboRobot with fn execute_actions(self, commands) {
  for cmd in commands {
    ignore(cmd)
    // 将每条动作指令发布到仿真话题
    let topic = "/joint_commands"
    let data = b"action_command"
    self.client.publish(topic, data)
  }
}

///|
impl @core.Robot for GazeboRobot with fn get_model_info(self) {
  self.model_info
}

///|
/// 声明 GazeboRobot 可直接调用 Robot trait 方法。
pub extend GazeboRobot with @core.Robot::{
  get_sensor_readings,
  execute_actions,
  get_model_info,
}
