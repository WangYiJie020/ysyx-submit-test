import json, os, subprocess, sys, time
from datetime import datetime, timezone

REPO = os.environ['REPO']
DELAY = int(os.environ.get('DELAY_SECONDS', '30'))
SOURCE = os.environ.get('SOURCE', 'auto')
skip_raw = os.environ.get('SKIP_STUIDS', '').strip()
skip_stuids = set(s.strip() for s in skip_raw.split(',') if s.strip())

print(f"Source: {SOURCE}")
print(f"Skip STUIDs: {skip_stuids or '(none)'}")
print(f"Delay between students: {DELAY}s")

# ========================================================
# 内嵌数据 (embedded): 上游2025年10月1日起关闭的issue中
# 每位学员的最新提交
# ========================================================
EMBEDDED_STUDENTS = [
{
  "stuid": "24070003",
  "upstream": 88,
  "body": "### 一生一芯学号\n\n24070003\n\n### 仓库URL\n\nhttps://github.com/jiang211/ysyx.git\n\n### 分支名\n\nysyx-b-stage-chip\n\n### 注释\n\n绝对路径\n\n### make参数\n\n- [ ] 不使用'-j'参数, 若cpu-tests等测试由于该参数而失败, 可以勾选此项"
},
{
  "stuid": "24080032",
  "upstream": 85,
  "body": "### 一生一芯学号\n\n24080032\n\n### 仓库URL\n\nhttps://github.com/PengchengYang-xdu/ysyx_24080032_new_ci\n\n### 分支名\n\nnew_ci\n\n### 注释\n\n12月23日重新提交\n\n### make参数\n\n- [x] 不使用'-j'参数, 若cpu-tests等测试由于该参数而失败, 可以勾选此项"
},
{
  "stuid": "24100012",
  "upstream": 78,
  "body": "### 一生一芯学号\n\n24100012\n\n### 仓库URL\n\nhttps://github.com/kuikuikuizzZ/ysyx-workbench\n\n### 分支名\n\nB5\n\n### 注释\n\nB5\n\n### make参数\n\n- [x] 不使用'-j'参数, 若cpu-tests等测试由于该参数而失败, 可以勾选此项"
},
{
  "stuid": "24110017",
  "upstream": 65,
  "body": "### 一生一芯学号\n\n24110017\n\n### 仓库URL\n\nhttps://github.com/dongfengjun/dongfengjun.git\n\n### 分支名\n\nCI\n\n### 注释\n\n重新提交5.13\n\n### make参数\n\n- [ ] 不使用'-j'参数, 若cpu-tests等测试由于该参数而失败, 可以勾选此项"
},
{
  "stuid": "24120011",
  "upstream": 75,
  "body": "### 一生一芯学号\n\n24120011\n\n### 仓库URL\n\nhttps://github.com/Plutoisy/ysyx-workbench\n\n### 分支名\n\ndev\n\n### 注释\n\nci\n\n### make参数\n\n- [x] 不使用'-j'参数, 若cpu-tests等测试由于该参数而失败, 可以勾选此项"
},
{
  "stuid": "25010008",
  "upstream": 69,
  "body": "### 一生一芯学号\n\n25010008\n\n### 仓库URL\n\nhttps://github.com/AfalpHy/ysyx-workbench\n\n### 分支名\n\nB_stage_test\n\n### 注释\n\n第一次提交\n第二次提交\n\n### make参数\n\n- [ ] 不使用'-j'参数, 若cpu-tests等测试由于该参数而失败, 可以勾选此项"
},
{
  "stuid": "25020039",
  "upstream": 91,
  "body": "### 一生一芯学号\n\n25020039\n\n### 仓库URL\n\nhttps://github.com/Ymaple17/ysyx-workbench\n\n### 分支名\n\nci\n\n### 注释\n\n第三十三次提交-修复ebreak的仿真问题(5)\n\n### make参数\n\n- [ ] 不使用'-j'参数, 若cpu-tests等测试由于该参数而失败, 可以勾选此项"
},
{
  "stuid": "25040111",
  "upstream": 77,
  "body": "### 一生一芯学号\n\n25040111\n\n### 仓库URL\n\nhttps://github.com/Dallous52/ysyx-workbench.git\n\n### 分支名\n\nmain\n\n### 注释\n\n第一次\n\n### make参数\n\n- [ ] 不使用'-j'参数, 若cpu-tests等测试由于该参数而失败, 可以勾选此项"
},
{
  "stuid": "25050136",
  "upstream": 87,
  "body": "### 一生一芯学号\n\n25050136\n\n### 仓库URL\n\nhttps://github.com/hai1223a/ysyxexam.git\n\n### 分支名\n\nBstage\n\n### 注释\n\n第一次失败后改版bianhua\n\n### make参数\n\n- [ ] 不使用'-j'参数, 若cpu-tests等测试由于该参数而失败, 可以勾选此项"
},
{
  "stuid": "25080222",
  "upstream": 83,
  "body": "### 一生一芯学号\n\n25080222\n\n### 仓库URL\n\nhttps://gitee.com/cloud_hxw/ysyx-workbench\n\n### 分支名\n\nCI\n\n### 注释\n\nitrace\n\n### make参数\n\n- [x] 不使用'-j'参数, 若cpu-tests等测试由于该参数而失败, 可以勾选此项"
}
]

