///|
/// SafetyCertification::check_speed_limit 合规与不合规。
test "SafetyCertification - check_speed_limit pass and fail" {
  // 合规：速度 <= 0.25
  let limits_ok = @core.SafetyLimits::{
    max_joint_velocity: 0.2,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let model_ok = @core.RobotModel::{
    urdf_path: "",
    joints: [],
    sensors: [],
    limits: limits_ok,
  }
  let cert_ok = SafetyCertification::new(model_ok)
  let check_ok = cert_ok.check_speed_limit()
  assert_true(check_ok.passed)
  // 不合规：速度 > 0.25
  let limits_bad = @core.SafetyLimits::{
    max_joint_velocity: 1.0,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let model_bad = @core.RobotModel::{
    urdf_path: "",
    joints: [],
    sensors: [],
    limits: limits_bad,
  }
  let cert_bad = SafetyCertification::new(model_bad)
  let check_bad = cert_bad.check_speed_limit()
  assert_false(check_bad.passed)
}

///|
/// SafetyCertification::check_force_limit 合规与不合规。
test "SafetyCertification - check_force_limit pass and fail" {
  // 合规：力矩 <= 150
  let limits_ok = @core.SafetyLimits::{
    max_joint_velocity: 0.2,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let model_ok = @core.RobotModel::{
    urdf_path: "",
    joints: [],
    sensors: [],
    limits: limits_ok,
  }
  let cert_ok = SafetyCertification::new(model_ok)
  let check_ok = cert_ok.check_force_limit()
  assert_true(check_ok.passed)
  // 不合规：力矩 > 150
  let limits_bad = @core.SafetyLimits::{
    max_joint_velocity: 0.2,
    max_joint_effort: 200.0,
    collision_check_distance: 0.01,
  }
  let model_bad = @core.RobotModel::{
    urdf_path: "",
    joints: [],
    sensors: [],
    limits: limits_bad,
  }
  let cert_bad = SafetyCertification::new(model_bad)
  let check_bad = cert_bad.check_force_limit()
  assert_false(check_bad.passed)
}

///|
/// SafetyCertification::check_protective_stop 缺失紧急停止/安全联锁。
test "SafetyCertification - check_protective_stop missing" {
  let model = @core.RobotBuilder::arm_6dof()
  let cert = SafetyCertification::new(model)
  // 缺失紧急停止
  let check_no_estop = cert.check_protective_stop(false, true)
  assert_false(check_no_estop.passed)
  // 缺失安全联锁
  let check_no_interlock = cert.check_protective_stop(true, false)
  assert_false(check_no_interlock.passed)
}

///|
/// SafetyCertification::check_collision_detection 缺失碰撞检测。
test "SafetyCertification - check_collision_detection missing" {
  let model = @core.RobotBuilder::arm_6dof()
  let cert = SafetyCertification::new(model)
  let check = cert.check_collision_detection(false)
  assert_false(check.passed)
}

///|
/// SafetyCertification::check_joint_limits 关节限位无效。
test "SafetyCertification - check_joint_limits invalid" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 0.2,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  // min >= max 导致限位无效
  let joint = @core.JointSpec::{
    name: "j1",
    joint_type: Revolute,
    min_position: 1.0,
    max_position: 0.0,
    max_velocity: 1.0,
    max_effort: 10.0,
  }
  let model = @core.RobotModel::{
    urdf_path: "",
    joints: [joint],
    sensors: [],
    limits,
  }
  let cert = SafetyCertification::new(model)
  let check = cert.check_joint_limits()
  assert_false(check.passed)
}

///|
/// SafetyCertification 查询方法。
test "SafetyCertification - query methods" {
  let model = @core.RobotBuilder::arm_6dof()
  let cert = SafetyCertification::new(model)
  assert_eq(cert.max_speed_limit(), 0.25)
  assert_eq(cert.max_force_limit(), 150.0)
}
