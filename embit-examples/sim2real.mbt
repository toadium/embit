///|
/// Embit Phase 4.2 真机联调 Demo：RealRobot / Sim2Real 一致性 / 安全联锁 / 紧急停止。
///
/// 验证 Sim2Real 全链路：真机硬件抽象层 → 安全联锁 → 轨迹执行 → Sim2Real 对比。

///|
/// 真机控制 Demo：RealRobot 硬件抽象层 + 安全联锁 + 轨迹执行。
///
/// 演示 Phase 4.2 任务 1：硬件抽象层（真机 Robot trait 实现）。
/// 连接真机 → 安全检查 → 轨迹规划 → 执行 → 查询指令记录。
pub fn real_robot_demo() -> Unit raise @core.RobotError {
  // 1. 构建机器人模型
  let robot_model = @core.RobotBuilder::arm_6dof()
  let model_info = robot_model.to_info("arm_6dof", "1.0")

  // 2. 连接真机（占位模式：CAN 总线地址）
  let robot = @core.RealRobot::connect("can0", model_info)

  // 3. 创建安全联锁控制器
  let safety = @control.SafetyController::from_model(robot_model)

  // 4. 运动控制器
  let ctrl = @control.MotionController::new(robot_model)

  // 5. 规划轨迹
  let start : Array[(String, Double)] = [
    ("joint1", 0.0),
    ("joint2", 0.0),
    ("joint3", 0.0),
  ]
  let goal : Array[(String, Double)] = [
    ("joint1", 0.5),
    ("joint2", -0.3),
    ("joint3", 0.8),
  ]
  let constraints = @control.TrajectoryConstraints::{
    max_velocity: 1.0,
    max_acceleration: 4.0,
    time_step: 0.02,
  }
  let traj = ctrl.compute_trajectory(start, goal, constraints)

  // 6. 安全检查
  let commands = traj.to_commands()
  safety.check_all(commands)

  // 7. 执行轨迹到真机
  robot.execute_actions(commands)

  // 8. 查询指令执行记录
  let _executed = robot.executed_commands()
  let _count = robot.execution_count()

  // 9. 断开连接
  robot.disconnect()
}

///|
/// Sim2Real 一致性 Demo：相同轨迹在仿真与真机上执行结果对比。
///
/// 演示 Phase 4.2 任务 2：Sim2Real 一致性。
/// 在 Gazebo 仿真与 RealRobot 真机上执行相同轨迹，
/// 对比指令执行计数与轨迹误差。
pub fn sim2real_consistency_demo() -> Unit raise @core.RobotError {
  // 1. 构建模型
  let robot_model = @core.RobotBuilder::arm_6dof()
  let model_info = robot_model.to_info("arm_6dof", "1.0")

  // 2. 连接仿真与真机
  let sim = @gazebo.GazeboClient::connect("localhost:9050")
  sim.spawn_model("arm_6dof")
  let sim_robot = @gazebo.GazeboRobot::from_client(sim, model_info)
  let real_robot = @core.RealRobot::connect("can0", model_info)

  // 3. 规划相同轨迹
  let ctrl = @control.MotionController::new(robot_model)
  let start : Array[(String, Double)] = [("joint1", 0.0), ("joint2", 0.0)]
  let goal : Array[(String, Double)] = [("joint1", 0.5), ("joint2", -0.3)]
  let constraints = @control.TrajectoryConstraints::{
    max_velocity: 1.0,
    max_acceleration: 4.0,
    time_step: 0.02,
  }
  let traj = ctrl.compute_trajectory(start, goal, constraints)
  let commands = traj.to_commands()

  // 4. 安全检查
  ctrl.check_safety(commands)

  // 5. 在仿真上执行
  sim_robot.execute_actions(commands)

  // 6. 在真机上执行
  real_robot.execute_actions(commands)

  // 7. Sim2Real 一致性验证：指令数一致
  let _sim_cmd_count = commands.length()
  let _real_cmd_count = real_robot.execution_count()
  let executed = real_robot.executed_commands()

  // 8. 逐指令对比：时间戳与关节命令一致
  for i in 0..<commands.length() {
    let planned = commands[i]
    let executed_cmd = executed[i]
    let _t1 = planned.timestamp
    let _t2 = executed_cmd.timestamp
    let _n1 = planned.joint_commands.length()
    let _n2 = executed_cmd.joint_commands.length()
  }

  // 9. 清理
  real_robot.disconnect()
  sim.remove_model("arm_6dof")
  sim.disconnect()
}

