///|
/// embit-core 配置管理白盒测试。

// ===== LogLevel 测试 =====

///|
/// from_str 应正确解析日志级别名称。
test "LogLevel - from_str parses known levels" {
  assert_eq(LogLevel::from_str("debug"), Debug)
  assert_eq(LogLevel::from_str("info"), Info)
  assert_eq(LogLevel::from_str("warn"), Warn)
  assert_eq(LogLevel::from_str("error"), Error)
}

///|
/// 未知名称应返回 Info。
test "LogLevel - from_str unknown returns Info" {
  assert_eq(LogLevel::from_str("verbose"), Info)
  assert_eq(LogLevel::from_str(""), Info)
}

///|
/// to_str 应与 from_str 互逆。
test "LogLevel - to_str from_str roundtrip" {
  assert_eq(LogLevel::Debug.to_str(), "debug")
  assert_eq(LogLevel::Info.to_str(), "info")
  assert_eq(LogLevel::Warn.to_str(), "warn")
  assert_eq(LogLevel::Error.to_str(), "error")
}

// ===== EmbConfig 测试 =====

///|
/// 默认配置应有正确的默认值。
test "EmbConfig - default values" {
  let cfg = EmbConfig::default()
  assert_eq(cfg.gazebo_address, "localhost:9000")
  assert_eq(cfg.vla_backend, "cpu")
  assert_eq(cfg.model_path, "")
  assert_eq(cfg.log_level, Info)
  assert_eq(cfg.control_frequency, 100.0)
  assert_eq(cfg.safety_check_enabled, true)
}

///|
/// 自定义配置应保留传入值。
test "EmbConfig - new creates custom config" {
  let cfg = EmbConfig::new(
    "192.168.1.100:9000",
    "cuda",
    "models/openvla-13b.gguf",
    Debug,
    200.0,
    false,
  )
  assert_eq(cfg.gazebo_address, "192.168.1.100:9000")
  assert_eq(cfg.vla_backend, "cuda")
  assert_eq(cfg.model_path, "models/openvla-13b.gguf")
  assert_eq(cfg.log_level, Debug)
  assert_eq(cfg.control_frequency, 200.0)
  assert_eq(cfg.safety_check_enabled, false)
}

///|
/// control_period 应为频率的倒数。
test "EmbConfig - control_period is reciprocal of frequency" {
  let cfg = EmbConfig::new("localhost:9000", "cpu", "", Info, 200.0, true)
  assert_true((cfg.control_period() - 0.005).abs() < 0.000001)
}

///|
/// 零频率的 control_period 应为 0。
test "EmbConfig - control_period zero frequency" {
  let cfg = EmbConfig::new("localhost:9000", "cpu", "", Info, 0.0, true)
  assert_eq(cfg.control_period(), 0.0)
}

///|
/// summary 应包含关键配置信息。
test "EmbConfig - summary contains key info" {
  let cfg = EmbConfig::new(
    "localhost:9000",
    "cuda",
    "models/test.gguf",
    Warn,
    50.0,
    true,
  )
  let s = cfg.summary()
  assert_true(s.contains("localhost:9000"))
  assert_true(s.contains("cuda"))
  assert_true(s.contains("models/test.gguf"))
  assert_true(s.contains("warn"))
  assert_true(s.contains("50"))
}
