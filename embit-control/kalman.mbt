///|
/// 一维卡尔曼滤波器：估计关节 [位置, 速度] 状态。
///
/// 采用常速度运动模型：
/// - 状态向量 x = [pos, vel]
/// - 状态转移 A = [[1, dt], [0, 1]]
/// - 观测 H = [1, 0]（仅观测位置）
///
/// 预测步：
///   x_pred = A · x
///   P_pred = A · P · A^T + Q
///
/// 更新步：
///   y = z - H · x_pred           （新息）
///   S = H · P_pred · H^T + R     （新息协方差）
///   K = P_pred · H^T / S         （卡尔曼增益）
///   x = x_pred + K · y
///   P = (I - K · H) · P_pred
pub struct KalmanFilter1D {
  mut pos : Double // 估计位置
  mut vel : Double // 估计速度
  mut p00 : Double // 协方差 P[0][0]
  mut p01 : Double // 协方差 P[0][1]
  mut p10 : Double // 协方差 P[1][0]
  mut p11 : Double // 协方差 P[1][1]
  q_pos : Double // 过程噪声方差（位置）
  q_vel : Double // 过程噪声方差（速度）
  r : Double // 测量噪声方差
}

///|
/// 创建卡尔曼滤波器。
///
/// `q_pos` 为位置过程噪声方差，`q_vel` 为速度过程噪声方差，
/// `r` 为测量噪声方差。初始协方差设为较大值（表示初始不确定度高）。
pub fn KalmanFilter1D::new(
  q_pos : Double,
  q_vel : Double,
  r : Double,
) -> KalmanFilter1D {
  {
    pos: 0.0,
    vel: 0.0,
    p00: 1.0, // 初始协方差：位置不确定度高
    p01: 0.0,
    p10: 0.0,
    p11: 1.0, // 初始协方差：速度不确定度高
    q_pos,
    q_vel,
    r,
  }
}

///|
/// 用已知初始状态创建卡尔曼滤波器。
pub fn KalmanFilter1D::with_initial(
  init_pos : Double,
  init_vel : Double,
  q_pos : Double,
  q_vel : Double,
  r : Double,
) -> KalmanFilter1D {
  {
    pos: init_pos,
    vel: init_vel,
    p00: 0.1,
    p01: 0.0,
    p10: 0.0,
    p11: 0.1,
    q_pos,
    q_vel,
    r,
  }
}

///|
/// 预测步：根据运动模型前推状态。
///
/// x_pred = [pos + vel·dt, vel]
/// P_pred = A·P·A^T + Q
pub fn KalmanFilter1D::predict(self : KalmanFilter1D, dt : Double) -> Unit {
  // 状态预测
  self.pos = self.pos + self.vel * dt
  // vel 不变

  // 协方差预测：P_pred = A·P·A^T + Q
  // A·P·A^T[0][0] = p00 + dt*(p01 + p10) + dt²*p11
  // A·P·A^T[0][1] = p01 + dt*p11
  // A·P·A^T[1][0] = p10 + dt*p11
  // A·P·A^T[1][1] = p11
  let new_p00 = self.p00 +
    dt * (self.p01 + self.p10) +
    dt * dt * self.p11 +
    self.q_pos
  let new_p01 = self.p01 + dt * self.p11
  let new_p10 = self.p10 + dt * self.p11
  let new_p11 = self.p11 + self.q_vel
  self.p00 = new_p00
  self.p01 = new_p01
  self.p10 = new_p10
  self.p11 = new_p11
}

///|
/// 更新步：用位置观测修正状态估计。
///
/// y = z - pos_pred
/// S = p00 + r
/// K = [p00/S, p10/S]
/// x = x_pred + K · y
/// P = (I - K·H) · P_pred
pub fn KalmanFilter1D::update(
  self : KalmanFilter1D,
  measurement : Double,
) -> Unit {
  let y = measurement - self.pos // 新息
  let s = self.p00 + self.r // 新息协方差
  if s.abs() < 0.000000001 {
    return // 避免除零
  }
  let k0 = self.p00 / s // 卡尔曼增益[0]
  let k1 = self.p10 / s // 卡尔曼增益[1]

  // 状态更新
  self.pos = self.pos + k0 * y
  self.vel = self.vel + k1 * y

  // 协方差更新：P = (I - K·H) · P_pred
  // (I - K·H) = [[1-k0, 0], [-k1, 1]]
  let new_p00 = (1.0 - k0) * self.p00
  let new_p01 = (1.0 - k0) * self.p01
  let new_p10 = -k1 * self.p00 + self.p10
  let new_p11 = -k1 * self.p01 + self.p11
  self.p00 = new_p00
  self.p01 = new_p01
  self.p10 = new_p10
  self.p11 = new_p11
}

///|
/// 预测+更新一步完成。
pub fn KalmanFilter1D::step(
  self : KalmanFilter1D,
  measurement : Double,
  dt : Double,
) -> Unit {
  self.predict(dt)
  self.update(measurement)
}

///|
/// 获取估计位置。
pub fn KalmanFilter1D::get_pos(self : KalmanFilter1D) -> Double {
  self.pos
}

///|
/// 获取估计速度。
pub fn KalmanFilter1D::get_vel(self : KalmanFilter1D) -> Double {
  self.vel
}

///|
/// 获取位置不确定度（P[0][0]）。
pub fn KalmanFilter1D::get_pos_uncertainty(self : KalmanFilter1D) -> Double {
  self.p00
}

///|
/// 重置滤波器状态。
pub fn KalmanFilter1D::reset(self : KalmanFilter1D) -> Unit {
  self.pos = 0.0
  self.vel = 0.0
  self.p00 = 1.0
  self.p01 = 0.0
  self.p10 = 0.0
  self.p11 = 1.0
}
