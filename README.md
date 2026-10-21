# 简单的检查者 1.0

一个 Codex skill，用于拆解刚刚编写或修改的代码，说明各功能板块的作用和代码位置，并用可复核的运行证据检查作用是否生效、原始需求是否完成。

## 功能

- 先依据用户目标建立验收项，再按实际职责划分代码板块。
- 默认生成独立的 `code-breakdown.md`：列出板块职责、输入输出、文件/符号/行号、验证状态、证据和限制。
- 使用 Mermaid 流程图标记状态：绿色表示范围内验证通过，红色表示已确认问题，黄色表示待核实，灰色表示未验证。
- 支持生成 Markdown 和离线 HTML 审查报告；报告生成器只校验记录并渲染，不执行记录内的命令。
- 提供 SHA-256 文件快照校验和 Python 标准库测试。

绿色状态只适用于明确记录的输入、环境和验证范围，不代表所有场景正确。缺少源码、依赖或环境时应保留未验证状态。

## 安装

将 `simple-checker-v1` 目录复制到 Codex 个人 skills 目录下。Windows 默认路径为：

```text
%USERPROFILE%\.codex\skills\simple-checker-v1
```

安装后在 Codex 中新开会话或刷新 skill 列表，然后调用：

```text
$simple-checker-v1 检查刚刚的代码，并单独生成代码拆解文件。
```

完整使用方法见 [使用说明](使用说明.md)。报告 JSON 格式见 [报告记录规范](references/report-contract.md)。

## 检查

要求 Python 3，无第三方依赖：

```powershell
python -B scripts/test_checker_report.py
python -B scripts/checker_report.py validate assets/review.example.json
python -B scripts/checker_report.py render assets/review.example.json --out .\review-output
```

内置订单导出示例故意保留“复用列表分页导致超过 20 条时导出不完整”的缺陷。构建示例会运行可复现检查并重写示例日志：

```powershell
python -B assets/order-export/build_example.py
```

示例报告不是其他项目的检查结果。

## 许可证

当前版本未附开源许可证。除非作者另行添加许可证，版权及复用权限仍由权利人保留。
