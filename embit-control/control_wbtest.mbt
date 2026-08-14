///|
/// embit-control 白盒测试：验证轨迹规划、状态估计与安全联锁。
///
/// 白盒测试位于包内，可直接使用 Trajectory / MotionController 等类型名，
/// 跨包类型用 @core / @gazebo 限定。

///|
/// 测试用模拟机器人，实现 @core.Robot trait。
struct MockRobot {
  executed : Array[@core.ActionCommand]
}

///|
impl @core.Robot for MockRobot with fn get_sensor_readings(self) {
  ignore(self)
  []
}

///|
impl @core.Robot for MockRobot with fn execute_actions(self, commands) {
  for cmd in commands {
    self.executed.push(cmd)
  }
}

///|
impl @core.Robot for MockRobot with fn get_model_info(self) {
  ignore(self)
  { name: "mock", version: "1.0", dof: 2, urdf_path: "" }
}

///|
fn make_mock_robot() -> MockRobot {
  { executed: [] }
}

///|
/// 构建测试用 RobotModel（2 关节，安全限幅 1.0 rad/s）。
fn make_test_model() -> @core.RobotModel {
  {
    urdf_path: "",
    joints: [],
    sensors: [],
    limits: {
      max_joint_velocity: 1.0,
      max_joint_effort: 10.0,
      collision_check_distance: 0.01,
    },
  }
}

///|
/// 浮点近似比较阈值。
let eps : Double = 0.000000001

// ===== Trajectory 测试 =====

///|
test "Trajectory - empty creates zero-duration trajectory" {
  let traj = Trajectory::empty()
  assert_eq(traj.length(), 0)
  assert_eq(traj.duration, 0.0)
}

///|
test "Trajectory - to_commands converts waypoints" {
  let traj : Trajectory = {
    waypoints: [
      { positions: [("j1", 0.0)], timestamp: 0.0 },
      { positions: [("j1", 1.0)], timestamp: 1.0 },
    ],
    duration: 1.0,
  }
  let cmds = traj.to_commands()
  assert_eq(cmds.length(), 2)
  assert_eq(cmds[0].timestamp, 0.0)
  assert_eq(cmds[1].joint_commands[0], ("j1", 1.0))
}

// ===== StateEstimator 测试 =====

///|
test "StateEstimator - new creates empty state" {
  let est = StateEstimator::new()
  assert_eq(est.get_state().length(), 0)
  assert_eq(est.last_update(), 0.0)
}

///|
test "StateEstimator - update sets last_update_time" {
  let est = StateEstimator::new()
  let readings : Array[@core.SensorReading] = [
    { kind: Imu, timestamp: 1.5, data: b"" },
    { kind: Camera, timestamp: 2.3, data: b"" },
  ]
  est.update(readings)
  assert_eq(est.last_update(), 2.3)
}

///|
test "StateEstimator - set_state injects state" {
  let est = StateEstimator::new()
  let state : Array[@core.JointState] = [
    { name: "j1", position: 0.5, velocity: 0.1, effort: 0.0 },
  ]
  est.set_state(state)
  assert_eq(est.get_state().length(), 1)
  assert_eq(est.get_state()[0].name, "j1")
}

// ===== MotionController 测试 =====

///|
test "MotionController - new creates controller with model" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  assert_false(ctrl.is_sim_attached())
  assert_eq(ctrl.get_state().length(), 0)
}

///|
test "MotionController - compute_trajectory linear interpolation" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let start : Array[(String, Double)] = [("j1", 0.0), ("j2", 0.0)]
  let goal : Array[(String, Double)] = [("j1", 1.0), ("j2", 2.0)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.25,
  }
  let traj = ctrl.compute_trajectory(start, goal, constraints)
  // duration = max_displacement(2.0) / max_velocity(1.0) = 2.0
  // steps = ceil(2.0 / 0.25) = 8, waypoints = 9
  assert_eq(traj.length(), 9)
  assert_eq(traj.duration, 2.0)
  // 起点位置
  let (start_name, start_pos) = traj.waypoints[0].positions[0]
  assert_eq(start_name, "j1")
  assert_true((start_pos - 0.0).abs() < eps)
  // 终点位置
  let (end_name, end_pos) = traj.waypoints[8].positions[1]
  assert_eq(end_name, "j2")
  assert_true((end_pos - 2.0).abs() < eps)
}

///|
test "MotionController - compute_trajectory rejects zero time_step" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.0,
  }
  try ctrl.compute_trajectory([], [], constraints) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("time_step"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected SafetyLimitViolation")
  }
}

