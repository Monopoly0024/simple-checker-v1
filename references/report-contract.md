# 报告记录规范 v1.0

脚本只使用 Python 3 标准库。审查者解释目标并实际运行验证后，写 UTF-8 JSON，再生成离线报告；脚本不会分析代码语义、执行验证命令或凭空发现问题。

```text
python <skill目录>/scripts/checker_report.py validate <review.json>
python <skill目录>/scripts/checker_report.py breakdown <review.json> --out <产物目录>
python <skill目录>/scripts/checker_report.py render <review.json> --out <审查产物目录>
```

可从 `assets/review.example.json` 开始。该文件是**已实际执行的示例案例**，不是待填模板，不得将其中证据当作项目证据。示例源程序和运行脚本在 `assets/order-export/`；参考后替换全部目标、位置、状态和证据。运行 `python build_example.py` 可重新生成本地示例记录与日志。

## 顶层与路径

- `schema_version`：`"1.0"`。
- `title`：用户可读标题；`reviewed_at`：带时区的 ISO 日期时间。
- `mode`：`review` / `review-and-fix`。
- `project_root`：绝对路径，或相对于 review.json 的路径。报告生成后记录绝对根路径。
- `snapshot`：`base_revision`、`notes`、`files: [{path, sha256}]`。登记所有影响本次验证的源文件、测试、配置与样例数据。SHA-256 为 64 位十六进制。
- `requirements`、`nodes`、`edges`、`issues`、`evidence` 为数组。新记录增加 `blocks` 数组。
- `journey_note`：实际入口到最终结果的验证范围和限制，可选但推荐。

所有文件与日志路径相对于 `project_root`；不得含上级跳转、指向根目录外的符号链接或无关文件。日志也放在项目内约定的审查产物位置。`cwd` 为根目录内的相对工作目录。ID 分别使用 R1、N1、I1、E1 等稳定编号。

## 独立代码拆解文件与板块 blocks

`breakdown` 仅生成 `code-breakdown.md`；`render` 生成该文件及原有三个报告文件。两种方式使用同一有效证据判定，独立文件不需要打开总报告即可阅读。

每板块：`id, title, purpose, node_ids`。ID 为 B1、B2…；title 是功能名称，purpose 说明整体职责，node_ids 包含属于此板块的节点。一板块可对应多个节点或多个文件。每个审查节点恰好归入一个主板块；跨板块调用仍用 edges 表达。板块覆盖本次全部已审查节点，但不自动代表全部项目源码。

板块状态由当前有效节点汇总：failed 优先，然后 pending、unchecked，全部 passed 才 passed。不能手写更乐观的板块结论覆盖节点失败。为兼容旧记录，未提供 blocks 时回退为每节点一板块，并在独立文件明确注明分组未经整体确认。新审查应人工按功能填写。

拆解文件包含板块彩色图、作用与位置总表、逐节点输入输出、应有/实际行为、生效证据、问题和覆盖边界。代码位置链接使用绝对路径和起始行号；符号及范围按提供值显示。依赖或验证文件未单独拆成板块时列入覆盖说明。

## 需求 requirements

每项：`id, text, source, acceptance, required, status, node_ids, evidence_ids`。

- `source` 引用真实用户需求来源，必要时注明假设。
- `status`：`passed`、`failed`、`unchecked`。未验证不是不通过。
- `passed` 需相关节点全通过及实际执行通过证据。一个节点只局部通过时，不得据此扩大需求通过范围。
- `failed` 需当前失败证据，可是实际运行或确定性的静态证据。
- 人工偏好与业务验收需记录具体操作和观察结果；未取得时保留 `unchecked`。

## 节点 nodes

每项：`id, title, role, expected, actual, input, output, scope, status, reason, locations, requirement_ids, evidence_ids, issue_ids`。

- `role`：`implemented` / `missing` / `unprovided`。缺失节点必须是已确认失败且关联问题和缺失证据；找不到单个符号不足以证明功能缺失。未提供的外部实现用 unprovided，保持 pending/unchecked，不伪装成已实现或已确认缺失。
- `status`：`passed`、`failed`、`pending`、`unchecked`。
- `locations`：`[{path, line, end_line?, symbol?}]`，line 为起始行，从 1 开始；end_line 不小于 line，symbol 为函数/类/关键代码名称。新记录优先提供完整符号和范围；旧记录只有起点仍可使用。范围和符号由审查者核实，生成器不证明符号语义。缺失节点可绑定相关入口或接口定义，未提供实现则为空并明确说明。
- `scope`：说明验证了什么输入、环境和路径；`reason` 说明状态依据。
- `affected_by` 可选，填上游节点 ID。它描述影响，不自动改变自身状态。
- `passed` 需要退出码 0、结果通过且当前日志完整的 runtime 证据；`failed` 需要 confirmed 问题和 failed 证据。

## 连线 edges

每项：`source, target, label, kind`，可选 `issue_ids`。

- `kind`：`normal`、`exception`、`affected`、`inferred`。
- normal 是确定的调用/数据关系；其他关系以虚线标明，label 说明含义。
- 连接错误可关联 issue；已确认错误边为红色，待核实为黄色。
- 程序存在循环时保留真实回边。大项目按模块分报告，不能为了美观删去关键分支。

## 问题 issues

每项：`id, title, status, severity, node_ids, evidence_ids, impact, suggestion`。

- `status`：`confirmed` / `suspected`。
- `severity`：`blocking` / `nonblocking`，与验证状态分开。
- confirmed 必须关联失败证据；suspected 在图中保持待核实。
- 修复后保留旧记录，生成新记录；不要让旧问题仍挂到绿色节点上。

## 证据 evidence

每项：`id, kind, command, cwd, exit_code, outcome, expected, observed, scope, source_files`。

- `kind`：`runtime` / `static`。runtime 包括真实命令执行和有记录的实际用户操作。
- `command`：实际命令或明确标注的人工操作步骤，不能写未执行的建议。
- `exit_code`：命令真实退出码；人工操作用 0 表示已完成记录并在 command 中标注人工。
- `outcome`：`passed`、`failed`、`blocked`。退出码 0 也可能观察到业务失败，结果应填 failed。
- `expected`：来自需求或独立样例；`observed`：实际观察，不能只写“测试通过”。
- `source_files`：关联快照中的文件，至少一项。
- runtime 另需 `log_path, log_sha256`，记录完整输出或实际操作日志；截图可作为额外人工证据，但需文字说明其范围。
- static 需要明确的代码位置、逻辑与反证范围写入 observed/scope；它能证明确定的问题，不能单独证明运行通过。

## 自动一致性检查与边界

生成器检查编号、引用、颜色与证据的基本一致性，核对登记源文件和日志哈希。变动或缺失会使关联证据过期，节点降为 pending、需求降为 unchecked；审查者重新确认其他充分证据后，可更新记录。过期问题不再作为当前确定性阻断依据。

生成器无法判断日志是否伪造、断言是否正确、未登记依赖是否变化，也无法证明端到端覆盖；这些由审查者负责。记录中的文本不会作为 HTML 执行。旧报告是快照；需要更新时重新生成。
