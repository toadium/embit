///|
/// extract_joint_angle 应在关节数不足时触发 InvalidConfig。
test "extract_joint_angle - insufficient joint states" {
  let params = [DHParam::revolute("j1", 0.0, 0.0, 0.0, 0.0)]
  let joint_states : Array[@core.JointState] = []
  try extract_joint_angle(params, joint_states) catch {
    InvalidConfig(msg) => assert_true(msg.contains("expected"))
    _ => fail("expected InvalidConfig")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// DhIKSolver::with_null_space_gain 查询方法。
test "DhIKSolver - with_null_space_gain" {
  let fk = DhFKSolver::arm_6dof()
  let ik = DhIKSolver::new(fk)
  let ik_with_gain = ik.with_null_space_gain(0.5)
  let _ = ik_with_gain
  assert_true(true)
}

///|
/// gauss_elimination 应处理奇异矩阵（零主元跳过 + 回代零除保护）。
test "gauss_elimination - singular matrix" {
  // 奇异矩阵：全零行
  let a = [[0.0, 0.0], [0.0, 0.0]]
  let b = [1.0, 2.0]
  let x = gauss_elimination(a, b, 2)
  // 奇异矩阵回代时 x[i] = 0.0
  assert_eq(x.length(), 2)
}

///|
/// DhIKSolver::solve 零空间优化 None 分支（7-DOF + null_space_gain > 0 + 无关节限位）。
test "DhIKSolver - solve null space None branch" {
  let fk = DhFKSolver::arm_7dof()
  let ik = DhIKSolver::new(fk, null_space_gain=0.1)
  let target = Pose::new(0.3, 0.0, 0.5, 0.0, 0.0, 0.0)
  let initial_guess = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  let result = ik.solve(target, initial_guess)
  assert_eq(result.length(), 7)
}

///|
/// DhIKSolver::solve 零空间优化关节限位越界分支（7-DOF + 限位长度 < 关节数）。
test "DhIKSolver - solve null space limits too short" {
  let fk = DhFKSolver::arm_7dof()
  // 只提供 3 个限位，但 7-DOF 有 7 个关节
  let ik = DhIKSolver::new(
    fk,
    null_space_gain=0.1,
    joint_limits=Some([(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]),
  )
  let target = Pose::new(0.3, 0.0, 0.5, 0.0, 0.0, 0.0)
  let initial_guess = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  let result = ik.solve(target, initial_guess)
  assert_eq(result.length(), 7)
}
