///|
/// 日志级别。
pub(all) enum LogLevel {
  Debug
  Info
  Warn
  Error
} derive(Eq, Debug)

///|
pub extend LogLevel with Eq::{not_equal, equal}

///|
pub extend LogLevel with @debug.Debug::{to_repr}

///|
/// Embit 框架全局配置。
///
/// 统一管理各模块的运行参数，可通过环境变量或代码构造。
/// 各字段对应技术文档 §7.3 配置说明中的环境变量。
pub(all) struct EmbConfig {
  gazebo_address : String // 仿真环境连接地址（host:port）
  vla_backend : String // VLA 推理后端（"cpu" / "cuda" / "metal"）
  model_path : String // VLA 模型文件路径（.gguf）
  log_level : LogLevel // 日志级别
  control_frequency : Double // 控制环路频率（Hz）
  safety_check_enabled : Bool // 是否启用安全联锁
}

///|
/// 默认配置。
///
/// - `gazebo_address` = `"localhost:9000"`
/// - `vla_backend` = `"cpu"`
/// - `model_path` = `""`
/// - `log_level` = `Info`
/// - `control_frequency` = `100.0` Hz
/// - `safety_check_enabled` = `true`
pub fn EmbConfig::default() -> EmbConfig {
  {
    gazebo_address: "localhost:9000",
    vla_backend: "cpu",
    model_path: "",
    log_level: Info,
    control_frequency: 100.0,
    safety_check_enabled: true,
  }
}

///|
/// 创建配置。
pub fn EmbConfig::new(
  gazebo_address : String,
  vla_backend : String,
  model_path : String,
  log_level : LogLevel,
  control_frequency : Double,
  safety_check_enabled : Bool,
) -> EmbConfig {
  {
    gazebo_address,
    vla_backend,
    model_path,
    log_level,
    control_frequency,
    safety_check_enabled,
  }
}

///|
/// 从日志级别名称创建 LogLevel。
///
/// `"debug"` → `Debug`，`"info"` → `Info`，`"warn"` → `Warn`，`"error"` → `Error`。
/// 未知名称返回 `Info`。
pub fn LogLevel::from_str(s : String) -> LogLevel {
  match s {
    "debug" => Debug
    "info" => Info
    "warn" => Warn
    "error" => Error
    _ => Info
  }
}

///|
/// 日志级别转字符串。
pub fn LogLevel::to_str(self : LogLevel) -> String {
  match self {
    Debug => "debug"
    Info => "info"
    Warn => "warn"
    Error => "error"
  }
}

///|
/// 控制环路周期（秒）：`1.0 / control_frequency`。
pub fn EmbConfig::control_period(self : EmbConfig) -> Double {
  if self.control_frequency <= 0.0 {
    0.0
  } else {
    1.0 / self.control_frequency
  }
}

///|
/// 配置摘要（用于日志输出）。
pub fn EmbConfig::summary(self : EmbConfig) -> String {
  "EmbitConfig{ gazebo=\{self.gazebo_address}, backend=\{self.vla_backend}, model=\{self.model_path}, log=\{self.log_level.to_str()}, freq=\{self.control_frequency}Hz, safety=\{self.safety_check_enabled} }"
}
