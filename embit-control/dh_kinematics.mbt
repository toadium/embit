///|
/// Denavit-Hartenberg 参数：描述相邻关节坐标系间的变换。
///
/// 四参数约定（标准 DH）：
/// - `a`：连杆长度（沿 x_i 从 z_{i-1} 到 z_i 的距离）
/// - `alpha`：连杆扭角（绕 x_i 从 z_{i-1} 到 z_i 的角度，弧度）
/// - `d`：连杆偏移（沿 z_{i-1} 从 x_{i-1} 到 x_i 的距离）
/// - `theta`：关节角（绕 z_{i-1} 从 x_{i-1} 到 x_i 的角度，弧度）
///
/// 对于旋转关节，`theta` 为变量（关节角度），其余为常量；
/// 对于移动关节，`d` 为变量。
pub(all) struct DHParam {
  a : Double
  alpha : Double
  d : Double
  theta : Double
  /// true 表示旋转关节（theta 为变量），false 表示移动关节（d 为变量）。
  revolute : Bool
  /// 关节名称。
  name : String
}

///|
/// 创建旋转关节的 DH 参数。
pub fn DHParam::revolute(
  name : String,
  a : Double,
  alpha : Double,
  d : Double,
  theta_offset : Double,
) -> DHParam {
  { a, alpha, d, theta: theta_offset, revolute: true, name }
}

///|
/// 创建移动关节的 DH 参数。
pub fn DHParam::prismatic(
  name : String,
  a : Double,
  alpha : Double,
  d_offset : Double,
  theta : Double,
) -> DHParam {
  { a, alpha, d: d_offset, theta, revolute: false, name }
}

///|
/// 计算单个 DH 变换矩阵对应的 Transform。
///
/// DH 变换：T = Rot_z(θ) · Trans_z(d) · Trans_x(a) · Rot_x(α)
/// 展开后平移分量为 (a·cos(θ), a·sin(θ), d)，
/// 旋转部分为 Rot_z(θ) · Rot_x(α)。
fn dh_transform(
  a : Double,
  alpha : Double,
  d : Double,
  theta : Double,
) -> @core.Transform {
  let ct = @math.cos(theta)
  let st = @math.sin(theta)
  // 旋转 R = Rot_z(θ) · Rot_x(α)，转为四元数
  let qz = @core.Quaternion::from_euler(0.0, 0.0, theta)
  let qx = @core.Quaternion::from_euler(alpha, 0.0, 0.0)
  let rot = qz.mul(qx)
  { translation: (a * ct, a * st, d), rotation: rot }
}

///|
/// 根据关节状态计算带变量代入的 DH 变换。
fn dh_transform_joint(param : DHParam, joint_value : Double) -> @core.Transform {
  if param.revolute {
    dh_transform(param.a, param.alpha, param.d, param.theta + joint_value)
  } else {
    dh_transform(param.a, param.alpha, param.d + joint_value, param.theta)
  }
}

///|
/// DH 参数正运动学解算器。
///
/// 使用标准 Denavit-Hartenberg 约定计算末端位姿。
/// 支持任意自由度的串联机器人。
pub struct DhFKSolver {
  params : Array[DHParam]
  ee_name : String
}

///|
/// 创建 DH 正运动学解算器。
///
/// `params` 为从基座到末端的 DH 参数序列，`ee_name` 为末端连杆名称。
pub fn DhFKSolver::new(params : Array[DHParam], ee_name : String) -> DhFKSolver {
  { params, ee_name }
}

///|
/// 从关节状态数组提取关节角度。
fn extract_joint_angle(
  params : Array[DHParam],
  joint_states : Array[@core.JointState],
) -> Array[Double] raise @core.RobotError {
  let n = params.length()
  if joint_states.length() < n {
    raise InvalidConfig(
      "expected \{n} joint states, got \{joint_states.length()}",
    )
  }
  let result : Array[Double] = []
  for i in 0..<n {
    result.push(joint_states[i].position)
  }
  result
}

///|
/// DH 正运动学核心：给定关节角度，计算末端 Transform。
pub fn DhFKSolver::fk(
  self : DhFKSolver,
  joint_angles : Array[Double],
) -> @core.Transform raise @core.RobotError {
  let n = self.params.length()
  if joint_angles.length() < n {
    raise InvalidConfig(
      "expected \{n} joint angles, got \{joint_angles.length()}",
    )
  }
  let mut tf = @core.Transform::identity()
  for i in 0..<n {
    let joint_tf = dh_transform_joint(self.params[i], joint_angles[i])
    tf = tf.compose(joint_tf)
  }
  tf
}

///|
/// 将 Transform 转换为 Pose（欧拉角表示）。
fn transform_to_pose(tf : @core.Transform) -> Pose {
  let (x, y, z) = tf.translation
  let (roll, pitch, yaw) = tf.rotation.to_euler()
  { position: (x, y, z), orientation: (roll, pitch, yaw) }
}

///|
impl FKSolver for DhFKSolver with fn solve_fk(self, joint_states) {
  let angles = try! extract_joint_angle(self.params, joint_states)
  let tf = try! self.fk(angles)
  transform_to_pose(tf)
}

