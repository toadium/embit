///|
/// embit-control 性能基准测试：验证关键算法在大规模迭代下的正确性与可扩展性。
///
/// 这些测试运行大量迭代以验证算法性能特征：
/// - 轨迹规划：1000 次轨迹计算
/// - PID 控制：10000 次控制环路更新
/// - 阻抗控制：10000 次力位混合控制
/// - 传感器融合：10000 次滤波更新
/// - IK/FK 解算：1000 次运动学解算
/// - 笛卡尔控制：500 次 move_to + to_joint_states 管线

///|
/// 轨迹规划基准：1000 次三次轨迹计算应正确完成。
test "bench - trajectory computation 1000 iterations" {
  let robot_model : @core.RobotModel = {
    urdf_path: "",
    joints: [],
    sensors: [],
    limits: {
      max_joint_velocity: 2.0,
      max_joint_effort: 50.0,
      collision_check_distance: 0.05,
    },
  }
  let ctrl = MotionController::new(robot_model)
  let start : Array[(String, Double)] = [("j1", 0.0), ("j2", 0.0)]
  let goal : Array[(String, Double)] = [("j1", 1.0), ("j2", 0.5)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 2.0,
    max_acceleration: 5.0,
    time_step: 0.01,
  }
  for _ in 0..<1000 {
    let traj = ctrl.compute_trajectory_cubic(start, goal, constraints)
    assert_true(traj.length() > 1)
    let cmds = traj.to_commands()
    assert_true(cmds.length() > 0)
  }
}

///|
/// PID 控制基准：10000 次控制环路更新应正确收敛。
test "bench - PID controller 10000 iterations" {
  let pid = PIDController::new(1.0, 0.1, 0.01)
  pid.set_output_limits(-10.0, 10.0)
  let target = 1.0
  let mut current = 0.0
  let dt = 0.01
  for _ in 0..<10000 {
    let output = pid.update(target, current, dt)
    current = current + output * dt
  }
  // 经过 10000 步（100s），应收敛到目标
  assert_true((current - target).abs() < 0.1)
}

///|
/// 阻抗控制基准：10000 次力位混合控制应正确收敛。
test "bench - impedance controller 10000 iterations" {
  let imp = ImpedanceController::new(100.0, 20.0)
  imp.set_target(0.5, 0.0)
  let dt = 0.001
  let mut pos = 0.0
  let mut vel = 0.0
  for _ in 0..<10000 {
    let force = imp.compute(pos, vel)
    let accel = force
    vel = vel + accel * dt
    pos = pos + vel * dt
  }
  // 经过 10000 步（10s），应收敛到目标位置
  assert_true((pos - 0.5).abs() < 0.05)
}

///|
/// 传感器融合基准：10000 次滤波更新应正确跟踪。
test "bench - sensor fusion 10000 iterations" {
  let fusion = SensorFusion::new(0.98)
  let dt = 0.01
  for i in 0..<10000 {
    let t = i.to_double() * dt
    let gyro_rate = @math.cos(t * 10.0)
    let accel_angle = @math.sin(t * 10.0)
    fusion.update(gyro_rate, accel_angle, dt)
  }
  // 融合后应产生有效的角度值
  let angle = fusion.get_orientation()
  assert_true(angle.abs() < 100.0)
}

///|
/// IK/FK 解算基准：1000 次运动学解算应保持一致性。
test "bench - IK/FK solve 1000 iterations" {
  let ik = SimpleIKSolver::new(6)
  let fk = SimpleFKSolver::new("ee_link")
  for i in 0..<1000 {
    let x = i.to_double() * 0.001
    let pose : Pose = {
      position: (x, x * 0.5, x * 0.3),
      orientation: (0.0, 0.0, 0.0),
    }
    // IK：位姿 → 关节
    let joints = ik.solve_ik(pose)
    assert_eq(joints.length(), 6)
    // FK：关节 → 位姿
    let recovered = fk.solve_fk(joints)
    let (rx, ry, rz) = recovered.position
    assert_true((rx - x).abs() < 0.001)
    assert_true((ry - x * 0.5).abs() < 0.001)
    assert_true((rz - x * 0.3).abs() < 0.001)
  }
}

///|
/// 笛卡尔控制管线基准：500 次 move_to + to_joint_states 应正确完成。
test "bench - cartesian pipeline 500 iterations" {
  let ctrl = SimpleCartesianController::new(6, "ee_link")
  let start : Pose = Pose::new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  for i in 0..<500 {
    let tx = i.to_double() * 0.002
    let target : Pose = Pose::new(tx, 0.1, 0.05, 0.0, 0.0, 0.0)
    let traj = ctrl.move_to(start, target, 1.0, 0.05)
    assert_true(traj.length() > 1)
    let joint_seqs = ctrl.to_joint_states(traj)
    assert_eq(joint_seqs.length(), traj.length())
    // 验证末端位姿一致性
    let last_pose = ctrl.get_end_effector_pose(
      joint_seqs[joint_seqs.length() - 1],
    )
    let (lx, _, _) = last_pose.position
    assert_true((lx - tx).abs() < 0.001)
  }
}

