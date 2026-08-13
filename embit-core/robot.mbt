///|
/// 机器人抽象接口。
///
/// 所有机型（仿真机器人、真机）需实现此 trait，
/// 提供传感器读取、动作执行与模型信息查询三项核心能力。
///
/// - `get_sensor_readings`：返回当前时刻所有传感器的观测数据
/// - `execute_actions`：执行一批动作指令，失败时抛出 `RobotError`
/// - `get_model_info`：返回机器人模型的运行时元数据
pub(open) trait Robot {
  fn get_sensor_readings(Self) -> Array[SensorReading]
  fn execute_actions(Self, Array[ActionCommand]) -> Unit raise RobotError
  fn get_model_info(Self) -> RobotModelInfo
}
