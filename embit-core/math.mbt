///|
/// 四元数：机器人姿态表示与旋转运算。
///
/// `w` 为标量分量，`x` / `y` / `z` 为矢量分量。
/// 单位四元数（|q| = 1）表示 SO(3) 旋转。
pub(all) struct Quaternion {
  w : Double
  x : Double
  y : Double
  z : Double
} derive(Eq, Debug)

///|
pub extend Quaternion with Eq::{not_equal, equal}

///|
pub extend Quaternion with @debug.Debug::{to_repr}

///|
/// 单位四元数（无旋转）。
pub fn Quaternion::identity() -> Quaternion {
  { w: 1.0, x: 0.0, y: 0.0, z: 0.0 }
}

///|
/// 从欧拉角（roll, pitch, yaw，弧度）创建四元数。
pub fn Quaternion::from_euler(
  roll : Double,
  pitch : Double,
  yaw : Double,
) -> Quaternion {
  let cr = @math.cos(roll * 0.5)
  let sr = @math.sin(roll * 0.5)
  let cp = @math.cos(pitch * 0.5)
  let sp = @math.sin(pitch * 0.5)
  let cy = @math.cos(yaw * 0.5)
  let sy = @math.sin(yaw * 0.5)
  {
    w: cr * cp * cy + sr * sp * sy,
    x: sr * cp * cy - cr * sp * sy,
    y: cr * sp * cy + sr * cp * sy,
    z: cr * cp * sy - sr * sp * cy,
  }
}

///|
/// 转换为欧拉角（roll, pitch, yaw，弧度）。
pub fn Quaternion::to_euler(self : Quaternion) -> (Double, Double, Double) {
  // roll (x-axis rotation)
  let sinr_cosp = 2.0 * (self.w * self.x + self.y * self.z)
  let cosr_cosp = 1.0 - 2.0 * (self.x * self.x + self.y * self.y)
  let roll = @math.atan2(sinr_cosp, cosr_cosp)
  // pitch (y-axis rotation)
  let sinp = 2.0 * (self.w * self.y - self.z * self.x)
  let pitch = if sinp.abs() >= 1.0 {
    sinp.signum() * pi * 0.5 // 万向锁，取 ±90°
  } else {
    @math.asin(sinp)
  }
  // yaw (z-axis rotation)
  let siny_cosp = 2.0 * (self.w * self.z + self.x * self.y)
  let cosy_cosp = 1.0 - 2.0 * (self.y * self.y + self.z * self.z)
  let yaw = @math.atan2(siny_cosp, cosy_cosp)
  (roll, pitch, yaw)
}

///|
/// 四元数乘法（旋转复合）。
pub fn Quaternion::mul(self : Quaternion, other : Quaternion) -> Quaternion {
  {
    w: self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z,
    x: self.w * other.x + self.x * other.w + self.y * other.z - self.z * other.y,
    y: self.w * other.y - self.x * other.z + self.y * other.w + self.z * other.x,
    z: self.w * other.z + self.x * other.y - self.y * other.x + self.z * other.w,
  }
}

///|
/// 共轭四元数（逆旋转，对单位四元数等同于逆）。
pub fn Quaternion::conjugate(self : Quaternion) -> Quaternion {
  { w: self.w, x: -self.x, y: -self.y, z: -self.z }
}

///|
/// 模（范数）。
pub fn Quaternion::norm(self : Quaternion) -> Double {
  (self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z).sqrt()
}

///|
/// 归一化为单位四元数。
pub fn Quaternion::normalize(self : Quaternion) -> Quaternion {
  let n = self.norm()
  if n == 0.0 {
    Quaternion::identity()
  } else {
    { w: self.w / n, x: self.x / n, y: self.y / n, z: self.z / n }
  }
}

///|
/// 旋转点：将四元数旋转应用于三维点 (px, py, pz)。
pub fn Quaternion::rotate_point(
  self : Quaternion,
  px : Double,
  py : Double,
  pz : Double,
) -> (Double, Double, Double) {
  // p' = q * p * q*
  let qp = self.mul({ w: 0.0, x: px, y: py, z: pz })
  let result = qp.mul(self.conjugate())
  (result.x, result.y, result.z)
}

///|
/// SE(3) 齐次变换：平移 + 旋转。
///
/// `translation` 为 (x, y, z) 平移分量，
/// `rotation` 为旋转四元数。
pub(all) struct Transform {
  translation : (Double, Double, Double)
  rotation : Quaternion
} derive(Eq, Debug)

///|
pub extend Transform with Eq::{not_equal, equal}

///|
pub extend Transform with @debug.Debug::{to_repr}

///|
/// 单位变换（无平移无旋转）。
pub fn Transform::identity() -> Transform {
  { translation: (0.0, 0.0, 0.0), rotation: Quaternion::identity() }
}

///|
/// 从平移和欧拉角创建变换。
pub fn Transform::from_pose(
  x : Double,
  y : Double,
  z : Double,
  roll : Double,
  pitch : Double,
  yaw : Double,
) -> Transform {
  { translation: (x, y, z), rotation: Quaternion::from_euler(roll, pitch, yaw) }
}

///|
/// 变换复合：`self` 后乘 `other`，等价于先应用 `other` 再应用 `self`。
pub fn Transform::compose(self : Transform, other : Transform) -> Transform {
  let (ox, oy, oz) = other.translation
  let (rx, ry, rz) = self.rotation.rotate_point(ox, oy, oz)
  let (sx, sy, sz) = self.translation
  {
    translation: (sx + rx, sy + ry, sz + rz),
    rotation: self.rotation.mul(other.rotation),
  }
}

///|
/// 逆变换。
pub fn Transform::inverse(self : Transform) -> Transform {
  let inv_rot = self.rotation.conjugate()
  let (tx, ty, tz) = self.translation
  let (rx, ry, rz) = inv_rot.rotate_point(tx, ty, tz)
  { translation: (-rx, -ry, -rz), rotation: inv_rot }
}

///|
/// 将变换应用于点 (px, py, pz)。
pub fn Transform::apply_point(
  self : Transform,
  px : Double,
  py : Double,
  pz : Double,
) -> (Double, Double, Double) {
  let (rx, ry, rz) = self.rotation.rotate_point(px, py, pz)
  let (tx, ty, tz) = self.translation
  (tx + rx, ty + ry, tz + rz)
}
