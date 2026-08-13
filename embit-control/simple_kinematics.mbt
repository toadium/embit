///|
/// 简化逆运动学解算器：将笛卡尔位姿直接映射为关节角度。
///
/// 将位姿 (x, y, z, roll, pitch, yaw) 映射为 6 个关节角度，
/// 适用于测试、演示与无运动学约束的占位场景。
/// 真实项目应替换为具体机型的解析或数值 IK 解算器。
pub struct SimpleIKSolver {
  dof_value : Int
}

///|
/// 创建简化 IK 解算器。
///
/// `dof` 为自由度（通常为 6）。
pub fn SimpleIKSolver::new(dof : Int) -> SimpleIKSolver {
  { dof_value: dof }
}

///|
impl IKSolver for SimpleIKSolver with fn solve_ik(self, pose) {
  ignore(self)
  let (x, y, z) = pose.position
  let (r, p, yaw) = pose.orientation
  [
    { name: "joint1", position: x, velocity: 0.0, effort: 0.0 },
    { name: "joint2", position: y, velocity: 0.0, effort: 0.0 },
    { name: "joint3", position: z, velocity: 0.0, effort: 0.0 },
    { name: "joint4", position: r, velocity: 0.0, effort: 0.0 },
    { name: "joint5", position: p, velocity: 0.0, effort: 0.0 },
    { name: "joint6", position: yaw, velocity: 0.0, effort: 0.0 },
  ]
}

///|
impl IKSolver for SimpleIKSolver with fn solve_ik_with_seed(self, pose, _seed) -> Array[
  @core.JointState,
] raise @core.RobotError {
  self.solve_ik(pose)
}

///|
impl IKSolver for SimpleIKSolver with fn dof(self) {
  self.dof_value
}

///|
pub extend SimpleIKSolver with IKSolver::{solve_ik, solve_ik_with_seed, dof}

///|
/// 简化正运动学解算器：将关节角度直接映射为笛卡尔位姿。
///
/// 将 6 个关节角度映射为位姿 (x, y, z, roll, pitch, yaw)，
/// 与 `SimpleIKSolver` 互为逆运算。
pub struct SimpleFKSolver {
  ee_name : String
}

///|
/// 创建简化 FK 解算器。
///
/// `ee_name` 为末端连杆名称。
pub fn SimpleFKSolver::new(ee_name : String) -> SimpleFKSolver {
  { ee_name, }
}

///|
impl FKSolver for SimpleFKSolver with fn solve_fk(self, joint_states) {
  ignore(self)
  let x = joint_states[0].position
  let y = joint_states[1].position
  let z = joint_states[2].position
  let r = joint_states[3].position
  let p = joint_states[4].position
  let yaw = joint_states[5].position
  { position: (x, y, z), orientation: (r, p, yaw) }
}

///|
impl FKSolver for SimpleFKSolver with fn end_effector(self) {
  self.ee_name
}

///|
pub extend SimpleFKSolver with FKSolver::{solve_fk, end_effector}

// ===== 简化笛卡尔控制器（非泛型包装器） =====

///|
/// 简化笛卡尔控制器：使用 SimpleIKSolver / SimpleFKSolver 的非泛型包装器。
///
/// 封装 `CartesianController[SimpleIKSolver, SimpleFKSolver]`，
/// 提供非泛型 API 供跨包使用。避免泛型 trait bound 跨包可见性问题。
pub struct SimpleCartesianController {
  inner : CartesianController[SimpleIKSolver, SimpleFKSolver]
}

///|
/// 创建简化笛卡尔控制器。
///
/// `dof` 为自由度，`ee_name` 为末端连杆名称。
pub fn SimpleCartesianController::new(
  dof : Int,
  ee_name : String,
) -> SimpleCartesianController {
  {
    inner: CartesianController::new(
      SimpleIKSolver::new(dof),
      SimpleFKSolver::new(ee_name),
    ),
  }
}

///|
/// 规划直线轨迹。
pub fn SimpleCartesianController::move_to(
  self : SimpleCartesianController,
  current : Pose,
  target : Pose,
  velocity : Double,
  time_step : Double,
) -> CartesianTrajectory raise @core.RobotError {
  self.inner.move_to(current, target, velocity, time_step)
}

///|
/// 将笛卡尔轨迹转换为关节指令序列。
pub fn SimpleCartesianController::to_joint_states(
  self : SimpleCartesianController,
  traj : CartesianTrajectory,
) -> Array[Array[@core.JointState]] raise @core.RobotError {
  self.inner.to_joint_states(traj)
}

///|
/// 查询当前末端位姿。
pub fn SimpleCartesianController::get_end_effector_pose(
  self : SimpleCartesianController,
  joint_states : Array[@core.JointState],
) -> Pose {
  self.inner.get_end_effector_pose(joint_states)
}

///|
/// 查询末端连杆名称。
pub fn SimpleCartesianController::end_effector_name(
  self : SimpleCartesianController,
) -> String {
  self.inner.end_effector_name()
}

///|
/// 查询控制器自由度。
pub fn SimpleCartesianController::dof(self : SimpleCartesianController) -> Int {
  self.inner.dof()
}
