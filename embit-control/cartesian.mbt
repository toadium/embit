///|
/// 笛卡尔空间轨迹点。
pub(all) struct CartesianWaypoint {
  pose : Pose
  timestamp : Double
} derive(Eq, Debug)

///|
/// 笛卡尔空间轨迹。
pub(all) struct CartesianTrajectory {
  waypoints : Array[CartesianWaypoint]
  duration : Double
} derive(Eq, Debug)

///|
/// 创建空笛卡尔轨迹。
pub fn CartesianTrajectory::empty() -> CartesianTrajectory {
  { waypoints: [], duration: 0.0 }
}

///|
/// 笛卡尔轨迹点数。
pub fn CartesianTrajectory::length(self : CartesianTrajectory) -> Int {
  self.waypoints.length()
}

///|
/// 笛卡尔空间控制器：末端位姿规划与执行。
///
/// 在笛卡尔空间规划轨迹（直线/圆弧），通过逆运动学转换为关节指令。
/// 需要绑定 `IKSolver` 与 `FKSolver` 实现具体机型的运动学解算。
///
/// 泛型参数 `IK` 为逆运动学解算器类型，`FK` 为正运动学解算器类型。
pub struct CartesianController[IK, FK] {
  ik_solver : IK
  fk_solver : FK
}

///|
/// 创建笛卡尔控制器。
pub fn[IK, FK] CartesianController::new(
  ik_solver : IK,
  fk_solver : FK,
) -> CartesianController[IK, FK] {
  { ik_solver, fk_solver }
}

///|
/// 规划直线轨迹：从当前位姿到目标位姿的线性插值。
///
/// `current` 为当前末端位姿，`target` 为目标位姿，
/// `velocity` 为末端线速度（m/s），`time_step` 为采样间隔。
pub fn[IK, FK] CartesianController::move_to(
  self : CartesianController[IK, FK],
  current : Pose,
  target : Pose,
  velocity : Double,
  time_step : Double,
) -> CartesianTrajectory raise @core.RobotError {
  ignore(self)
  if velocity <= 0.0 || time_step <= 0.0 {
    raise InvalidConfig("velocity and time_step must be positive")
  }
  let (cx, cy, cz) = current.position
  let (tx, ty, tz) = target.position
  let dx = tx - cx
  let dy = ty - cy
  let dz = tz - cz
  let distance = (dx * dx + dy * dy + dz * dz).sqrt()
  let duration = distance / velocity
  let (cr, cp, cyaw) = current.orientation
  let (tr, tp, tyaw) = target.orientation
  let waypoints : Array[CartesianWaypoint] = []
  let steps = (duration / time_step).ceil().to_int()
  let actual_steps = if steps > 0 { steps } else { 1 }
  for step in 0..<=actual_steps {
    let alpha = if actual_steps == 0 {
      1.0
    } else {
      step.to_double() / actual_steps.to_double()
    }
    let t = duration * alpha
    let pose : Pose = {
      position: (cx + dx * alpha, cy + dy * alpha, cz + dz * alpha),
      orientation: (
        cr + (tr - cr) * alpha,
        cp + (tp - cp) * alpha,
        cyaw + (tyaw - cyaw) * alpha,
      ),
    }
    waypoints.push({ pose, timestamp: t })
  }
  { waypoints, duration }
}

///|
/// 将笛卡尔轨迹转换为关节指令序列。
///
/// 通过逆运动学将每个笛卡尔位姿解算为关节角度。
pub fn[IK : IKSolver, FK] CartesianController::to_joint_states(
  self : CartesianController[IK, FK],
  traj : CartesianTrajectory,
) -> Array[Array[@core.JointState]] raise @core.RobotError {
  let result : Array[Array[@core.JointState]] = []
  for wp in traj.waypoints {
    let joint_states = self.ik_solver.solve_ik(wp.pose)
    result.push(joint_states)
  }
  result
}

///|
/// 查询当前末端位姿（通过正运动学）。
///
/// `joint_states` 为当前关节状态。
pub fn[IK, FK : FKSolver] CartesianController::get_end_effector_pose(
  self : CartesianController[IK, FK],
  joint_states : Array[@core.JointState],
) -> Pose {
  self.fk_solver.solve_fk(joint_states)
}

///|
/// 查询末端连杆名称。
pub fn[IK, FK : FKSolver] CartesianController::end_effector_name(
  self : CartesianController[IK, FK],
) -> String {
  self.fk_solver.end_effector()
}

///|
/// 查询控制器自由度。
pub fn[IK : IKSolver, FK] CartesianController::dof(
  self : CartesianController[IK, FK],
) -> Int {
  self.ik_solver.dof()
}
