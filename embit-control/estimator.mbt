///|
/// 状态估计器：融合传感器观测为关节状态估计。
///
/// 支持两种模式：
/// - **直通模式**（`new()`）：直接存储关节状态，不做滤波
/// - **卡尔曼模式**（`new_kalman()`）：对每个关节独立运行 1D 卡尔曼滤波，
///   估计 [位置, 速度] 状态，抑制传感器噪声
pub struct StateEstimator {
  mut current_state : Array[@core.JointState]
  mut last_update_time : Double
  use_kalman : Bool // 是否启用卡尔曼滤波
  filters : Map[String, KalmanFilter1D] // 关节名 → 滤波器
  q_pos : Double // 位置过程噪声方差
  q_vel : Double // 速度过程噪声方差
  r : Double // 测量噪声方差
}

///|
/// 创建直通状态估计器（无滤波，向后兼容）。
pub fn StateEstimator::new() -> StateEstimator {
  {
    current_state: [],
    last_update_time: 0.0,
    use_kalman: false,
    filters: Map([]),
    q_pos: 0.0,
    q_vel: 0.0,
    r: 0.0,
  }
}

///|
/// 创建卡尔曼状态估计器。
///
/// `q_pos` 为位置过程噪声方差，`q_vel` 为速度过程噪声方差，
/// `r` 为测量噪声方差。典型值：q_pos=0.001, q_vel=0.01, r=0.1
pub fn StateEstimator::new_kalman(
  q_pos : Double,
  q_vel : Double,
  r : Double,
) -> StateEstimator {
  {
    current_state: [],
    last_update_time: 0.0,
    use_kalman: true,
    filters: Map([]),
    q_pos,
    q_vel,
    r,
  }
}

///|
/// 从传感器读数更新状态估计。
///
/// 直通模式下仅更新时间戳。
/// 卡尔曼模式下需要调用 `update_joints` 提供结构化关节状态。
pub fn StateEstimator::update(
  self : StateEstimator,
  readings : Array[@core.SensorReading],
) -> Unit {
  if readings.length() > 0 {
    let mut max_ts = 0.0
    for r in readings {
      if r.timestamp > max_ts {
        max_ts = r.timestamp
      }
    }
    self.last_update_time = max_ts
  }
}

///|
/// 用关节状态观测更新估计（卡尔曼模式）。
///
/// 对每个关节运行 predict + update 步骤。`dt` 为时间步长（秒）。
/// 关节速度从 `JointState.velocity` 字段读取作为辅助观测。
pub fn StateEstimator::update_joints(
  self : StateEstimator,
  observed : Array[@core.JointState],
  dt : Double,
) -> Unit {
  if observed.length() == 0 {
    return
  }
  if !self.use_kalman {
    // 直通模式：直接存储
    self.current_state = observed
    return
  }
  // 卡尔曼模式：逐关节滤波
  let filtered : Array[@core.JointState] = []
  for js in observed {
    let kf = self.filters.get_or_init(js.name, fn() {
      KalmanFilter1D::new(self.q_pos, self.q_vel, self.r)
    })
    // 预测 + 用位置观测更新
    kf.predict(dt)
    kf.update(js.position)
    // 用速度观测修正速度估计（简单加权）
    if js.velocity.abs() > 0.0 {
      kf.vel = 0.5 * kf.vel + 0.5 * js.velocity
    }
    filtered.push({
      name: js.name,
      position: kf.get_pos(),
      velocity: kf.get_vel(),
      effort: js.effort,
    })
  }
  self.current_state = filtered
  // 更新时间戳
  self.last_update_time = self.last_update_time + dt
}

///|
/// 获取当前状态估计。
pub fn StateEstimator::get_state(
  self : StateEstimator,
) -> Array[@core.JointState] {
  self.current_state
}

///|
/// 获取上次更新时间戳。
pub fn StateEstimator::last_update(self : StateEstimator) -> Double {
  self.last_update_time
}

///|
/// 手动设置关节状态估计（用于测试或外部注入）。
pub fn StateEstimator::set_state(
  self : StateEstimator,
  state : Array[@core.JointState],
) -> Unit {
  self.current_state = state
}

///|
/// 是否启用卡尔曼滤波。
pub fn StateEstimator::is_kalman_enabled(self : StateEstimator) -> Bool {
  self.use_kalman
}

///|
/// 获取指定关节的卡尔曼滤波器（若存在）。
pub fn StateEstimator::get_filter(
  self : StateEstimator,
  joint_name : String,
) -> KalmanFilter1D? {
  self.filters.get(joint_name)
}

///|
/// 重置所有滤波器状态。
pub fn StateEstimator::reset(self : StateEstimator) -> Unit {
  self.current_state = []
  self.last_update_time = 0.0
  for entry in self.filters.iter() {
    let (_, kf) = entry
    kf.reset()
  }
}
