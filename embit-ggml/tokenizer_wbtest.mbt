///|
/// embit-ggml Tokenizer 白盒测试。

///|
/// 默认 Tokenizer 词表大小为 32000。
test "Tokenizer - default vocab size" {
  let tok = Tokenizer::default()
  assert_eq(tok.get_vocab_size(), 32000)
}

///|
/// count_tokens 空字符串返回 0。
test "Tokenizer - count_tokens empty string" {
  let tok = Tokenizer::default()
  assert_eq(tok.count_tokens(""), 0)
}

///|
/// count_tokens 按空格分词。
test "Tokenizer - count_tokens splits by space" {
  let tok = Tokenizer::default()
  assert_eq(tok.count_tokens("hello world"), 2)
  assert_eq(tok.count_tokens("pick up the red block"), 5)
  assert_eq(tok.count_tokens("single"), 1)
}

///|
/// count_tokens 处理多空格与换行。
test "Tokenizer - count_tokens multiple spaces" {
  let tok = Tokenizer::default()
  assert_eq(tok.count_tokens("a  b   c"), 3)
  assert_eq(tok.count_tokens("a\nb\nc"), 3)
}

///|
/// encode 返回 token ID 序列。
test "Tokenizer - encode returns token ids" {
  let tok = Tokenizer::new(1000)
  let ids = tok.encode("hello world")
  assert_eq(ids.length(), 2)
  assert_eq(tok.encode_count(), 1)
}

///|
/// encode 空字符串返回空数组。
test "Tokenizer - encode empty string" {
  let tok = Tokenizer::default()
  let ids = tok.encode("")
  assert_eq(ids.length(), 0)
}

///|
/// encode 零词表大小应抛出错误。
test "Tokenizer - encode zero vocab raises error" {
  let tok = Tokenizer::new(0)
  try tok.encode("test") catch {
    InvalidConfig(msg) => assert_true(msg.contains("vocab_size"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// encode 生成的 ID 应在词表范围内。
test "Tokenizer - encode ids within vocab range" {
  let tok = Tokenizer::new(100)
  let ids = tok.encode("hello world foo bar baz")
  for id in ids {
    assert_true(id >= 0)
    assert_true(id < 100)
  }
}

///|
/// decode 返回占位字符串。
test "Tokenizer - decode returns placeholder" {
  let tok = Tokenizer::default()
  let result = tok.decode([1, 2, 3])
  assert_true(result.contains("decoded"))
  assert_true(result.contains("3"))
}

///|
/// decode 空数组返回空字符串。
test "Tokenizer - decode empty returns empty string" {
  let tok = Tokenizer::default()
  assert_eq(tok.decode([]), "")
}

///|
/// estimate_context_usage 应返回 token 数加 margin。
test "Tokenizer - estimate_context_usage" {
  let tok = Tokenizer::default()
  let usage = tok.estimate_context_usage("hello world foo", 10)
  assert_eq(usage, 13) // 3 tokens + 10 margin
}
