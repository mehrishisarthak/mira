import json, sys

for path in sys.argv[1:]:
    d = json.load(open(path, encoding='utf-8', errors='replace'))
    p = d['performance']
    hz = p.get('displayRefreshRate') or 60
    budget = 1000.0/hz
    ff = p['flutterFrames']
    builds = [f['build']/1000.0 for f in ff]   # ms
    rasters = [f['raster']/1000.0 for f in ff]  # ms
    total = [(f['build']+f['raster'])/1000.0 for f in ff]
    n = len(ff)
    def stat(xs):
        s = sorted(xs)
        return (max(xs), s[n//2], s[int(n*0.95)] if n>1 else s[0])
    bmax,bp50,bp95 = stat(builds)
    rmax,rp50,rp95 = stat(rasters)
    jank_build = sum(1 for b in builds if b > budget)
    jank_raster = sum(1 for r in rasters if r > budget)
    jank_total = sum(1 for t in total if t > budget)
    print(f"\n=== {path}  ({hz}Hz, budget {budget:.1f}ms, {n} frames) ===")
    print(f"  BUILD  (UI thread)   : max {bmax:7.1f}  p50 {bp50:5.2f}  p95 {bp95:6.2f}   janky(>budget): {jank_build}")
    print(f"  RASTER (GPU thread)  : max {rmax:7.1f}  p50 {rp50:5.2f}  p95 {rp95:6.2f}   janky(>budget): {jank_raster}")
    print(f"  frames over budget (build+raster): {jank_total}/{n}")
    # worst 8 frames
    worst = sorted(ff, key=lambda f: f['build']+f['raster'], reverse=True)[:8]
    print("  worst frames (build / raster ms):")
    for f in worst:
        print(f"     #{f['number']:<5} build {f['build']/1000.0:7.2f}   raster {f['raster']/1000.0:7.2f}   vsyncOH {f['vsyncOverhead']/1000.0:.1f}")
