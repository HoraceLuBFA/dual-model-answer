#!/usr/bin/env bash
# dual-model-answer 调度员工具库
#   source /Users/lumenghe/.agents/skills/dual-model-answer/scripts/dma-lib.sh
#
# 这些函数封装的都是「抄错了不会报错、只会悄悄给出坏结果」的操作：
# 三层嵌套的正文提取、退出码不可信的 codex 调用、日志会缺尾的联网核验。
# 手抄一次错一次的风险远大于读一遍函数体，所以一律调用，不要复制片段。

# ---------- 正文提取 ----------
# answer 文档结构：frontmatter / 正文 / --- / 修订说明 / --- / 取舍备忘
# 只取正文：去 frontmatter → 切到留痕块之前 → 剥掉首尾空行与残留分隔线。
# 末尾那道剥离不能省：正文与「## 修订说明」之间的 --- 会被前一步带出来，
# 留着它每次 diff 都会多一条假差异，而审阅方会拿着假差异去质问对方。
dma_body() {
  sed '1,/^---$/d' "$1" \
  | awk '/^## (修订说明|取舍备忘)/{exit} {print}' \
  | awk '{b[NR]=$0} END{s=1; e=NR;
      while (s<=e && b[s]=="") s++;
      while (e>=s && (b[e]=="" || b[e]=="---")) e--;
      for(i=s;i<=e;i++) print b[i]}'
}

# dma_diff <上一版> <这一版> <输出 diff 路径>
# 供审阅方查回归用。空 diff 是正常的（正文没动）；整份被判为改动则多半是
# 分隔线或标题写法跑偏，该退回重出而不是将就。
dma_diff() {
  local prev="$1" curr="$2" out="$3" t
  t=$(mktemp -d)
  dma_body "$prev" > "$t/prev.txt"
  dma_body "$curr" > "$t/curr.txt"
  diff -u "$t/prev.txt" "$t/curr.txt" > "$out"
  local added removed
  added=$(grep -c '^+[^+]' "$out" || true)
  removed=$(grep -c '^-[^-]' "$out" || true)
  echo "diff: +${added} -${removed} → $out"
  [ "$removed" -gt 0 ] && echo "  ↑ 有删除行，审阅方须核对方修订说明里是否交代"
  rm -rf "$t"
}

# ---------- Codex 调用 ----------
# dma_codex <工作目录> <prompt文件> <回收文件> <日志文件> [额外 codex 参数...]
# 用 Bash 工具的 run_in_background 发起，命令里不要再加 &。
# prompt 走 stdin 的 -，不要用 "$(cat 文件)"：内联传法实测会把长中文 prompt
# 静默截断，而退出码、回收文件大小、产出结构全都正常，从外部看不出来。
dma_codex() {
  local workdir="$1" promptfile="$2" outfile="$3" logfile="$4"; shift 4
  codex exec -s read-only --skip-git-repo-check -c tools.web_search=true \
    -C "$workdir" -o "$outfile" "$@" - < "$promptfile" > "$logfile" 2>&1
  # 退出码不可信：参数错误时 codex 秒退，后台包装层照样报 0，-o 文件根本没建。
  if [ ! -s "$outfile" ]; then
    echo "DMA-FAIL 回收文件为空：$outfile" >&2
    tail -20 "$logfile" >&2
    return 1
  fi
  echo "OK $(wc -c < "$outfile" | tr -d ' ') 字节 → $outfile"
}

# dma_smoke <scratchpad目录>   开工前跑一次，确认联网真的挂上了
# 判据是 rollout 里 web__run 的调用次数。两个更直觉的判据都被实测否掉了：
#   · smoke.md 的内容——Codex 联网正常时也会给栏目页 URL，看答案分不清搜的还是编的
#   · 日志里的 web search: 行——run.log 会缺尾，某次一条工具调用都没记，
#     同次 rollout 里 web__run 实调了 9 次。日志的沉默不是证据。
dma_smoke() {
  local d="$1" sid roll n
  printf '联网查一条今天的新闻，两行内回答，注明来源 URL。\n' > "$d/smoke.txt"
  codex exec -s read-only --skip-git-repo-check -c tools.web_search=true \
    -c model_reasoning_effort=low -o "$d/smoke.md" - < "$d/smoke.txt" > "$d/smoke.log" 2>&1
  sid=$(grep -m1 '^session id:' "$d/smoke.log" | awk '{print $3}')
  if [ -z "$sid" ]; then echo "DMA-FAIL 日志里没有 session id" >&2; tail -20 "$d/smoke.log" >&2; return 1; fi
  roll=$(ls -t "$HOME"/.codex/sessions/*/*/*/rollout-*"$sid"*.jsonl 2>/dev/null | head -1)
  if [ -z "$roll" ]; then echo "DMA-FAIL 找不到 rollout 文件（sid=$sid）" >&2; return 1; fi
  n=$(grep -c 'web__run' "$roll" || true)
  echo "web__run 调用次数：$n"
  if [ "$n" -eq 0 ]; then echo "DMA-FAIL 联网没挂上，停下报告用户，不要降级开跑" >&2; return 1; fi
}

