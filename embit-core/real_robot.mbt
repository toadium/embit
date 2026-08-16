///|
/// 真机硬件抽象层：`RealRobot` 实现 `Robot` trait。
///
/// Phase 4.2 新增：为真机联调提供硬件通信协议适配。
/// `RealRobot` 封装真机关节通信接口，实现 `Robot` trait，
/// 支持传感器读取、动作执行、紧急停止与连接管理。
/// 占位模式下验证逻辑流程；真实模式下通过硬件通信协议（CAN/EtherCAT/Modbus）
/// 与真机交互，由子类提供协议适配。

///|
/// 真机机器人封装。
///
/// 实现 `Robot` trait，提供真机传感器读取与动作执行接口。
/// 占位模式：记录执行指令与传感器读数，用于 Sim2Real 一致性验证。
/// 真实模式：通过硬件通信协议与真机交互。
pub struct RealRobot {
  model_info : RobotModelInfo
  mut connected : Bool // 连接状态
  mut emergency_stopped : Bool // 紧急停止状态
  mut sensor_readings : Array[SensorReading] // 缓存传感器读数
  executed_commands : Array[ActionCommand] // 已执行指令记录
  mut execution_count : Int // 动作执行计数
  address : String // 通信地址
}

///|
/// 连接真机。
///
/// `address` 为硬件通信地址（如 `"can0"` / `"192.168.1.100:502"`）。
/// 占位模式始终连接成功；真实模式通过硬件协议建立连接。
pub fn RealRobot::connect(
  address : String,
  model_info : RobotModelInfo,
) -> RealRobot {
  {
    model_info,
    connected: true,
    emergency_stopped: false,
    sensor_readings: [],
    executed_commands: [],
    execution_count: 0,
    address,
  }
}

///|
/// 查询连接状态。
pub fn RealRobot::is_connected(self : RealRobot) -> Bool {
  self.connected
}

///|
/// 断开真机连接。
pub fn RealRobot::disconnect(self : RealRobot) -> Unit {
  self.connected = false
}

///|
/// 触发紧急停止。
///
/// 停止所有关节运动，拒绝后续动作指令。
pub fn RealRobot::emergency_stop(self : RealRobot) -> Unit {
  self.emergency_stopped = true
}

///|
/// 查询紧急停止状态。
pub fn RealRobot::is_emergency_stopped(self : RealRobot) -> Bool {
  self.emergency_stopped
}

///|
/// 重置紧急停止，恢复正常运行。
pub fn RealRobot::reset_emergency_stop(self : RealRobot) -> Unit {
  self.emergency_stopped = false
}

///|
/// 更新传感器读数。
///
/// 由硬件通信轮询调用，将最新传感器数据推入缓存。
pub fn RealRobot::update_sensors(
  self : RealRobot,
  readings : Array[SensorReading],
) -> Unit {
  self.sensor_readings = readings
}

///|
/// 查询已执行指令记录。
///
/// 用于 Sim2Real 一致性验证：对比仿真与真机执行的指令序列。
pub fn RealRobot::executed_commands(self : RealRobot) -> Array[ActionCommand] {
  self.executed_commands
}

///|
/// 查询动作执行计数。
pub fn RealRobot::execution_count(self : RealRobot) -> Int {
  self.execution_count
}

///|
/// 查询通信地址。
pub fn RealRobot::address(self : RealRobot) -> String {
  self.address
}

// ===== Robot trait 实现 =====

///|
impl Robot for RealRobot with fn get_sensor_readings(self) {
  self.sensor_readings
}

///|
impl Robot for RealRobot with fn execute_actions(self, commands) {
  if !self.connected {
    raise ActionExecuteError("real robot not connected")
  }
  if self.emergency_stopped {
    raise SafetyLimitViolation("emergency stop active, actions rejected")
  }
  for cmd in commands {
    self.executed_commands.push(cmd)
    self.execution_count = self.execution_count + 1
  }
}

///|
impl Robot for RealRobot with fn get_model_info(self) {
  self.model_info
}

///|
/// 声明 RealRobot 可直接调用 Robot trait 方法。
pub extend RealRobot with Robot::{
  get_sensor_readings,
  execute_actions,
  get_model_info,
}
