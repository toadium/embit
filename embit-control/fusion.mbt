///|
/// 传感器融合：互补滤波器，融合 IMU 与编码器数据估计姿态。
///
/// 互补滤波器结合陀螺仪（高频准确但有漂移）与加速度计（低频准确但噪声大）：
/// `orientation = alpha * (orientation + gyro * dt) + (1 - alpha) * accel_angle`
///
/// `alpha` 通常取 0.95~0.99，越大越信任陀螺仪。
pub struct SensorFusion {
  alpha : Double // 互补滤波系数（0~1）
  mut orientation : Double // 融合后的姿态角（rad）
  mut velocity : Double // 融合后的角速度（rad/s）
  mut bias : Double // 陀螺仪零偏估计（rad/s）
  mut update_count : Int // 更新次数
}

///|
/// 创建传感器融合器。
///
/// `alpha` 为互补滤波系数，通常取 0.98。
pub fn SensorFusion::new(alpha : Double) -> SensorFusion {
  { alpha, orientation: 0.0, velocity: 0.0, bias: 0.0, update_count: 0 }
}

///|
/// 创建默认传感器融合器（alpha = 0.98）。
pub fn SensorFusion::default() -> SensorFusion {
  SensorFusion::new(0.98)
}

///|
/// 更新融合状态。
///
/// `gyro_rate` 为陀螺仪角速度（rad/s），`accel_angle` 为加速度计推算角度（rad），
/// `dt` 为时间步长（秒）。
pub fn SensorFusion::update(
  self : SensorFusion,
  gyro_rate : Double,
  accel_angle : Double,
  dt : Double,
) -> Unit {
  if dt <= 0.0 {
    return
  }
  // 陀螺仪积分（减去零偏）
  let corrected_gyro = gyro_rate - self.bias
  let gyro_angle = self.orientation + corrected_gyro * dt
  // 互补滤波
  self.orientation = self.alpha * gyro_angle + (1.0 - self.alpha) * accel_angle
  self.velocity = corrected_gyro
  self.update_count = self.update_count + 1
}

///|
/// 更新陀螺仪零偏估计。
///
/// 在静止状态下调用，用长期平均角速度估计零偏。
/// `gyro_rate` 为当前陀螺仪读数，`gain` 为更新增益（0~1，越小越慢）。
pub fn SensorFusion::calibrate_bias(
  self : SensorFusion,
  gyro_rate : Double,
  gain : Double,
) -> Unit {
  self.bias = self.bias + gain * (gyro_rate - self.bias)
}

///|
/// 获取融合姿态角（rad）。
pub fn SensorFusion::get_orientation(self : SensorFusion) -> Double {
  self.orientation
}

///|
/// 获取融合角速度（rad/s）。
pub fn SensorFusion::get_velocity(self : SensorFusion) -> Double {
  self.velocity
}

///|
/// 获取陀螺仪零偏估计（rad/s）。
pub fn SensorFusion::get_bias(self : SensorFusion) -> Double {
  self.bias
}

///|
/// 获取更新次数。
pub fn SensorFusion::update_count(self : SensorFusion) -> Int {
  self.update_count
}

///|
/// 重置融合状态。
pub fn SensorFusion::reset(self : SensorFusion) -> Unit {
  self.orientation = 0.0
  self.velocity = 0.0
  self.bias = 0.0
  self.update_count = 0
}

///|
/// 关节编码器速度估计：差分法。
///
/// `current_pos` 为当前关节位置，`prev_pos` 为上一时刻位置，
/// `dt` 为时间步长。返回估计角速度。
pub fn SensorFusion::estimate_velocity(
  current_pos : Double,
  prev_pos : Double,
  dt : Double,
) -> Double {
  if dt <= 0.0 {
    0.0
  } else {
    (current_pos - prev_pos) / dt
  }
}

///|
/// 低通滤波：一阶 IIR 滤波器。
///
/// `cutoff_freq` 为截止频率（Hz），`dt` 为采样间隔，
/// `current_value` 为当前原始值，`prev_filtered` 为上次滤波结果。
pub fn SensorFusion::lowpass_filter(
  cutoff_freq : Double,
  dt : Double,
  current_value : Double,
  prev_filtered : Double,
) -> Double {
  // alpha = dt / (RC + dt), RC = 1 / (2*pi*cutoff_freq)
  let rc = 1.0 / (6.28318530717958647692 * cutoff_freq)
  let alpha = dt / (rc + dt)
  alpha * current_value + (1.0 - alpha) * prev_filtered
}