///|
test "MotionController - compute_trajectory rejects mismatched lengths" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.1,
  }
  try ctrl.compute_trajectory([("j1", 0.0)], [], constraints) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("same number"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected SafetyLimitViolation")
  }
}

///|
test "MotionController - check_safety passes within limits" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  // 速度 = |1.0 - 0.0| / 1.0 = 1.0，等于限制 1.0，应通过
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j1", 1.0)], timestamp: 1.0 },
  ]
  ctrl.check_safety(commands)
}

///|
test "MotionController - check_safety rejects velocity exceeding limit" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  // 速度 = |2.0 - 0.0| / 0.5 = 4.0，超过限制 1.0
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j1", 2.0)], timestamp: 0.5 },
  ]
  try ctrl.check_safety(commands) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("velocity"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected SafetyLimitViolation")
  }
}

///|
test "MotionController - execute_trajectory dispatches to robot" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let robot = make_mock_robot()
  let traj : Trajectory = {
    waypoints: [
      { positions: [("j1", 0.0)], timestamp: 0.0 },
      { positions: [("j1", 0.5)], timestamp: 0.5 },
      { positions: [("j1", 1.0)], timestamp: 1.0 },
    ],
    duration: 1.0,
  }
  ctrl.execute_trajectory(traj, robot)
  assert_eq(robot.executed.length(), 3)
  assert_eq(robot.executed[0].timestamp, 0.0)
  assert_eq(robot.executed[2].joint_commands[0], ("j1", 1.0))
}

///|
test "MotionController - attach_simulation sets sim client" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  assert_false(ctrl.is_sim_attached())
  let client = @gazebo.GazeboClient::connect("localhost:9000")
  ctrl.attach_simulation(client)
  assert_true(ctrl.is_sim_attached())
  client.disconnect()
}

///|
test "MotionController - update_state delegates to estimator" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let readings : Array[@core.SensorReading] = [
    { kind: Imu, timestamp: 3.0, data: b"" },
  ]
  ctrl.update_state(readings)
  // 状态估计器内部时间戳应已更新
  assert_eq(ctrl.get_state().length(), 0)
}

// ===== 三次多项式轨迹规划测试 =====

///|
/// 三次多项式轨迹起止点位置正确，起止速度为零。
test "MotionController - compute_trajectory_cubic endpoints" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let start : Array[(String, Double)] = [("j1", 0.0)]
  let goal : Array[(String, Double)] = [("j1", 1.0)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.1,
  }
  let traj = ctrl.compute_trajectory_cubic(start, goal, constraints)
  assert_true(traj.length() > 1)
  // 起点位置 = 0.0
  let (_, start_pos) = traj.waypoints[0].positions[0]
  assert_true(start_pos.abs() < eps)
  // 终点位置 = 1.0
  let (_, end_pos) = traj.waypoints[traj.length() - 1].positions[0]
  assert_true((end_pos - 1.0).abs() < eps)
  // 中点应在 0.5 附近（三次多项式对称性，离散采样有偏差）
  let mid_idx = traj.length() / 2
  let (_, mid_pos) = traj.waypoints[mid_idx].positions[0]
  assert_true((mid_pos - 0.5).abs() < 0.1)
}

///|
/// 三次多项式轨迹拒绝零时间步。
test "MotionController - compute_trajectory_cubic rejects zero time_step" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.0,
  }
  try ctrl.compute_trajectory_cubic([], [], constraints) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("time_step"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected SafetyLimitViolation")
  }
}

///|
/// 三次多项式轨迹比线性轨迹更平滑（中间点偏离线性）。
test "MotionController - cubic differs from linear at midpoints" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let start : Array[(String, Double)] = [("j1", 0.0)]
  let goal : Array[(String, Double)] = [("j1", 1.0)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.05,
  }
  let traj_lin = ctrl.compute_trajectory(start, goal, constraints)
  let traj_cub = ctrl.compute_trajectory_cubic(start, goal, constraints)
  // 1/4 处：三次多项式应低于线性（因为 h(0.25) = 3*0.0625 - 2*0.015625 = 0.15625 < 0.25）
  let idx = traj_lin.length() / 4
  let (_, lin_pos) = traj_lin.waypoints[idx].positions[0]
  let (_, cub_pos) = traj_cub.waypoints[idx].positions[0]
  assert_true(cub_pos < lin_pos)
}

// ===== 五次多项式轨迹规划测试 =====

