///|
/// Embit 高级 Demo：多机型场景 / 笛卡尔控制 / 全栈综合。
///
/// 演示 Phase 3-4 新增功能在复杂场景下的组合使用。

// ===== Phase 3 第二轮：多机型完整示例 =====

///|
/// 多机型场景管理 Demo：使用 RobotBuilder 构建多种机型并在仿真中管理。
///
/// 演示 Phase 3 新增功能：
/// - RobotBuilder 预定义机型工厂（人形/四足/机械臂/双臂/移动底盘）
/// - GazeboRobot 仿真机器人封装（实现 Robot trait）
/// - JointGroup / JointGroupManager 关节分组管理
/// - GazeboClient 场景管理（spawn_model / remove_model）
pub fn multi_robot_scene_demo() -> Unit raise @core.RobotError {
  // 1. 连接仿真环境
  let sim = @gazebo.GazeboClient::connect("localhost:9010")

  // 2. 使用 RobotBuilder 构建多种机型
  let humanoid_model = @core.RobotBuilder::humanoid_12dof()
  let quadruped_model = @core.RobotBuilder::quadruped_12dof()
  let arm_model = @core.RobotBuilder::arm_6dof()

  // 3. 生成模型到仿真场景
  sim.spawn_model("humanoid")
  sim.spawn_model("quadruped")
  sim.spawn_model("arm_6dof")

  // 4. 创建 GazeboRobot 封装
  let humanoid_info = humanoid_model.to_info("humanoid", "1.0")
  let quadruped_info = quadruped_model.to_info("quadruped", "1.0")
  let arm_info = arm_model.to_info("arm_6dof", "1.0")

  let humanoid_robot = @gazebo.GazeboRobot::from_client(sim, humanoid_info)
  let quadruped_robot = @gazebo.GazeboRobot::from_client(sim, quadruped_info)
  let arm_robot = @gazebo.GazeboRobot::from_client(sim, arm_info)

  // 5. 验证 Robot trait 接口
  let _h_info = humanoid_robot.get_model_info()
  let _q_info = quadruped_robot.get_model_info()
  let _a_info = arm_robot.get_model_info()

  // 6. 关节分组管理：人形机器人左腿/右腿
  let left_leg = @control.JointGroup::new("left_leg", [
    "left_hip_yaw", "left_hip_roll", "left_hip_pitch", "left_knee", "left_ankle_pitch",
    "left_ankle_roll",
  ])
  let right_leg = @control.JointGroup::new("right_leg", [
    "right_hip_yaw", "right_hip_roll", "right_hip_pitch", "right_knee", "right_ankle_pitch",
    "right_ankle_roll",
  ])
  let leg_manager = @control.JointGroupManager::new()
  leg_manager.add(left_leg)
  leg_manager.add(right_leg)

  // 7. 设置关节位置（模拟行走步态）
  let left_leg_group = leg_manager.get("left_leg")
  left_leg_group.set_position("left_hip_pitch", 0.3)
  left_leg_group.set_position("left_knee", 0.6)
  let right_leg_group = leg_manager.get("right_leg")
  right_leg_group.set_position("right_hip_pitch", -0.3)
  right_leg_group.set_position("right_knee", 0.0)

  // 8. 执行动作指令
  let commands : Array[@core.ActionCommand] = [
    { joint_commands: left_leg_group.get_positions(), timestamp: 0.0 },
    { joint_commands: right_leg_group.get_positions(), timestamp: 0.5 },
  ]
  humanoid_robot.execute_actions(commands)

  // 9. 四足机器人关节分组
  let fl_leg = @control.JointGroup::new("fl_leg", [
    "fl_hip", "fl_thigh", "fl_knee",
  ])
  fl_leg.set_positions([("fl_hip", 0.2), ("fl_thigh", -0.5), ("fl_knee", 1.0)])

  // 10. 场景清理：移除模型
  sim.remove_model("arm_6dof")
  sim.remove_model("quadruped")
  sim.remove_model("humanoid")

  // 11. 断开连接
  sim.disconnect()
}

