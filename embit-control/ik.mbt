///|
/// 笛卡尔位姿：位置 + 欧拉角姿态。
///
/// `position` 为 (x, y, z) 平移分量，
/// `orientation` 为 (roll, pitch, yaw) 旋转分量（弧度）。
pub(all) struct Pose {
  position : (Double, Double, Double)
  orientation : (Double, Double, Double)
} derive(Eq, Debug)

///|
pub extend Pose with Eq::{not_equal, equal}

///|
pub extend Pose with @debug.Debug::{to_repr}

///|
/// 创建位姿。
pub fn Pose::new(
  x : Double,
  y : Double,
  z : Double,
  roll : Double,
  pitch : Double,
  yaw : Double,
) -> Pose {
  { position: (x, y, z), orientation: (roll, pitch, yaw) }
}

///|
/// 逆运动学解算器 trait。
///
/// 不同机型需实现此 trait，将笛卡尔目标位姿映射为关节角度。
/// Phase 2 提供接口骨架，Phase 3 实现具体机型解算器。
pub(open) trait IKSolver {
  /// 求解逆运动学：目标位姿 → 关节角度序列。
  ///
  /// 失败时抛出 `RobotError::UnsupportedRobotType`（目标不可达）。
  fn solve_ik(Self, Pose) -> Array[@core.JointState] raise @core.RobotError

  /// 带初始猜测的逆运动学求解。
  ///
  /// `seed` 为关节初值，用于引导解算收敛到期望分支。
  fn solve_ik_with_seed(Self, Pose, Array[@core.JointState]) -> Array[
    @core.JointState,
  ] raise @core.RobotError

  /// 查询解算器支持的自由度。
  fn dof(Self) -> Int
}

///|
/// 正运动学解算器 trait。
///
/// 将关节角度映射为末端笛卡尔位姿。
pub(open) trait FKSolver {
  /// 求解正运动学：关节角度 → 末端位姿。
  fn solve_fk(Self, Array[@core.JointState]) -> Pose

  /// 查询末端连杆名称。
  fn end_effector(Self) -> String
}

// ===== Phase 3.2: 人形腿逆运动学 =====

///|
/// 人形腿逆运动学解算器：2-DOF 平面解析解 + 6-DOF 姿态分解。
///
/// 针对人形机器人腿部 6 自由度结构（hip: yaw/roll/pitch, knee: pitch, ankle: pitch/roll），
/// 提供解析逆运动学求解。核心为 2-DOF 平面解（hip pitch + knee pitch），
/// 使用余弦定理求解，外层 4-DOF 通过姿态分解求解。
pub struct LegIKSolver {
  thigh_length : Double // 大腿长度（hip 到 knee，米）
  shin_length : Double // 小腿长度（knee 到 ankle，米）
  ankle_height : Double // 踝关节到脚底高度（米）
}

///|
/// 创建人形腿 IK 解算器。
///
/// `thigh_length` 为大腿长度，`shin_length` 为小腿长度，
/// `ankle_height` 为踝关节到脚底高度（默认 0）。
pub fn LegIKSolver::new(
  thigh_length : Double,
  shin_length : Double,
  ankle_height? : Double = 0.0,
) -> LegIKSolver {
  { thigh_length, shin_length, ankle_height }
}

///|
/// 2-DOF 平面逆运动学：给定目标位置 (r, z)，求解 hip pitch 和 knee pitch。
///
/// 使用余弦定理：
/// - `d² = r² + z²`
/// - `cos(θ_knee) = (d² - L1² - L2²) / (2·L1·L2)`
/// - `θ_knee = -acos(cos_knee)`（负值，膝盖向后弯曲）
/// - `θ_hip = atan2(r, z) - atan2(L2·sin(θ_knee), L1 + L2·cos(θ_knee))`
///
/// 返回 `(hip_pitch, knee_pitch)`。目标不可达时抛出 `RobotError::UnsupportedRobotType`。
///
/// 默认膝盖向后弯曲（knee_pitch < 0）。如需选择肘上/肘下解，使用 `solve_planar_with_seed`。
pub fn LegIKSolver::solve_planar(
  self : LegIKSolver,
  r : Double,
  z : Double,
) -> (Double, Double) raise @core.RobotError {
  self.solve_planar_internal(r, z, false)
}

///|
/// 2-DOF 平面逆运动学（带种子选择）。
///
/// `seed_knee_pitch` 的符号决定解分支：正值选肘上解（膝盖前弯），负值选肘下解（膝盖后弯）。
pub fn LegIKSolver::solve_planar_with_seed(
  self : LegIKSolver,
  r : Double,
  z : Double,
  seed_knee_pitch : Double,
) -> (Double, Double) raise @core.RobotError {
  self.solve_planar_internal(r, z, seed_knee_pitch > 0.0)
}

