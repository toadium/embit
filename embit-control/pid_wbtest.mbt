///|
/// PIDController 白盒测试：验证控制步进、限幅与抗饱和。

///|
/// 比例控制：输出应正比于误差。
test "PIDController - proportional control" {
  let pid = PIDController::new(2.0, 0.0, 0.0)
  let output = pid.update(1.0, 0.0, 0.1)
  // error = 1.0, output = kp * error = 2.0
  assert_true((output - 2.0).abs() < 0.000001)
}

///|
/// 积分控制：积分项应随时间累积。
test "PIDController - integral control" {
  let pid = PIDController::new(0.0, 1.0, 0.0)
  // 恒定误差 1.0，dt=0.1，两次更新后积分 = 0.1 + 0.1 = 0.2
  ignore(pid.update(1.0, 0.0, 0.1))
  ignore(pid.update(1.0, 0.0, 0.1))
  assert_true((pid.get_integral() - 0.2).abs() < 0.000001)
}

///|
/// 微分控制：基于测量值变化率。
test "PIDController - derivative control" {
  let pid = PIDController::new(0.0, 0.0, 1.0)
  // 第一次更新：derivative = 0（first_update）
  ignore(pid.update(0.0, 0.0, 0.1))
  // 第二次更新：measurement 从 0 变到 0.1，dt=0.1
  // derivative = (0.1 - 0.0) / 0.1 = 1.0
  // output = -kd * derivative = -1.0
  let output = pid.update(0.0, 0.1, 0.1)
  assert_true((output - -1.0).abs() < 0.000001)
}

///|
/// 输出限幅应截断超限输出。
test "PIDController - output limits clamp" {
  let pid = PIDController::new(100.0, 0.0, 0.0)
  pid.set_output_limits(-5.0, 5.0)
  let output = pid.update(1.0, 0.0, 0.1)
  // kp=100, error=1.0, raw output=100.0 → clamped to 5.0
  assert_true((output - 5.0).abs() < 0.000001)
}

///|
/// 积分抗饱和：输出饱和时回退积分项。
test "PIDController - integral anti-windup" {
  let pid = PIDController::new(0.0, 100.0, 0.0)
  pid.set_output_limits(-5.0, 5.0)
  // 恒定误差 1.0，ki=100，dt=0.1
  // 第一次：integral=0.1, output=10.0 → clamped to 5.0, integral 回退到 0
  let output = pid.update(1.0, 0.0, 0.1)
  assert_true((output - 5.0).abs() < 0.000001)
  // 积分项应被回退
  assert_true(pid.get_integral().abs() < 0.000001)
}

///|
/// reset 应清零积分与微分状态。
test "PIDController - reset clears state" {
  let pid = PIDController::new(1.0, 1.0, 1.0)
  ignore(pid.update(1.0, 0.5, 0.1))
  ignore(pid.update(1.0, 0.6, 0.1))
  assert_true(pid.get_integral().abs() > 0.0)
  pid.reset()
  assert_true(pid.get_integral().abs() < 0.000001)
  assert_true(pid.get_error().abs() < 0.000001)
}

///|
/// 增益参数应正确存储。
test "PIDController - gain parameters" {
  let pid = PIDController::new(1.5, 0.5, 0.05)
  assert_eq(pid.get_kp(), 1.5)
  assert_eq(pid.get_ki(), 0.5)
  assert_eq(pid.get_kd(), 0.05)
}

///|
/// 零误差时比例输出为零。
test "PIDController - zero error gives zero proportional output" {
  let pid = PIDController::new(2.0, 0.0, 0.0)
  let output = pid.update(0.5, 0.5, 0.1)
  assert_true(output.abs() < 0.000001)
}
