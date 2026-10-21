# 简单的检查者 1.0

一个 Codex skill，用于拆解刚刚编写或修改的代码，说明各功能板块的作用和代码位置，并用可复核的运行证据检查作用是否生效、原始需求是否完成。适用于重度agent编码依赖，可以在不太懂代码编写的同时读懂ai写的代码结构和思路。

## 功能

- 先依据用户目标建立验收项，再按实际职责划分代码板块。
- 默认生成独立的 `code-breakdown.html` 图文页面和 `code-breakdown.md` 文字版：逐块解释职责、输入输出、文件/符号/行号、源码片段、验证状态、证据和限制。
- HTML 内置板块导航、输入→职责→输出示意、可选步骤图和教学样例；支持源码展开、点击/键盘跳转、筛选及打印，离线可读，适配手机。
- 使用流程图标记状态( Mermaid )：绿色表示范围内验证通过，红色表示已确认问题，黄色表示待核实，灰色表示未验证。
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
python -B scripts/checker_report.py breakdown assets/review.example.json --out .\review-output
python -B scripts/checker_report.py render assets/review.example.json --out .\review-output
```

内置订单导出示例故意保留“复用列表分页导致超过 20 条时导出不完整”的缺陷。构建示例会运行可复现检查并重写示例日志：

```powershell
python -B assets/order-export/build_example.py
```

示例报告不是其他项目的检查结果。

打开 `review-output/code-breakdown.html` 看图文拆解。`breakdown` 输出 HTML 和 Markdown 两个独立文件；`render` 再附总审查报告和有效记录。现有 `review.json` 兼容，缺少图文补充字段时仍自动生成输入输出图、源码与证据卡。

当前工具版本为 **1.1.0**，skill 调用名仍为 `$simple-checker-v1`，界面名仍为“简单的检查者1.0”。更新时用仓库完整内容替换原安装目录；仅下载单个 `SKILL.md` 不会更新模板和生成器。生成页面可能含源码与本地路径，请按项目约定保存和分享。

可选浏览器自检（生成器本身无需 Node 或 Playwright）：

```text
npm install --no-save --package-lock=false playwright@1.56.1
npx playwright install chromium
node scripts/test_breakdown_browser.cjs review-output/code-breakdown.html review-output/browser
```

CI 在 Windows/Linux 运行 Python 测试，并在 Chromium 检查源码展开、键盘跳转、筛选、390/700/1024px 宽度及离线请求；订单示例 HTML 和截图随 Actions 产物保存。

## 许可证

当前版本未附开源许可证。除非作者另行添加许可证，版权及复用权限仍由权利人保留。
