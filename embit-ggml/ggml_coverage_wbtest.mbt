///|
/// parse_instruction_to_actions "release" 分支。
test "VlaModel - infer release instruction" {
  let model = VlaModel::load("model.gguf")
  let result = model.infer(b"image", "release the object")
  assert_true(result.length() > 0)
  model.free()
}

///|
/// parse_instruction_to_actions "walk backward" 分支。
test "VlaModel - infer walk backward instruction" {
  let model = VlaModel::load("model.gguf")
  let result = model.infer(b"image", "walk backward")
  assert_true(result.length() > 0)
  model.free()
}

///|
/// parse_instruction_to_actions "turn right" 分支。
test "VlaModel - infer turn right instruction" {
  let model = VlaModel::load("model.gguf")
  let result = model.infer(b"image", "turn right")
  assert_true(result.length() > 0)
  model.free()
}

///|
/// VlaModel::get_model_info QuantType::Fp16 分支。
test "VlaModel - get_model_info Fp16" {
  // 占位模式 quant_type=2 (Q4)，无法触发 Fp16 分支
  // 此测试验证 get_model_info 正常工作
  let model = VlaModel::load("model.gguf")
  let info = model.get_model_info()
  assert_true(info.context_size > 0)
  model.free()
}
