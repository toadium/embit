///|
/// Embit 管线 Demo：VLA 推理 / 阻抗控制 / 传感器融合 / 批量推理。
///
/// 演示 Phase 2 新增功能在各子模块间的组合使用。

///|
/// 示例工程占位入口（保留用于编译期依赖验证）。
pub fn demo_skeleton() -> Unit {
  let _ = @gazebo.GazeboClient::connect("localhost:9000")
  let _ = @ggml.VlaModel::load("models/smolvla.gguf")
  let _ = @view.ViewPanel::new()
  let limits = @core.SafetyLimits::{
    max_joint_velocity: 0.0,
    max_joint_effort: 0.0,
    collision_check_distance: 0.0,
  }
  let model = @core.RobotModel::{
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
    // 传感器噪声：确定性伪噪声（正弦扰动，模拟周期性电磁干扰）
    let gyro_noise = 0.002 * @math.sin(t * 63.0)
    let accel_noise = 0.005 * @math.sin(t * 37.0 + 1.0)
    // 陀螺仪读数 = 真实角速度 + 噪声
    let gyro_rate = @core.deg_to_rad(30.0) *
      10.0 *
      @math.cos(t * 10.0) /
      @core.pi +
      gyro_noise
    // 加速度计读数 = 真实角度 + 噪声
    let accel_angle = true_angle + accel_noise
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
  // 3. 准备多组推理输入
  let instructions = [
    "pick up the red block", "place it on the green plate", "open the top drawer",
    "push the blue button", "rotate the valve clockwise",
  ]
  // 4. 检查上下文窗口是否足够（token 数 + margin <= context_size）
  for instruction in instructions {
    let usage = tokenizer.estimate_context_usage(instruction, 50)
    if usage > info.context_size {
      raise InvalidConfig(
        "context window insufficient: instruction needs \{usage} tokens, model has \{info.context_size}",
      )
    }
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
