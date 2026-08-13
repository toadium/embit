///|
/// Embit 示例工程集。
///
/// 提供三类典型具身任务 Demo，展示框架端到端使用方式：
/// - `humanoid_walk`：人形机器人行走任务
/// - `quadruped_avoid`：四足机器人避障任务
/// - `arm_grasp`：机械臂抓取任务
///
/// 每个 Demo 串联仿真通信 → VLA 推理 → 运动控制 → 可视化监控全链路。

///|
/// 构建人形机器人模型（12 自由度，双腿 + 双臂 + 躯干）。
fn humanoid_model() -> @core.RobotModel {
  {
    urdf_path: "models/humanoid.urdf",
    joints: [],
    sensors: [
      { name: "camera", sensor_type: Camera, topic: "/camera/image" },
      { name: "imu", sensor_type: Imu, topic: "/imu/data" },
    ],
    limits: {
      max_joint_velocity: 2.0,
      max_joint_effort: 50.0,
      collision_check_distance: 0.05,
    },
  }
}

///|
/// 构建四足机器人模型（12 自由度，四腿各 3 关节）。
fn quadruped_model() -> @core.RobotModel {
  {
    urdf_path: "models/quadruped.urdf",
    joints: [],
    sensors: [{ name: "lidar", sensor_type: Lidar, topic: "/lidar/scan" }],
    limits: {
      max_joint_velocity: 3.0,
      max_joint_effort: 30.0,
      collision_check_distance: 0.1,
    },
  }
}

///|
/// 构建机械臂模型（6 自由度）。
fn arm_model() -> @core.RobotModel {
  {
    urdf_path: "models/arm6dof.urdf",
    joints: [],
    sensors: [
      {
        name: "wrist_camera",
        sensor_type: Camera,
        topic: "/wrist_camera/image",
      },
    ],
    limits: {
      max_joint_velocity: 1.5,
      max_joint_effort: 20.0,
      collision_check_distance: 0.02,
    },
  }
}

