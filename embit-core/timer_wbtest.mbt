///|
/// embit-core 计时器白盒测试。

///|
/// 新创建的计时器应处于停止状态。
test "Timer - new is stopped" {
  let t = Timer::new()
  assert_false(t.is_running())
  assert_eq(t.elapsed(), 0.0)
  assert_eq(t.ticks(), 0)
}

///|
/// start 创建的计时器应处于运行状态。
test "Timer - start is running" {
  let t = Timer::start()
  assert_true(t.is_running())
}

///|
/// tick 应在运行时累计时间。
test "Timer - tick accumulates when running" {
  let t = Timer::start()
  t.tick(0.1)
  t.tick(0.2)
  t.tick(0.3)
  assert_true((t.elapsed() - 0.6).abs() < 0.000001)
  assert_eq(t.ticks(), 3)
}

///|
/// 暂停后 tick 不应累计时间。
test "Timer - tick does not accumulate when paused" {
  let t = Timer::start()
  t.tick(0.5)
  t.pause()
  t.tick(0.5)
  assert_true((t.elapsed() - 0.5).abs() < 0.000001)
  assert_eq(t.ticks(), 2)
}

///|
/// unpause 应恢复计时。
test "Timer - unpause resumes timing" {
  let t = Timer::start()
  t.tick(0.1)
  t.pause()
  t.tick(0.1)
  t.unpause()
  t.tick(0.1)
  assert_true((t.elapsed() - 0.2).abs() < 0.000001)
}

///|
/// reset 应清零所有状态。
test "Timer - reset clears all" {
  let t = Timer::start()
  t.tick(1.0)
  t.tick(1.0)
  t.reset()
  assert_false(t.is_running())
  assert_eq(t.elapsed(), 0.0)
  assert_eq(t.ticks(), 0)
}

///|
/// average_interval 应正确计算。
test "Timer - average_interval" {
  let t = Timer::start()
  t.tick(0.01)
  t.tick(0.01)
  t.tick(0.01)
  assert_true((t.average_interval() - 0.01).abs() < 0.000001)
}

///|
/// average_frequency 应正确计算。
test "Timer - average_frequency" {
  let t = Timer::start()
  for _ in 0..<100 {
    t.tick(0.01)
  }
  // 100 ticks in 1.0 second → 100 Hz
  assert_true((t.average_frequency() - 100.0).abs() < 1.0)
}

///|
/// 零 tick 的 average_interval 应为 0。
test "Timer - average_interval zero ticks" {
  let t = Timer::new()
  assert_eq(t.average_interval(), 0.0)
  assert_eq(t.average_frequency(), 0.0)
}
