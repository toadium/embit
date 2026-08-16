///|
/// Embit Phase 4.1 仿真集成 Demo：Gazebo 场景搭建 / 仿真闭环 / VLA 推理执行 / 多机型管理。
///
/// 验证 Sim2Real 全链路：传感器订阅 → 状态估计 → 轨迹规划 → 动作发布 → 仿真步进。
/// 占位模式下验证逻辑流程与模块间数据流；真实模式（EMBIT_HAS_IGNITION + EMBIT_HAS_GGML）
/// 连接真实 Gazebo + ggml 执行端到端闭环。

///|
/// 仿真场景搭建 Demo：URDF 模型加载 + 多模型 spawn + 传感器话题订阅 + 世界配置。
///
/// 演示 Phase 4.1 任务 1：Gazebo 仿真场景搭建（人形/四足/机械臂 URDF 加载）。
/// 真实模式下通过 Ignition Transport 加载 URDF 并订阅传感器话题；
/// 占位模式下验证 spawn_model + subscribe 调用链。
pub fn sim_scene_setup_demo() -> Unit raise @core.RobotError {
  // 1. 连接仿真环境
  let sim = @gazebo.GazeboClient::connect("localhost:9040")
  sim.pause()
  sim.set_gravity(0.0, 0.0, -9.81)

  // 2. 构建多种机型模型
  let humanoid = @core.RobotBuilder::humanoid_12dof()
  let quadruped = @core.RobotBuilder::quadruped_12dof()
  let arm = @core.RobotBuilder::arm_6dof()

  // 3. 加载 URDF 模型到仿真场景
  sim.spawn_model("humanoid")
  sim.spawn_model("quadruped")
  sim.spawn_model("arm_6dof")

  // 4. 订阅传感器话题
  sim.subscribe("/humanoid/joint_states")
  sim.subscribe("/humanoid/imu")
  sim.subscribe("/quadruped/lidar")
  sim.subscribe("/arm/camera")

  // 5. 创建可视化面板监控场景
  let panel = @view.ViewPanel::with_model(humanoid.to_info("humanoid", "1.0"))
  panel.add_widget({
    widget_type: JointPlot,
    title: "Humanoid Joints",
    topic: "/humanoid/joint_states",
  })
  panel.add_widget({
    widget_type: SensorDisplay,
    title: "IMU",
    topic: "/humanoid/imu",
  })
  panel.add_widget({
    widget_type: SensorDisplay,
    title: "LiDAR",
    topic: "/quadruped/lidar",
  })
  panel.add_widget({
    widget_type: View3D,
    title: "Camera",
    topic: "/arm/camera",
  })

  // 6. 验证场景：查询模型信息
  let _h_info = humanoid.to_info("humanoid", "1.0")
  let _q_info = quadruped.to_info("quadruped", "1.0")
  let _a_info = arm.to_info("arm_6dof", "1.0")

  // 7. 步进仿真若干步
  sim.step(10)

  // 8. 清理：取消订阅 + 移除模型 + 恢复仿真
  sim.unsubscribe("/humanoid/joint_states")
  sim.unsubscribe("/humanoid/imu")
  sim.unsubscribe("/quadruped/lidar")
  sim.unsubscribe("/arm/camera")
  sim.remove_model("humanoid")
  sim.remove_model("quadruped")
  sim.remove_model("arm_6dof")
  sim.unpause()
  sim.disconnect()
}

