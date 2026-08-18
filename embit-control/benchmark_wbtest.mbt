///|
/// ControlLoopBenchmark::compute_result 空结果（0 迭代）。
test "ControlLoopBenchmark - compute_result empty" {
  let bench = ControlLoopBenchmark::new(1000.0, 0)
  let result = bench.compute_result()
  assert_eq(result.iterations, 0)
  assert_eq(result.total_time, 0.0)
  assert_eq(result.average_frequency, 0.0)
}

///|
/// ControlLoopBenchmark::target_frequency 查询方法。
test "ControlLoopBenchmark - target_frequency query" {
  let bench = ControlLoopBenchmark::new(500.0, 10)
  assert_eq(bench.target_frequency(), 500.0)
}

///|
/// ControlLoopBenchmark::iteration_count 查询方法。
test "ControlLoopBenchmark - iteration_count query" {
  let bench = ControlLoopBenchmark::new(1000.0, 42)
  assert_eq(bench.iteration_count(), 42)
}

///|
/// sort_latencies 应正确排序并触发交换分支。
test "sort_latencies - sorts and swaps" {
  let sorted = sort_latencies([3.0, 1.0, 2.0])
  assert_eq(sorted[0], 1.0)
  assert_eq(sorted[1], 2.0)
  assert_eq(sorted[2], 3.0)
}

///|
/// compute_result 应正确计算 max_latency 和 frequency。
test "ControlLoopBenchmark - compute_result max and freq" {
  let bench = ControlLoopBenchmark::new(1000.0, 3)
  bench.latencies.push(0.001)
  bench.latencies.push(0.003)
  bench.latencies.push(0.002)
  let result = bench.compute_result()
  assert_eq(result.iterations, 3)
  assert_eq(result.max_latency, 0.003)
  assert_true(result.average_frequency > 0.0)
}
