///|
/// 控制环路性能基准：测量控制环路延迟与抖动统计。
///
/// Phase 5.1 新增：为性能调优提供环路抖动测量工具。
/// `ControlLoopBenchmark` 运行 N 次控制环路迭代，
/// 统计平均延迟、最大延迟、P99 抖动与频率。

///|
/// 控制环路基准测试结果。
pub(all) struct LoopBenchmarkResult {
  iterations : Int // 迭代次数
  total_time : Double // 总耗时（秒）
  average_latency : Double // 平均延迟（秒）
  max_latency : Double // 最大延迟（秒）
  min_latency : Double // 最小延迟（秒）
  jitter_p99 : Double // P99 抖动（秒）
  average_frequency : Double // 平均频率（Hz）
}

///|
/// 控制环路基准测试器。
///
/// 使用 `Timer` 测量控制环路迭代延迟，
/// 统计抖动与频率，用于验证 1kHz 控制环路性能。
pub struct ControlLoopBenchmark {
  target_frequency : Double // 目标频率（Hz）
  iteration_count : Int // 迭代次数
  latencies : Array[Double] // 每次迭代延迟（秒）
}

///|
/// 创建控制环路基准测试器。
///
/// `target_frequency` 为目标控制频率（Hz），`iteration_count` 为迭代次数。
pub fn ControlLoopBenchmark::new(
  target_frequency : Double,
  iteration_count : Int,
) -> ControlLoopBenchmark {
  { target_frequency, iteration_count, latencies: [] }
}

///|
/// 运行控制环路基准测试。
///
/// 执行 `iteration_count` 次迭代，每次迭代调用 `loop_body`，
/// 测量每次迭代的延迟并记录。
pub fn ControlLoopBenchmark::run(
  self : ControlLoopBenchmark,
  loop_body : (Int) -> Unit,
) -> LoopBenchmarkResult {
  let timer = @core.Timer::start()
  let target_dt = 1.0 / self.target_frequency
  for i in 0..<self.iteration_count {
    let iter_start = timer.elapsed()
    loop_body(i)
    let iter_end = timer.elapsed()
    self.latencies.push(iter_end - iter_start)
    // 模拟目标频率等待（占位：实际应用 sleep）
    timer.tick(target_dt)
  }
  self.compute_result()
}

///|
/// 计算基准测试结果统计。
fn ControlLoopBenchmark::compute_result(
  self : ControlLoopBenchmark,
) -> LoopBenchmarkResult {
  let n = self.latencies.length()
  if n == 0 {
    return {
      iterations: 0,
      total_time: 0.0,
      average_latency: 0.0,
      max_latency: 0.0,
      min_latency: 0.0,
      jitter_p99: 0.0,
      average_frequency: 0.0,
    }
  }
  let mut total = 0.0
  let mut max_l = 0.0
  let mut min_l = 1000000000.0
  for lat in self.latencies {
    total = total + lat
    if lat > max_l {
      max_l = lat
    }
    if lat < min_l {
      min_l = lat
    }
  }
  let avg = total / n.to_double()
  // P99 抖动：取第 99 百分位的延迟与平均值的差
  let p99_idx = (n * 99 / 100 - 1).max(0)
  let sorted = sort_latencies(self.latencies)
  let p99 = sorted[p99_idx.min(n - 1)]
  let jitter = (p99 - avg).abs()
  let freq = if total > 0.0 { n.to_double() / total } else { 0.0 }
  {
    iterations: n,
    total_time: total,
    average_latency: avg,
    max_latency: max_l,
    min_latency: min_l,
    jitter_p99: jitter,
    average_frequency: freq,
  }
}

///|
/// 简化排序（冒泡排序，用于小数组）。
fn sort_latencies(arr : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  for v in arr {
    result.push(v)
  }
  let n = result.length()
  for i in 0..<n {
    for j in 0..<(n - 1 - i) {
      if result[j] > result[j + 1] {
        let tmp = result[j]
        result[j] = result[j + 1]
        result[j + 1] = tmp
      }
    }
  }
  result
}

///|
/// 查询目标频率。
pub fn ControlLoopBenchmark::target_frequency(
  self : ControlLoopBenchmark,
) -> Double {
  self.target_frequency
}

///|
/// 查询迭代次数。
pub fn ControlLoopBenchmark::iteration_count(
  self : ControlLoopBenchmark,
) -> Int {
  self.iteration_count
}