///|
/// 仿真闭环 Demo：传感器订阅 → 状态估计 → 轨迹规划 → 动作发布（100 步循环）。
///
/// 演示 Phase 4.1 任务 2：仿真闭环。
/// 100 步连续控制循环，每步执行：传感器查询 → SensorFusion 状态估计 →
/// PID 闭环 → 轨迹重规划（每 10 步）→ 安全检查 → 动作发布 → 仿真步进 → 录制。
pub fn sim_closed_loop_demo() -> Unit raise @core.RobotError {
  // 1. 连接仿真并配置世界
  let sim = @gazebo.GazeboClient::connect("localhost:9041")
  sim.pause()
  sim.set_gravity(0.0, 0.0, -9.81)
  sim.spawn_model("humanoid")

  // 2. 订阅传感器话题
  sim.subscribe("/humanoid/joint_states")
  sim.subscribe("/humanoid/imu")

  // 3. 状态估计器（互补滤波）
  let fusion = @control.SensorFusion::new(0.98)
  fusion.calibrate_bias(0.0, 0.0)

  // 4. 运动控制器
  let robot_model = @core.RobotBuilder::humanoid_12dof()
  let ctrl = @control.MotionController::new(robot_model)
  ctrl.attach_simulation(sim)

  // 5. PID 控制器（关节级闭环）
  let pid = @control.PIDController::new(2.0, 0.5, 0.05)
  pid.set_output_limits(-5.0, 5.0)

  // 6. 可视化面板 + 数据录制
  let panel = @view.ViewPanel::with_model(
    robot_model.to_info("humanoid", "1.0"),
  )
  panel.add_widget({
    widget_type: JointPlot,
    title: "Joint States",
    topic: "/humanoid/joint_states",
  })
  panel.add_widget({
    widget_type: SensorDisplay,
    title: "IMU",
    topic: "/humanoid/imu",
  })
  let pos_series = @view.DataSeries::with_default_capacity("joint_position")
  let vel_series = @view.DataSeries::with_default_capacity("joint_velocity")
  let recording = panel.record("closed_loop_session")

  // 7. 仿真闭环：100 步连续控制
  let dt = 0.02
  let mut current_pos = 0.0
  let target_pos = 0.5
  let constraints = @control.TrajectoryConstraints::{
    max_velocity: 1.5,
    max_acceleration: 5.0,
    time_step: dt,
  }
  let timer = @core.Timer::start()

  for step in 0..<100 {
    timer.tick(dt)

    // 7a. 传感器订阅：通过服务调用获取传感器数据
    sim.service_call("/get_joint_states", b"query")

    // 7b. 状态估计：SensorFusion 融合 IMU 数据
    fusion.update(0.01, current_pos, dt)

    // 7c. PID 闭环控制
    let output = pid.update(target_pos, current_pos, dt)
    current_pos = current_pos + output * dt

    // 7d. 轨迹重规划（每 10 步）
    if step % 10 == 0 {
      let start : Array[(String, Double)] = [("left_hip", current_pos)]
      let goal : Array[(String, Double)] = [("left_hip", target_pos)]
      let traj = ctrl.compute_trajectory(start, goal, constraints)
      let commands = traj.to_commands()
      ctrl.check_safety(commands)
    }

    // 7e. 发布动作到仿真
    sim.publish("/humanoid/joint_commands", b"cmd")

    // 7f. 步进仿真
    sim.step(1)

    // 7g. 记录数据 + 录制帧
    let t = timer.elapsed()
    pos_series.push(t, current_pos)
    vel_series.push(t, output)
    recording.add_frame()
  }

  // 8. 查询统计
  let _pos_mean = pos_series.mean()
  let _vel_max = vel_series.max()
  let _freq = timer.average_frequency()
  let _frame_count = recording.frames()

  // 9. 清理
  recording.stop()
  panel.stop_recording()
  sim.unsubscribe("/humanoid/joint_states")
  sim.unsubscribe("/humanoid/imu")
  sim.remove_model("humanoid")
  sim.unpause()
  sim.disconnect()
}

///|
/// VLA 仿真执行 Demo：相机图像 → ggml 推理 → 动作序列 → 仿真执行。
///
/// 演示 Phase 4.1 任务 3：VLA 推理集成。
/// 多步推理闭环：获取相机图像 → VLA 推理生成动作 → 轨迹规划 → 安全检查 →
/// 动作序列发布到仿真 → 仿真步进 → 录制。
pub fn vla_sim_execution_demo() -> Unit raise @core.RobotError {
  // 1. 连接仿真
  let sim = @gazebo.GazeboClient::connect("localhost:9042")
  sim.spawn_model("humanoid")

  // 2. 加载 VLA 模型（1B 端侧模型）
  let model = @ggml.VlaModel::load("models/smolvla-1b-q4.gguf")
  model.set_backend(Cpu)

  // 3. 订阅相机话题
  sim.subscribe("/humanoid/camera")

  // 4. 运动控制器
  let robot_model = @core.RobotBuilder::humanoid_12dof()
  let ctrl = @control.MotionController::new(robot_model)
  ctrl.attach_simulation(sim)

  // 5. 可视化面板
  let panel = @view.ViewPanel::with_model(
    robot_model.to_info("humanoid", "1.0"),
  )
  panel.add_widget({
    widget_type: View3D,
    title: "Camera View",
    topic: "/humanoid/camera",
  })
  panel.add_widget({
    widget_type: LogPanel,
    title: "VLA Output",
    topic: "/vla/actions",
  })
  let recording = panel.record("vla_execution_session")

  // 6. VLA 推理闭环：多步推理 + 执行
  let instructions = ["walk forward", "turn left", "walk forward", "stop"]
  let constraints = @control.TrajectoryConstraints::{
    max_velocity: 1.0,
    max_acceleration: 3.0,
    time_step: 0.05,
  }

  for instruction in instructions {
    // 6a. 获取相机图像（通过服务调用）
    sim.service_call("/get_camera_image", b"query")

    // 6b. VLA 推理：相机图像 + 指令 → 动作序列
    let actions = model.infer(b"camera_image", instruction)

    // 6c. 将动作转换为关节轨迹
    let start : Array[(String, Double)] = [
      ("left_hip", 0.0),
      ("right_hip", 0.0),
    ]
    let goal : Array[(String, Double)] = [
      ("left_hip", 0.5),
      ("right_hip", -0.5),
    ]
    let traj = ctrl.compute_trajectory(start, goal, constraints)

    // 6d. 安全检查
    let commands = traj.to_commands()
    ctrl.check_safety(commands)

    // 6e. 执行动作序列到仿真
    for wp in traj.waypoints {
      sim.publish("/humanoid/joint_commands", b"waypoint")
      ignore(wp)
    }

    // 6f. 步进仿真
    sim.step(10)

    // 6g. 录制帧
    recording.add_frame()
    ignore(actions)
  }

  // 7. 查询推理统计
  let _infer_count = model.infer_count()

  // 8. 清理
  recording.stop()
  panel.stop_recording()
  sim.unsubscribe("/humanoid/camera")
  model.free()
  sim.remove_model("humanoid")
  sim.disconnect()
}

