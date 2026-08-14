///|
/// 人形腿逆运动学白盒测试。

///|
/// 2-DOF 平面解：膝盖完全伸直时，末端距离 = L1 + L2。
test "LegIKSolver - planar straight leg" {
  let solver = LegIKSolver::new(0.4, 0.4)
  // 目标在正前方，距离 = L1 + L2 = 0.8
  let (hip, knee) = solver.solve_planar(0.8, 0.0)
  // 膝盖伸直：knee_pitch ≈ 0
  assert_true(knee.abs() < 0.001)
  // hip 指向正前方：atan2(0.8, 0) = π/2
  assert_true((hip - 1.5707963267948966).abs() < 0.001)
}

///|
/// 2-DOF 平面解：膝盖弯曲 90° 时，末端在 (L2, L1)。
test "LegIKSolver - planar 90 degree knee" {
  let solver = LegIKSolver::new(0.3, 0.3)
  // 膝盖弯曲 90°：末端位于 (L2, L1) = (0.3, 0.3)
  let (hip, knee) = solver.solve_planar(0.3, 0.3)
  // knee_pitch ≈ -π/2（负值表示向后弯曲）
  assert_true((knee + 1.5707963267948966).abs() < 0.01)
  // hip_pitch 应使大腿指向对角线方向
  let expected_hip = @math.atan2(0.3, 0.3) -
    @math.atan2(0.3 * @math.sin(knee), 0.3 + 0.3 * @math.cos(knee))
  assert_true((hip - expected_hip).abs() < 0.01)
}

///|
/// 2-DOF 平面解：目标不可达（超出最大伸展）应抛出异常。
test "LegIKSolver - planar unreachable raises" {
  let solver = LegIKSolver::new(0.3, 0.3)
  // 最大伸展 0.6，目标 1.0 不可达
  let raised = try {
    let _ = solver.solve_planar(1.0, 0.0)
    false
  } catch {
    UnsupportedRobotType(_) => true
    _ => false
  }
  assert_true(raised)
}

///|
/// 2-DOF 平面解：目标太近（小于 |L1 - L2|）应抛出异常。
test "LegIKSolver - planar too close raises" {
  let solver = LegIKSolver::new(0.4, 0.2)
  // |L1 - L2| = 0.2，目标 0.05 太近
  let raised = try {
    let _ = solver.solve_planar(0.05, 0.0)
    false
  } catch {
    UnsupportedRobotType(_) => true
    _ => false
  }
  assert_true(raised)
}

///|
/// 2-DOF 平面解：往返一致——FK(IK(target)) ≈ target。
test "LegIKSolver - planar round trip" {
  let l1 = 0.4
  let l2 = 0.35
  let solver = LegIKSolver::new(l1, l2)
  // 目标位置
  let r = 0.5
  let z = 0.2
  let (hip_pitch, knee_pitch) = solver.solve_planar(r, z)
  // 正运动学：末端位置
  // x = L1·sin(hip) + L2·sin(hip + knee)
  // z = L1·cos(hip) + L2·cos(hip + knee)
  let x_recon = l1 * @math.sin(hip_pitch) +
    l2 * @math.sin(hip_pitch + knee_pitch)
  let z_recon = l1 * @math.cos(hip_pitch) +
    l2 * @math.cos(hip_pitch + knee_pitch)
  assert_true((x_recon - r).abs() < 0.001)
  assert_true((z_recon - z).abs() < 0.001)
}

///|
/// 6-DOF 解：dof() 返回 6。
test "LegIKSolver - dof is 6" {
  let solver = LegIKSolver::new(0.4, 0.4)
  assert_eq(solver.dof(), 6)
}

///|
/// 6-DOF 解：目标在正前方，hip_yaw 应为 0。
test "LegIKSolver - 6dof forward target" {
  let solver = LegIKSolver::new(0.4, 0.4, ankle_height=0.0)
  let target = Pose::{ position: (0.6, 0.0, 0.0), orientation: (0.0, 0.0, 0.0) }
  let (hip_yaw, hip_roll, _, _, _, ankle_roll) = solver.solve_6dof(target)
  // y = 0 → hip_yaw = atan2(0, 0.6) = 0
  assert_true(hip_yaw.abs() < 0.001)
  // roll = 0 → hip_roll = 0, ankle_roll = 0
  assert_true(hip_roll.abs() < 0.001)
  assert_true(ankle_roll.abs() < 0.001)
}

///|
/// 6-DOF 解：目标在侧方，hip_yaw 应为 π/2。
test "LegIKSolver - 6dof lateral target" {
  let solver = LegIKSolver::new(0.4, 0.4, ankle_height=0.0)
  let target = Pose::{ position: (0.0, 0.6, 0.0), orientation: (0.0, 0.0, 0.0) }
  let (hip_yaw, _, _, _, _, _) = solver.solve_6dof(target)
  // x = 0, y = 0.6 → hip_yaw = atan2(0.6, 0) = π/2
  assert_true((hip_yaw - 1.5707963267948966).abs() < 0.001)
}

