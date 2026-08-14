///|
/// 多维张量：封装推理引擎中的数据容器。
///
/// `shape` 为各维度大小（如 `[1, 3, 224, 224]` 表示 NCHW 格式图像），
/// `data` 为展平的一维浮点数据（行主序）。
/// 元素总数 = `shape` 各维度之积，应等于 `data.length()`。
pub(all) struct Tensor {
  shape : Array[Int]
  data : Array[Double]
} derive(Eq, Debug)

///|
pub extend Tensor with Eq::{not_equal, equal}

///|
pub extend Tensor with @debug.Debug::{to_repr}

///|
/// 张量数据类型。
pub(all) enum DType {
  F32
  F16
  I32
  I8
} derive(Eq, Debug)

///|
pub extend DType with Eq::{not_equal, equal}

///|
pub extend DType with @debug.Debug::{to_repr}

///|
/// 创建标量张量。
pub fn Tensor::scalar(value : Double) -> Tensor {
  { shape: [], data: [value] }
}

///|
/// 创建一维张量（向量）。
pub fn Tensor::vector(data : Array[Double]) -> Tensor {
  { shape: [data.length()], data }
}

///|
/// 从形状和数据创建张量。
///
/// 若 `data.length()` 不等于 `shape` 各维度之积，抛出 `RobotError::InvalidConfig`。
pub fn Tensor::new(
  shape : Array[Int],
  data : Array[Double],
) -> Tensor raise @core.RobotError {
  let expected = Tensor::shape_size(shape)
  if data.length() != expected {
    raise InvalidConfig(
      "tensor data length \{data.length()} != shape product \{expected}",
    )
  }
  { shape, data }
}

///|
/// 计算形状各维度之积（元素总数）。
pub fn Tensor::shape_size(shape : Array[Int]) -> Int {
  let mut product = 1
  for dim in shape {
    product *= dim
  }
  product
}

///|
/// 张量维度数（rank）。
pub fn Tensor::rank(self : Tensor) -> Int {
  self.shape.length()
}

///|
/// 张量元素总数。
pub fn Tensor::size(self : Tensor) -> Int {
  Tensor::shape_size(self.shape)
}

///|
/// 获取标量值（仅适用于标量张量）。
///
/// 若张量非标量，抛出 `RobotError::InvalidConfig`。
pub fn Tensor::to_scalar(self : Tensor) -> Double raise @core.RobotError {
  if self.size() != 1 {
    raise InvalidConfig("tensor is not a scalar")
  }
  if self.data.length() == 0 {
    raise InvalidConfig("tensor has no data")
  }
  self.data[0]
}

///|
/// 张量加法（逐元素相加）。
///
/// 形状必须一致，否则抛出 `RobotError::InvalidConfig`。
pub fn Tensor::add(
  self : Tensor,
  other : Tensor,
) -> Tensor raise @core.RobotError {
  if self.shape != other.shape {
    raise InvalidConfig("tensor shape mismatch in add")
  }
  let result : Array[Double] = []
  for i in 0..<self.data.length() {
    result.push(self.data[i] + other.data[i])
  }
  { shape: self.shape, data: result }
}

///|
/// 张量标量乘法。
pub fn Tensor::scale(self : Tensor, s : Double) -> Tensor {
  let result : Array[Double] = []
  for v in self.data {
    result.push(v * s)
  }
  { shape: self.shape, data: result }
}

///|
/// 批量推理：对多组图像 + 指令执行推理。
///
/// `inputs` 为 `(image, instruction)` 元组数组。
/// 返回每组推理结果（空数组占位）。任一推理失败时抛出 `RobotError::ActionExecuteError`。
pub fn VlaModel::batch_infer(
  self : VlaModel,
  inputs : Array[(Bytes, String)],
) -> Array[Array[@core.ActionCommand]] raise @core.RobotError {
  let results : Array[Array[@core.ActionCommand]] = []
  for i in 0..<inputs.length() {
    let (image, instruction) = inputs[i]
    let result = self.infer(image, instruction)
    results.push(result)
  }
  results
}

///|
/// 批量推理（带配置）：对多组输入使用同一配置执行推理。
pub fn VlaModel::batch_infer_with_config(
  self : VlaModel,
  inputs : Array[(Bytes, String)],
  config : InferConfig,
) -> Array[Array[@core.ActionCommand]] raise @core.RobotError {
  let results : Array[Array[@core.ActionCommand]] = []
  for i in 0..<inputs.length() {
    let (image, instruction) = inputs[i]
    let result = self.infer_with_config(image, instruction, config)
    results.push(result)
  }
  results
}
