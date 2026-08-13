///|
/// 机器人关节状态。
///
/// 描述单个关节在某一时刻的运动学状态，是控制环路与状态估计的基本单元。
pub(all) struct JointState {
  name : String
  position : Double // 关节角度（rad）
  velocity : Double // 关节角速度（rad/s）
  effort : Double // 关节力矩（Nm）
} derive(Eq, Debug)

///|
/// 传感器类型枚举。
///
/// `JointEncoder` 表示关节编码器传感器，与结构体 `JointState` 区分命名。
pub(all) enum SensorType {
  Camera // 相机（RGB/RGBD）
  Lidar // 激光雷达
  Imu // 惯性测量单元
  JointEncoder // 关节编码器
} derive(Eq, Debug)

///|
/// 传感器观测数据。
///
/// `data` 为原始字节流，具体格式由 `kind` 决定；
/// 上层模块（如 embit-ggml）负责按传感器类型解码为结构化数据。
pub(all) struct SensorReading {
  kind : SensorType
  timestamp : Double // 采集时间戳（秒）
  data : Bytes // 原始数据字节流
} derive(Eq, Debug)

///|
/// 动作指令。
///
/// `joint_commands` 为目标关节位置映射（关节名 → 目标角度），
/// 控制器按 `timestamp` 顺序执行。
pub(all) struct ActionCommand {
  joint_commands : Array[(String, Double)]
  timestamp : Double
} derive(Eq, Debug)
