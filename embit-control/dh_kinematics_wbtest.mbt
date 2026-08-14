///|
/// DH 参数运动学白盒测试。

///|
/// DH 参数正运动学：零关节角度应返回基座变换。
test "DhFKSolver - zero joints" {
  let fk = DhFKSolver::arm_6dof()
  let joints : Array[@core.JointState] = [
    { name: "shoulder_pan", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "shoulder_lift", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "elbow", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "wrist_1", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "wrist_2", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "wrist_3", position: 0.0, velocity: 0.0, effort: 0.0 },
  ]
  let pose = fk.solve_fk(joints)
  let (x, _, _) = pose.position
  // 零关节角度时，末端 x 分量应为 a1 + a2 = 0.425 + 0.392 = 0.817
  assert_true((x - 0.817).abs() < 0.001)
}

///|
/// DH 参数正运动学：末端连杆名称正确。
test "DhFKSolver - end_effector name" {
  let fk = DhFKSolver::arm_6dof(ee_name="tool0")
  assert_eq(fk.end_effector(), "tool0")
}

///|
/// DH 参数正运动学：单关节旋转改变末端位置。
test "DhFKSolver - shoulder rotation changes x" {
  let fk = DhFKSolver::arm_6dof()
  let joints_zero : Array[@core.JointState] = [
    { name: "j1", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j2", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j3", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j4", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j5", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j6", position: 0.0, velocity: 0.0, effort: 0.0 },
  ]
  let pose_zero = fk.solve_fk(joints_zero)
  let joints_rot : Array[@core.JointState] = [
    { name: "j1", position: 1.5707963267948966, velocity: 0.0, effort: 0.0 },
    { name: "j2", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j3", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j4", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j5", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j6", position: 0.0, velocity: 0.0, effort: 0.0 },
  ]
  let pose_rot = fk.solve_fk(joints_rot)
  let (x0, y0, _) = pose_zero.position
  let (x1, y1, _) = pose_rot.position
  // 旋转 90° 后 x/y 应显著变化
  assert_true((x0 - x1).abs() > 0.1 || (y0 - y1).abs() > 0.1)
}

///|
/// DH 逆运动学：FK(IK(target)) ≈ target（往返一致性）。
test "DhIKSolver - fk after ik approximates target" {
  let fk = DhFKSolver::arm_6dof()
  let ik = DhIKSolver::new(fk, damping=0.1, max_iter=200, tolerance=0.0001)
  // 目标位姿：在机械臂工作空间内
  let target = Pose::new(0.3, 0.2, 0.5, 0.0, 1.57, 0.0)
  let joint_states = ik.solve_ik(target)
  // 用求得的关节角度做 FK
  let result = fk.solve_fk(joint_states)
  let (tx, ty, tz) = target.position
  let (rx, ry, rz) = result.position
  // 位置误差应小于 0.01 米
  let err = ((tx - rx) * (tx - rx) +
  (ty - ry) * (ty - ry) +
  (tz - rz) * (tz - rz)).sqrt()
  assert_true(err < 0.01)
}

///|
/// DH 逆运动学：dof 返回关节数。
test "DhIKSolver - dof" {
  let fk = DhFKSolver::arm_6dof()
  let ik = DhIKSolver::new(fk)
  assert_eq(ik.dof(), 6)
}

///|
/// DH 逆运动学：带种子求解。
test "DhIKSolver - solve with seed" {
  let fk = DhFKSolver::arm_6dof()
  let ik = DhIKSolver::new(fk, damping=0.1, max_iter=200, tolerance=0.0001)
  let target = Pose::new(0.4, 0.0, 0.3, 0.0, 1.57, 0.0)
  let seed : Array[@core.JointState] = [
    { name: "j1", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j2", position: -0.5, velocity: 0.0, effort: 0.0 },
    { name: "j3", position: 1.0, velocity: 0.0, effort: 0.0 },
    { name: "j4", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j5", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j6", position: 0.0, velocity: 0.0, effort: 0.0 },
  ]
  let joint_states = ik.solve_ik_with_seed(target, seed)
  let result = fk.solve_fk(joint_states)
  let (tx, ty, tz) = target.position
  let (rx, ry, rz) = result.position
  let err = ((tx - rx) * (tx - rx) +
  (ty - ry) * (ty - ry) +
  (tz - rz) * (tz - rz)).sqrt()
  assert_true(err < 0.01)
}

///|
/// DHParam::revolute 创建旋转关节。
test "DHParam - revolute" {
  let p = DHParam::revolute("joint1", 0.1, 0.0, 0.2, 0.0)
  assert_eq(p.name, "joint1")
  assert_true(p.revolute)
  assert_eq(p.a, 0.1)
  assert_eq(p.d, 0.2)
}

///|
/// DHParam::prismatic 创建移动关节。
test "DHParam - prismatic" {
  let p = DHParam::prismatic("joint1", 0.0, 0.0, 0.0, 0.0)
  assert_eq(p.name, "joint1")
  assert_true(!p.revolute)
}

///|
/// 高斯消元：已知方程组求解。
test "gauss_elimination - simple system" {
  // 2x + y = 5
  // x + 3y = 10
  // 解：x = 1, y = 3
  let a : Array[Array[Double]] = [[2.0, 1.0], [1.0, 3.0]]
  let b : Array[Double] = [5.0, 10.0]
  let x = gauss_elimination(a, b, 2)
  assert_true((x[0] - 1.0).abs() < 0.0001)
  assert_true((x[1] - 3.0).abs() < 0.0001)
}

///|
/// 高斯消元：3×3 方程组。
test "gauss_elimination - 3x3 system" {
  // x + y + z = 6
  // 2x - y + z = 3
  // x + 2y - z = 2
  // 解：x = 1, y = 2, z = 3
  let a : Array[Array[Double]] = [
    [1.0, 1.0, 1.0],
    [2.0, -1.0, 1.0],
    [1.0, 2.0, -1.0],
  ]
  let b : Array[Double] = [6.0, 3.0, 2.0]
  let x = gauss_elimination(a, b, 3)
  assert_true((x[0] - 1.0).abs() < 0.0001)
  assert_true((x[1] - 2.0).abs() < 0.0001)
  assert_true((x[2] - 3.0).abs() < 0.0001)
}

///|
/// DH FK：单关节正运动学。
test "DhFKSolver - single joint" {
  let fk = DhFKSolver::new([DHParam::revolute("j1", 1.0, 0.0, 0.0, 0.0)], "ee")
  let joints : Array[@core.JointState] = [
    { name: "j1", position: 0.0, velocity: 0.0, effort: 0.0 },
  ]
  let pose = fk.solve_fk(joints)
  let (x, _, _) = pose.position
  // a=1.0, theta=0 → x=1.0
  assert_true((x - 1.0).abs() < 0.001)
}

///|
/// DH FK：空关节列表返回单位变换。
test "DhFKSolver - empty joints" {
  let fk = DhFKSolver::new([], "ee")
  let pose = fk.solve_fk([])
  let (x, y, z) = pose.position
  assert_true(x.abs() < 0.001)
  assert_true(y.abs() < 0.001)
  assert_true(z.abs() < 0.001)
}

///|
/// DH FK：prismatic 关节沿 z 轴平移。
test "DhFKSolver - prismatic joint" {
  let fk = DhFKSolver::new([DHParam::prismatic("j1", 0.0, 0.0, 0.0, 0.0)], "ee")
  let joints : Array[@core.JointState] = [
    { name: "j1", position: 0.5, velocity: 0.0, effort: 0.0 },
  ]
  let pose = fk.solve_fk(joints)
  let (_, _, z) = pose.position
  // prismatic 关节位移 0.5 → z=0.5
  assert_true((z - 0.5).abs() < 0.001)
}

///|
/// DH IK：不可达目标不收敛（返回最优努力但不抛错）。
test "DhIKSolver - unreachable target best effort" {
  let fk = DhFKSolver::arm_6dof()
  let ik = DhIKSolver::new(fk, damping=0.1, max_iter=10, tolerance=0.0001)
  // 目标远超工作空间
  let target = Pose::new(100.0, 100.0, 100.0, 0.0, 0.0, 0.0)
  let joint_states = ik.solve_ik(target)
  let result = fk.solve_fk(joint_states)
  let (tx, ty, tz) = target.position
  let (rx, ry, rz) = result.position
  let err = ((tx - rx) * (tx - rx) +
  (ty - ry) * (ty - ry) +
  (tz - rz) * (tz - rz)).sqrt()
  // 不可达目标误差应很大
  assert_true(err > 1.0)
}

///|
/// 卡尔曼滤波：大时间步预测。
test "KalmanFilter1D - large dt predict" {
  let kf = KalmanFilter1D::with_initial(0.0, 1.0, 0.001, 0.01, 0.1)
  kf.predict(1.0)
  // pos = 0 + 1.0*1.0 = 1.0
  assert_kf_approx(kf.get_pos(), 1.0)
  assert_kf_approx(kf.get_vel(), 1.0)
}

///|
/// 卡尔曼滤波：零时间步预测不改变状态。
test "KalmanFilter1D - zero dt predict" {
  let kf = KalmanFilter1D::with_initial(0.5, 0.3, 0.001, 0.01, 0.1)
  kf.predict(0.0)
  assert_eq(kf.get_pos(), 0.5)
  assert_eq(kf.get_vel(), 0.3)
}

///|
/// 卡尔曼滤波：高测量噪声应更信任预测。
test "KalmanFilter1D - high measurement noise" {
  // 高 R → 滤波器更信任预测模型，收敛慢
  let kf_high_r = KalmanFilter1D::new(0.001, 0.01, 10.0)
  // 低 R → 滤波器更信任观测，收敛快
  let kf_low_r = KalmanFilter1D::new(0.001, 0.01, 0.001)
  // 低 R 在 5 步内应接近 1.0
  for _ in 0..<5 {
    kf_low_r.step(1.0, 0.01)
  }
  assert_kf_approx(kf_low_r.get_pos(), 1.0)
  // 高 R 在 5 步内尚未收敛
  for _ in 0..<5 {
    kf_high_r.step(1.0, 0.01)
  }
  assert_true((kf_high_r.get_pos() - 1.0).abs() > 0.1)
  // 但高 R 在 1000 步后也收敛
  for _ in 0..<995 {
    kf_high_r.step(1.0, 0.01)
  }
  assert_kf_approx(kf_high_r.get_pos(), 1.0)
}

// ===== 边缘 case 覆盖测试 =====

///|
/// DhFKSolver::fk 关节角度数不足应抛出错误。
test "DhFKSolver - fk rejects mismatched angle count" {
  let fk = DhFKSolver::arm_6dof()
  try fk.fk([0.0, 0.0, 0.0]) catch {
    InvalidConfig(msg) => assert_true(msg.contains("joint angles"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|

///|
/// DhIKSolver::solve 初始猜测长度不足应抛出错误。
test "DhIKSolver - solve rejects mismatched initial guess" {
  let fk = DhFKSolver::arm_6dof()
  let ik = DhIKSolver::new(fk)
  let target = Pose::new(0.5, 0.0, 0.5, 0.0, 0.0, 0.0)
  try ik.solve(target, [0.0, 0.0, 0.0]) catch {
    InvalidConfig(msg) => assert_true(msg.contains("initial joint values"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// DhIKSolver::solve_ik_with_seed 种子关节数少于参数数时应补零。
test "DhIKSolver - solve_ik_with_seed with fewer seed joints" {
  let fk = DhFKSolver::arm_6dof()
  let ik = DhIKSolver::new(fk)
  let target = Pose::new(0.5, 0.0, 0.5, 0.0, 0.0, 0.0)
  // 只提供 3 个种子关节（少于 6 个参数），应自动补零
  let seed : Array[@core.JointState] = [
    { name: "j1", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j2", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "j3", position: 0.0, velocity: 0.0, effort: 0.0 },
  ]
  let result = ik.solve_ik_with_seed(target, seed)
  assert_eq(result.length(), 6)
}

///|
/// DhIKSolver 空 DH 参数时求解应安全处理空雅可比。
test "DhIKSolver - solve with zero params handles empty jacobian" {
  let fk = DhFKSolver::new([], "ee")
  let ik = DhIKSolver::new(fk, max_iter=3)
  let target = Pose::new(1.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  let result = ik.solve(target, [])
  assert_eq(result.length(), 0)
}
