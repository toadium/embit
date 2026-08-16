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
/// decode 词表内 ID 返回真实文本。
test "Tokenizer - decode returns real text" {
  let tok = Tokenizer::default()
  // ID 4="pick", 5="up", 6="the"
  let result = tok.decode([4, 5, 6])
  assert_eq(result, "pick up the")
}

///|
/// decode 空数组返回空字符串。
test "Tokenizer - decode empty returns empty string" {
  let tok = Tokenizer::default()
  assert_eq(tok.decode([]), "")
}

///|
/// decode 词表外 ID 返回 "<unk>"。
test "Tokenizer - decode out-of-vocab returns unk" {
  let tok = Tokenizer::new(100)
  // ID 99 在词表外（词表仅 82 词），应返回 "<unk>"
  let result = tok.decode([99])
  assert_eq(result, "<unk>")
}

///|
/// encode → decode 往返一致（词表内单词）。
test "Tokenizer - encode decode roundtrip" {
  let tok = Tokenizer::default()
  let text = "pick up the red block"
  let ids = tok.encode(text)
  let decoded = tok.decode(ids)
  assert_eq(decoded, text)
}

///|
/// encode → decode 往返一致（多词句）。
test "Tokenizer - encode decode roundtrip multi" {
  let tok = Tokenizer::default()
  let text = "move to the table walk forward turn left"
  let ids = tok.encode(text)
  let decoded = tok.decode(ids)
  assert_eq(decoded, text)
}

///|
/// encode 一致性：相同单词始终映射到相同 ID。
test "Tokenizer - encode consistency" {
  let tok = Tokenizer::new(1000)
  let ids1 = tok.encode("pick up")
  let ids2 = tok.encode("pick up")
  assert_eq(ids1[0], ids2[0])
  assert_eq(ids1[1], ids2[1])
}

///|
/// with_vocab 使用自定义词表创建分词器。
test "Tokenizer - with_vocab custom" {
  let tok = Tokenizer::with_vocab(["<pad>", "hello", "world"])
  assert_eq(tok.get_vocab_size(), 3)
  let ids = tok.encode("hello world")
  assert_eq(ids[0], 1)
  assert_eq(ids[1], 2)
  assert_eq(tok.decode(ids), "hello world")
}

///|
/// estimate_context_usage 应返回 token 数加 margin。
test "Tokenizer - estimate_context_usage" {
  let tok = Tokenizer::default()
  let usage = tok.estimate_context_usage("hello world foo", 10)
  assert_eq(usage, 13) // 3 tokens + 10 margin
}

// ===== ggml tokenizer 绑定测试 =====

///|
/// 占位模式下 encode_with_ggml 回退到内置词表 encode。
test "Tokenizer - encode_with_ggml fallback in placeholder" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  let tok = Tokenizer::default()
  let ids = tok.encode_with_ggml(model.ctx, "pick up")
  // 占位模式：embit_ggml_tokenize 返回 -1，回退到内置词表
  assert_true(ids.length() >= 1)
  model.free()
}

///|
/// 占位模式下 decode_with_ggml 回退到内置词表 decode。
test "Tokenizer - decode_with_ggml fallback in placeholder" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  let tok = Tokenizer::default()
  let ids = tok.encode("pick up")
  let text = tok.decode_with_ggml(model.ctx, ids)
  // 占位模式：embit_ggml_detokenize 返回空 Bytes，回退到内置词表
  assert_eq(text, "pick up")
  model.free()
}

///|
/// 占位模式下 count_tokens_with_ggml 回退到 count_tokens。
test "Tokenizer - count_tokens_with_ggml fallback in placeholder" {
  let model = VlaModel::load("models/smolvla-7b-q4.gguf")
  let tok = Tokenizer::default()
  let n = tok.count_tokens_with_ggml(model.ctx, "pick up the red block")
  // 占位模式：回退到空白字符分词，5 个词
  assert_eq(n, 5)
  model.free()
}