///|
/// 五次多项式轨迹起止点位置正确。
test "MotionController - compute_trajectory_quintic endpoints" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let start : Array[(String, Double)] = [("j1", 0.0)]
  let goal : Array[(String, Double)] = [("j1", 1.0)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.1,
  }
  let traj = ctrl.compute_trajectory_quintic(start, goal, constraints)
  assert_true(traj.length() > 1)
  // 起点位置 = 0.0
  let (_, start_pos) = traj.waypoints[0].positions[0]
  assert_true(start_pos.abs() < eps)
  // 终点位置 = 1.0
  let (_, end_pos) = traj.waypoints[traj.length() - 1].positions[0]
  assert_true((end_pos - 1.0).abs() < eps)
  // 中点应在 0.5 附近
  let mid_idx = traj.length() / 2
  let (_, mid_pos) = traj.waypoints[mid_idx].positions[0]
  assert_true((mid_pos - 0.5).abs() < 0.1)
}

///|
/// 五次多项式轨迹拒绝零时间步。
test "MotionController - compute_trajectory_quintic rejects zero time_step" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.0,
  }
  try ctrl.compute_trajectory_quintic([], [], constraints) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("time_step"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected SafetyLimitViolation")
  }
}

///|
/// 五次多项式比三次多项式在中段更平缓（五次起止加速度也为零）。
test "MotionController - quintic is smoother than cubic at quarter" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let start : Array[(String, Double)] = [("j1", 0.0)]
  let goal : Array[(String, Double)] = [("j1", 1.0)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.05,
  }
  let traj_cub = ctrl.compute_trajectory_cubic(start, goal, constraints)
  let traj_qui = ctrl.compute_trajectory_quintic(start, goal, constraints)
  // 1/4 处：五次多项式 h(0.25) = 10*0.015625 - 15*0.00390625 + 6*0.0009765625
  //   = 0.15625 - 0.05859375 + 0.005859375 ≈ 0.103515625
  // 三次多项式 h(0.25) = 3*0.0625 - 2*0.015625 = 0.15625
  // 五次 < 三次（起止更平缓）
  let idx = traj_cub.length() / 4
  let (_, cub_pos) = traj_cub.waypoints[idx].positions[0]
  let (_, qui_pos) = traj_qui.waypoints[idx].positions[0]
  assert_true(qui_pos < cub_pos)
}

// ===== 轨迹融合测试 =====

///|
/// 融合两条轨迹应生成包含两段加过渡段的轨迹。
test "Trajectory - blend produces combined trajectory" {
  let t1 : Trajectory = {
    waypoints: [
      { positions: [("j1", 0.0)], timestamp: 0.0 },
      { positions: [("j1", 1.0)], timestamp: 1.0 },
    ],
    duration: 1.0,
  }
  let t2 : Trajectory = {
    waypoints: [
      { positions: [("j1", 2.0)], timestamp: 0.0 },
      { positions: [("j1", 3.0)], timestamp: 1.0 },
    ],
    duration: 1.0,
  }
  let blended = Trajectory::blend(t1, t2, 0.5)
  // 总时长 = 1.0 + 0.5 + 1.0 = 2.5
  assert_true((blended.duration - 2.5).abs() < eps)
  // 轨迹点数 > 4（至少 t1 的 2 点 + 过渡段 + t2 的 2 点）
  assert_true(blended.length() > 4)
}

///|
/// 融合后第一段应保持原始轨迹。
test "Trajectory - blend preserves first trajectory" {
  let t1 : Trajectory = {
    waypoints: [
      { positions: [("j1", 0.0)], timestamp: 0.0 },
      { positions: [("j1", 1.0)], timestamp: 1.0 },
    ],
    duration: 1.0,
  }
  let t2 : Trajectory = {
    waypoints: [{ positions: [("j1", 2.0)], timestamp: 0.0 }],
    duration: 0.0,
  }
  let blended = Trajectory::blend(t1, t2, 0.3)
  // 前两个点应与 t1 一致
  assert_eq(blended.waypoints[0].timestamp, 0.0)
  assert_eq(blended.waypoints[1].timestamp, 1.0)
  let (_, p0) = blended.waypoints[0].positions[0]
  assert_true(p0.abs() < eps)
}