///|
/// 笛卡尔空间控制 Demo：使用 CartesianController 规划末端轨迹。
///
/// 演示 Phase 3 新增功能：
/// - CartesianController 笛卡尔空间控制器
/// - CartesianTrajectory 笛卡尔轨迹规划
/// - IKSolver / FKSolver 运动学解算 trait
/// - move_to 直线轨迹规划
/// - to_joint_states 笛卡尔→关节转换
pub fn cartesian_control_demo() -> Unit raise @core.RobotError {
  // 1. 创建简化笛卡尔控制器（6-DOF 机械臂）
  let ctrl = @control.SimpleCartesianController::new(6, "ee_link")

  // 2. 定义起点和目标位姿
  let start : @control.Pose = @control.Pose::new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  let target : @control.Pose = @control.Pose::new(0.5, 0.3, 0.2, 0.1, 0.0, 0.0)

  // 3. 规划直线轨迹（速度 0.5 m/s，采样间隔 0.05s）
  let traj = ctrl.move_to(start, target, 0.5, 0.05)

  // 4. 转换为关节状态序列
  let joint_seqs = ctrl.to_joint_states(traj)

  // 5. 验证末端位姿一致性（通过正运动学）
  for i in 0..<joint_seqs.length() {
    let _pose = ctrl.get_end_effector_pose(joint_seqs[i])
    let _wp = traj.waypoints[i]
  }

  // 6. 查询控制器属性
  let _dof = ctrl.dof()
  let _ee = ctrl.end_effector_name()
}