///|
/// 创建可视化面板并添加标准组件。
fn make_view_panel(model_info : @core.RobotModelInfo) -> @view.ViewPanel {
  let panel = @view.ViewPanel::with_model(model_info)
  panel.add_widget({
    widget_type: JointPlot,
    title: "Joint Trajectories",
    topic: "/joint_states",
  })
  panel.add_widget({
    widget_type: View3D,
    title: "3D Robot View",
    topic: "/robot_state",
  })
  panel.add_widget({
    widget_type: LogPanel,
    title: "Control Log",
    topic: "/control/log",
  })
  panel
}

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
  let constraints : @control.TrajectoryConstraints = {
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
  let constraints : @control.TrajectoryConstraints = {
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
  let constraints : @control.TrajectoryConstraints = {
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

///|
/// 示例工程占位入口（保留用于编译期依赖验证）。
pub fn demo_skeleton() -> Unit {
  let _ = @gazebo.GazeboClient::connect("localhost:9000")
  let _ = @ggml.VlaModel::load("models/smolvla.gguf")
  let _ = @view.ViewPanel::new()
  let limits : @core.SafetyLimits = {
    max_joint_velocity: 0.0,
    max_joint_effort: 0.0,
    collision_check_distance: 0.0,
  }
  let model : @core.RobotModel = {
    urdf_path: "",
    joints: [],
    sensors: [],
    limits,
  }
  let _ = @control.MotionController::new(model)
}

///|
/// VLA 推理管线完整 Demo。
///
/// 演示 Phase 2 新增功能：
/// - Tensor 张量创建与运算
/// - InferConfig 推理配置
/// - batch_infer 批量推理
/// - ImpedanceController 阻抗控制
/// - Twist / Wrench 空间力学
/// - ViewPanel 参数在线调优与快照导出
pub fn vla_pipeline_demo() -> Unit raise @core.RobotError {
  // 1. 连接仿真并加载模型
  let sim = @gazebo.GazeboClient::connect("localhost:9003")
  let model = @ggml.VlaModel::load("models/smolvla-7b-q4.gguf")
  // 2. 配置推理参数
  let cfg = @ggml.InferConfig::new(0.7, 40, 0.9, 256)
  // 3. 批量推理：多组图像 + 指令
  let inputs : Array[(Bytes, String)] = [
    (b"scene_1_image", "pick up the red block"),
    (b"scene_2_image", "place it on the shelf"),
    (b"scene_3_image", "open the drawer"),
  ]
  let _ = model.batch_infer_with_config(inputs, cfg)
  // 4. 张量运算：构建动作向量
  let action_vec = @ggml.Tensor::vector([0.5, -0.3, 0.8, 0.0, 0.1, -0.2])
  let scaled = action_vec.scale(2.0)
  ignore(scaled)
  // 5. 阻抗控制：弹簧-阻尼模型
  let imp = @control.ImpedanceController::new(100.0, 20.0)
  imp.set_target(0.5, 0.0)
  let _force = imp.compute(0.3, 0.1)
  // 6. 空间力学：Twist 与 Wrench
  let twist = @core.Twist::linear(0.5, 0.0, 0.0)
  let wrench = @core.Wrench::force(10.0, 0.0, 0.0)
  let power = twist.dot_wrench(wrench)
  ignore(power)
  // 7. 可视化面板与参数调优
  let panel = @view.ViewPanel::with_model({
    name: "vla_pipeline",
    version: "2.0",
    dof: 6,
    urdf_path: "models/arm6dof.urdf",
  })
  panel.add_widget({
    widget_type: ParameterTuner,
    title: "Impedance Gains",
    topic: "/control/impedance",
  })
  panel.tune_parameter("stiffness", 100.0)
  panel.tune_parameter("damping", 20.0)
  panel.tune_parameter("max_velocity", 1.5)
  // 8. 导出快照
  let _snapshot = panel.export_snapshot()
  // 9. 服务调用
  sim.service_call("/get_robot_state", b"query")
  // 10. 清理
  model.free()
  sim.disconnect()
}

///|
/// 阻抗控制 Demo：弹簧-阻尼模型实现力位混合控制。
///
/// 演示 Phase 2 新增功能：
/// - ImpedanceController 阻抗控制（刚度/阻尼/前馈力）
/// - Timer 控制环路计时
/// - SensorFusion 互补滤波器
/// - DataSeries 实时数据记录
/// - 仿真世界控制（暂停/步进/重力设置）
pub fn impedance_control_demo() -> Unit raise @core.RobotError {
  // 1. 连接仿真并配置世界
  let sim = @gazebo.GazeboClient::connect("localhost:9004")
  sim.pause()
  sim.set_gravity(0.0, 0.0, -9.81)
  // 2. 创建阻抗控制器（K=200, D=28.28 ≈ 临界阻尼）
  let imp = @control.ImpedanceController::new(200.0, 28.28)
  imp.set_target(0.5, 0.0) // 目标位置 0.5 rad
  // 3. 创建计时器与传感器融合
  let timer = @core.Timer::start()
  let fusion = @control.SensorFusion::default()
  // 4. 创建数据序列记录位置与力
  let pos_series = @view.DataSeries::with_default_capacity("joint_position")
  let force_series = @view.DataSeries::with_default_capacity("control_force")
  // 5. 模拟控制环路（100 步，dt=0.01s）
  let dt = 0.01
  let mut current_pos = 0.0
  let mut current_vel = 0.0
  for _ in 0..<100 {
    // 计时
    timer.tick(dt)
    // 阻抗控制计算输出力
    let force = imp.compute(current_pos, current_vel)
    // 简化动力学：m * a = F（m=1kg）
    let accel = force // / mass(1.0)
    current_vel = current_vel + accel * dt
    current_pos = current_pos + current_vel * dt
    // 传感器融合（模拟 IMU 数据）
    fusion.update(current_vel, current_pos, dt)
    // 记录数据
    let t = timer.elapsed()
    pos_series.push(t, current_pos)
    force_series.push(t, force)
    // 步进仿真
    sim.step(1)
  }
  // 6. 查询统计
  let _pos_mean = pos_series.mean()
  let _force_max = force_series.max()
  // 7. 恢复仿真并清理
  sim.unpause()
  sim.disconnect()
}

///|
/// 传感器融合 Demo：互补滤波器融合 IMU 与编码器数据。
///
/// 演示 SensorFusion 互补滤波、零偏校准与低通滤波全流程。
pub fn sensor_fusion_demo() -> Unit {
  // 1. 创建传感器融合器（alpha=0.98）
  let fusion = @control.SensorFusion::new(0.98)
  // 2. 零偏校准（模拟静止时陀螺仪有 0.02 rad/s 零偏）
  for _ in 0..<200 {
    fusion.calibrate_bias(0.02, 0.05)
  }
  // 3. 模拟运动：正弦摆动
  let dt = 0.01
  let timer = @core.Timer::start()
  let pos_series = @view.DataSeries::with_default_capacity("fused_orientation")
  let vel_series = @view.DataSeries::with_default_capacity("fused_velocity")
  for i in 0..<500 {
    timer.tick(dt)
    // 真实角度 = sin(t)
    let t = i.to_double() * dt
    let true_angle = @core.deg_to_rad(30.0) * @math.sin(t * 10.0) / @core.pi
    // 陀螺仪读数 = 真实角速度 + 噪声（占位：省略噪声）
    let gyro_rate = @core.deg_to_rad(30.0) *
      10.0 *
      @math.cos(t * 10.0) /
      @core.pi
    // 加速度计读数 = 真实角度 + 噪声（占位：省略噪声）
    let accel_angle = true_angle
    // 融合更新
    fusion.update(gyro_rate, accel_angle, dt)
    // 记录数据
    pos_series.push(t, fusion.get_orientation())
    vel_series.push(t, fusion.get_velocity())
  }
  // 4. 查询统计
  let _pos_stats = pos_series.mean()
  let _vel_stats = vel_series.max()
}

///|
/// 批量推理 Demo：对多组场景执行 VLA 批量推理。
///
/// 演示 Tensorizer、InferConfig 与 batch_infer_with_config 全流程。
pub fn batch_inference_demo() -> Unit raise @core.RobotError {
  // 1. 加载模型与创建 Tokenizer
  let model = @ggml.VlaModel::load("models/smolvla-7b-q4.gguf")
  let tokenizer = @ggml.Tokenizer::default()
  // 2. 查询模型元信息
  let info = model.get_model_info()
  ignore(info)
  // 3. 准备多组推理输入
  let instructions = [
    "pick up the red block", "place it on the green plate", "open the top drawer",
    "push the blue button", "rotate the valve clockwise",
  ]
  // 4. 检查上下文窗口是否足够
  for instruction in instructions {
    let token_count = tokenizer.count_tokens(instruction)
    let usage = tokenizer.estimate_context_usage(instruction, 50)
    // 占位：真实实现应检查 usage <= info.context_size
    ignore(token_count)
    ignore(usage)
  }
  // 5. 批量推理
  let inputs : Array[(Bytes, String)] = []
  for instruction in instructions {
    inputs.push((b"scene_image", instruction))
  }
  let cfg = @ggml.InferConfig::new(0.7, 40, 0.9, 256)
  let results = model.batch_infer_with_config(inputs, cfg)
  ignore(results)
  // 6. 验证结果
  // 每组推理返回空数组（占位）
  // 7. 清理
  model.free()
}

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
