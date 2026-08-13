# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to semantic versioning.

## [Unreleased] — 2026-08-13

### Added
- 初版文档：项目申报书、技术文档、品牌故事、README
- 一致性审查与验证报告
- CHANGELOG 文件

### Changed
- README 文档结构优化，应用小型项目模板
- 移除待接入 CI 的占位徽章

### Fixed
- 02-技术文档.md：修正 `EMBET_*` → `EMBIT_*` 环境变量拼写错误
- 02-技术文档.md：修正 `EMBET_GAZEBO_ADDR` 默认值为 `localhost:9000`
- 01/02/03/04：清理「全球首个完全基于 MoonBit 语言构建的」绝对化表述
- 02-技术文档.md：将 `context_size` 字段从 `RobotModel` 移至 `VlaModel` 实体
- 04-README.md：安装步骤补充 `embit-examples`
- 04-README.md：环境要求补充 CMake >= 3.20 和 Git LFS
- 03-品牌故事.md：商标检索提示移至附录
- 01-项目申报书.md：Phase 4 补充性能验证里程碑
