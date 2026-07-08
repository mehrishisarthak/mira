import json, sys
from collections import defaultdict

path = sys.argv[1]
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    data = json.load(f)

events = data['traceEvents'] if isinstance(data, dict) and 'traceEvents' in data else data

# tid -> thread name
tname = {}
for e in events:
    if e.get('ph') == 'M' and e.get('name') == 'thread_name':
        tname[(e.get('pid'), e.get('tid'))] = e.get('args', {}).get('name', '')

def thr(e):
    return tname.get((e.get('pid'), e.get('tid')), f"tid:{e.get('tid')}")

# Complete slices
slices = [e for e in events if e.get('ph') == 'X' and 'dur' in e]
print(f"=== {path} ===")
print(f"total events: {len(events)}  complete-slices: {len(slices)}")

# duration span of trace
ts = [e['ts'] for e in events if 'ts' in e]
if ts:
    print(f"trace span: {(max(ts)-min(ts))/1000:.0f} ms")

# Thread names present
print("threads:", sorted(set(tname.values())))

# Frame markers
ui_marks = ['Animator::BeginFrame']
raster_marks = ['GPURasterizer::Draw', 'Rasterizer::DoDraw']

def frame_stats(names):
    durs = [e['dur']/1000.0 for e in slices if e.get('name') in names]
    if not durs:
        return None
    durs_sorted = sorted(durs)
    over16 = sum(1 for d in durs if d > 16.0)
    over33 = sum(1 for d in durs if d > 33.0)
    n = len(durs)
    p50 = durs_sorted[n//2]
    p90 = durs_sorted[int(n*0.9)]
    return dict(n=n, max=max(durs), p50=p50, p90=p90, over16=over16, over33=over33)

for label, names in [('UI build (Animator::BeginFrame)', ui_marks),
                     ('Raster (GPURasterizer::Draw/DoDraw)', raster_marks)]:
    s = frame_stats(names)
    if s:
        print(f"\n{label}: frames={s['n']} max={s['max']:.1f}ms p50={s['p50']:.1f}ms "
              f"p90={s['p90']:.1f}ms  >16ms={s['over16']} >33ms={s['over33']}")
    else:
        print(f"\n{label}: (no marker events found)")

# Top longest slices overall (dedupe by name+thread, keep max)
longest = sorted(slices, key=lambda e: e.get('dur', 0), reverse=True)[:25]
print("\nTop 25 longest slices (name @ thread = dur):")
for e in longest:
    print(f"  {e['dur']/1000.0:8.1f}ms  {e.get('name','?')[:55]:55}  @ {thr(e)}")

# Aggregate time by slice name on the platform/raster threads (where HC cost lands)
agg = defaultdict(float)
cnt = defaultdict(int)
for e in slices:
    agg[(e.get('name','?'), thr(e))] += e.get('dur',0)/1000.0
    cnt[(e.get('name','?'), thr(e))] += 1
top_agg = sorted(agg.items(), key=lambda kv: kv[1], reverse=True)[:20]
print("\nTop 20 by total time (name @ thread = total ms / count):")
for (name, t), total in top_agg:
    print(f"  {total:9.1f}ms  x{cnt[(name,t)]:5}  {name[:45]:45} @ {t}")
