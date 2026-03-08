import json, os, re, sys, time, urllib.request, urllib.error

REPO = os.environ['REPO']
GH_TOKEN = os.environ['GH_TOKEN']
ISSUE_NUMBER = os.environ.get('ISSUE_NUMBER', '').strip()
NUM_STUDENTS = int(os.environ.get('NUM_STUDENTS', '0'))
TIMEOUT_MINUTES = int(os.environ.get('TIMEOUT_MINUTES', '20'))

if not ISSUE_NUMBER or NUM_STUDENTS == 0:
    print("No issue or students to monitor. Exiting.")
    sys.exit(0)

# Jobs to report in the task list (in display order)
RELEVANT_JOBS = [
    'riscv-tests',
    'cpu-tests',
    'rt-thread',
    'microbench',
    'hello',
    'iverilog-microbench',
]

HEADERS = {
    'Authorization': f'Bearer {GH_TOKEN}',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
}


def gh_get(path):
    url = f"https://api.github.com{path}"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
    except Exception as e:
        print(f"  GET {path} error: {e}")
        return None


def gh_post(path, data=None):
    url = f"https://api.github.com{path}"
    body = json.dumps(data).encode() if data is not None else b''
    req = urllib.request.Request(
        url, data=body,
        headers={**HEADERS, 'Content-Type': 'application/json'},
        method='POST',
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        if e.code == 204:
            return {}
        print(f"  POST {path} error: {e.code} {e.read().decode(errors='replace')}")
        return None
    except Exception as e:
        print(f"  POST {path} error: {e}")
        return None


def get_issue_comments():
    result = gh_get(f"/repos/{REPO}/issues/{ISSUE_NUMBER}/comments?per_page=100")
    return result or []


def extract_run_urls(comments):
    """Return distinct workflow run URLs found in bot comments, preserving order."""
    seen = set()
    urls = []
    for comment in comments:
        if comment.get('user', {}).get('login') != 'github-actions[bot]':
            continue
        body = comment.get('body', '')
        for line in body.splitlines():
            m = re.search(r'Workflow URL - (https://\S+/actions/runs/\d+)', line)
            if m:
                url = m.group(1)
                if url not in seen:
                    seen.add(url)
                    urls.append(url)
    return urls


def get_run_id_from_url(url):
    m = re.search(r'/runs/(\d+)', url)
    return m.group(1) if m else None


def get_run_info(run_id):
    data = gh_get(f"/repos/{REPO}/actions/runs/{run_id}")
    if not data:
        return None, None
    return data.get('status'), data.get('conclusion')


def cancel_run(run_id):
    result = gh_post(f"/repos/{REPO}/actions/runs/{run_id}/cancel")
    return result is not None


def get_run_jobs(run_id):
    data = gh_get(f"/repos/{REPO}/actions/runs/{run_id}/jobs?per_page=100")
    if not data:
        return []
    return data.get('jobs', [])


def post_comment(body):
    return gh_post(f"/repos/{REPO}/issues/{ISSUE_NUMBER}/comments", {'body': body})


# ---------------------------------------------------------------------------
# Main monitoring loop
# ---------------------------------------------------------------------------
POLL_INTERVAL = 30  # seconds between polls
CANCEL_PROPAGATION_DELAY = 20  # seconds to wait for cancellations to propagate

deadline = time.time() + TIMEOUT_MINUTES * 60

print(f"Monitoring issue #{ISSUE_NUMBER} for up to {TIMEOUT_MINUTES} minute(s)")
print(f"Expecting {NUM_STUDENTS} workflow run(s)")

# tracked_runs: url -> dict with run metadata
tracked_runs = {}   # url -> {run_id, status, conclusion, canceled_by_us}

while True:
    remaining = deadline - time.time()
    if remaining <= 0:
        print("Timeout reached.")
        break

    # Fetch latest issue comments and discover new workflow URLs
    comments = get_issue_comments()
    for url in extract_run_urls(comments):
        if url not in tracked_runs:
            run_id = get_run_id_from_url(url)
            tracked_runs[url] = {
                'run_id': run_id,
                'url': url,
                'status': None,
                'conclusion': None,
                'canceled_by_us': False,
            }
            print(f"  Discovered workflow: {url}")

    # Refresh status for all known runs
    for info in tracked_runs.values():
        if info['status'] != 'completed':
            status, conclusion = get_run_info(info['run_id'])
            info['status'] = status
            info['conclusion'] = conclusion

    completed = sum(1 for i in tracked_runs.values() if i['status'] == 'completed')
    found = len(tracked_runs)
    print(f"  {completed}/{found} completed, {found}/{NUM_STUDENTS} found, "
          f"{int(remaining)}s remaining")

    if found >= NUM_STUDENTS and completed >= NUM_STUDENTS:
        print("All workflows completed!")
        break

    sleep_secs = min(POLL_INTERVAL, max(0, deadline - time.time()))
    if sleep_secs <= 0:
        print("Timeout reached.")
        break
    time.sleep(sleep_secs)

# ---------------------------------------------------------------------------
# Cancel any still-running workflows
# ---------------------------------------------------------------------------
still_running = [i for i in tracked_runs.values() if i['status'] != 'completed']
if still_running:
    print(f"\nCanceling {len(still_running)} still-running workflow(s)...")
    for info in still_running:
        print(f"  Canceling run {info['run_id']} ...")
        cancel_run(info['run_id'])
        info['canceled_by_us'] = True

    # Wait for cancellations to propagate
    time.sleep(CANCEL_PROPAGATION_DELAY)

    # Refresh status after cancel
    for info in still_running:
        status, conclusion = get_run_info(info['run_id'])
        info['status'] = status
        info['conclusion'] = conclusion

# ---------------------------------------------------------------------------
# Build summary comment
# ---------------------------------------------------------------------------
print("\nBuilding summary comment...")

summary_parts = []

for url, info in tracked_runs.items():
    run_id = info['run_id']
    canceled_by_us = info['canceled_by_us']

    jobs = get_run_jobs(run_id)
    jobs_by_name = {j['name']: j for j in jobs}

    lines = [f"[Workflow Run]({url})", ""]

    setup_job = jobs_by_name.get('setup')
    setup_conclusion = setup_job.get('conclusion') if setup_job else None

    if setup_conclusion == 'failure':
        lines.append("**Setup Failed**")
    else:
        for test_name in RELEVANT_JOBS:
            job = jobs_by_name.get(test_name)
            if job:
                conclusion = job.get('conclusion')
                if conclusion == 'success':
                    lines.append(f"- [x] {test_name}")
                elif conclusion == 'cancelled':
                    lines.append(f"- [ ] {test_name} (canceled)")
                else:
                    # failed, skipped, or still in progress when we read it
                    lines.append(f"- [ ] {test_name}")
            else:
                # Job not present – run was cancelled before this job started
                if canceled_by_us:
                    lines.append(f"- [ ] {test_name} (canceled)")
                else:
                    lines.append(f"- [ ] {test_name}")

    summary_parts.append('\n'.join(lines))

if summary_parts:
    summary = "\n\n---\n\n".join(summary_parts)
else:
    summary = "No workflow runs were found for this retest."

print("Posting summary comment to issue...")
result = post_comment(summary)
if result:
    print(f"Summary posted: {result.get('html_url', '(unknown URL)')}")
else:
    print("Failed to post summary comment. Content:")
    print(summary)