///|
/// 关节组管理基准：大规模关节组操作应正确完成。
test "bench - joint group large scale" {
  let joint_names : Array[String] = []
  for i in 0..<100 {
    joint_names.push("joint_\{i}")
  }
  let group = JointGroup::new("large_group", joint_names)
  assert_eq(group.size(), 100)
  // 批量设置
  let values : Array[(String, Double)] = []
  for i in 0..<100 {
    values.push(("joint_\{i}", i.to_double() * 0.01))
  }
  group.set_positions(values)
  // 验证
  for i in 0..<100 {
    let v = group.get_position("joint_\{i}")
    assert_true((v - i.to_double() * 0.01).abs() < 0.001)
  }
  // 重置
  group.reset()
  for i in 0..<100 {
    let v = group.get_position("joint_\{i}")
    assert_true(v.abs() < 0.001)
  }
}

///|
/// 五次轨迹规划基准：500 次五次多项式轨迹计算。
test "bench - quintic trajectory 500 iterations" {
  let robot_model : @core.RobotModel = {
    urdf_path: "",
    joints: [],
    sensors: [],
    limits: {
      max_joint_velocity: 2.0,
      max_joint_effort: 50.0,
      collision_check_distance: 0.05,
    },
  }
  let ctrl = MotionController::new(robot_model)
  let start : Array[(String, Double)] = [("j1", 0.0)]
  let goal : Array[(String, Double)] = [("j1", 3.14)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 2.0,
    max_acceleration: 5.0,
    time_step: 0.02,
  }
  for _ in 0..<500 {
    let traj = ctrl.compute_trajectory_quintic(start, goal, constraints)
    assert_true(traj.length() > 1)
  }
}

///|
/// 轨迹融合基准：1000 次轨迹拼接。
test "bench - trajectory blend 1000 iterations" {
  let robot_model : @core.RobotModel = {
    urdf_path: "",
    joints: [],
    sensors: [],
    limits: {
      max_joint_velocity: 2.0,
      max_joint_effort: 50.0,
      collision_check_distance: 0.05,
    },
  }
  let ctrl = MotionController::new(robot_model)
  let s1 : Array[(String, Double)] = [("j1", 0.0)]
  let g1 : Array[(String, Double)] = [("j1", 1.0)]
  let g2 : Array[(String, Double)] = [("j1", 2.0)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 2.0,
    max_acceleration: 5.0,
    time_step: 0.05,
  }
  for _ in 0..<1000 {
    let traj1 = ctrl.compute_trajectory(s1, g1, constraints)
    let traj2 = ctrl.compute_trajectory(g1, g2, constraints)
    let blended = Trajectory::blend(traj1, traj2, 0.1)
    assert_true(blended.length() > 0)
  }
}

// ===== DH 运动学 & 卡尔曼滤波性能基准 =====

///|
/// DH 正运动学基准：1000 次 6-DOF FK 解算。
test "bench - DH forward kinematics 1000 iterations" {
  let fk = DhFKSolver::arm_6dof()
  let angles : Array[Double] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6]
  for _ in 0..<1000 {
    let tf = fk.fk(angles)
    let (x, _, _) = tf.translation
    assert_true(x.abs() < 10.0)
  }
}

///|
/// DH 逆运动学基准：100 次 6-DOF IK 迭代求解。
test "bench - DH inverse kinematics 100 iterations" {
  let fk = DhFKSolver::arm_6dof()
  let ik = DhIKSolver::new(fk)
  let target = Pose::new(0.5, 0.1, 0.3, 0.0, 1.57, 0.0)
  for _ in 0..<100 {
    let q = ik.solve(target, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    assert_eq(q.length(), 6)
  }
}

///|
/// 卡尔曼滤波基准：10000 次 predict + update 循环。
test "bench - Kalman filter 10000 iterations" {
  let kf = KalmanFilter1D::new(0.001, 0.01, 0.1)
  let dt = 0.01
  let mut true_pos = 0.0
  let true_vel = 2.0
  for _ in 0..<10000 {
    true_pos = true_pos + true_vel * dt
    kf.step(true_pos, dt)
  }
  // 滤波后应跟踪真实位置
  assert_true((kf.get_pos() - true_pos).abs() < 0.1)
  assert_true((kf.get_vel() - true_vel).abs() < 0.1)
}

///|
/// 状态估计器卡尔曼模式基准：5000 次多关节滤波。
test "bench - StateEstimator kalman 5000 iterations" {
  let est = StateEstimator::new_kalman(0.001, 0.01, 0.1)
  for _ in 0..<5000 {
    let observed : Array[@core.JointState] = [
      { name: "j1", position: 1.0, velocity: 0.5, effort: 0.0 },
      { name: "j2", position: -0.5, velocity: 0.3, effort: 0.0 },
      { name: "j3", position: 0.8, velocity: -0.2, effort: 0.0 },
    ]
    est.update_joints(observed, 0.01)
  }
  let state = est.get_state()
  assert_eq(state.length(), 3)
}