///|
/// 6-DOF 解：ankle_height 偏移正确。
test "LegIKSolver - 6dof with ankle height" {
  let solver = LegIKSolver::new(0.4, 0.4, ankle_height=0.1)
  // 目标 z = 0.1（ankle_height），矢状面有效 z = 0
  let target = Pose::{ position: (0.8, 0.0, 0.1), orientation: (0.0, 0.0, 0.0) }
  let (_, _, _, knee_pitch, _, _) = solver.solve_6dof(target)
  // 有效距离 = 0.8 = L1 + L2 → 膝盖伸直
  assert_true(knee_pitch.abs() < 0.001)
}

///|
/// IKSolver trait：solve_ik 返回 6 个 JointState。
test "LegIKSolver - solve_ik returns 6 joints" {
  let solver = LegIKSolver::new(0.4, 0.4)
  let target = Pose::{ position: (0.5, 0.0, 0.3), orientation: (0.0, 0.0, 0.0) }
  let joints = solver.solve_ik(target)
  assert_eq(joints.length(), 6)
  // 关节名称正确
  assert_eq(joints[0].name, "hip_yaw")
  assert_eq(joints[1].name, "hip_roll")
  assert_eq(joints[2].name, "hip_pitch")
  assert_eq(joints[3].name, "knee_pitch")
  assert_eq(joints[4].name, "ankle_pitch")
  assert_eq(joints[5].name, "ankle_roll")
}

///|
/// IKSolver trait：solve_ik_with_seed 使用种子选择肘上/肘下解分支。
test "LegIKSolver - seed selects knee branch" {
  let solver = LegIKSolver::new(0.4, 0.4)
  let target = Pose::{ position: (0.5, 0.0, 0.3), orientation: (0.0, 0.0, 0.0) }
  // 种子 knee_pitch > 0 → 肘上解（knee_pitch > 0）
  let seed_forward : Array[@core.JointState] = [
    { name: "hip_yaw", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "hip_roll", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "hip_pitch", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "knee_pitch", position: 1.0, velocity: 0.0, effort: 0.0 },
    { name: "ankle_pitch", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "ankle_roll", position: 0.0, velocity: 0.0, effort: 0.0 },
  ]
  // 种子 knee_pitch < 0 → 肘下解（knee_pitch < 0）
  let seed_backward : Array[@core.JointState] = [
    { name: "hip_yaw", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "hip_roll", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "hip_pitch", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "knee_pitch", position: -1.0, velocity: 0.0, effort: 0.0 },
    { name: "ankle_pitch", position: 0.0, velocity: 0.0, effort: 0.0 },
    { name: "ankle_roll", position: 0.0, velocity: 0.0, effort: 0.0 },
  ]
  let result_forward = solver.solve_ik_with_seed(target, seed_forward)
  let result_backward = solver.solve_ik_with_seed(target, seed_backward)
  // 肘上解：knee_pitch > 0
  assert_true(result_forward[3].position > 0.0)
  // 肘下解：knee_pitch < 0
  assert_true(result_backward[3].position < 0.0)
  // 两种解的 knee_pitch 绝对值应相同（对称解）
  assert_true(
    (result_forward[3].position + result_backward[3].position).abs() < 0.001,
  )
}

///|
/// solve_planar_with_seed：种子符号决定解分支。
test "LegIKSolver - planar with seed" {
  let solver = LegIKSolver::new(0.4, 0.4)
  let (hip_fwd, knee_fwd) = solver.solve_planar_with_seed(0.5, 0.3, 1.0)
  let (hip_bwd, knee_bwd) = solver.solve_planar_with_seed(0.5, 0.3, -1.0)
  // 肘上解 knee > 0，肘下解 knee < 0
  assert_true(knee_fwd > 0.0)
  assert_true(knee_bwd < 0.0)
  // 绝对值相同
  assert_true((knee_fwd + knee_bwd).abs() < 0.001)
  // hip 角度不同（两个解分支）
  assert_true((hip_fwd - hip_bwd).abs() > 0.01)
}

///|
/// 6-DOF 解：roll 均分到 hip_roll 和 ankle_roll。
test "LegIKSolver - roll split" {
  let solver = LegIKSolver::new(0.4, 0.4)
  let target = Pose::{ position: (0.5, 0.0, 0.3), orientation: (0.4, 0.0, 0.0) }
  let (_, hip_roll, _, _, _, ankle_roll) = solver.solve_6dof(target)
  // roll 均分：hip_roll = ankle_roll = 0.2
  assert_true((hip_roll - 0.2).abs() < 0.001)
  assert_true((ankle_roll - 0.2).abs() < 0.001)
}
