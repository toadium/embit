///|
/// SafetyController::last_violation 查询方法。
test "SafetyController - last_violation query" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 1.0,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let safety = SafetyController::new(limits, [(0.0, 1.0)])
  assert_eq(safety.last_violation(), "")
  safety.emergency_stop()
  assert_true(safety.last_violation().contains("emergency"))
}

///|
/// check_joint_limits 应检测位置超下限。
test "SafetyController - check_joint_limits below min" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 100.0,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let safety = SafetyController::new(limits, [(0.0, 1.0)])
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("joint1", -1.0)], timestamp: 0.0 },
  ]
  try safety.check_joint_limits(commands) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("below"))
    _ => fail("expected below limit violation")
  } noraise {
    _ => fail("expected below limit violation")
  }
  assert_true(safety.violation_count() > 0)
}

///|
/// check_joint_limits 应检测位置超上限。
test "SafetyController - check_joint_limits above max" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 100.0,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let safety = SafetyController::new(limits, [(0.0, 1.0)])
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("joint1", 2.0)], timestamp: 0.0 },
  ]
  try safety.check_joint_limits(commands) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("above"))
    _ => fail("expected above limit violation")
  } noraise {
    _ => fail("expected above limit violation")
  }
}

///|
/// check_velocity_limits 应在 max_vel <= 0 时早返回。
test "SafetyController - check_velocity_limits zero max_vel" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 0.0,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let safety = SafetyController::new(limits, [])
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j1", 100.0)], timestamp: 0.01 },
  ]
  safety.check_velocity_limits(commands)
  assert_eq(safety.violation_count(), 0)
}

///|
/// check_velocity_limits 应在 dt <= 0 时跳过。
test "SafetyController - check_velocity_limits zero dt" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 1.0,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let safety = SafetyController::new(limits, [])
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 1.0 },
    { joint_commands: [("j1", 100.0)], timestamp: 1.0 },
  ]
  safety.check_velocity_limits(commands)
  assert_eq(safety.violation_count(), 0)
}

///|
/// check_velocity_limits 应在关节不存在时跳过。
test "SafetyController - check_velocity_limits joint not found" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 1.0,
    max_joint_effort: 100.0,
    collision_check_distance: 0.01,
  }
  let safety = SafetyController::new(limits, [])
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j2", 100.0)], timestamp: 0.01 },
  ]
  safety.check_velocity_limits(commands)
  assert_eq(safety.violation_count(), 0)
}

///|
/// check_effort_limits 应在 max_effort <= 0 时早返回。
test "SafetyController - check_effort_limits zero max_effort" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 100.0,
    max_joint_effort: 0.0,
    collision_check_distance: 0.01,
  }
  let safety = SafetyController::new(limits, [])
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j1", 1.0)], timestamp: 0.01 },
    { joint_commands: [("j1", 100.0)], timestamp: 0.02 },
  ]
  safety.check_effort_limits(commands)
  assert_eq(safety.violation_count(), 0)
}

///|
/// check_effort_limits 应在 dt <= 0 时跳过。
test "SafetyController - check_effort_limits zero dt" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 100.0,
    max_joint_effort: 1.0,
    collision_check_distance: 0.01,
  }
  let safety = SafetyController::new(limits, [])
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j1", 1.0)], timestamp: 1.0 },
    { joint_commands: [("j1", 100.0)], timestamp: 1.0 },
  ]
  safety.check_effort_limits(commands)
  assert_eq(safety.violation_count(), 0)
}

///|
/// check_effort_limits 应检测加速度超限。
test "SafetyController - check_effort_limits acceleration exceeds" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 100.0,
    max_joint_effort: 1.0,
    collision_check_distance: 0.01,
  }
  let safety = SafetyController::new(limits, [])
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j1", 0.0)], timestamp: 0.01 },
    { joint_commands: [("j1", 100.0)], timestamp: 0.02 },
  ]
  try safety.check_effort_limits(commands) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("effort"))
    _ => fail("expected effort violation")
  } noraise {
    _ => fail("expected effort violation")
  }
}

///|
/// check_effort_limits 应在关节不存在时跳过。
test "SafetyController - check_effort_limits joint not found" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 100.0,
    max_joint_effort: 1.0,
    collision_check_distance: 0.01,
  }
  let safety = SafetyController::new(limits, [])
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j1", 0.0)], timestamp: 0.01 },
    { joint_commands: [("j2", 100.0)], timestamp: 0.02 },
  ]
  safety.check_effort_limits(commands)
  assert_eq(safety.violation_count(), 0)
}

///|
/// check_collision 应在负碰撞距离时触发错误。
test "SafetyController - check_collision negative distance" {
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 100.0,
    max_joint_effort: 100.0,
    collision_check_distance: -1.0,
  }
  let safety = SafetyController::new(limits, [])
  let commands : Array[@core.ActionCommand] = []
  try safety.check_collision(commands) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("non-negative"))
    _ => fail("expected collision distance violation")
  } noraise {
    _ => fail("expected collision distance violation")
  }
}