def fetch_upstream_issues():
  """从上游仓库自动读取2025年12月1日起的关闭issue"""
  import urllib.request, urllib.error
  print("正在从上游仓库 sashimi-yzh/ysyx-submit-test 读取关闭的issue...")
  url = "https://api.github.com/repos/sashimi-yzh/ysyx-submit-test/issues?state=closed&since=2025-12-01T00:00:00Z&per_page=100"
  req = urllib.request.Request(url, headers={
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28'
  })
  try:
      with urllib.request.urlopen(req, timeout=30) as resp:
          issues = json.loads(resp.read())
      print(f"获取到 {len(issues)} 个issue")
      return issues
  except Exception as e:
      print(f"获取上游issue失败: {e}")
      return None

def extract_unique_students(issues):
  """提取每位学员的最新提交"""
  target_date = datetime(2025, 10, 1, tzinfo=timezone.utc)
  students = {}
  for issue in issues:
      body = issue.get('body', '')
      if not body:
          continue
      created = datetime.fromisoformat(
          issue['created_at'].replace('Z', '+00:00')
      )
      if created < target_date:
          continue
      lines = body.split('\n')
      stuid = lines[2].strip() if len(lines) > 2 else ''
      if stuid and stuid not in students:
          students[stuid] = {
              'stuid': stuid,
              'upstream': issue['number'],
              'body': body
          }
  return list(students.values())

# 决定数据来源
if SOURCE == 'auto':
  upstream_issues = fetch_upstream_issues()
  if upstream_issues:
      students = extract_unique_students(upstream_issues)
      print(f"自动模式: 找到 {len(students)} 位学员")
  else:
      print("自动获取失败，回退到内嵌数据")
      students = EMBEDDED_STUDENTS
else:
  print("使用内嵌数据")
  students = EMBEDDED_STUDENTS

# 过滤跳过的学号
students = [s for s in students if s['stuid'] not in skip_stuids]
print(f"将测试 {len(students)} 位学员: {[s['stuid'] for s in students]}")

if not students:
  print("没有需要测试的学员，退出")
  sys.exit(0)

# 按学号排序
sorted_students = sorted(students, key=lambda x: x['stuid'])
first_student = sorted_students[0]
remaining_students = sorted_students[1:]

# 用第一个学员的body作为issue初始内容（直接触发CI，避免空body触发无效run）
print(f"\n正在创建测试issue（初始body为学员 {first_student['stuid']}）...")
result = subprocess.run(
  ['gh', 'issue', 'create',
   '--repo', REPO,
   '--title', 'Retest: 重测上游2025-12-01起的关闭issue（CI验证）',
   '--body', first_student['body']],
  capture_output=True, text=True, check=True
)
issue_url = result.stdout.strip()
issue_number = issue_url.split('/')[-1]
print(f"创建了测试issue #{issue_number}: {issue_url}")
print(f"触发了学员 {first_student['stuid']} (上游issue #{first_student['upstream']}) 的CI")

# 逐一替换issue body来触发各学员的CI
print(f"\n开始逐一触发剩余学员CI（每次间隔{DELAY}秒）...")
for i, student in enumerate(remaining_students):
  stuid = student['stuid']
  upstream_num = student['upstream']
  body = student['body']

  if DELAY > 0:
      print(f"  等待 {DELAY}s 后触发下一位学员...")
      time.sleep(DELAY)

  print(f"\n[{i+2}/{len(sorted_students)}] 触发学员 {stuid} 的CI (上游issue #{upstream_num})...")

  result = subprocess.run(
      ['gh', 'issue', 'edit', issue_number,
       '--repo', REPO,
       '--body', body],
      capture_output=True, text=True
  )

  if result.returncode != 0:
      print(f"  错误: {result.stderr}")
  else:
      print(f"  成功触发学员 {stuid} 的CI")

print(f"\n全部 {len(students)} 位学员已触发CI！")
print(f"请查看 issue #{issue_number} 的评论来跟踪各学员的CI结果。")
print(f"Issue URL: {issue_url}")
