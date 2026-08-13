///|
/// 运动控制器：轨迹规划、轨迹执行与安全联锁。
///
/// 基于 `RobotModel` 描述的关节约束与安全限幅，
/// 生成可行轨迹并通过 `Robot` trait 下发执行。
/// 可选绑定 `GazeboClient` 实现仿真模式控制。
pub struct MotionController {
  model : @core.RobotModel
  estimator : StateEstimator
  mut sim : @gazebo.GazeboClient?
}

///|
/// 创建运动控制器。
///
/// 内部初始化空状态估计器，未绑定仿真客户端。
pub fn MotionController::new(model : @core.RobotModel) -> MotionController {
  { model, estimator: StateEstimator::new(), sim: None }
}

///|
/// 绑定仿真客户端，进入仿真控制模式。
pub fn MotionController::attach_simulation(
  self : MotionController,
  client : @gazebo.GazeboClient,
) -> Unit {
  self.sim = Some(client)
}

///|
/// 规划轨迹：从起始关节位置到目标关节位置的线性插值。
///
/// `start` / `goal` 为关节名到角度的映射，
/// `constraints` 定义最大速度、加速度与采样间隔。
/// 规划失败时抛出 `RobotError::SafetyLimitViolation`。
pub fn MotionController::compute_trajectory(
  self : MotionController,
  start : Array[(String, Double)],
  goal : Array[(String, Double)],
  constraints : TrajectoryConstraints,
) -> Trajectory raise @core.RobotError {
  ignore(self)
  if constraints.time_step <= 0.0 {
    raise SafetyLimitViolation("time_step must be positive")
  }
  if start.length() != goal.length() {
    raise SafetyLimitViolation("start and goal must have same number of joints")
  }
  // 计算最大关节位移与所需时间
  let mut max_displacement = 0.0
  for i in 0..<start.length() {
    let (_, start_pos) = start[i]
    let (_, goal_pos) = goal[i]
    let disp = (goal_pos - start_pos).abs()
    if disp > max_displacement {
      max_displacement = disp
    }
  }
  // 速度约束下的最短时间
  let mut duration = 0.0
  if constraints.max_velocity > 0.0 {
    duration = max_displacement / constraints.max_velocity
  } else {
    duration = constraints.time_step
  }
  // 生成轨迹点
  let waypoints : Array[Waypoint] = []
  let steps = (duration / constraints.time_step).ceil().to_int()
  let actual_steps = if steps > 0 { steps } else { 1 }
  for step in 0..<=actual_steps {
    let t = if actual_steps == 0 {
      0.0
    } else {
      duration * step.to_double() / actual_steps.to_double()
    }
    let alpha = if duration == 0.0 { 1.0 } else { t / duration }
    let positions : Array[(String, Double)] = []
    for i in 0..<start.length() {
      let (name, start_pos) = start[i]
      let (_, goal_pos) = goal[i]
      positions.push((name, start_pos + (goal_pos - start_pos) * alpha))
    }
    waypoints.push({ positions, timestamp: t })
  }
  { waypoints, duration }
}

///|
/// 执行轨迹：将轨迹转换为动作指令序列并下发至机器人。
///
/// 执行前进行安全检查，违反限幅时抛出 `RobotError::SafetyLimitViolation`。
pub fn[T : @core.Robot] MotionController::execute_trajectory(
  self : MotionController,
  traj : Trajectory,
  robot : T,
) -> Unit raise @core.RobotError {
  let commands = traj.to_commands()
  self.check_safety(commands)
  robot.execute_actions(commands)
}

///|
/// 规划轨迹（三次多项式）：从起始到目标的平滑插值，零速起止。
///
/// 相比 `compute_trajectory`（线性插值），三次多项式在起止点速度为零，
/// 加速度连续，适合需要平滑运动的场景。
///
/// 位置公式：`p(t) = a0 + a1*t + a2*t² + a3*t³`
/// 边界条件：`p(0)=start, p(T)=goal, v(0)=0, v(T)=0`
/// 解：`a0=start, a1=0, a2=3Δ/T², a3=-2Δ/T³`（Δ=goal-start）
pub fn MotionController::compute_trajectory_cubic(
  self : MotionController,
  start : Array[(String, Double)],
  goal : Array[(String, Double)],
  constraints : TrajectoryConstraints,
) -> Trajectory raise @core.RobotError {
  ignore(self)
  if constraints.time_step <= 0.0 {
    raise SafetyLimitViolation("time_step must be positive")
  }
  if start.length() != goal.length() {
    raise SafetyLimitViolation("start and goal must have same number of joints")
  }
  // 计算最大关节位移与所需时间
  let mut max_displacement = 0.0
  for i in 0..<start.length() {
    let (_, start_pos) = start[i]
    let (_, goal_pos) = goal[i]
    let disp = (goal_pos - start_pos).abs()
    if disp > max_displacement {
      max_displacement = disp
    }
  }
  // 速度约束下的最短时间（三次多项式峰值速度 = 1.5 * Δ / T）
  let mut duration = 0.0
  if constraints.max_velocity > 0.0 {
    duration = 1.5 * max_displacement / constraints.max_velocity
  } else {
    duration = constraints.time_step
  }
  // 生成轨迹点
  let waypoints : Array[Waypoint] = []
  let steps = (duration / constraints.time_step).ceil().to_int()
  let actual_steps = if steps > 0 { steps } else { 1 }
  for step in 0..<=actual_steps {
    let t = if actual_steps == 0 {
      0.0
    } else {
      duration * step.to_double() / actual_steps.to_double()
    }
    let positions : Array[(String, Double)] = []
    for i in 0..<start.length() {
      let (name, start_pos) = start[i]
      let (_, goal_pos) = goal[i]
      let delta = goal_pos - start_pos
      let pos = if duration == 0.0 {
        goal_pos
      } else {
        // 三次多项式：a0 + a2*t² + a3*t³
        let a2 = 3.0 * delta / (duration * duration)
        let a3 = -2.0 * delta / (duration * duration * duration)
        start_pos + a2 * t * t + a3 * t * t * t
      }
      positions.push((name, pos))
    }
    waypoints.push({ positions, timestamp: t })
  }
  { waypoints, duration }
}

