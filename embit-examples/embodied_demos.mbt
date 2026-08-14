///|
/// Embit 具身智能任务 Demo：人形行走 / 四足避障 / 机械臂抓取。
///
/// 每个 Demo 串联仿真通信 → VLA 推理 → 运动控制 → 可视化监控全链路。

///|
/// 人形机器人行走任务 Demo。
///
/// 演示完整链路：连接仿真 → 加载 VLA 模型 → 规划行走轨迹 → 执行 → 监控。
/// Phase 1 占位实现：验证模块间依赖与数据流，不执行真实控制。
pub fn humanoid_walk() -> Unit raise @core.RobotError {
  // 1. 连接仿真环境
  let sim = @gazebo.GazeboClient::connect("localhost:9000")
  // 2. 加载 VLA 模型
  let model = @ggml.VlaModel::load("models/smolvla-7b-q4.gguf")
  // 3. 构建运动控制器
  let robot_model = humanoid_model()
  let ctrl = @control.MotionController::new(robot_model)
  ctrl.attach_simulation(sim)
  // 4. 创建可视化面板
  let panel = make_view_panel({
    name: "humanoid",
    version: "1.0",
    dof: 12,
    urdf_path: "models/humanoid.urdf",
  })
  // 5. 录制会话
  let recording = panel.record("humanoid_walk_session")
  recording.add_frame()
  // 6. VLA 推理：图像 + 指令 → 动作序列
  let _ = model.infer(b"camera_image_data", "walk forward 2 meters")
  // 7. 规划行走轨迹（双腿交替前进）
  let start : Array[(String, Double)] = [("left_hip", 0.0), ("right_hip", 0.0)]
  let goal : Array[(String, Double)] = [("left_hip", 0.5), ("right_hip", -0.5)]
  let constraints = @control.TrajectoryConstraints::{
    max_velocity: 1.5,
    max_acceleration: 5.0,
    time_step: 0.05,
  }
  let traj = ctrl.compute_trajectory(start, goal, constraints)
  // 8. 安全联锁检查
  let commands = traj.to_commands()
  ctrl.check_safety(commands)
  // 9. 发布轨迹到仿真
  for wp in traj.waypoints {
    sim.publish("/joint_commands", b"waypoint")
    ignore(wp)
  }
  // 10. 停止录制并清理
  recording.stop()
  panel.stop_recording()
  model.free()
  sim.disconnect()
}

///|
/// 四足机器人避障任务 Demo。
///
/// 演示 LiDAR 感知 → VLA 决策 → 避障轨迹规划 → 执行全链路。
pub fn quadruped_avoid() -> Unit raise @core.RobotError {
  let sim = @gazebo.GazeboClient::connect("localhost:9001")
  let model = @ggml.VlaModel::load("models/smolvla-7b-q4.gguf")
  let robot_model = quadruped_model()
  let ctrl = @control.MotionController::new(robot_model)
  ctrl.attach_simulation(sim)
  let panel = make_view_panel({
    name: "quadruped",
    version: "1.0",
    dof: 12,
    urdf_path: "models/quadruped.urdf",
  })
  panel.add_widget({
    widget_type: SensorDisplay,
    title: "LiDAR Scan",
    topic: "/lidar/scan",
  })
  let recording = panel.record("quadruped_avoid_session")
  // VLA 推理：LiDAR 数据 + 避障指令 → 转向动作
  let _ = model.infer(b"lidar_scan_data", "avoid obstacle on the left")
  // 规划转向轨迹
  let start : Array[(String, Double)] = [("fl_hip", 0.0), ("fr_hip", 0.0)]
  let goal : Array[(String, Double)] = [("fl_hip", 0.3), ("fr_hip", -0.3)]
  let constraints = @control.TrajectoryConstraints::{
    max_velocity: 2.0,
    max_acceleration: 8.0,
    time_step: 0.02,
  }
  let traj = ctrl.compute_trajectory(start, goal, constraints)
  // 安全联锁检查
  let commands = traj.to_commands()
  ctrl.check_safety(commands)
  for wp in traj.waypoints {
    sim.publish("/gait_commands", b"avoid_waypoint")
    ignore(wp)
  }
  recording.add_frame()
  recording.stop()
  model.free()
  sim.disconnect()
}

///|
/// 机械臂抓取任务 Demo。
///
/// 演示视觉感知 → VLA 抓取策略 → 关节轨迹规划 → 抓取执行全链路。
pub fn arm_grasp() -> Unit raise @core.RobotError {
  let sim = @gazebo.GazeboClient::connect("localhost:9002")
  let model = @ggml.VlaModel::load("models/smolvla-7b-q4.gguf")
  let robot_model = arm_model()
  let ctrl = @control.MotionController::new(robot_model)
  ctrl.attach_simulation(sim)
  let panel = make_view_panel({
    name: "arm6dof",
    version: "1.0",
    dof: 6,
    urdf_path: "models/arm6dof.urdf",
  })
  panel.add_widget({
    widget_type: ParameterTuner,
    title: "Grasp Parameters",
    topic: "/grasp/params",
  })
  let recording = panel.record("arm_grasp_session")
  // VLA 推理：腕部相机图像 + 抓取指令 → 关节目标
  let _ = model.infer(b"wrist_camera_image", "grasp the red block")
  // 规划抓取轨迹（从初始位置到目标位置）
  let start : Array[(String, Double)] = [
    ("joint1", 0.0),
    ("joint2", 0.0),
    ("joint3", 0.0),
  ]
  let goal : Array[(String, Double)] = [
    ("joint1", 0.8),
    ("joint2", -0.5),
    ("joint3", 1.2),
  ]
  let constraints = @control.TrajectoryConstraints::{
    max_velocity: 1.0,
    max_acceleration: 4.0,
    time_step: 0.01,
  }
  let traj = ctrl.compute_trajectory(start, goal, constraints)
  // 安全联锁检查
  let commands = traj.to_commands()
  ctrl.check_safety(commands)
  for wp in traj.waypoints {
    sim.publish("/arm_commands", b"grasp_waypoint")
    ignore(wp)
  }
  recording.add_frame()
  recording.stop()
  // 回放录制
  if recording.frames() > 0 {
    let _ = panel.playback(recording)
  }
  model.free()
  sim.disconnect()
}
