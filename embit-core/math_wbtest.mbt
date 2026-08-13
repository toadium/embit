///|
/// embit-core 数学工具白盒测试：验证四元数与 SE(3) 变换运算。
///
/// 白盒测试位于包内，可直接使用 Quaternion / Transform 等类型名。

///|
/// 浮点近似比较阈值。
let math_eps : Double = 0.000001

///|
/// 辅助断言两个 Double 近似相等。
fn assert_approx(a : Double, b : Double) -> Unit raise {
  assert_true((a - b).abs() < math_eps)
}

// ===== Quaternion 测试 =====

///|
/// 单位四元数应为 (1, 0, 0, 0)。
test "Quaternion - identity is (1,0,0,0)" {
  let q = Quaternion::identity()
  assert_eq(q.w, 1.0)
  assert_eq(q.x, 0.0)
  assert_eq(q.y, 0.0)
  assert_eq(q.z, 0.0)
}

///|
/// 从零欧拉角创建的四元数应为单位四元数。
test "Quaternion - from_euler zero is identity" {
  let q = Quaternion::from_euler(0.0, 0.0, 0.0)
  assert_approx(q.w, 1.0)
  assert_approx(q.x, 0.0)
  assert_approx(q.y, 0.0)
  assert_approx(q.z, 0.0)
}

///|
/// from_euler → to_euler 往返应恢复原始角度。
test "Quaternion - from_euler to_euler roundtrip" {
  let roll = 0.5
  let pitch = 0.3
  let yaw = 0.8
  let q = Quaternion::from_euler(roll, pitch, yaw)
  let (r2, p2, y2) = q.to_euler()
  assert_approx(r2, roll)
  assert_approx(p2, pitch)
  assert_approx(y2, yaw)
}

///|
/// 绕 Z 轴旋转 90° 的四元数应正确表示。
test "Quaternion - from_euler yaw 90deg" {
  let q = Quaternion::from_euler(0.0, 0.0, pi * 0.5)
  // 90° 绕 Z 轴：w = cos(45°) ≈ 0.7071, z = sin(45°) ≈ 0.7071
  assert_approx(q.w, 0.7071067811865476)
  assert_approx(q.x, 0.0)
  assert_approx(q.y, 0.0)
  assert_approx(q.z, 0.7071067811865476)
}

///|
/// 单位四元数乘法应返回单位四元数。
test "Quaternion - mul identity is identity" {
  let q = Quaternion::from_euler(0.3, 0.5, 0.7)
  let id = Quaternion::identity()
  let r = q.mul(id)
  assert_approx(r.w, q.w)
  assert_approx(r.x, q.x)
  assert_approx(r.y, q.y)
  assert_approx(r.z, q.z)
}

///|
/// 四元数乘以其共轭应返回单位四元数（对单位四元数）。
test "Quaternion - mul conjugate returns identity for unit quaternion" {
  let q = Quaternion::from_euler(0.3, 0.5, 0.7).normalize()
  let qc = q.conjugate()
  let r = q.mul(qc)
  assert_approx(r.w, 1.0)
  assert_approx(r.x, 0.0)
  assert_approx(r.y, 0.0)
  assert_approx(r.z, 0.0)
}

///|
/// 共轭应反转矢量分量。
test "Quaternion - conjugate negates vector part" {
  let q = { w: 0.5, x: 0.3, y: -0.2, z: 0.4 }
  let qc = q.conjugate()
  assert_eq(qc.w, 0.5)
  assert_eq(qc.x, -0.3)
  assert_eq(qc.y, 0.2)
  assert_eq(qc.z, -0.4)
}

///|
/// 单位四元数的模应为 1。
test "Quaternion - norm of unit quaternion is 1" {
  let q = Quaternion::from_euler(0.3, 0.5, 0.7).normalize()
  assert_approx(q.norm(), 1.0)
}

///|
/// 归一化后模应为 1。
test "Quaternion - normalize makes norm 1" {
  let q = { w: 2.0, x: 0.0, y: 0.0, z: 0.0 }
  let qn = q.normalize()
  assert_approx(qn.norm(), 1.0)
  assert_approx(qn.w, 1.0)
}

