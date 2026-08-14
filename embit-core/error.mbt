///|
/// 机器人操作错误类型。
///
/// 所有上层模块（仿真通信、推理、控制）的失败均映射为此错误的某个变体，
/// 通过 MoonBit checked error 机制在调用链中传播。
pub(all) suberror RobotError {
  /// 连接仿真环境或真机失败
  ConnectError(String)
  /// 传感器数据读取失败
  SensorReadError(String)
  /// 动作指令执行失败
  ActionExecuteError(String)
  /// 模型文件加载或解析失败
  ModelLoadError(String)
  /// 关节状态超出安全限制（速度/力矩/位置越界）
  SafetyLimitViolation(String)
  /// 不支持的机器人机型或配置
  UnsupportedRobotType(String)
  /// 参数配置无效（形状不匹配、值超出范围等）
  InvalidConfig(String)
} derive(Eq, Debug)

///|
pub extend RobotError with Eq::{not_equal, equal}

///|
pub extend RobotError with @debug.Debug::{to_repr}
