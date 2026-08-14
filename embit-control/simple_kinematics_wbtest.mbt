///|
/// 简化运动学解算器白盒测试。

///|
/// SimpleIKSolver 基本逆运动学。
test "SimpleIKSolver - solve_ik maps pose to joints" {
  let ik = SimpleIKSolver::new(6)
  let pose = Pose::{ position: (1.0, 2.0, 3.0), orientation: (0.1, 0.2, 0.3) }
  let joints = ik.solve_ik(pose)
  assert_eq(joints.length(), 6)
  assert_eq(joints[0].position, 1.0)
  assert_eq(joints[1].position, 2.0)
  assert_eq(joints[2].position, 3.0)
  assert_eq(joints[3].position, 0.1)
  assert_eq(joints[4].position, 0.2)
  assert_eq(joints[5].position, 0.3)
}

///|
/// SimpleIKSolver::solve_ik_with_seed 应忽略种子直接求解。
test "SimpleIKSolver - solve_ik_with_seed ignores seed" {
  let ik = SimpleIKSolver::new(6)
  let pose = Pose::{ position: (0.5, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  let seed : Array[@core.JointState] = [
    { name: "j1", position: 99.0, velocity: 0.0, effort: 0.0 },
    { name: "j2", position: 99.0, velocity: 0.0, effort: 0.0 },
    { name: "j3", position: 99.0, velocity: 0.0, effort: 0.0 },
    { name: "j4", position: 99.0, velocity: 0.0, effort: 0.0 },
    { name: "j5", position: 99.0, velocity: 0.0, effort: 0.0 },
    { name: "j6", position: 99.0, velocity: 0.0, effort: 0.0 },
  ]
  let joints = ik.solve_ik_with_seed(pose, seed)
  assert_eq(joints.length(), 6)
  // 应忽略种子，直接映射位姿
  assert_eq(joints[0].position, 0.5)
}

///|
/// SimpleIKSolver::dof 返回自由度。
test "SimpleIKSolver - dof" {
  let ik = SimpleIKSolver::new(7)
  assert_eq(ik.dof(), 7)
}

///|
/// SimpleFKSolver 基本正运动学。
test "SimpleFKSolver - solve_fk maps joints to pose" {
  let fk = SimpleFKSolver::new("ee_link")
  let joints : Array[@core.JointState] = [
    { name: "j1", position: 1.0, velocity: 0.0, effort: 0.0 },
    { name: "j2", position: 2.0, velocity: 0.0, effort: 0.0 },
    { name: "j3", position: 3.0, velocity: 0.0, effort: 0.0 },
    { name: "j4", position: 0.1, velocity: 0.0, effort: 0.0 },
    { name: "j5", position: 0.2, velocity: 0.0, effort: 0.0 },
    { name: "j6", position: 0.3, velocity: 0.0, effort: 0.0 },
  ]
  let pose = fk.solve_fk(joints)
  let (x, y, z) = pose.position
  assert_eq(x, 1.0)
  assert_eq(y, 2.0)
  assert_eq(z, 3.0)
}

///|
/// SimpleFKSolver::end_effector 返回末端名称。
test "SimpleFKSolver - end_effector" {
  let fk = SimpleFKSolver::new("tool0")
  assert_eq(fk.end_effector(), "tool0")
}

///|
/// SimpleCartesianController 端到端测试。
test "SimpleCartesianController - move_to and end_effector" {
  let ctrl = SimpleCartesianController::new(6, "gripper")
  assert_eq(ctrl.end_effector_name(), "gripper")
  assert_eq(ctrl.dof(), 6)
  let current = Pose::{
    position: (0.0, 0.0, 0.0),
    orientation: (0.0, 0.0, 0.0),
  }
  let target = Pose::{ position: (0.1, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  let traj = ctrl.move_to(current, target, 0.05, 0.01)
  assert_true(traj.waypoints.length() > 1)
}
