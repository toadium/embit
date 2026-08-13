///|
/// 角度与时间转换工具函数。
///
/// 提供机器人控制中常用的数学工具，避免各模块重复实现。

///|
/// 圆周率。
pub let pi : Double = 3.14159265358979323846

///|
/// 两倍圆周率。
pub let two_pi : Double = 6.28318530717958647692

///|
/// 角度转弧度。
pub fn deg_to_rad(deg : Double) -> Double {
  deg * pi / 180.0
}

///|
/// 弧度转角度。
pub fn rad_to_deg(rad : Double) -> Double {
  rad * 180.0 / pi
}

///|
/// 将角度归一化到 `[-π, π]` 区间。
pub fn normalize_angle(rad : Double) -> Double {
  let mut result = rad
  while result > pi {
    result = result - two_pi
  }
  while result < -pi {
    result = result + two_pi
  }
  result
}

///|
/// 将值限制在 `[min, max]` 区间内。
pub fn clamp(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
/// 线性插值：`a + (b - a) * t`。
///
/// `t = 0` 返回 `a`，`t = 1` 返回 `b`。
pub fn lerp(a : Double, b : Double, t : Double) -> Double {
  a + (b - a) * t
}

///|
/// 三次多项式插值（Hermite 样条）：零速起止。
///
/// `t = 0` 返回 `a`，`t = 1` 返回 `b`，起止速度为零。
pub fn cubic_interp(a : Double, b : Double, t : Double) -> Double {
  // h(t) = 3t² - 2t³
  let h = 3.0 * t * t - 2.0 * t * t * t
  a + (b - a) * h
}

///|
/// 计算两点间欧氏距离（3D）。
pub fn distance3d(
  x1 : Double,
  y1 : Double,
  z1 : Double,
  x2 : Double,
  y2 : Double,
  z2 : Double,
) -> Double {
  let dx = x2 - x1
  let dy = y2 - y1
  let dz = z2 - z1
  (dx * dx + dy * dy + dz * dz).sqrt()
}

///|
/// 毫秒转秒。
pub fn ms_to_sec(ms : Double) -> Double {
  ms / 1000.0
}

///|
/// 秒转毫秒。
pub fn sec_to_ms(sec : Double) -> Double {
  sec * 1000.0
}

///|
/// 微秒转秒。
pub fn us_to_sec(us : Double) -> Double {
  us / 1000000.0
}

///|
/// 秒转微秒。
pub fn sec_to_us(sec : Double) -> Double {
  sec * 1000000.0
}

///|
/// 频率转周期（Hz → 秒）。
pub fn hz_to_period(hz : Double) -> Double {
  if hz == 0.0 {
    0.0
  } else {
    1.0 / hz
  }
}

///|
/// 周期转频率（秒 → Hz）。
pub fn period_to_hz(period : Double) -> Double {
  if period == 0.0 {
    0.0
  } else {
    1.0 / period
  }
}