///|
impl FKSolver for DhFKSolver with fn end_effector(self) {
  self.ee_name
}

///|
pub extend DhFKSolver with FKSolver::{solve_fk, end_effector}

// ===== 数值雅可比 + 阻尼最小二乘逆运动学 =====

///|
/// DH 参数逆运动学解算器。
///
/// 使用数值雅可比 + 阻尼最小二乘（Levenberg-Marquardt）迭代求解。
/// 适用于任意自由度的串联机器人，不依赖解析解。
pub struct DhIKSolver {
  fk_solver : DhFKSolver
  /// 阻尼因子（越大越稳定但收敛越慢）。
  damping : Double
  /// 最大迭代次数。
  max_iter : Int
  /// 收敛阈值（末端位置误差，米）。
  tolerance : Double
}

///|
/// 创建 DH 逆运动学解算器。
///
/// `fk_solver` 为对应的正运动学解算器，
/// `damping` 为阻尼因子（推荐 0.01~0.1），
/// `max_iter` 为最大迭代次数（推荐 50~200），
/// `tolerance` 为收敛阈值（推荐 1e-6）。
pub fn DhIKSolver::new(
  fk_solver : DhFKSolver,
  damping? : Double = 0.05,
  max_iter? : Int = 100,
  tolerance? : Double = 0.000001,
) -> DhIKSolver {
  { fk_solver, damping, max_iter, tolerance }
}

///|
/// 提取位姿的 6 维误差向量 (dx, dy, dz, droll, dpitch, dyaw)。
fn pose_error(target : Pose, current : Pose) -> Array[Double] {
  let (tx, ty, tz) = target.position
  let (cx, cy, cz) = current.position
  let (tr, tp, tyaw) = target.orientation
  let (cr, cp, cyaw) = current.orientation
  [tx - cx, ty - cy, tz - cz, tr - cr, tp - cp, tyaw - cyaw]
}

///|
/// 计算数值雅可比矩阵（6×n）。
///
/// 对每个关节施加微小扰动 δ，计算 FK 输出的 6 维差分，
/// 作为雅可比矩阵的对应列。
fn numerical_jacobian(
  fk : DhFKSolver,
  joint_angles : Array[Double],
  delta : Double,
) -> Array[Array[Double]] raise @core.RobotError {
  let n = joint_angles.length()
  let jacobian : Array[Array[Double]] = []
  let base_tf = fk.fk(joint_angles)
  let base_pose = transform_to_pose(base_tf)
  for j in 0..<n {
    let perturbed : Array[Double] = []
    for k in 0..<n {
      if k == j {
        perturbed.push(joint_angles[k] + delta)
      } else {
        perturbed.push(joint_angles[k])
      }
    }
    let perturbed_tf = fk.fk(perturbed)
    let perturbed_pose = transform_to_pose(perturbed_tf)
    let col : Array[Double] = []
    let (px, py, pz) = perturbed_pose.position
    let (bx, by, bz) = base_pose.position
    let (pr, pp, pyaw) = perturbed_pose.orientation
    let (br, bp, byaw) = base_pose.orientation
    col.push((px - bx) / delta)
    col.push((py - by) / delta)
    col.push((pz - bz) / delta)
    col.push((pr - br) / delta)
    col.push((pp - bp) / delta)
    col.push((pyaw - byaw) / delta)
    jacobian.push(col)
  }
  jacobian
}

///|
/// 阻尼最小二乘求解：δq = J^T · (J · J^T + λ²·I)⁻¹ · e
fn damped_least_squares(
  jacobian : Array[Array[Double]],
  error : Array[Double],
  damping : Double,
) -> Array[Double] {
  let n = jacobian.length()
  if n == 0 {
    return []
  }
  let m = 6
  let lambda_sq = damping * damping
  // 1. 计算 A = J · J^T + λ²·I（m×m）
  let a : Array[Array[Double]] = []
  for i in 0..<m {
    let row : Array[Double] = []
    for j in 0..<m {
      let sum = for k in 0..<n; s = 0.0 {
        continue s + jacobian[k][i] * jacobian[k][j]
      } nobreak {
        s
      }
      row.push(if i == j { sum + lambda_sq } else { sum })
    }
    a.push(row)
  }
  // 2. 高斯消元求解 A · x = error
  let x = gauss_elimination(a, error, m)
  // 3. δq = J^T · x
  let dq : Array[Double] = []
  for k in 0..<n {
    let sum = for i in 0..<m; s = 0.0 {
      continue s + jacobian[k][i] * x[i]
    } nobreak {
      s
    }
    dq.push(sum)
  }
  dq
}

