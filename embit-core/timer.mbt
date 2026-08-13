///|
/// 计时器：跟踪累计时间，用于控制环路计时与性能测量。
///
/// 计时器通过 `tick` 方法手动推进时间，适用于确定性控制环路。
/// 可启动/暂停/重置，查询已运行时间与运行状态。
pub struct Timer {
  mut elapsed_time : Double // 累计运行时间（秒）
  mut running : Bool // 是否正在运行
  mut tick_count : Int // tick 调用次数
}

///|
/// 创建计时器（初始停止状态）。
pub fn Timer::new() -> Timer {
  { elapsed_time: 0.0, running: false, tick_count: 0 }
}

///|
/// 创建并启动计时器。
pub fn Timer::start() -> Timer {
  { elapsed_time: 0.0, running: true, tick_count: 0 }
}

///|
/// 启动计时器（从当前累计时间继续）。
pub fn Timer::unpause(self : Timer) -> Unit {
  self.running = true
}

///|
/// 暂停计时器。
pub fn Timer::pause(self : Timer) -> Unit {
  self.running = false
}

///|
/// 重置计时器（清零累计时间与 tick 次数，停止运行）。
pub fn Timer::reset(self : Timer) -> Unit {
  self.elapsed_time = 0.0
  self.running = false
  self.tick_count = 0
}

///|
/// 推进时间：若正在运行，累计 `dt` 秒。
///
/// `dt` 为时间步长（秒），必须非负。
pub fn Timer::tick(self : Timer, dt : Double) -> Unit {
  self.tick_count = self.tick_count + 1
  if self.running && dt > 0.0 {
    self.elapsed_time = self.elapsed_time + dt
  }
}

///|
/// 查询累计运行时间（秒）。
pub fn Timer::elapsed(self : Timer) -> Double {
  self.elapsed_time
}

///|
/// 查询是否正在运行。
pub fn Timer::is_running(self : Timer) -> Bool {
  self.running
}

///|
/// 查询 tick 调用次数。
pub fn Timer::ticks(self : Timer) -> Int {
  self.tick_count
}

///|
/// 平均 tick 间隔（秒）：`elapsed_time / tick_count`。
///
/// 若 tick 次数为零，返回 0.0。
pub fn Timer::average_interval(self : Timer) -> Double {
  if self.tick_count == 0 {
    0.0
  } else {
    self.elapsed_time / self.tick_count.to_double()
  }
}

///|
/// 平均频率（Hz）：`tick_count / elapsed_time`。
///
/// 若累计时间为零，返回 0.0。
pub fn Timer::average_frequency(self : Timer) -> Double {
  if self.elapsed_time <= 0.0 {
    0.0
  } else {
    self.tick_count.to_double() / self.elapsed_time
  }
}