///|
/// 全栈综合 Demo：串联框架全部核心功能。
///
/// 演示 Phase 1-4 完整能力：
/// - RobotBuilder 机型工厂 + GazeboRobot 仿真封装
/// - 世界控制（暂停/步进/重力）+ 场景管理（spawn/remove）
/// - JointGroup 关节分组 + SimpleCartesianController 笛卡尔规划
/// - PID 闭环控制 + SensorFusion 状态估计
/// - VLA 推理 + 安全联锁 + 可视化监控 + 数据录制
pub fn full_stack_demo() -> Unit raise @core.RobotError {
  // 1. 连接仿真并配置世界
  let sim = @gazebo.GazeboClient::connect("localhost:9030")
  sim.pause()
  sim.set_gravity(0.0, 0.0, -9.81)

  // 2. 使用 RobotBuilder 构建 6-DOF 机械臂
  let arm_model = @core.RobotBuilder::arm_6dof()
  let arm_info = arm_model.to_info("arm_6dof", "1.0")

  // 3. 场景管理：生成模型
  sim.spawn_model("arm_6dof")

  // 4. 创建 GazeboRobot 封装
  let robot = @gazebo.GazeboRobot::from_client(sim, arm_info)

  // 5. 加载 VLA 模型
  let model = @ggml.VlaModel::load("models/smolvla-7b-q4.gguf")

  // 6. 创建运动控制器
  let ctrl = @control.MotionController::new(arm_model)
  ctrl.attach_simulation(sim)

  // 7. 关节分组：前 3 关节 + 后 3 关节
  let wrist = @control.JointGroup::new("wrist", ["joint1", "joint2", "joint3"])
  let gripper = @control.JointGroup::new("gripper", [
    "joint4", "joint5", "joint6",
  ])
  ignore(wrist)
  ignore(gripper)

  // 8. 笛卡尔控制器
  let cart_ctrl = @control.SimpleCartesianController::new(6, "ee_link")

  // 9. PID 控制器（关节级闭环）
  let pid = @control.PIDController::new(2.0, 0.5, 0.05)
  pid.set_output_limits(-5.0, 5.0)

  // 10. 传感器融合 + 计时器
  let fusion = @control.SensorFusion::new(0.98)
  let timer = @core.Timer::start()

  // 11. 可视化面板 + 数据录制
  let panel = @view.ViewPanel::with_model(arm_info)
  panel.add_widget({
    widget_type: JointPlot,
    title: "Joint Trajectories",
    topic: "/joint_states",
  })
  panel.add_widget({
    widget_type: View3D,
    title: "3D View",
    topic: "/robot_state",
  })
  panel.add_widget({
    widget_type: ParameterTuner,
    title: "Control Gains",
    topic: "/control/params",
  })
  let pos_series = @view.DataSeries::with_default_capacity("joint_position")
  let vel_series = @view.DataSeries::with_default_capacity("joint_velocity")

  // 12. VLA 推理：场景图像 + 抓取指令 → 动作
  let _ = model.infer(
    b"workspace_image", "pick up the red block and place on green pad",
  )

  // 13. 笛卡尔轨迹规划：从初始位姿到抓取位姿
  let home : @control.Pose = @control.Pose::new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  let pick : @control.Pose = @control.Pose::new(0.4, 0.0, 0.1, 0.0, 1.57, 0.0)
  let place : @control.Pose = @control.Pose::new(0.4, 0.3, 0.1, 0.0, 1.57, 0.0)

  let traj1 = cart_ctrl.move_to(home, pick, 0.3, 0.02)
  let traj2 = cart_ctrl.move_to(pick, place, 0.3, 0.02)
  let traj3 = cart_ctrl.move_to(place, home, 0.3, 0.02)
  ignore(traj1)
  ignore(traj2)
  ignore(traj3)

  // 14. 关节级轨迹规划（安全联锁）
  let start_joints : Array[(String, Double)] = [
    ("joint1", 0.0),
    ("joint2", 0.0),
    ("joint3", 0.0),
  ]
  let goal_joints : Array[(String, Double)] = [
    ("joint1", 0.5),
    ("joint2", -0.3),
    ("joint3", 0.8),
  ]
  let constraints : @control.TrajectoryConstraints = {
    max_velocity: 1.5,
    max_acceleration: 4.0,
    time_step: 0.02,
  }
  let joint_traj = ctrl.compute_trajectory_cubic(
    start_joints, goal_joints, constraints,
  )
  let commands = joint_traj.to_commands()
  ctrl.check_safety(commands)

  // 15. 控制环路：步进仿真 + PID 闭环 + 传感器融合 + 数据录制
  let dt = 0.02
  let mut current_pos = 0.0
  let recording = panel.record("full_stack_session")
  for i in 0..<joint_traj.waypoints.length() {
    timer.tick(dt)
    // PID 闭环
    let (_, target_pos) = goal_joints[0]
    let output = pid.update(target_pos, current_pos, dt)
    current_pos = current_pos + output * dt
    // 传感器融合
    fusion.update(output, current_pos, dt)
    // 记录数据
    let t = timer.elapsed()
    pos_series.push(t, current_pos)
    vel_series.push(t, output)
    // 发布关节指令
    sim.publish("/joint_commands", b"cmd")
    // 步进仿真
    sim.step(1)
    // 录制帧
    if i % 10 == 0 {
      recording.add_frame()
    }
  }

  // 16. 参数调优
  panel.tune_parameter("kp", 2.0)
  panel.tune_parameter("ki", 0.5)
  panel.tune_parameter("kd", 0.05)

  // 17. 导出快照
  let _snapshot = panel.export_snapshot()

  // 18. 查询统计
  let _pos_mean = pos_series.mean()
  let _vel_max = vel_series.max()
  let _freq = timer.average_frequency()

  // 19. 执行动作指令
  robot.execute_actions(commands)

  // 20. 清理：停止录制 + 移除模型 + 恢复仿真 + 断开
  recording.stop()
  panel.stop_recording()
  sim.remove_model("arm_6dof")
  sim.unpause()
  model.free()
  sim.disconnect()
}