///|
/// 融合零时长应抛出错误。
test "Trajectory - blend zero duration raises error" {
  let t1 : Trajectory = {
    waypoints: [{ positions: [("j1", 0.0)], timestamp: 0.0 }],
    duration: 0.0,
  }
  let t2 : Trajectory = {
    waypoints: [{ positions: [("j1", 1.0)], timestamp: 0.0 }],
    duration: 0.0,
  }
  try Trajectory::blend(t1, t2, 0.0) catch {
    InvalidConfig(msg) => assert_true(msg.contains("blend_duration"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// 融合空轨迹应抛出错误。
test "Trajectory - blend empty trajectory raises error" {
  let t1 = Trajectory::empty()
  let t2 : Trajectory = {
    waypoints: [{ positions: [("j1", 1.0)], timestamp: 0.0 }],
    duration: 0.0,
  }
  try Trajectory::blend(t1, t2, 0.5) catch {
    InvalidConfig(msg) => assert_true(msg.contains("empty"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

// ===== 边缘 case 覆盖测试 =====

///|
/// max_velocity=0 时 compute_duration 回退到 time_step。
test "MotionController - compute_trajectory with zero max_velocity" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let start : Array[(String, Double)] = [("j1", 0.0)]
  let goal : Array[(String, Double)] = [("j1", 1.0)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 0.0,
    max_acceleration: 5.0,
    time_step: 0.1,
  }
  let traj = ctrl.compute_trajectory(start, goal, constraints)
  // duration = time_step = 0.1, steps = 1, waypoints = 2
  assert_eq(traj.duration, 0.1)
  assert_true(traj.length() >= 2)
}

///|
/// 三次多项式轨迹拒绝长度不匹配。
test "MotionController - cubic rejects mismatched lengths" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.1,
  }
  try ctrl.compute_trajectory_cubic([("j1", 0.0)], [], constraints) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("same number"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected SafetyLimitViolation")
  }
}

///|
/// 三次多项式轨迹起止相同时 duration=0。
test "MotionController - cubic zero duration same start goal" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let start : Array[(String, Double)] = [("j1", 0.5)]
  let goal : Array[(String, Double)] = [("j1", 0.5)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.1,
  }
  let traj = ctrl.compute_trajectory_cubic(start, goal, constraints)
  assert_eq(traj.duration, 0.0)
  // 所有点位置应为 0.5
  for wp in traj.waypoints {
    let (_, pos) = wp.positions[0]
    assert_true((pos - 0.5).abs() < eps)
  }
}

///|
/// 五次多项式轨迹拒绝长度不匹配。
test "MotionController - quintic rejects mismatched lengths" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.1,
  }
  try ctrl.compute_trajectory_quintic([("j1", 0.0)], [], constraints) catch {
    SafetyLimitViolation(msg) => assert_true(msg.contains("same number"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected SafetyLimitViolation")
  }
}

///|
/// 五次多项式轨迹起止相同时 duration=0。
test "MotionController - quintic zero duration same start goal" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let start : Array[(String, Double)] = [("j1", 0.3)]
  let goal : Array[(String, Double)] = [("j1", 0.3)]
  let constraints : TrajectoryConstraints = {
    max_velocity: 1.0,
    max_acceleration: 5.0,
    time_step: 0.1,
  }
  let traj = ctrl.compute_trajectory_quintic(start, goal, constraints)
  assert_eq(traj.duration, 0.0)
  for wp in traj.waypoints {
    let (_, pos) = wp.positions[0]
    assert_true((pos - 0.3).abs() < eps)
  }
}

///|
/// check_safety 少于 2 条指令时直接通过。
test "MotionController - check_safety single command passes" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
  ]
  ctrl.check_safety(commands)
}

///|
/// check_safety 空指令列表直接通过。
test "MotionController - check_safety empty commands passes" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  ctrl.check_safety([])
}

///|
/// check_safety 相邻指令时间戳相同时跳过速度检查。
test "MotionController - check_safety same timestamp skips check" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  // 两条指令时间戳相同，dt=0，应跳过检查不报错
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 1.0 },
    { joint_commands: [("j1", 100.0)], timestamp: 1.0 },
  ]
  ctrl.check_safety(commands)
}

///|
/// check_safety 前后指令关节名不同时跳过该关节。
test "MotionController - check_safety unknown joint skips" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  // 第二条指令的关节名在第一条中不存在，应跳过不报错
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("j1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("j2", 100.0)], timestamp: 0.1 },
  ]
  ctrl.check_safety(commands)
}

///|
/// get_model 返回控制器持有的模型。
test "MotionController - get_model returns model" {
  let model = make_test_model()
  let ctrl = MotionController::new(model)
  let got = ctrl.get_model()
  assert_eq(got.limits.max_joint_velocity, 1.0)
  assert_eq(got.limits.max_joint_effort, 10.0)
}
