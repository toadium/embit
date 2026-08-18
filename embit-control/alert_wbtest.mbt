///|
/// AlertSystem::check_joint_velocity 应检测 Error 级别告警。
test "AlertSystem - check_joint_velocity Error level" {
  let alert_system = AlertSystem::new(2.0, 0.1, 0.1)
  // 速度在 1.5x-2x 之间触发 Error
  alert_system.check_joint_velocity("j1", 3.5, 0.0)
  assert_eq(alert_system.alert_count(), 1)
  let alerts = alert_system.alerts()
  assert_true(alerts[0].level == Error)
}

///|
/// AlertSystem::check_communication 应检测多级告警。
test "AlertSystem - check_communication multi-level" {
  let alert_system = AlertSystem::new(2.0, 0.1, 0.1)
  // Warning: 0.1-0.2s 之间
  alert_system.check_communication(0.15, 0.0)
  // Error: 0.2-0.5s 之间
  alert_system.check_communication(0.3, 0.1)
  // Critical: > 0.5s
  alert_system.check_communication(0.6, 0.2)
  assert_eq(alert_system.alert_count(), 3)
  assert_eq(alert_system.critical_count(), 1)
}

///|
/// AlertSystem::check_inference 应检测 Error 级别告警。
test "AlertSystem - check_inference Error level" {
  let alert_system = AlertSystem::new(2.0, 0.1, 0.1)
  // 推理延迟 > 3x 阈值触发 Error
  alert_system.check_inference(0.5, 0.0)
  assert_eq(alert_system.alert_count(), 1)
  let alerts = alert_system.alerts()
  assert_true(alerts[0].level == Error)
}

///|
/// AlertSystem::alerts 查询方法。
test "AlertSystem - alerts query" {
  let alert_system = AlertSystem::new(2.0, 0.1, 0.1)
  assert_eq(alert_system.alerts().length(), 0)
  alert_system.check_joint_velocity("j1", 3.0, 0.0)
  assert_eq(alert_system.alerts().length(), 1)
}

///|
/// AlertSystem::clear 清除所有告警。
test "AlertSystem - clear alerts" {
  let alert_system = AlertSystem::new(2.0, 0.1, 0.1)
  alert_system.check_joint_velocity("j1", 3.0, 0.0)
  assert_true(alert_system.alert_count() > 0)
  alert_system.clear()
  assert_eq(alert_system.alerts().length(), 0)
}
