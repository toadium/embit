///|
/// embit-ggml 张量与批量推理白盒测试。

// ===== Tensor 测试 =====

///|
/// 标量张量。
test "Tensor - scalar" {
  let t = Tensor::scalar(3.14)
  assert_eq(t.rank(), 0)
  assert_eq(t.size(), 1)
  assert_eq(t.data[0], 3.14)
}

///|
/// 一维张量（向量）。
test "Tensor - vector" {
  let t = Tensor::vector([1.0, 2.0, 3.0])
  assert_eq(t.rank(), 1)
  assert_eq(t.size(), 3)
  assert_eq(t.shape[0], 3)
}

///|
/// 从形状和数据创建张量（合法）。
test "Tensor - new valid shape" {
  let t = Tensor::new([2, 3], [1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
  assert_eq(t.rank(), 2)
  assert_eq(t.size(), 6)
}

///|
/// 形状与数据不匹配应抛出错误。
test "Tensor - new mismatched shape raises error" {
  try Tensor::new([2, 3], [1.0, 2.0, 3.0]) catch {
    InvalidConfig(msg) => assert_true(msg.contains("shape"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// to_scalar 提取标量值。
test "Tensor - to_scalar from scalar" {
  let t = Tensor::scalar(42.0)
  let v = t.to_scalar()
  assert_eq(v, 42.0)
}

///|
/// to_scalar 对非标量张量应抛出错误。
test "Tensor - to_scalar on vector raises error" {
  let t = Tensor::vector([1.0, 2.0])
  try t.to_scalar() catch {
    InvalidConfig(msg) => assert_true(msg.contains("scalar"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// 张量加法。
test "Tensor - add" {
  let a = Tensor::vector([1.0, 2.0, 3.0])
  let b = Tensor::vector([4.0, 5.0, 6.0])
  let c = a.add(b)
  assert_eq(c.data[0], 5.0)
  assert_eq(c.data[1], 7.0)
  assert_eq(c.data[2], 9.0)
}

///|
/// 张量加法形状不匹配应抛出错误。
test "Tensor - add shape mismatch raises error" {
  let a = Tensor::vector([1.0, 2.0, 3.0])
  let b = Tensor::vector([1.0, 2.0])
  try a.add(b) catch {
    InvalidConfig(msg) => assert_true(msg.contains("mismatch"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// 张量标量乘法。
test "Tensor - scale" {
  let t = Tensor::vector([1.0, 2.0, 3.0])
  let s = t.scale(2.0)
  assert_eq(s.data[0], 2.0)
  assert_eq(s.data[1], 4.0)
  assert_eq(s.data[2], 6.0)
}

///|
/// shape_size 计算各维度之积。
test "Tensor - shape_size" {
  assert_eq(Tensor::shape_size([2, 3, 4]), 24)
  assert_eq(Tensor::shape_size([]), 1)
  assert_eq(Tensor::shape_size([1]), 1)
}

// ===== 批量推理测试 =====

///|
/// batch_infer 应对每组输入执行推理并递增计数，返回非空动作序列。
test "VlaModel - batch_infer processes all inputs" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  let inputs : Array[(Bytes, String)] = [
    (b"img1", "pick up the block"),
    (b"img2", "move to the table"),
    (b"img3", "walk forward"),
  ]
  let results = model.batch_infer(inputs)
  assert_eq(results.length(), 3)
  for result in results {
    assert_true(result.length() > 0)
  }
  assert_eq(model.infer_count(), 3)
  model.free()
}

///|
/// batch_infer_with_config 使用同一配置。
test "VlaModel - batch_infer_with_config" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  let cfg = InferConfig::new(0.8, 50, 0.95, 128)
  let inputs : Array[(Bytes, String)] = [(b"img1", "task1"), (b"img2", "task2")]
  let results = model.batch_infer_with_config(inputs, cfg)
  assert_eq(results.length(), 2)
  assert_eq(model.infer_count(), 2)
  model.free()
}

///|
/// 空批量输入应返回空结果。
test "VlaModel - batch_infer empty inputs" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  let inputs : Array[(Bytes, String)] = []
  let results = model.batch_infer(inputs)
  assert_eq(results.length(), 0)
  assert_eq(model.infer_count(), 0)
  model.free()
}

///|
/// 标量张量但无数据时 to_scalar 应抛出错误。
test "Tensor - to_scalar with empty data raises error" {
  let t = Tensor::{ shape: [], data: [] }
  try t.to_scalar() catch {
    InvalidConfig(msg) => assert_true(msg.contains("no data"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}
