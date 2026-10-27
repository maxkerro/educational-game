"""backlog.md <-> board JSON. Usage:
  python3 backlog_board.py to-json <backlog.md>                 -> prints {"data":..., "state":...}
  python3 backlog_board.py set-status <backlog.md> ID=status ...  -> rewrites the Status lines
"""
import json, re, sys, datetime

FIELD = re.compile(r'^- \*\*(.+?):\*\*\s*(.*)$')

def parse(text):
    milestones, items, status = [], [], {}
    current_m, item, field = None, None, None
    for raw in text.splitlines():
        line = raw.rstrip()
        if line.startswith('| ') and not line.startswith('| ID') and not set(line) <= set('|- '):
            cells = [c.strip() for c in line.strip('|').split('|')]
            if len(cells) >= 4 and re.fullmatch(r'[A-Z0-9]+', cells[0]):
                milestones.append({'id': cells[0], 'name': cells[1], 'platform': cells[2], 'goal': cells[3]})
            continue
        m = re.match(r'^## (\S+) — ', line)
        if m:
            current_m, item = m.group(1), None
            continue
        m = re.match(r'^### (\S+) — (.+)$', line)
        if m:
            item = {'id': m.group(1), 'm': current_m, 'area': '', 'title': m.group(2), 'pts': 0,
                    'pri': 'Should', 'story': '', 'desc': '', 'ac': [], 'notes': '', 'deps': [],
                    '_tests': '', '_commits': ''}
            items.append(item); status[item['id']] = 'todo'; field = None
            continue
        if item is None:
            continue
        m = FIELD.match(line)
        if m:
            key, val = m.group(1).lower(), m.group(2).strip()
            field = key
            if key == 'status':
                status[item['id']] = val.split()[0].lower() if val else 'todo'
            elif key == 'area':
                for part in ('Area: ' + val).split('·'):
                    k, _, v = part.strip().strip('*').partition(':')
                    k = k.strip('* ').lower(); v = v.strip('* ').strip()
                    if k == 'area': item['area'] = v
                    elif k == 'points': item['pts'] = int(re.sub(r'\D', '', v) or 0)
                    elif k == 'priority': item['pri'] = v
                    elif k == 'depends on': item['deps'] = [d.strip() for d in v.split(',') if d.strip() and d.strip() != '—']
            elif key == 'story': item['story'] = val
            elif key == 'description': item['desc'] = val
            elif key == 'notes': item['notes'] = val
            elif key == 'tests': item['_tests'] = val
            elif key == 'commits': item['_commits'] = val
            continue
        m = re.match(r'^\s+- \[[ xX]\] (.+)$', line)
        if m and field == 'acceptance criteria':
            item['ac'].append(m.group(1)); continue
        if line.startswith('  ') and line.strip() and field in ('notes', 'description', 'story', 'tests'):
            k = {'notes': 'notes', 'description': 'desc', 'story': 'story', 'tests': '_tests'}[field]
            item[k] = (item[k] + ' ' + line.strip()).strip()
    for it in items:
        extra = [x for x in (('Commits: ' + it.pop('_commits')) if it['_commits'] else '',
                             ('Tests: ' + it.pop('_tests')) if it.get('_tests') else '') if x]
        it.pop('_commits', None); it.pop('_tests', None)
        it['notes'] = ' · '.join([x for x in [it['notes']] + extra if x])
    return {'milestones': milestones, 'items': items}, status

def set_status(text, changes):
    out, cur = [], None
    for line in text.splitlines(keepends=True):
        m = re.match(r'^### (\S+) — ', line)
        if m: cur = m.group(1)
        elif line.startswith('## '): cur = None
        if cur in changes and line.startswith('- **Status:**'):
            line = '- **Status:** %s\n' % changes[cur]
        out.append(line)
    return ''.join(out)

if __name__ == '__main__':
    cmd, path = sys.argv[1], sys.argv[2]
    text = open(path, encoding='utf-8').read()
    if cmd == 'to-json':
        data, status = parse(text)
        print(json.dumps({'data': data, 'state': {'status': status,
              'updatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}}))
    elif cmd == 'set-status':
        changes = dict(a.split('=', 1) for a in sys.argv[3:])
        open(path, 'w', encoding='utf-8').write(set_status(text, changes))
