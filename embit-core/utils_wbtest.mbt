///|
/// embit-core 工具函数白盒测试。

///|
/// 角度弧度互转。
test "utils - deg_to_rad and rad_to_deg" {
  assert_true((deg_to_rad(180.0) - pi).abs() < 0.000001)
  assert_true((rad_to_deg(pi) - 180.0).abs() < 0.000001)
  assert_true((deg_to_rad(90.0) - 1.5707963).abs() < 0.0001)
}

///|
/// 角度归一化到 [-π, π]。
test "utils - normalize_angle" {
  assert_true(normalize_angle(0.0).abs() < 0.000001)
  assert_true((normalize_angle(pi) - pi).abs() < 0.000001)
  assert_true((normalize_angle(-pi) + pi).abs() < 0.000001)
  // 3π → π（减去 2π）
  assert_true((normalize_angle(3.0 * pi) - pi).abs() < 0.000001)
  // -3π → -π（加上 2π）
  assert_true((normalize_angle(-3.0 * pi) + pi).abs() < 0.000001)
}

///|
/// clamp 限制值域。
test "utils - clamp" {
  assert_eq(clamp(5.0, 0.0, 10.0), 5.0)
  assert_eq(clamp(-1.0, 0.0, 10.0), 0.0)
  assert_eq(clamp(15.0, 0.0, 10.0), 10.0)
}

///|
/// 线性插值。
test "utils - lerp" {
  assert_eq(lerp(0.0, 10.0, 0.0), 0.0)
  assert_eq(lerp(0.0, 10.0, 1.0), 10.0)
  assert_eq(lerp(0.0, 10.0, 0.5), 5.0)
}

///|
/// 三次多项式插值：零速起止。
test "utils - cubic_interp" {
  assert_eq(cubic_interp(0.0, 10.0, 0.0), 0.0)
  assert_eq(cubic_interp(0.0, 10.0, 1.0), 10.0)
  // 中点 t=0.5: h = 3*0.25 - 2*0.125 = 0.75 - 0.25 = 0.5
  assert_eq(cubic_interp(0.0, 10.0, 0.5), 5.0)
}

///|
/// 3D 距离计算。
test "utils - distance3d" {
  let d = distance3d(0.0, 0.0, 0.0, 3.0, 4.0, 0.0)
  assert_true((d - 5.0).abs() < 0.000001)
  let d2 = distance3d(1.0, 2.0, 3.0, 1.0, 2.0, 3.0)
  assert_true(d2.abs() < 0.000001)
}

///|
/// 时间单位转换。
test "utils - time conversions" {
  assert_eq(ms_to_sec(1000.0), 1.0)
  assert_eq(sec_to_ms(1.0), 1000.0)
  assert_eq(us_to_sec(1000000.0), 1.0)
  assert_eq(sec_to_us(1.0), 1000000.0)
}

///|
/// 频率周期转换。
test "utils - frequency period conversion" {
  assert_eq(hz_to_period(100.0), 0.01)
  assert_eq(period_to_hz(0.01), 100.0)
  assert_eq(hz_to_period(0.0), 0.0)
  assert_eq(period_to_hz(0.0), 0.0)
}
