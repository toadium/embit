///|
/// embit-control 白盒测试：笛卡尔空间控制器。
///
/// 使用 MockIKSolver / MockFKSolver 验证 CartesianController 的
/// 轨迹规划、逆运动学转换与正运动学查询。

///|
/// 模拟逆运动学解算器（6-DOF）。
///
/// 将笛卡尔位姿 (x, y, z, roll, pitch, yaw) 映射为 6 个关节角度。
struct MockIKSolver {
  dof_value : Int
}

///|
fn MockIKSolver::new(dof : Int) -> MockIKSolver {
  { dof_value: dof }
}

///|
impl IKSolver for MockIKSolver with fn solve_ik(self, pose) {
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
impl IKSolver for MockIKSolver with fn solve_ik_with_seed(self, pose, _seed) -> Array[
  @core.JointState,
] raise @core.RobotError {
  self.solve_ik(pose)
}

///|
impl IKSolver for MockIKSolver with fn dof(self) {
  self.dof_value
}

///|
extend MockIKSolver with IKSolver::{solve_ik}

///|
/// 模拟正运动学解算器（6-DOF）。
///
/// 将 6 个关节角度映射为笛卡尔位姿 (x, y, z, roll, pitch, yaw)。
struct MockFKSolver {
  ee_name : String
}

///|
fn MockFKSolver::new(ee : String) -> MockFKSolver {
  { ee_name: ee }
}

///|
impl FKSolver for MockFKSolver with fn solve_fk(self, joint_states) {
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
impl FKSolver for MockFKSolver with fn end_effector(self) {
  self.ee_name
}

///|

///|
/// 创建测试用笛卡尔控制器（6-DOF）。
fn make_controller() -> CartesianController[MockIKSolver, MockFKSolver] {
  CartesianController::new(MockIKSolver::new(6), MockFKSolver::new("ee_link"))
}

///|
/// 控制器自由度应等于 IK 解算器自由度。
test "CartesianController - dof matches ik solver" {
  let ctrl = make_controller()
  assert_eq(ctrl.dof(), 6)
}

///|
/// 末端连杆名称应等于 FK 解算器返回值。
test "CartesianController - end_effector_name" {
  let ctrl = make_controller()
  assert_eq(ctrl.end_effector_name(), "ee_link")
}

///|
/// 相同位姿的 move_to 应生成单点轨迹（距离为零）。
test "CartesianController - move_to same pose" {
  let ctrl = make_controller()
  let pose = Pose::{ position: (1.0, 2.0, 3.0), orientation: (0.0, 0.0, 0.0) }
  let traj = ctrl.move_to(pose, pose, 1.0, 0.1)
  assert_true(traj.length() >= 1)
  assert_true(traj.duration < 0.001)
}

///|
/// move_to 应生成线性插值轨迹，起点和终点匹配。
test "CartesianController - move_to linear interpolation" {
  let ctrl = make_controller()
  let start = Pose::{ position: (0.0, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  let target = Pose::{ position: (1.0, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  let traj = ctrl.move_to(start, target, 1.0, 0.1)
  // 距离 = 1.0, 速度 = 1.0, 时长 = 1.0s
  assert_true((traj.duration - 1.0).abs() < 0.001)
  // 轨迹点数应 > 1
  assert_true(traj.length() > 1)
  // 第一个点应为起点
  let first = traj.waypoints[0]
  let (fx, _, _) = first.pose.position
  assert_true(fx.abs() < 0.001)
  // 最后一个点应为终点
  let last = traj.waypoints[traj.length() - 1]
  let (lx, _, _) = last.pose.position
  assert_true((lx - 1.0).abs() < 0.001)
}

///|
/// move_to 的时间戳应单调递增。
test "CartesianController - move_to timestamps monotonic" {
  let ctrl = make_controller()
  let start = Pose::{ position: (0.0, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  let target = Pose::{ position: (0.0, 0.0, 2.0), orientation: (0.0, 0.0, 0.0) }
  let traj = ctrl.move_to(start, target, 1.0, 0.2)
  for i in 1..<traj.length() {
    assert_true(traj.waypoints[i].timestamp >= traj.waypoints[i - 1].timestamp)
  }
}

///|
/// move_to 零速度应抛出 InvalidConfig。
test "CartesianController - move_to zero velocity raises" {
  let ctrl = make_controller()
  let start = Pose::{ position: (0.0, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  let target = Pose::{ position: (1.0, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  try ctrl.move_to(start, target, 0.0, 0.1) catch {
    InvalidConfig(msg) => assert_true(msg.contains("velocity"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// move_to 零时间步应抛出 InvalidConfig。
test "CartesianController - move_to zero time_step raises" {
  let ctrl = make_controller()
  let start = Pose::{ position: (0.0, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  let target = Pose::{ position: (1.0, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  try ctrl.move_to(start, target, 1.0, 0.0) catch {
    InvalidConfig(msg) => assert_true(msg.contains("time_step"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// to_joint_states 应将每个笛卡尔位姿转换为关节状态序列。
test "CartesianController - to_joint_states" {
  let ctrl = make_controller()
  let traj = CartesianTrajectory::{
    waypoints: [
      {
        pose: { position: (1.0, 2.0, 3.0), orientation: (0.0, 0.0, 0.0) },
        timestamp: 0.0,
      },
      {
        pose: { position: (1.5, 2.0, 3.0), orientation: (0.0, 0.0, 0.0) },
        timestamp: 0.5,
      },
    ],
    duration: 0.5,
  }
  let joint_seqs = ctrl.to_joint_states(traj)
  assert_eq(joint_seqs.length(), 2)
  // 每组应有 6 个关节状态
  assert_eq(joint_seqs[0].length(), 6)
  // 第一个关节的 position 应等于 x 坐标
  assert_true((joint_seqs[0][0].position - 1.0).abs() < 0.001)
  assert_true((joint_seqs[1][0].position - 1.5).abs() < 0.001)
}

///|
/// get_end_effector_pose 应通过正运动学返回末端位姿。
test "CartesianController - get_end_effector_pose" {
  let ctrl = make_controller()
  let joints : Array[@core.JointState] = [
    { name: "j1", position: 1.0, velocity: 0.0, effort: 0.0 },
    { name: "j2", position: 2.0, velocity: 0.0, effort: 0.0 },
    { name: "j3", position: 3.0, velocity: 0.0, effort: 0.0 },
    { name: "j4", position: 0.5, velocity: 0.0, effort: 0.0 },
    { name: "j5", position: 0.3, velocity: 0.0, effort: 0.0 },
    { name: "j6", position: 0.1, velocity: 0.0, effort: 0.0 },
  ]
  let pose = ctrl.get_end_effector_pose(joints)
  let (x, y, z) = pose.position
  let (r, p, yaw) = pose.orientation
  assert_true((x - 1.0).abs() < 0.001)
  assert_true((y - 2.0).abs() < 0.001)
  assert_true((z - 3.0).abs() < 0.001)
  assert_true((r - 0.5).abs() < 0.001)
  assert_true((p - 0.3).abs() < 0.001)
  assert_true((yaw - 0.1).abs() < 0.001)
}

///|
/// 完整管线：move_to → to_joint_states → get_end_effector_pose 应保持位姿一致性。
test "CartesianController - full pipeline consistency" {
  let ctrl = make_controller()
  let start = Pose::{ position: (0.0, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  let target = Pose::{ position: (0.5, 0.3, 0.2), orientation: (0.1, 0.2, 0.3) }
  // 1. 规划笛卡尔轨迹
  let traj = ctrl.move_to(start, target, 0.5, 0.1)
  assert_true(traj.length() > 1)
  // 2. 转换为关节状态序列
  let joint_seqs = ctrl.to_joint_states(traj)
  assert_eq(joint_seqs.length(), traj.length())
  // 3. 对每个关节状态做正运动学，验证位姿一致性
  for i in 0..<joint_seqs.length() {
    let pose = ctrl.get_end_effector_pose(joint_seqs[i])
    let (tx, ty, tz) = traj.waypoints[i].pose.position
    let (px, py, pz) = pose.position
    assert_true((px - tx).abs() < 0.001)
    assert_true((py - ty).abs() < 0.001)
    assert_true((pz - tz).abs() < 0.001)
  }
}

///|
/// 空轨迹的 to_joint_states 应返回空数组。
test "CartesianController - to_joint_states empty trajectory" {
  let ctrl = make_controller()
  let traj = CartesianTrajectory::empty()
  let result = ctrl.to_joint_states(traj)
  assert_eq(result.length(), 0)
}

///|
/// CartesianTrajectory::empty 应创建空轨迹。
test "CartesianTrajectory - empty" {
  let traj = CartesianTrajectory::empty()
  assert_eq(traj.length(), 0)
  assert_true(traj.duration.abs() < 0.001)
}

///|
/// 3D 空间对角线移动应正确计算距离。
test "CartesianController - diagonal 3d move" {
  let ctrl = make_controller()
  let start = Pose::{ position: (0.0, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  let target = Pose::{ position: (1.0, 1.0, 1.0), orientation: (0.0, 0.0, 0.0) }
  let traj = ctrl.move_to(start, target, 1.0, 0.1)
  // 距离 = sqrt(3) ≈ 1.732, 速度 = 1.0, 时长 ≈ 1.732s
  let expected = 1.7320508
  assert_true((traj.duration - expected).abs() < 0.01)
}
