///|
/// 安全认证：ISO 10218 工业机器人安全标准合规检查。
///
/// Phase 5.3 新增：为安全认证提供 ISO 10218 合规检查工具。
/// `SafetyCertification` 检查关节速度/力矩硬限位、保护停止功能、
/// 碰撞检测等安全要求，生成合规报告。

///|
/// ISO 10218 合规检查项。
pub(all) struct ComplianceCheck {
  name : String // 检查项名称
  passed : Bool // 是否通过
  detail : String // 检查详情
}

///|
/// 安全认证报告。
pub(all) struct CertificationReport {
  standard : String // 标准名称
  checks : Array[ComplianceCheck] // 检查项列表
  overall_passed : Bool // 总体是否通过
}

///|
/// 安全认证检查器。
///
/// 基于 ISO 10218 工业机器人安全标准，
/// 检查速度限制（250 mm/s）、力矩限制、保护停止、碰撞检测等要求。
pub struct SafetyCertification {
  max_speed_limit : Double // ISO 10218 速度限制（m/s，默认 0.25）
  max_force_limit : Double // ISO 10218 力限制（N，默认 150）
  model : @core.RobotModel // 机器人模型
}

///|
/// 创建安全认证检查器。
pub fn SafetyCertification::new(
  model : @core.RobotModel,
) -> SafetyCertification {
  // ISO 10218-1 默认限制
  // 速度限制：250 mm/s = 0.25 m/s（协作机器人模式）
  // 力限制：150 N（协作机器人模式）
  { max_speed_limit: 0.25, max_force_limit: 150.0, model }
}

///|
/// 检查速度限制合规性。
///
/// ISO 10218-1 要求协作机器人末端速度不超过 250 mm/s。
pub fn SafetyCertification::check_speed_limit(
  self : SafetyCertification,
) -> ComplianceCheck {
  let max_vel = self.model.limits.max_joint_velocity
  let passed = max_vel <= self.max_speed_limit
  let detail = if passed {
    "max velocity \{max_vel} m/s within ISO 10218 limit \{self.max_speed_limit} m/s"
  } else {
    "max velocity \{max_vel} m/s exceeds ISO 10218 limit \{self.max_speed_limit} m/s"
  }
  { name: "speed_limit", passed, detail }
}

///|
/// 检查力矩限制合规性。
///
/// ISO 10218-1 要求协作机器人最大静态力不超过 150 N。
pub fn SafetyCertification::check_force_limit(
  self : SafetyCertification,
) -> ComplianceCheck {
  let max_effort = self.model.limits.max_joint_effort
  let passed = max_effort <= self.max_force_limit
  let detail = if passed {
    "max effort \{max_effort} N within ISO 10218 limit \{self.max_force_limit} N"
  } else {
    "max effort \{max_effort} N exceeds ISO 10218 limit \{self.max_force_limit} N"
  }
  { name: "force_limit", passed, detail }
}

///|
/// 检查保护停止功能。
///
/// ISO 10218-1 要求机器人具备保护停止功能（安全联锁 + 紧急停止）。
pub fn SafetyCertification::check_protective_stop(
  self : SafetyCertification,
  has_emergency_stop : Bool,
  has_safety_interlock : Bool,
) -> ComplianceCheck {
  let _ = self.max_speed_limit
  let passed = has_emergency_stop && has_safety_interlock
  let detail = if passed {
    "protective stop: emergency stop + safety interlock both present"
  } else if !has_emergency_stop {
    "protective stop: emergency stop missing"
  } else {
    "protective stop: safety interlock missing"
  }
  { name: "protective_stop", passed, detail }
}

///|
/// 检查碰撞检测功能。
///
/// ISO 10218-1 要求协作机器人具备碰撞检测功能。
pub fn SafetyCertification::check_collision_detection(
  self : SafetyCertification,
  has_collision_detection : Bool,
) -> ComplianceCheck {
  let _ = self.max_force_limit
  let passed = has_collision_detection
  let detail = if passed {
    "collision detection: present"
  } else {
    "collision detection: missing (required for collaborative mode)"
  }
  { name: "collision_detection", passed, detail }
}

///|
/// 检查关节限位合规性。
///
/// ISO 10218-1 要求所有关节具备位置限位（软件+硬件双重保护）。
pub fn SafetyCertification::check_joint_limits(
  self : SafetyCertification,
) -> ComplianceCheck {
  let mut all_limited = true
  let mut count = 0
  for joint in self.model.joints {
    count = count + 1
    if joint.min_position >= joint.max_position {
      all_limited = false
    }
  }
  let passed = all_limited && count > 0
  let detail = if passed {
    "all \{count} joints have valid position limits"
  } else {
    "joint limits incomplete or invalid"
  }
  { name: "joint_limits", passed, detail }
}

///|
/// 生成完整认证报告。
///
/// 执行所有 ISO 10218 合规检查，生成认证报告。
pub fn SafetyCertification::certification_report(
  self : SafetyCertification,
  has_emergency_stop : Bool,
  has_safety_interlock : Bool,
  has_collision_detection : Bool,
) -> CertificationReport {
  let checks : Array[ComplianceCheck] = [
    self.check_speed_limit(),
    self.check_force_limit(),
    self.check_protective_stop(has_emergency_stop, has_safety_interlock),
    self.check_collision_detection(has_collision_detection),
    self.check_joint_limits(),
  ]
  let mut all_passed = true
  for check in checks {
    if !check.passed {
      all_passed = false
    }
  }
  { standard: "ISO 10218-1", checks, overall_passed: all_passed }
}

///|
/// 查询速度限制。
pub fn SafetyCertification::max_speed_limit(
  self : SafetyCertification,
) -> Double {
  self.max_speed_limit
}

///|
/// 查询力限制。
pub fn SafetyCertification::max_force_limit(
  self : SafetyCertification,
) -> Double {
  self.max_force_limit
}
