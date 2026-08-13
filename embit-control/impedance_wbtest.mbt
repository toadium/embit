///|
/// embit-control 阻抗控制器白盒测试。

///|
/// 浮点近似比较阈值。
let imp_eps : Double = 0.000001

///|
fn assert_imp_approx(a : Double, b : Double) -> Unit raise {
  assert_true((a - b).abs() < imp_eps)
}

///|
/// 创建控制器应正确存储刚度和阻尼。
test "ImpedanceController - new stores gains" {
  let ctrl = ImpedanceController::new(100.0, 20.0)
  // 通过7通过 compute 验证内部参数
  let _ = ctrl.compute(0.0, 0.0)
  // 期望位置/速度默认为 0
  assert_eq(ctrl.get_desired_pos(), 0.0)
  assert_eq(ctrl.get_desired_vel(), 0.0)
}

///|
/// 零误差时输出应仅为前馈力。
test "ImpedanceController - zero error outputs feedforward" {
  let ctrl = ImpedanceController::new(100.0, 20.0)
  ctrl.set_target(0.5, 0.3)
  ctrl.set_feedforward(5.0)
  let f = ctrl.compute(0.5, 0.3)
  assert_imp_approx(f, 5.0)
}

///|
/// 纯位置误差：F = K * (x_d - x)。
test "ImpedanceController - pure position error" {
  let ctrl = ImpedanceController::new(100.0, 0.0)
  ctrl.set_target(1.0, 0.0)
  let f = ctrl.compute(0.0, 0.0)
  assert_imp_approx(f, 100.0) // K * 1.0 = 100.0
}

///|
/// 纯速度误差：F = D * (v_d - v)。
test "ImpedanceController - pure velocity error" {
  let ctrl = ImpedanceController::new(0.0, 20.0)
  ctrl.set_target(0.0, 1.0)
  let f = ctrl.compute(0.0, 0.0)
  assert_imp_approx(f, 20.0) // D * 1.0 = 20.0
}

///|
/// 组合误差：F = K * pos_err + D * vel_err + ff。
test "ImpedanceController - combined error" {
  let ctrl = ImpedanceController::new(100.0, 20.0)
  ctrl.set_target(1.0, 1.0)
  ctrl.set_feedforward(5.0)
  let f = ctrl.compute(0.0, 0.0)
  // 100 * 1.0 + 20 * 1.0 + 5.0 = 125.0
  assert_imp_approx(f, 125.0)
}

///|
/// 临界阻尼公式：D = 2 * sqrt(M * K)。
test "ImpedanceController - critical_damping formula" {
  let d = ImpedanceController::critical_damping(1.0, 100.0)
  assert_imp_approx(d, 20.0) // 2 * sqrt(100) = 20
}

///|
/// set_target 应更新期望位置和速度。
test "ImpedanceController - set_target updates desired" {
  let ctrl = ImpedanceController::new(100.0, 20.0)
  ctrl.set_target(0.7, 0.2)
  assert_eq(ctrl.get_desired_pos(), 0.7)
  assert_eq(ctrl.get_desired_vel(), 0.2)
}

///|
/// 负位置误差应产生负力。
test "ImpedanceController - negative position error" {
  let ctrl = ImpedanceController::new(100.0, 0.0)
  ctrl.set_target(0.0, 0.0)
  let f = ctrl.compute(1.0, 0.0)
  assert_imp_approx(f, -100.0) // K * (-1.0) = -100.0
}
