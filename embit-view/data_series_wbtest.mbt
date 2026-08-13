///|
/// embit-view DataSeries 白盒测试。

///|
/// 新创建的 DataSeries 应为空。
test "DataSeries - new is empty" {
  let ds = DataSeries::new("test", 100)
  assert_eq(ds.length(), 0)
  assert_eq(ds.get_name(), "test")
  assert_eq(ds.get_capacity(), 100)
}

///|
/// push 应增加数据点数。
test "DataSeries - push increments length" {
  let ds = DataSeries::new("test", 100)
  ds.push(0.0, 1.0)
  ds.push(0.1, 2.0)
  ds.push(0.2, 3.0)
  assert_eq(ds.length(), 3)
}

///|
/// 超过容量时应丢弃最旧的数据点。
test "DataSeries - capacity drops oldest" {
  let ds = DataSeries::new("test", 3)
  ds.push(0.0, 1.0)
  ds.push(0.1, 2.0)
  ds.push(0.2, 3.0)
  ds.push(0.3, 4.0) // 应丢弃 (0.0, 1.0)
  assert_eq(ds.length(), 3)
  let latest = ds.latest()
  assert_eq(latest, Some({ timestamp: 0.3, value: 4.0 }))
}

///|
/// latest 空序列返回 None。
test "DataSeries - latest empty returns None" {
  let ds = DataSeries::new("test", 100)
  assert_eq(ds.latest(), None)
}

///|
/// query_range 应返回时间范围内的数据点。
test "DataSeries - query_range" {
  let ds = DataSeries::new("test", 100)
  ds.push(0.0, 1.0)
  ds.push(0.5, 2.0)
  ds.push(1.0, 3.0)
  ds.push(1.5, 4.0)
  let result = ds.query_range(0.3, 1.2)
  assert_eq(result.length(), 2)
  assert_eq(result[0].timestamp, 0.5)
  assert_eq(result[1].timestamp, 1.0)
}

///|
/// min / max / mean 统计计算。
test "DataSeries - statistics" {
  let ds = DataSeries::new("test", 100)
  ds.push(0.0, 1.0)
  ds.push(0.1, 3.0)
  ds.push(0.2, 2.0)
  assert_eq(ds.min(), Some(1.0))
  assert_eq(ds.max(), Some(3.0))
  assert_eq(ds.mean(), Some(2.0))
}

///|
/// 空序列的统计返回 None。
test "DataSeries - statistics empty returns None" {
  let ds = DataSeries::new("test", 100)
  assert_eq(ds.min(), None)
  assert_eq(ds.max(), None)
  assert_eq(ds.mean(), None)
}

///|
/// clear 应清空数据。
test "DataSeries - clear" {
  let ds = DataSeries::new("test", 100)
  ds.push(0.0, 1.0)
  ds.push(0.1, 2.0)
  ds.clear()
  assert_eq(ds.length(), 0)
}

///|
/// with_default_capacity 应使用 1000 点容量。
test "DataSeries - with_default_capacity" {
  let ds = DataSeries::with_default_capacity("sensor")
  assert_eq(ds.get_capacity(), 1000)
}

///|
/// to_string 应包含序列名称与数据点数。
test "DataSeries - to_string" {
  let ds = DataSeries::new("joint_pos", 100)
  ds.push(0.0, 1.0)
  let s = ds.to_string()
  assert_true(s.contains("joint_pos"))
  assert_true(s.contains("1"))
}
