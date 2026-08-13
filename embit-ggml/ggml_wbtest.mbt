///|
/// embit-ggml 白盒测试：验证 FFI 通道与安全封装行为。
///
/// 白盒测试位于包内，可直接使用 VlaModel / Backend 等类型名，
/// 跨包错误类型仍用 @core.RobotError 限定。

///|
/// 加载后应处于已加载状态，默认 CPU 后端，推理计数初值为 0。
test "VlaModel - load and is_loaded" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  assert_true(model.is_loaded())
  assert_eq(model.get_backend(), Cpu)
  assert_eq(model.infer_count(), 0)
  model.free()
}

///|
/// 推理调用应使推理计数递增。
test "VlaModel - infer increments infer_count" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  let image = b"\x89PNG\r\n\x1a\n"
  let _ = model.infer(image, "pick up the red block")
  let _ = model.infer(image, "move to the table")
  assert_eq(model.infer_count(), 2)
  model.free()
}

///|
/// 设置后端应更新 get_backend 的返回值。
test "VlaModel - set_backend and get_backend" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  model.set_backend(Cuda)
  assert_eq(model.get_backend(), Cuda)
  model.set_backend(Metal)
  assert_eq(model.get_backend(), Metal)
  model.set_backend(Cpu)
  assert_eq(model.get_backend(), Cpu)
  model.free()
}

///|
/// 释放后 is_loaded 应返回 false。
test "VlaModel - free sets is_loaded false" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  assert_true(model.is_loaded())
  model.free()
  assert_false(model.is_loaded())
}

///|
/// 释放后再推理应抛出 RobotError::ActionExecuteError。
test "VlaModel - infer after free raises error" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  model.free()
  try model.infer(b"", "do something") catch {
    ActionExecuteError(msg) => assert_true(msg.contains("infer failed"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ActionExecuteError after free")
  }
}

///|
/// supported_backends 应返回全部三种后端。
test "VlaModel - supported_backends returns all three" {
  let backends = VlaModel::supported_backends()
  assert_eq(backends.length(), 3)
  assert_eq(backends[0], Cpu)
  assert_eq(backends[1], Cuda)
  assert_eq(backends[2], Metal)
}

///|
/// 多个模型实例互不影响，各独立维护推理计数与后端。
test "VlaModel - multiple models are independent" {
  let m1 = VlaModel::load("models/smolvla-7b-q4.gguf")
  let m2 = VlaModel::load("models/openvla-13b-q4.gguf")
  let _ = m1.infer(b"img1", "task1")
  let _ = m1.infer(b"img2", "task2")
  let _ = m2.infer(b"img3", "task3")
  assert_eq(m1.infer_count(), 2)
  assert_eq(m2.infer_count(), 1)
  m1.set_backend(Cuda)
  assert_eq(m1.get_backend(), Cuda)
  assert_eq(m2.get_backend(), Cpu)
  m1.free()
  m2.free()
}

// ===== InferConfig 测试 =====

///|
/// 默认推理配置应有正确的默认值。
test "InferConfig - default values" {
  let cfg = InferConfig::default()
  assert_eq(cfg.temperature, 1.0)
  assert_eq(cfg.top_k, 0)
  assert_eq(cfg.top_p, 1.0)
  assert_eq(cfg.max_tokens, 0)
}

///|
/// 自定义推理配置应保留传入值。
test "InferConfig - new creates custom config" {
  let cfg = InferConfig::new(0.7, 40, 0.9, 512)
  assert_eq(cfg.temperature, 0.7)
  assert_eq(cfg.top_k, 40)
  assert_eq(cfg.top_p, 0.9)
  assert_eq(cfg.max_tokens, 512)
}

///|
/// infer_with_config 应使推理计数递增。
test "VlaModel - infer_with_config increments infer_count" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  let cfg = InferConfig::new(0.8, 50, 0.95, 256)
  let _ = model.infer_with_config(b"img", "task1", cfg)
  let _ = model.infer_with_config(b"img", "task2", InferConfig::default())
  assert_eq(model.infer_count(), 2)
  model.free()
}

///|
/// infer 内部调用 infer_with_config，行为应一致。
test "VlaModel - infer delegates to infer_with_config" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  let _ = model.infer(b"img", "do something")
  assert_eq(model.infer_count(), 1)
  model.free()
}

// ===== 模型元信息测试 =====

///|
/// 加载后 get_model_info 应返回正确的默认元信息。
test "VlaModel - get_model_info default values" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  let info = model.get_model_info()
  assert_true(info.context_size > 0)
  assert_true(info.param_count > 0)
  assert_eq(info.quant_type, Q4)
  assert_eq(info.backend, Cpu)
  assert_true(info.is_loaded)
  model.free()
}

///|
/// 释放后 is_loaded 应为 false。
test "VlaModel - get_model_info after free" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  model.free()
  let info = model.get_model_info()
  assert_false(info.is_loaded)
}

///|
/// 切换后端后 get_model_info 应反映新后端。
test "VlaModel - get_model_info reflects backend change" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  model.set_backend(Cuda)
  let info = model.get_model_info()
  assert_eq(info.backend, Cuda)
  model.free()
}

///|
/// QuantType 枚举值。
test "QuantType - enum values" {
  assert_eq(QuantType::Fp16, Fp16)
  assert_eq(QuantType::Q4, Q4)
  assert_true(QuantType::Fp16 != Q4)
}
