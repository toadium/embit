///|
/// 时间序列数据点。
pub(all) struct DataPoint {
  timestamp : Double
  value : Double
} derive(Eq, Debug)

///|
/// 实时时间序列：存储带时间戳的标量数据，用于可视化监控。
///
/// 内部使用环形缓冲区，当数据点超过 `capacity` 时自动丢弃最旧的数据。
/// 支持范围查询与统计计算（最小/最大/均值/最新值）。
pub struct DataSeries {
  name : String
  capacity : Int
  data : Array[DataPoint]
}

///|
/// 创建时间序列。
///
/// `name` 为序列名称，`capacity` 为最大存储点数（必须 > 0）。
pub fn DataSeries::new(name : String, capacity : Int) -> DataSeries {
  let cap = if capacity > 0 { capacity } else { 100 }
  { name, capacity: cap, data: [] }
}

///|
/// 默认容量（1000 点）。
pub fn DataSeries::with_default_capacity(name : String) -> DataSeries {
  DataSeries::new(name, 1000)
}

///|
/// 追加数据点。
///
/// 当数据点数超过 `capacity` 时，丢弃最旧的数据点。
pub fn DataSeries::push(
  self : DataSeries,
  timestamp : Double,
  value : Double,
) -> Unit {
  self.data.push({ timestamp, value })
  if self.data.length() > self.capacity {
    // 丢弃最旧的数据点（索引 0）
    ignore(self.data.remove(0))
  }
}

///|
/// 当前数据点数。
pub fn DataSeries::length(self : DataSeries) -> Int {
  self.data.length()
}

///|
/// 序列名称。
pub fn DataSeries::get_name(self : DataSeries) -> String {
  self.name
}

///|
/// 容量。
pub fn DataSeries::get_capacity(self : DataSeries) -> Int {
  self.capacity
}

///|
/// 清空数据。
pub fn DataSeries::clear(self : DataSeries) -> Unit {
  self.data.clear()
}

///|
/// 获取最新数据点。
///
/// 空序列返回 `None`。
pub fn DataSeries::latest(self : DataSeries) -> DataPoint? {
  if self.data.length() == 0 {
    None
  } else {
    Some(self.data[self.data.length() - 1])
  }
}

///|
/// 查询时间范围内的数据点。
///
/// 返回时间戳在 `[start, end]` 区间内的所有数据点。
pub fn DataSeries::query_range(
  self : DataSeries,
  start : Double,
  end : Double,
) -> Array[DataPoint] {
  let result : Array[DataPoint] = []
  for dp in self.data {
    if dp.timestamp >= start && dp.timestamp <= end {
      result.push(dp)
    }
  }
  result
}

///|
/// 计算最小值。
///
/// 空序列返回 `None`。
pub fn DataSeries::min(self : DataSeries) -> Double? {
  if self.data.length() == 0 {
    None
  } else {
    let mut m = self.data[0].value
    for dp in self.data {
      if dp.value < m {
        m = dp.value
      }
    }
    Some(m)
  }
}

///|
/// 计算最大值。
///
/// 空序列返回 `None`。
pub fn DataSeries::max(self : DataSeries) -> Double? {
  if self.data.length() == 0 {
    None
  } else {
    let mut m = self.data[0].value
    for dp in self.data {
      if dp.value > m {
        m = dp.value
      }
    }
    Some(m)
  }
}

///|
/// 计算均值。
///
/// 空序列返回 `None`。
pub fn DataSeries::mean(self : DataSeries) -> Double? {
  if self.data.length() == 0 {
    None
  } else {
    let mut sum = 0.0
    for dp in self.data {
      sum = sum + dp.value
    }
    Some(sum / self.data.length().to_double())
  }
}

///|
/// 导出为字符串（用于日志/调试）。
pub fn DataSeries::to_string(self : DataSeries) -> String {
  let mut result = "DataSeries(\{self.name})[\{self.data.length()}]: "
  for i in 0..<self.data.length() {
    if i > 0 {
      result += ", "
    }
    let dp = self.data[i]
    result += "(\{dp.timestamp}, \{dp.value})"
  }
  result
}
