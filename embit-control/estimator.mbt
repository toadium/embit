///|
/// 状态估计器：融合传感器观测为关节状态估计。
///
/// Phase 1 实现简单的直通估计：直接从关节编码器读数提取关节状态。
/// Phase 2 将扩展为卡尔曼滤波或互补滤波。
pub struct StateEstimator {
  mut current_state : Array[@core.JointState]
  mut last_update_time : Double
}

///|
/// 创建状态估计器（初始状态为空）。
pub fn StateEstimator::new() -> StateEstimator {
  { current_state: [], last_update_time: 0.0 }
}

///|
/// 从传感器读数更新状态估计。
///
/// Phase 1 占位实现：仅更新时间戳，不解析传感器数据。
/// 真实实现将根据 `SensorType::JointEncoder` 读数解析关节位置/速度/力矩。
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