///|
/// 归一化零四元数应返回单位四元数。
test "Quaternion - normalize zero returns identity" {
  let q = { w: 0.0, x: 0.0, y: 0.0, z: 0.0 }
  let qn = q.normalize()
  assert_approx(qn.w, 1.0)
  assert_approx(qn.x, 0.0)
  assert_approx(qn.y, 0.0)
  assert_approx(qn.z, 0.0)
}

///|
/// 绕 Z 轴旋转 90° 应将 (1,0,0) 变换为 (0,1,0)。
test "Quaternion - rotate_point yaw 90deg" {
  let q = Quaternion::from_euler(0.0, 0.0, pi * 0.5)
  let (rx, ry, rz) = q.rotate_point(1.0, 0.0, 0.0)
  assert_approx(rx, 0.0)
  assert_approx(ry, 1.0)
  assert_approx(rz, 0.0)
}

///|
/// 单位四元数旋转点应不改变点位置。
test "Quaternion - rotate_point identity is no-op" {
  let q = Quaternion::identity()
  let (rx, ry, rz) = q.rotate_point(1.5, 2.5, 3.5)
  assert_approx(rx, 1.5)
  assert_approx(ry, 2.5)
  assert_approx(rz, 3.5)
}

// ===== Transform 测试 =====

///|
/// 单位变换应无平移无旋转。
test "Transform - identity" {
  let t = Transform::identity()
  let (x, y, z) = t.translation
  assert_eq(x, 0.0)
  assert_eq(y, 0.0)
  assert_eq(z, 0.0)
  assert_eq(t.rotation, Quaternion::identity())
}

///|
/// from_pose 应正确设置平移与旋转。
test "Transform - from_pose" {
  let t = Transform::from_pose(1.0, 2.0, 3.0, 0.0, 0.0, 0.0)
  let (x, y, z) = t.translation
  assert_eq(x, 1.0)
  assert_eq(y, 2.0)
  assert_eq(z, 3.0)
  assert_eq(t.rotation, Quaternion::identity())
}

///|
/// 单位变换复合任意变换应返回该变换。
test "Transform - compose with identity" {
  let t = Transform::from_pose(1.0, 2.0, 3.0, 0.3, 0.5, 0.7)
  let id = Transform::identity()
  let r = id.compose(t)
  let (rx, ry, rz) = r.translation
  assert_approx(rx, 1.0)
  assert_approx(ry, 2.0)
  assert_approx(rz, 3.0)
}

///|
/// 变换复合其逆应返回单位变换。
test "Transform - compose with inverse is identity" {
  let t = Transform::from_pose(1.0, 2.0, 3.0, 0.3, 0.5, 0.7)
  let inv = t.inverse()
  let r = t.compose(inv)
  let (rx, ry, rz) = r.translation
  assert_approx(rx, 0.0)
  assert_approx(ry, 0.0)
  assert_approx(rz, 0.0)
  assert_approx(r.rotation.w, 1.0)
  assert_approx(r.rotation.x, 0.0)
  assert_approx(r.rotation.y, 0.0)
  assert_approx(r.rotation.z, 0.0)
}

///|
/// 单位变换应用于点应不改变点位置。
test "Transform - apply_point identity is no-op" {
  let t = Transform::identity()
  let (rx, ry, rz) = t.apply_point(1.5, 2.5, 3.5)
  assert_approx(rx, 1.5)
  assert_approx(ry, 2.5)
  assert_approx(rz, 3.5)
}

///|
/// 纯平移变换应用于点应叠加平移。
test "Transform - apply_point pure translation" {
  let t = Transform::from_pose(10.0, 20.0, 30.0, 0.0, 0.0, 0.0)
  let (rx, ry, rz) = t.apply_point(1.0, 2.0, 3.0)
  assert_approx(rx, 11.0)
  assert_approx(ry, 22.0)
  assert_approx(rz, 33.0)
}

///|
/// 绕 Z 轴 90° 变换应用于 (1,0,0) 应得到 (0,1,0)（无平移时）。
test "Transform - apply_point yaw 90deg no translation" {
  let t = Transform::from_pose(0.0, 0.0, 0.0, 0.0, 0.0, pi * 0.5)
  let (rx, ry, rz) = t.apply_point(1.0, 0.0, 0.0)
  assert_approx(rx, 0.0)
  assert_approx(ry, 1.0)
  assert_approx(rz, 0.0)
}