# ---------- Claude 侧回收 ----------
# dma_collect <回收文件>   派 subagent 时给它一个约定路径，让它把正文 Write 到那里，
# 回来后跑这个验收。它是 Codex 侧 -o 的等价物，两侧运输通道由此对称。
#
# 为什么不从 subagent 的最终回复里取正文：那条回复要经 transcript 提取，杂质形态每次
# 不同——HTML 转义、对话性开场白（实测出现过「All facts verified. Writing v2.」）、
# 尾部残留围栏。混进交付文档不会报错，只会让 dma_body 提不出正文、dma_diff 整份判为改动。
# 走文件还有第二个好处：subagent 的正文不再经通知灌进调度员上下文，调度员只看见字节数。
dma_collect() {
  local f="$1" first
  if [ ! -s "$f" ]; then
    echo "DMA-FAIL 回收文件为空或不存在：$f" >&2
    echo "  ↑ subagent 可能没按约定 Write，或路径写错了" >&2
    return 1
  fi
  first=$(grep -m1 -v '^[[:space:]]*$' "$f")
  case "$first" in
    '## '*) ;;
    *) echo "DMA-WARN 首行不是二级标题，疑似混入开场白或 frontmatter：" >&2
       echo "  $first" >&2
       echo "  ↑ 退回该方重出，不要由调度员代删" >&2
       return 1 ;;
  esac
  echo "OK $(wc -c < "$f" | tr -d ' ') 字节 → $f"
}

# ---------- 留痕区配额 ----------
# dma_check_ratio <answer文件>   留痕区（修订说明 + 取舍备忘）不得超过正文的 1/4。
# 不设上限时它会膨胀：实测同一套模板、同一个任务，一侧留痕合计占正文 25%
# （修订说明 12% + 取舍备忘 13%），另一侧写成小论文占到 79%（44% + 35%）。
# 25% 就是有纪律的写法的实际值，故取 1/4 为线。
#
# 修订说明的体量随收到的发现条数走，不随正文长短走，所以要压就压单条：每条两三句，
# 证据指向 review 的 finding 编号而不复述原文——低配那一侧每条约 366 字节，超标那一侧
# 每条约 2,100 字节，差距全在复述上。超了退回该方压缩，不由调度员代删——删哪一句是
# 作者意图的取舍，调度员没有依据做这个判断。
dma_check_ratio() {
  local f="$1" body trace pct
  body=$(dma_body "$f" | wc -c | tr -d ' ')
  trace=$(sed '1,/^---$/d' "$f" | awk '/^## (修订说明|取舍备忘)/{p=1} p' | wc -c | tr -d ' ')
  if [ "$body" -eq 0 ]; then
    echo "DMA-WARN 正文为空，分区写法多半不符规范：$f" >&2; return 1
  fi
  pct=$(( trace * 100 / body ))
  echo "留痕/正文：${trace}/${body} = ${pct}%（上限 25%）"
  if [ "$pct" -gt 25 ]; then
    echo "DMA-WARN 留痕区超配额，退回该方压缩后重出：$f" >&2
    return 1
  fi
}

# ---------- 写盘 ----------
# dma_write <frontmatter文件> <正文文件> <目标路径>
# frontmatter 由调度员生成（它才知道自己传了什么进去，agent 自报的不可信）；
# 正文原文照录，调度员不润色、不改写。
dma_write() {
  { cat "$1"; echo; cat "$2"; } > "$3"
  echo "写入 $(wc -l < "$3" | tr -d ' ') 行 → $3"
}

# ---------- 结构校验 ----------
# dma_check_review <review文件> [full|final]
# 只校验机器要用到的结构：节数、三个标题的字面、finding 是否为标题式。
# 内容质量不在这里管——那是对方审阅方的事。
dma_check_review() {
  local f="$1" mode="${2:-full}" rc=0 h2 expect n bad
  h2=$(grep -c '^## ' "$f")
  expect=3; [ "$mode" = final ] && expect=2
  [ "$h2" -eq "$expect" ] || { echo "DMA-WARN 二级标题 $h2 个，应为 $expect" >&2; rc=1; }
  grep -q '^## 一、闭环核对$'   "$f" || { echo "DMA-WARN 缺「## 一、闭环核对」" >&2; rc=1; }
  grep -q '^## 二、核查发现$'   "$f" || { echo "DMA-WARN 缺「## 二、核查发现」" >&2; rc=1; }
  if [ "$mode" = full ]; then
    grep -q '^## 三、可吸收之处$' "$f" || { echo "DMA-WARN 缺「## 三、可吸收之处」" >&2; rc=1; }
  fi
  n=$(grep -c '^### ' "$f" || true)
  echo "findings：$n 条"
  if [ "$n" -gt 0 ]; then
    bad=$(grep '^### ' "$f" | grep -vE '^### (Cl|Cx)(R[0-9]+|F)-[0-9]{2} .+｜(关键|重要|次要)$' || true)
    if [ -n "$bad" ]; then
      echo "DMA-WARN 下列 finding 标题不符「### 编号 类型｜严重度」：" >&2
      echo "$bad" >&2; rc=1
    fi
  elif ! grep -q '未发现' "$f"; then
    echo "DMA-WARN 零 finding 且未写明「未发现」" >&2; rc=1
  fi
  return $rc
}

# dma_findings <review文件...>   抽 finding 表，供 07 共识与分歧.md 拼装
# 输出：编号 <TAB> 类型 <TAB> 严重度 <TAB> 来源文件
dma_findings() {
  local f
  for f in "$@"; do
    grep '^### ' "$f" 2>/dev/null | sed 's/^### //' \
      | awk -F'｜' -v src="$(basename "$f")" \
          '{split($1,a," "); printf "%s\t%s\t%s\t%s\n", a[1], a[2], $2, src}'
  done
}
