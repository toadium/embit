///|
/// Gazebo 仿真机器人：封装 `GazeboClient` 实现 `Robot` trait。
///
/// 将仿真通信客户端适配为统一的机器人接口，
/// 使上层控制代码可透明切换仿真与真机。
///
/// - `register_sensor`：注册传感器话题并订阅
/// - `poll_sensors`：从已注册话题轮询传感器数据
/// - `get_sensor_readings`：返回最新传感器读数
/// - `execute_actions`：将动作指令发布到仿真话题
/// - `get_model_info`：返回构造时绑定的模型信息
pub struct GazeboRobot {
  client : GazeboClient
  model_info : @core.RobotModelInfo
  mut sensor_readings : Array[@core.SensorReading]
  sensor_subscriptions : Array[(String, @core.SensorType)] // (话题名, 传感器类型)
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
  { client, model_info, sensor_readings: [], sensor_subscriptions: [] }
}

///|
/// 从已有客户端创建 Gazebo 仿真机器人。
pub fn GazeboRobot::from_client(
  client : GazeboClient,
  model_info : @core.RobotModelInfo,
) -> GazeboRobot {
  { client, model_info, sensor_readings: [], sensor_subscriptions: [] }
}

///|
/// 获取内部客户端引用（用于直接调用仿真控制方法）。
pub fn GazeboRobot::client(self : GazeboRobot) -> GazeboClient {
  self.client
}

///|
/// 注册传感器话题并订阅。
///
/// `topic` 为仿真话题名（如 `/imu`、`/camera`），`kind` 为传感器类型。
/// 注册后可通过 `poll_sensors` 轮询采集数据。
pub fn GazeboRobot::register_sensor(
  self : GazeboRobot,
  topic : String,
  kind : @core.SensorType,
) -> Unit raise @core.RobotError {
  self.client.subscribe(topic)
  self.sensor_subscriptions.push((topic, kind))
}

///|
/// 轮询已注册传感器话题，生成最新读数。
///
/// `timestamp` 为当前采集时间戳。由于 C stub 为功能化占位，
/// 生成的 `data` 为话题名的字节编码，真实实现将从 Ignition Transport 回调读取。
pub fn GazeboRobot::poll_sensors(
  self : GazeboRobot,
  timestamp : Double,
) -> Unit {
  let readings : Array[@core.SensorReading] = []
  for i in 0..<self.sensor_subscriptions.length() {
    let (topic, kind) = self.sensor_subscriptions[i]
    readings.push({ kind, timestamp, data: @utf8.encode(topic) })
  }
  self.sensor_readings = readings
}

///|
/// 直接注入传感器读数（用于测试或外部数据源）。
pub fn GazeboRobot::update_sensors(
  self : GazeboRobot,
  readings : Array[@core.SensorReading],
) -> Unit {
  self.sensor_readings = readings
}

///|
/// 查询已注册传感器话题数量。
pub fn GazeboRobot::sensor_count(self : GazeboRobot) -> Int {
  self.sensor_subscriptions.length()
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