///|
/// 2-DOF 平面逆运动学内部实现。
///
/// `knee_forward = true` 选肘上解（knee_pitch > 0），`false` 选肘下解（knee_pitch < 0）。
fn LegIKSolver::solve_planar_internal(
  self : LegIKSolver,
  r : Double,
  z : Double,
  knee_forward : Bool,
) -> (Double, Double) raise @core.RobotError {
  let l1 = self.thigh_length
  let l2 = self.shin_length
  let d_sq = r * r + z * z
  let d = d_sq.sqrt()
  // 可达性检查
  let max_reach = l1 + l2
  let min_reach = (l1 - l2).abs()
  if d > max_reach + 0.0001 {
    raise UnsupportedRobotType(
      "leg target unreachable: d=\{d} > L1+L2=\{max_reach}",
    )
  }
  if d < min_reach - 0.0001 {
    raise UnsupportedRobotType(
      "leg target too close: d=\{d} < |L1-L2|=\{min_reach}",
    )
  }
  // 余弦定理求膝盖角度
  let cos_knee = (d_sq - l1 * l1 - l2 * l2) / (2.0 * l1 * l2)
  // 钳位到 [-1, 1] 避免数值误差导致 acos 出 NaN
  let cos_clamped = if cos_knee > 1.0 {
    1.0
  } else if cos_knee < -1.0 {
    -1.0
  } else {
    cos_knee
  }
  let acos_val = @math.acos(cos_clamped)
  // knee_forward → 肘上解（正值）；否则肘下解（负值，膝盖向后弯曲）
  let knee_pitch = if knee_forward { acos_val } else { -acos_val }
  // hip pitch
  let sin_knee = @math.sin(knee_pitch)
  let cos_k = @math.cos(knee_pitch)
  let hip_pitch = @math.atan2(r, z) -
    @math.atan2(l2 * sin_knee, l1 + l2 * cos_k)
  (hip_pitch, knee_pitch)
}

///|
/// 6-DOF 腿逆运动学：给定目标脚部位姿，求解 6 个关节角度。
///
/// 关节顺序：hip_yaw, hip_roll, hip_pitch, knee_pitch, ankle_pitch, ankle_roll。
/// 求解策略：
/// 1. hip_yaw = atan2(y, x)（指向目标方向）
/// 2. 投影到矢状面：r = sqrt(x²+y²), z' = z - ankle_height
/// 3. 2-DOF 平面解 → hip_pitch, knee_pitch
/// 4. ankle_pitch = target_pitch - hip_pitch - knee_pitch
/// 5. hip_roll = target_roll / 2, ankle_roll = target_roll / 2
pub fn LegIKSolver::solve_6dof(
  self : LegIKSolver,
  target : Pose,
) -> (Double, Double, Double, Double, Double, Double) raise @core.RobotError {
  self.solve_6dof_internal(target, false)
}

///|
/// 6-DOF 腿逆运动学（带种子选择）。
///
/// `seed_knee_pitch` 的符号决定肘上/肘下解分支。
pub fn LegIKSolver::solve_6dof_with_seed(
  self : LegIKSolver,
  target : Pose,
  seed_knee_pitch : Double,
) -> (Double, Double, Double, Double, Double, Double) raise @core.RobotError {
  self.solve_6dof_internal(target, seed_knee_pitch > 0.0)
}

///|
/// 6-DOF 腿逆运动学内部实现。
fn LegIKSolver::solve_6dof_internal(
  self : LegIKSolver,
  target : Pose,
  knee_forward : Bool,
) -> (Double, Double, Double, Double, Double, Double) raise @core.RobotError {
  let (x, y, z) = target.position
  let (roll, pitch, _) = target.orientation
  // hip_yaw：指向目标方向
  let hip_yaw = @math.atan2(y, x)
  // 投影到矢状面
  let r = (x * x + y * y).sqrt()
  let z_eff = z - self.ankle_height
  // 2-DOF 平面解
  let (hip_pitch, knee_pitch) = self.solve_planar_internal(
    r, z_eff, knee_forward,
  )
  // ankle_pitch：剩余角度
  let ankle_pitch = pitch - hip_pitch - knee_pitch
  // hip_roll / ankle_roll：均分目标 roll
  let hip_roll = roll / 2.0
  let ankle_roll = roll / 2.0
  (hip_yaw, hip_roll, hip_pitch, knee_pitch, ankle_pitch, ankle_roll)
}

///|
/// 将 6 个关节角度转为 JointState 数组。
fn leg_angles_to_joint_states(
  angles : (Double, Double, Double, Double, Double, Double),
) -> Array[@core.JointState] {
  let (j1, j2, j3, j4, j5, j6) = angles
  [
    { name: "hip_yaw", position: j1, velocity: 0.0, effort: 0.0 },
    { name: "hip_roll", position: j2, velocity: 0.0, effort: 0.0 },
    { name: "hip_pitch", position: j3, velocity: 0.0, effort: 0.0 },
    { name: "knee_pitch", position: j4, velocity: 0.0, effort: 0.0 },
    { name: "ankle_pitch", position: j5, velocity: 0.0, effort: 0.0 },
    { name: "ankle_roll", position: j6, velocity: 0.0, effort: 0.0 },
  ]
}

///|
/// 从种子关节状态中提取 knee_pitch 值，用于解分支选择。
fn extract_seed_knee_pitch(seed : Array[@core.JointState]) -> Double {
  for joint in seed {
    if joint.name == "knee_pitch" {
      return joint.position
    }
  }
  0.0
}

///|
impl IKSolver for LegIKSolver with fn solve_ik(self, pose) {
  let angles = self.solve_6dof(pose)
  leg_angles_to_joint_states(angles)
}

///|
/// 基于种子的多解选择：种子中 knee_pitch 的符号决定肘上/肘下解分支。
impl IKSolver for LegIKSolver with fn solve_ik_with_seed(self, pose, seed) -> Array[
  @core.JointState,
] raise @core.RobotError {
  let seed_knee = extract_seed_knee_pitch(seed)
  let angles = self.solve_6dof_with_seed(pose, seed_knee)
  leg_angles_to_joint_states(angles)
}

///|
impl IKSolver for LegIKSolver with fn dof(_self) {
  6
}

///|
pub extend LegIKSolver with IKSolver::{solve_ik, solve_ik_with_seed, dof}
