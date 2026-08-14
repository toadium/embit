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