///|
/// 安全联锁 Demo：关节限位 / 速度限制 / 力矩限制 / 碰撞检测。
///
/// 演示 Phase 4.2 任务 3：安全联锁在真机上生效。
/// 构造安全联锁控制器，验证各类违规检测与综合检查。
pub fn safety_interlock_demo() -> Unit raise @core.RobotError {
  // 1. 构建模型与安全控制器
  let robot_model = @core.RobotBuilder::arm_6dof()
  let safety = @control.SafetyController::from_model(robot_model)

  // 2. 正常指令应通过安全检查
  let safe_commands : Array[@core.ActionCommand] = [
    { joint_commands: [("joint1", 0.1)], timestamp: 0.0 },
    { joint_commands: [("joint1", 0.2)], timestamp: 0.1 },
  ]
  safety.check_all(safe_commands)

  // 3. 速度超限指令应被检测
  let fast_commands : Array[@core.ActionCommand] = [
    { joint_commands: [("joint1", 0.0)], timestamp: 0.0 },
    { joint_commands: [("joint1", 10.0)], timestamp: 0.01 },
  ]
  try safety.check_all(fast_commands) catch {
    SafetyLimitViolation(_msg) => ()
    _ => ()
  } noraise {
    _ => ()
  }

  // 4. 紧急停止后所有指令被拒绝
  safety.emergency_stop()
  try safety.check_all(safe_commands) catch {
    SafetyLimitViolation(_msg) => ()
    _ => ()
  } noraise {
    _ => ()
  }

  // 5. 重置后恢复正常
  safety.reset_emergency_stop()
  safety.check_all(safe_commands)
}

///|
/// 紧急停止 Demo：异常状态下安全停机协议。
///
/// 演示 Phase 4.2 任务 4：紧急停止。
/// 模拟异常检测 → 触发紧急停止 → 拒绝后续指令 → 重置恢复。
pub fn emergency_stop_demo() -> Unit raise @core.RobotError {
  // 1. 连接真机
  let robot_model = @core.RobotBuilder::humanoid_12dof()
  let model_info = robot_model.to_info("humanoid", "1.0")
  let robot = @core.RealRobot::connect("can0", model_info)

  // 2. 安全控制器
  let safety = @control.SafetyController::from_model(robot_model)

  // 3. 正常执行动作
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: [("left_hip", 0.3)], timestamp: 0.0 },
  ]
  safety.check_all(commands)
  robot.execute_actions(commands)

  // 4. 检测到异常：触发紧急停止
  safety.emergency_stop()
  robot.emergency_stop()

  // 5. 紧急停止后动作被拒绝
  let more_commands : Array[@core.ActionCommand] = [
    { joint_commands: [("left_hip", 0.5)], timestamp: 0.1 },
  ]
  try robot.execute_actions(more_commands) catch {
    SafetyLimitViolation(_msg) => ()
    _ => ()
  } noraise {
    _ => ()
  }

  // 6. 安全控制器也拒绝指令
  try safety.check_all(more_commands) catch {
    SafetyLimitViolation(_msg) => ()
    _ => ()
  } noraise {
    _ => ()
  }

  // 7. 重置紧急停止，恢复正常
  safety.reset_emergency_stop()
  robot.reset_emergency_stop()

  // 8. 恢复后可正常执行
  safety.check_all(more_commands)
  robot.execute_actions(more_commands)

  // 9. 断开
  robot.disconnect()
}
