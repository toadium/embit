///|
/// embit-core 空间力学白盒测试：验证 Twist 与 Wrench 运算。

///|
/// 浮点近似比较阈值。
let spatial_eps : Double = 0.000001

///|
fn assert_approx2(a : Double, b : Double) -> Unit raise {
  assert_true((a - b).abs() < spatial_eps)
}

// ===== Twist 测试 =====

///|
/// 零 Twist 应所有分量为零。
test "Twist - zero is all zeros" {
  let t = Twist::zero()
  assert_eq(t.vx, 0.0)
  assert_eq(t.vy, 0.0)
  assert_eq(t.vz, 0.0)
  assert_eq(t.wx, 0.0)
  assert_eq(t.wy, 0.0)
  assert_eq(t.wz, 0.0)
}

///|
/// 仅线速度的 Twist 角速度应为零。
test "Twist - linear has zero angular" {
  let t = Twist::linear(1.0, 2.0, 3.0)
  assert_eq(t.vx, 1.0)
  assert_eq(t.vy, 2.0)
  assert_eq(t.vz, 3.0)
  assert_eq(t.wx, 0.0)
  assert_eq(t.wy, 0.0)
  assert_eq(t.wz, 0.0)
}

///|
/// 仅角速度的 Twist 线速度应为零。
test "Twist - angular has zero linear" {
  let t = Twist::angular(0.1, 0.2, 0.3)
  assert_eq(t.vx, 0.0)
  assert_eq(t.vy, 0.0)
  assert_eq(t.vz, 0.0)
  assert_eq(t.wx, 0.1)
  assert_eq(t.wy, 0.2)
  assert_eq(t.wz, 0.3)
}

///|
/// Twist 加法应逐分量相加。
test "Twist - add componentwise" {
  let a = Twist::new(1.0, 2.0, 3.0, 0.1, 0.2, 0.3)
  let b = Twist::new(0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
  let c = a.add(b)
  assert_eq(c.vx, 1.5)
  assert_eq(c.vy, 2.5)
  assert_eq(c.vz, 3.5)
  assert_eq(c.wx, 0.6)
  assert_eq(c.wy, 0.7)
  assert_eq(c.wz, 0.8)
}

///|
/// Twist 标量乘法。
test "Twist - scale" {
  let t = Twist::new(1.0, 2.0, 3.0, 0.0, 0.0, 0.0)
  let s = t.scale(2.0)
  assert_eq(s.vx, 2.0)
  assert_eq(s.vy, 4.0)
  assert_eq(s.vz, 6.0)
}

///|
/// 线速度范数。
test "Twist - linear_norm" {
  let t = Twist::linear(3.0, 4.0, 0.0)
  assert_approx2(t.linear_norm(), 5.0)
}

///|
/// 角速度范数。
test "Twist - angular_norm" {
  let t = Twist::angular(0.0, 0.0, 2.0)
  assert_approx2(t.angular_norm(), 2.0)
}

// ===== Wrench 测试 =====

///|
/// 零 Wrench 应所有分量为零。
test "Wrench - zero is all zeros" {
  let w = Wrench::zero()
  assert_eq(w.fx, 0.0)
  assert_eq(w.fy, 0.0)
  assert_eq(w.fz, 0.0)
  assert_eq(w.tx, 0.0)
  assert_eq(w.ty, 0.0)
  assert_eq(w.tz, 0.0)
}

///|
/// 仅力的 Wrench 力矩应为零。
test "Wrench - force has zero torque" {
  let w = Wrench::force(10.0, 20.0, 30.0)
  assert_eq(w.fx, 10.0)
  assert_eq(w.fy, 20.0)
  assert_eq(w.fz, 30.0)
  assert_eq(w.tx, 0.0)
  assert_eq(w.ty, 0.0)
  assert_eq(w.tz, 0.0)
}

///|
/// 仅力矩的 Wrench 力应为零。
test "Wrench - torque has zero force" {
  let w = Wrench::torque(1.0, 2.0, 3.0)
  assert_eq(w.fx, 0.0)
  assert_eq(w.fy, 0.0)
  assert_eq(w.fz, 0.0)
  assert_eq(w.tx, 1.0)
  assert_eq(w.ty, 2.0)
  assert_eq(w.tz, 3.0)
}

///|
/// Wrench 加法。
test "Wrench - add componentwise" {
  let a = Wrench::force(10.0, 0.0, 0.0)
  let b = Wrench::torque(0.0, 0.0, 5.0)
  let c = a.add(b)
  assert_eq(c.fx, 10.0)
  assert_eq(c.tz, 5.0)
}

///|
/// 力范数。
test "Wrench - force_norm" {
  let w = Wrench::force(3.0, 4.0, 0.0)
  assert_approx2(w.force_norm(), 5.0)
}

///|
/// 力矩范数。
test "Wrench - torque_norm" {
  let w = Wrench::torque(0.0, 0.0, 7.0)
  assert_approx2(w.torque_norm(), 7.0)
}

// ===== 互易积测试 =====

///|
/// Twist 与 Wrench 互易积等于功率。
test "Twist - dot_wrench computes power" {
  // 线速度 (1,0,0) m/s，力 (10,0,0) N → 功率 10 W
  let t = Twist::linear(1.0, 0.0, 0.0)
  let w = Wrench::force(10.0, 0.0, 0.0)
  assert_approx2(t.dot_wrench(w), 10.0)
}

///|
/// 正交的 Twist 与 Wrench 互易积为零。
test "Twist - dot_wrench orthogonal is zero" {
  // 线速度 (1,0,0)，力 (0,1,0) → 功率 0
  let t = Twist::linear(1.0, 0.0, 0.0)
  let w = Wrench::force(0.0, 10.0, 0.0)
  assert_approx2(t.dot_wrench(w), 0.0)
}

///|
/// 角速度与力矩的互易积。
test "Twist - dot_wrench angular torque" {
  // 角速度 (0,0,2) rad/s，力矩 (0,0,5) N·m → 功率 10 W
  let t = Twist::angular(0.0, 0.0, 2.0)
  let w = Wrench::torque(0.0, 0.0, 5.0)
  assert_approx2(t.dot_wrench(w), 10.0)
}

// ===== Wrench 构造与运算覆盖测试 =====

///|
/// Wrench::new 创建带力和力矩的 Wrench。
test "Wrench - new creates with force and torque" {
  let w = Wrench::new(1.0, 2.0, 3.0, 4.0, 5.0, 6.0)
  assert_eq(w.fx, 1.0)
  assert_eq(w.fy, 2.0)
  assert_eq(w.fz, 3.0)
  assert_eq(w.tx, 4.0)
  assert_eq(w.ty, 5.0)
  assert_eq(w.tz, 6.0)
}

///|
/// Wrench::scale 标量乘法。
test "Wrench - scale multiplies all components" {
  let w = Wrench::new(1.0, 2.0, 3.0, 4.0, 5.0, 6.0)
  let s = w.scale(2.0)
  assert_eq(s.fx, 2.0)
  assert_eq(s.fy, 4.0)
  assert_eq(s.fz, 6.0)
  assert_eq(s.tx, 8.0)
  assert_eq(s.ty, 10.0)
  assert_eq(s.tz, 12.0)
}
