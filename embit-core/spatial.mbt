///|
/// 空间速度（Twist）：刚体运动的线速度与角速度组合。
///
/// `vx` / `vy` / `vz` 为线速度分量（m/s），
/// `wx` / `wy` / `wz` 为角速度分量（rad/s）。
/// 在机器人学中，Twist 描述刚体在 SE(3) 上的瞬时运动。
pub(all) struct Twist {
  vx : Double
  vy : Double
  vz : Double
  wx : Double
  wy : Double
  wz : Double
} derive(Eq, Debug)

///|
pub extend Twist with Eq::{not_equal, equal}

///|
pub extend Twist with @debug.Debug::{to_repr}

///|
/// 零 Twist（静止）。
pub fn Twist::zero() -> Twist {
  { vx: 0.0, vy: 0.0, vz: 0.0, wx: 0.0, wy: 0.0, wz: 0.0 }
}

///|
/// 从线速度和角速度创建 Twist。
pub fn Twist::new(
  vx : Double,
  vy : Double,
  vz : Double,
  wx : Double,
  wy : Double,
  wz : Double,
) -> Twist {
  { vx, vy, vz, wx, wy, wz }
}

///|
/// 仅线速度（无旋转）。
pub fn Twist::linear(vx : Double, vy : Double, vz : Double) -> Twist {
  { vx, vy, vz, wx: 0.0, wy: 0.0, wz: 0.0 }
}

///|
/// 仅角速度（无平移）。
pub fn Twist::angular(wx : Double, wy : Double, wz : Double) -> Twist {
  { vx: 0.0, vy: 0.0, vz: 0.0, wx, wy, wz }
}

///|
/// Twist 加法。
pub fn Twist::add(self : Twist, other : Twist) -> Twist {
  {
    vx: self.vx + other.vx,
    vy: self.vy + other.vy,
    vz: self.vz + other.vz,
    wx: self.wx + other.wx,
    wy: self.wy + other.wy,
    wz: self.wz + other.wz,
  }
}

///|
/// Twist 标量乘法。
pub fn Twist::scale(self : Twist, s : Double) -> Twist {
  {
    vx: self.vx * s,
    vy: self.vy * s,
    vz: self.vz * s,
    wx: self.wx * s,
    wy: self.wy * s,
    wz: self.wz * s,
  }
}

///|
/// 线速度范数（m/s）。
pub fn Twist::linear_norm(self : Twist) -> Double {
  (self.vx * self.vx + self.vy * self.vy + self.vz * self.vz).sqrt()
}

///|
/// 角速度范数（rad/s）。
pub fn Twist::angular_norm(self : Twist) -> Double {
  (self.wx * self.wx + self.wy * self.wy + self.wz * self.wz).sqrt()
}

///|
/// 空间力旋量（Wrench）：力与力矩组合。
///
/// `fx` / `fy` / `fz` 为力分量（N），
/// `tx` / `ty` / `tz` 为力矩分量（N·m）。
/// Wrench 是 Twist 的对偶量，二者内积为功率（W）。
pub(all) struct Wrench {
  fx : Double
  fy : Double
  fz : Double
  tx : Double
  ty : Double
  tz : Double
} derive(Eq, Debug)

///|
pub extend Wrench with Eq::{not_equal, equal}

///|
pub extend Wrench with @debug.Debug::{to_repr}

///|
/// 零 Wrench（无力作用）。
pub fn Wrench::zero() -> Wrench {
  { fx: 0.0, fy: 0.0, fz: 0.0, tx: 0.0, ty: 0.0, tz: 0.0 }
}

///|
/// 从力和力矩创建 Wrench。
pub fn Wrench::new(
  fx : Double,
  fy : Double,
  fz : Double,
  tx : Double,
  ty : Double,
  tz : Double,
) -> Wrench {
  { fx, fy, fz, tx, ty, tz }
}

///|
/// 仅力（无力矩）。
pub fn Wrench::force(fx : Double, fy : Double, fz : Double) -> Wrench {
  { fx, fy, fz, tx: 0.0, ty: 0.0, tz: 0.0 }
}

///|
/// 仅力矩（无力）。
pub fn Wrench::torque(tx : Double, ty : Double, tz : Double) -> Wrench {
  { fx: 0.0, fy: 0.0, fz: 0.0, tx, ty, tz }
}

///|
/// Wrench 加法。
pub fn Wrench::add(self : Wrench, other : Wrench) -> Wrench {
  {
    fx: self.fx + other.fx,
    fy: self.fy + other.fy,
    fz: self.fz + other.fz,
    tx: self.tx + other.tx,
    ty: self.ty + other.ty,
    tz: self.tz + other.tz,
  }
}

///|
/// Wrench 标量乘法。
pub fn Wrench::scale(self : Wrench, s : Double) -> Wrench {
  {
    fx: self.fx * s,
    fy: self.fy * s,
    fz: self.fz * s,
    tx: self.tx * s,
    ty: self.ty * s,
    tz: self.tz * s,
  }
}

///|
/// 力范数（N）。
pub fn Wrench::force_norm(self : Wrench) -> Double {
  (self.fx * self.fx + self.fy * self.fy + self.fz * self.fz).sqrt()
}

///|
/// 力矩范数（N·m）。
pub fn Wrench::torque_norm(self : Wrench) -> Double {
  (self.tx * self.tx + self.ty * self.ty + self.tz * self.tz).sqrt()
}

///|
/// 互易积（reciprocal product）：Twint 与 Wrench 的内积，等于瞬时功率（W）。
///
/// `power = f·v + τ·ω`
pub fn Twist::dot_wrench(self : Twist, w : Wrench) -> Double {
  self.vx * w.fx +
  self.vy * w.fy +
  self.vz * w.fz +
  self.wx * w.tx +
  self.wy * w.ty +
  self.wz * w.tz
}
