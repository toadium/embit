///|
/// 异常告警系统：多级告警 + 阈值监控 + 告警历史。
///
/// Phase 5.2 新增：为监控告警提供多级告警机制。
/// `AlertSystem` 监控关节超限、通信超时、推理失败等异常，
/// 生成 Info/Warning/Error/Critical 四级告警，支持告警历史查询与清除。

///|
/// 告警级别。
pub(all) enum AlertLevel {
  Info // 信息
  Warning // 警告
  Error // 错误
  Critical // 严重
} derive(Eq, Debug)

///|
pub extend AlertLevel with Eq::{not_equal, equal}

///|
pub extend AlertLevel with @debug.Debug::{to_repr}

///|
/// 告警记录。
pub(all) struct Alert {
  level : AlertLevel
  message : String
  timestamp : Double
  source : String // 告警源（如 "joint_limit" / "communication" / "inference"）
}

///|
/// 告警系统。
///
/// 持有告警历史与监控阈值，提供关节超限、通信超时、推理失败检测。
pub struct AlertSystem {
  mut alerts : Array[Alert] // 告警历史
  mut alert_count : Int // 告警总数
  joint_velocity_threshold : Double // 关节速度告警阈值
  communication_timeout_threshold : Double // 通信超时阈值（秒）
  inference_latency_threshold : Double // 推理延迟阈值（秒）
}

///|
/// 创建告警系统。
pub fn AlertSystem::new(
  joint_velocity_threshold : Double,
  communication_timeout_threshold : Double,
  inference_latency_threshold : Double,
) -> AlertSystem {
  {
    alerts: [],
    alert_count: 0,
    joint_velocity_threshold,
    communication_timeout_threshold,
    inference_latency_threshold,
  }
}

///|
/// 创建默认告警系统。
pub fn AlertSystem::default() -> AlertSystem {
  AlertSystem::new(2.0, 0.1, 0.1)
}

///|
/// 添加告警。
pub fn AlertSystem::add_alert(
  self : AlertSystem,
  level : AlertLevel,
  source : String,
  message : String,
  timestamp : Double,
) -> Unit {
  self.alerts.push({ level, message, timestamp, source })
  self.alert_count = self.alert_count + 1
}

///|
/// 检查关节速度超限告警。
pub fn AlertSystem::check_joint_velocity(
  self : AlertSystem,
  joint_name : String,
  velocity : Double,
  timestamp : Double,
) -> Unit {
  if velocity.abs() > self.joint_velocity_threshold {
    let level = if velocity.abs() > self.joint_velocity_threshold * 2.0 {
      Critical
    } else if velocity.abs() > self.joint_velocity_threshold * 1.5 {
      Error
    } else {
      Warning
    }
    self.add_alert(
      level,
      "joint_limit",
      "joint \{joint_name} velocity \{velocity} exceeds threshold \{self.joint_velocity_threshold}",
      timestamp,
    )
  }
}

///|
/// 检查通信超时告警。
pub fn AlertSystem::check_communication(
  self : AlertSystem,
  latency : Double,
  timestamp : Double,
) -> Unit {
  if latency > self.communication_timeout_threshold {
    let level = if latency > self.communication_timeout_threshold * 5.0 {
      Critical
    } else if latency > self.communication_timeout_threshold * 2.0 {
      Error
    } else {
      Warning
    }
    self.add_alert(
      level,
      "communication",
      "communication latency \{latency}s exceeds timeout \{self.communication_timeout_threshold}s",
      timestamp,
    )
  }
}

///|
/// 检查推理延迟告警。
pub fn AlertSystem::check_inference(
  self : AlertSystem,
  latency : Double,
  timestamp : Double,
) -> Unit {
  if latency > self.inference_latency_threshold {
    let level = if latency > self.inference_latency_threshold * 3.0 {
      Error
    } else {
      Warning
    }
    self.add_alert(
      level,
      "inference",
      "inference latency \{latency}s exceeds threshold \{self.inference_latency_threshold}s",
      timestamp,
    )
  }
}

///|
/// 查询所有告警。
pub fn AlertSystem::alerts(self : AlertSystem) -> Array[Alert] {
  self.alerts
}

///|
/// 查询告警总数。
pub fn AlertSystem::alert_count(self : AlertSystem) -> Int {
  self.alert_count
}

///|
/// 查询 Critical 级别告警数。
pub fn AlertSystem::critical_count(self : AlertSystem) -> Int {
  let mut count = 0
  for alert in self.alerts {
    if alert.level == Critical {
      count = count + 1
    }
  }
  count
}

///|
/// 清除所有告警。
pub fn AlertSystem::clear(self : AlertSystem) -> Unit {
  self.alerts = []
}