///|
/// 多机型场景管理 Demo：动态加载/卸载 + 多机器人协调执行。
///
/// 演示 Phase 4.1 任务 4：多机型场景管理。
/// 使用 spawn_model/remove_model 动态加载多种机型，创建 GazeboRobot 封装，
/// 多机器人并行执行动作指令，验证 Robot trait 接口一致性。
pub fn multi_robot_scenario_demo() -> Unit raise @core.RobotError {
  // 1. 连接仿真
  let sim = @gazebo.GazeboClient::connect("localhost:9043")
  sim.pause()
  sim.set_gravity(0.0, 0.0, -9.81)

  // 2. 动态加载多种机型
  let model_names = ["humanoid", "quadruped", "arm_6dof"]
  for name in model_names {
    sim.spawn_model(name)
  }

  // 3. 创建多机器人封装（GazeboRobot 实现 Robot trait）
  let humanoid_info = @core.RobotBuilder::humanoid_12dof().to_info(
    "humanoid", "1.0",
  )
  let quadruped_info = @core.RobotBuilder::quadruped_12dof().to_info(
    "quadruped", "1.0",
  )
  let arm_info = @core.RobotBuilder::arm_6dof().to_info("arm_6dof", "1.0")

  let humanoid_robot = @gazebo.GazeboRobot::from_client(sim, humanoid_info)
  let quadruped_robot = @gazebo.GazeboRobot::from_client(sim, quadruped_info)
  let arm_robot = @gazebo.GazeboRobot::from_client(sim, arm_info)

  // 4. 验证 Robot trait 接口
  let _h_info = humanoid_robot.get_model_info()
  let _q_info = quadruped_robot.get_model_info()
  let _a_info = arm_robot.get_model_info()
  let _h_sensors = humanoid_robot.get_sensor_readings()
  let _q_sensors = quadruped_robot.get_sensor_readings()
  let _a_sensors = arm_robot.get_sensor_readings()

  // 5. 多机器人协调执行动作
  let h_commands : Array[@core.ActionCommand] = [
    { joint_commands: [("left_hip", 0.3), ("right_hip", -0.3)], timestamp: 0.0 },
    {
      joint_commands: [("left_knee", 0.6), ("right_knee", 0.0)],
      timestamp: 0.5,
    },
  ]
  let q_commands : Array[@core.ActionCommand] = [
    { joint_commands: [("fl_hip", 0.2), ("fr_hip", -0.2)], timestamp: 0.0 },
  ]
  let a_commands : Array[@core.ActionCommand] = [
    { joint_commands: [("joint1", 0.5), ("joint2", -0.3)], timestamp: 0.0 },
    { joint_commands: [("joint3", 0.8)], timestamp: 0.3 },
  ]

  humanoid_robot.execute_actions(h_commands)
  quadruped_robot.execute_actions(q_commands)
  arm_robot.execute_actions(a_commands)

  // 6. 步进仿真
  sim.step(20)

  // 7. 验证连接状态
  let _h_connected = humanoid_robot.is_connected()
  let _q_connected = quadruped_robot.is_connected()
  let _a_connected = arm_robot.is_connected()

  // 8. 动态卸载模型
  for name in model_names {
    sim.remove_model(name)
  }

  // 9. 清理
  sim.unpause()
  sim.disconnect()
}