///|
/// 高斯消元法求解线性方程组 A·x = b。
fn gauss_elimination(
  a : Array[Array[Double]],
  b : Array[Double],
  n : Int,
) -> Array[Double] {
  let mat : Array[Array[Double]] = []
  for i in 0..<n {
    let row : Array[Double] = []
    for j in 0..<n {
      row.push(a[i][j])
    }
    row.push(b[i])
    mat.push(row)
  }
  // 前向消元 + 选主元
  for i in 0..<n {
    let mut max_row = i
    for k in (i + 1)..<n {
      if mat[k][i].abs() > mat[max_row][i].abs() {
        max_row = k
      }
    }
    if max_row != i {
      let tmp = mat[i]
      mat[i] = mat[max_row]
      mat[max_row] = tmp
    }
    if mat[i][i].abs() < 0.0000000001 {
      continue
    }
    for k in (i + 1)..<n {
      let factor = mat[k][i] / mat[i][i]
      for j in i..<=n {
        mat[k][j] = mat[k][j] - factor * mat[i][j]
      }
    }
  }
  // 回代
  let x : Array[Double] = []
  for _ in 0..<n {
    x.push(0.0)
  }
  let mut i = n - 1
  while i >= 0 {
    let mut sum = mat[i][n]
    for j in (i + 1)..<n {
      sum = sum - mat[i][j] * x[j]
    }
    if mat[i][i].abs() < 0.0000000001 {
      x[i] = 0.0
    } else {
      x[i] = sum / mat[i][i]
    }
    i -= 1
  }
  x
}

///|
/// DH 逆运动学核心：给定目标位姿和初始猜测，迭代求解关节角度。
pub fn DhIKSolver::solve(
  self : DhIKSolver,
  target : Pose,
  initial_guess : Array[Double],
) -> Array[Double] raise @core.RobotError {
  let n = self.fk_solver.params.length()
  if initial_guess.length() < n {
    raise InvalidConfig(
      "expected \{n} initial joint values, got \{initial_guess.length()}",
    )
  }
  let q : Array[Double] = []
  for i in 0..<n {
    q.push(initial_guess[i])
  }
  let delta = 0.0001
  for _ in 0..<self.max_iter {
    let tf = self.fk_solver.fk(q)
    let current = transform_to_pose(tf)
    let err = pose_error(target, current)
    let pos_err = (err[0] * err[0] + err[1] * err[1] + err[2] * err[2]).sqrt()
    if pos_err < self.tolerance {
      return q
    }
    let jacobian = numerical_jacobian(self.fk_solver, q, delta)
    let dq = damped_least_squares(jacobian, err, self.damping)
    for i in 0..<n {
      q[i] = q[i] + dq[i]
    }
  }
  q
}

///|
/// 从关节角度数组生成 JointState 数组。
fn angles_to_joint_states(
  params : Array[DHParam],
  angles : Array[Double],
) -> Array[@core.JointState] {
  let result : Array[@core.JointState] = []
  for i in 0..<params.length() {
    result.push({
      name: params[i].name,
      position: angles[i],
      velocity: 0.0,
      effort: 0.0,
    })
  }
  result
}

///|
/// 从 JointState 数组提取关节角度数组。
fn joint_states_to_angles(
  n : Int,
  joint_states : Array[@core.JointState],
) -> Array[Double] {
  let result : Array[Double] = []
  for i in 0..<n {
    if i < joint_states.length() {
      result.push(joint_states[i].position)
    } else {
      result.push(0.0)
    }
  }
  result
}

///|
impl IKSolver for DhIKSolver with fn solve_ik(self, pose) {
  let n = self.fk_solver.params.length()
  let initial : Array[Double] = []
  for _ in 0..<n {
    initial.push(0.0)
  }
  let angles = self.solve(pose, initial)
  angles_to_joint_states(self.fk_solver.params, angles)
}

///|
impl IKSolver for DhIKSolver with fn solve_ik_with_seed(self, pose, seed) -> Array[
  @core.JointState,
] raise @core.RobotError {
  let n = self.fk_solver.params.length()
  let initial = joint_states_to_angles(n, seed)
  let angles = self.solve(pose, initial)
  angles_to_joint_states(self.fk_solver.params, angles)
}

///|
impl IKSolver for DhIKSolver with fn dof(self) {
  self.fk_solver.params.length()
}

///|
pub extend DhIKSolver with IKSolver::{solve_ik, solve_ik_with_seed, dof}

///|
/// 预设：6-DOF 工业机械臂 DH 参数（类似 UR5 尺寸）。
///
/// 返回 6 个旋转关节的 DH 参数，适用于标准 6 轴机械臂。
/// 连杆长度（米）：a1=0.425, a2=0.392, d1=0.089, d4=0.109, d6=0.082
pub fn DhFKSolver::arm_6dof(ee_name? : String = "ee_link") -> DhFKSolver {
  let params : Array[DHParam] = [
    DHParam::revolute("shoulder_pan", 0.0, 1.5707963267948966, 0.089, 0.0),
    DHParam::revolute("shoulder_lift", 0.425, 0.0, 0.0, 0.0),
    DHParam::revolute("elbow", 0.392, 0.0, 0.0, 0.0),
    DHParam::revolute("wrist_1", 0.0, 1.5707963267948966, 0.109, 0.0),
    DHParam::revolute("wrist_2", 0.0, 1.5707963267948966, 0.0, 0.0),
    DHParam::revolute("wrist_3", 0.0, 0.0, 0.082, 0.0),
  ]
  DhFKSolver::new(params, ee_name)
}