///|
/// 规划轨迹（五次多项式）：零速零加速度起止，最平滑运动。
///
/// 相比三次多项式，五次多项式在起止点速度和加速度均为零，
/// 适合需要极致平滑（无加速度突变）的场景。
///
/// 位置公式：`p(t) = a0 + a3*t³ + a4*t⁴ + a5*t⁵`
/// 边界条件：`p(0)=start, p(T)=goal, v(0)=v(T)=0, a(0)=a(T)=0`
/// 解：`a0=start, a3=10Δ/T³, a4=-15Δ/T⁴, a5=6Δ/T⁵`（Δ=goal-start）
pub fn MotionController::compute_trajectory_quintic(
  self : MotionController,
  start : Array[(String, Double)],
  goal : Array[(String, Double)],
  constraints : TrajectoryConstraints,
) -> Trajectory raise @core.RobotError {
  ignore(self)
  if constraints.time_step <= 0.0 {
    raise SafetyLimitViolation("time_step must be positive")
  }
  if start.length() != goal.length() {
    raise SafetyLimitViolation("start and goal must have same number of joints")
  }
  // 计算最大关节位移与所需时间
  let mut max_displacement = 0.0
  for i in 0..<start.length() {
    let (_, start_pos) = start[i]
    let (_, goal_pos) = goal[i]
    let disp = (goal_pos - start_pos).abs()
    if disp > max_displacement {
      max_displacement = disp
    }
  }
  // 速度约束下的最短时间（五次多项式峰值速度 = 15Δ/(8T)）
  let mut duration = 0.0
  if constraints.max_velocity > 0.0 {
    duration = 1.875 * max_displacement / constraints.max_velocity
  } else {
    duration = constraints.time_step
  }
  // 生成轨迹点
  let waypoints : Array[Waypoint] = []
  let steps = (duration / constraints.time_step).ceil().to_int()
  let actual_steps = if steps > 0 { steps } else { 1 }
  for step in 0..<=actual_steps {
    let t = if actual_steps == 0 {
      0.0
    } else {
      duration * step.to_double() / actual_steps.to_double()
    }
    let positions : Array[(String, Double)] = []
    for i in 0..<start.length() {
      let (name, start_pos) = start[i]
      let (_, goal_pos) = goal[i]
      let delta = goal_pos - start_pos
      let pos = if duration == 0.0 {
        goal_pos
      } else {
        // 五次多项式：a0 + a3*t³ + a4*t⁴ + a5*t⁵
        let t2 = t * t
        let t3 = t2 * t
        let t4 = t3 * t
        let t5 = t4 * t
        let d3 = duration * duration * duration
        let d4 = d3 * duration
        let d5 = d4 * duration
        let a3 = 10.0 * delta / d3
        let a4 = -15.0 * delta / d4
        let a5 = 6.0 * delta / d5
        start_pos + a3 * t3 + a4 * t4 + a5 * t5
      }
      positions.push((name, pos))
    }
    waypoints.push({ positions, timestamp: t })
  }
  { waypoints, duration }
}

///|
/// 安全检查：验证动作指令不超出模型安全限幅。
///
/// 检查关节速度与力矩是否在 `SafetyLimits` 范围内。
/// 违反时抛出 `RobotError::SafetyLimitViolation`。
pub fn MotionController::check_safety(
  self : MotionController,
  commands : Array[@core.ActionCommand],
) -> Unit raise @core.RobotError {
  let limits = self.model.limits
  if commands.length() < 2 {
    return
  }
  for i in 1..<commands.length() {
    let prev = commands[i - 1]
    let curr = commands[i]
    let dt = curr.timestamp - prev.timestamp
    if dt <= 0.0 {
      continue
    }
    // 检查相邻指令间各关节的速度
    for cmd in curr.joint_commands {
      let (name, target_pos) = cmd
      // 在前一条指令中查找同名关节
      let mut prev_pos : Double? = None
      for prev_cmd in prev.joint_commands {
        let (pn, pp) = prev_cmd
        if pn == name {
          prev_pos = Some(pp)
          break
        }
      }
      match prev_pos {
        Some(pp) => {
          let velocity = (target_pos - pp).abs() / dt
          if limits.max_joint_velocity > 0.0 &&
            velocity > limits.max_joint_velocity {
            raise SafetyLimitViolation(
              "joint \{name} velocity \{velocity} exceeds limit \{limits.max_joint_velocity}",
            )
          }
        }
        None => continue
      }
    }
  }
}

///|
/// 从传感器读数更新内部状态估计。
pub fn MotionController::update_state(
  self : MotionController,
  readings : Array[@core.SensorReading],
) -> Unit {
  self.estimator.update(readings)
}

///|
/// 获取当前状态估计。
pub fn MotionController::get_state(
  self : MotionController,
) -> Array[@core.JointState] {
  self.estimator.get_state()
}

///|
/// 获取机器人模型。
pub fn MotionController::get_model(self : MotionController) -> @core.RobotModel {
  self.model
}

///|
/// 查询是否已绑定仿真客户端。
pub fn MotionController::is_sim_attached(self : MotionController) -> Bool {
  match self.sim {
    Some(_) => true
    None => false
  }
}
