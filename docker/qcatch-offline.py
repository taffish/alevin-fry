#!/opt/qcatch/bin/python3
"""Bundle known QCatch 0.2.14 browser assets without changing result payloads."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import tempfile

from bs4 import BeautifulSoup
from plotly.offline import get_plotlyjs

ASSETS = Path('/opt/alevin-fry/share/qcatch-assets')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists() or args.output.is_symlink():
        parser.error('output already exists; choose a new file, never overwrite a retained report')
    raw = args.input.read_bytes()
    soup = BeautifulSoup(raw.decode('utf-8'), 'html.parser')
    if not soup.find('title') or 'QCatch' not in soup.title.get_text():
        parser.error('input is not a QCatch report')
    inventory = json.loads((ASSETS / 'assets.json').read_text())
    available = {}
    for entry in inventory:
        data = (ASSETS / entry['file']).read_bytes()
        if hashlib.sha256(data).hexdigest() != entry['sha256']:
            raise ValueError('bundled asset checksum mismatch: ' + entry['file'])
        available[entry['url']] = data
    plotly_done = False
    counts = {'script': 0, 'style': 0}
    omitted = []
    original_plot_scripts = [tag.string for tag in soup.find_all('script')
                             if not tag.get('src') and tag.string and 'Plotly.newPlot' in tag.string]
    for tag in list(soup.find_all('script', src=True)):
        url = tag['src']
        if re.fullmatch(r'https://cdn\.plot\.ly/plotly-[0-9.]+\.min\.js', url):
            if plotly_done:
                tag.decompose()
                continue
            data = get_plotlyjs()
            plotly_done = True
        elif url in available:
            data = available[url].decode('utf-8')
        else:
            raise ValueError('unknown script dependency: ' + url)
        tag.attrs = {}
        tag.string = re.sub(r'</script', r'<\/script', data, flags=re.I)
        counts['script'] += 1
    for tag in list(soup.find_all('link', rel='stylesheet')):
        url = tag.get('href')
        # The 0.2.14 template references this file, but neither its wheel/sdist
        # nor its native output supplies it. Do not invent a replacement style.
        if url == 'css/index.css' and not (args.input.parent / url).exists():
            omitted.append(url)
            tag.decompose()
            continue
        if url not in available:
            raise ValueError('unknown stylesheet dependency: ' + str(url))
        data = available[url].decode('utf-8')
        if 'bootstrap-icons' in url:
            for extension in ('woff2', 'woff'):
                font = (ASSETS / ('bootstrap-icons.' + extension)).read_bytes()
                encoded = base64.b64encode(font).decode('ascii')
                data = re.sub(r'url\(["\']?\.?/?fonts/bootstrap-icons\.' + extension + r'(?:\?[^)"\']*)?["\']?\)',
                              'url(data:font/' + extension + ';base64,' + encoded + ')', data)
        if re.search(r'@import|url\(["\']?(?:https?:|//)', data, re.I):
            raise ValueError('unresolved stylesheet dependency')
        style = soup.new_tag('style')
        style.string = data
        tag.replace_with(style)
        counts['style'] += 1
    if soup.find('script', src=True) or soup.find('link', rel='stylesheet'):
        raise ValueError('external assets remain')
    if any(tag.get('src', '').startswith(('http:', 'https:', '//')) for tag in soup.find_all(['img', 'iframe'])):
        raise ValueError('external image/frame dependency')
    final_plot_scripts = [tag.string for tag in soup.find_all('script')
                          if tag.string and 'Plotly.newPlot' in tag.string and tag.string in original_plot_scripts]
    if original_plot_scripts != final_plot_scripts:
        raise ValueError('plot payload changed while bundling')
    # Presentation-only adaptation: retain native plot dimensions and payloads,
    # but make every chart reachable on a narrow screen without page overflow.
    viewport = soup.find('meta', attrs={'name': 'viewport'})
    if viewport:
        viewport['content'] = 'width=device-width, initial-scale=1'
    for plot in soup.select('.plotly-graph-div'):
        frame = plot.parent
        frame['class'] = list(frame.get('class', [])) + ['taffish-chart-scroll']
        frame['tabindex'] = '0'
        frame['role'] = 'region'
        frame['aria-label'] = 'Interactive chart; scroll horizontally on narrow screens'
    style = soup.new_tag('style', attrs={'id': 'taffish-qcatch-responsive'})
    style.string = '''
.main-content, .main-content .row > *, .main-content .container { min-width: 0; }
.main-content .d-flex > div { min-width: 0; max-width: 100%; }
#umi_dedup4 { width: 100%; max-width: 100%; }
.taffish-chart-scroll { width: 100%; max-width: 100%; overflow-x: auto; overscroll-behavior-x: contain; }
.taffish-chart-scroll:focus-visible { outline: 2px solid #0d6efd; outline-offset: 2px; }
.main-content table { overflow-wrap: anywhere; }
.main-content .value-cell { white-space: nowrap; overflow-wrap: normal; }
.main-content [id^="section"] { scroll-margin-top: 80px; }
.taffish-offline-note { font-size: .9rem; color: #43546a; margin: 0 0 1rem; }
@media (max-width: 1200px) { #tab1 .col-md-6 { flex: 0 0 100%; width: 100%; } }
@media (max-width: 767px) {
 .floating-sidebar { position: static; width: auto; margin: 0 12px 20px; padding: 8px 12px; }
 .floating-sidebar ul { display: flex; flex-wrap: wrap; gap: 4px; }
 .floating-sidebar ul li { margin: 0; } .floating-sidebar ul li a { padding: 6px; }
 .main-content { margin-left: 0; } #description > .col { flex: 0 0 100%; width: 100%; }
 #summary_table { font-size: .85rem; } .value-cell { font-size: 1rem; }
}
'''
    soup.head.append(style)
    explanation = soup.new_tag('p', attrs={'class': 'taffish-offline-note'})
    explanation.string = ('Offline copy with TAFFISH narrow-screen layout support. '
                          'Scroll inside charts when needed; native plot data and the original report are unchanged.')
    main_page = soup.find(id='main_page')
    if main_page:
        main_page.insert(0, explanation)
    note = soup.new_tag('meta', attrs={'name': 'taffish-qcatch-source-sha256',
                                     'content': hashlib.sha256(raw).hexdigest()})
    soup.head.append(note)
    payload = str(soup).encode('utf-8')
    # Exclusive atomic promotion protects an existing output or dangling symlink.
    temporary = None
    interrupted = 0
    previous = {}
    def defer(signum, _frame):
        nonlocal interrupted
        interrupted = signum
    def stop(signum, _frame):
        raise SystemExit(128 + signum)
    for sig in (signal.SIGINT, signal.SIGTERM):
        previous[sig] = signal.signal(sig, defer)
    try:
        fd, temporary = tempfile.mkstemp(prefix='.qcatch-offline-', dir=args.output.parent)
        with os.fdopen(fd, 'wb') as target:
            for sig in previous:
                signal.signal(sig, stop)
            if interrupted:
                raise SystemExit(128 + interrupted)
            target.write(payload)
            target.flush()
            os.fsync(target.fileno())
        os.chmod(temporary, 0o644)
        os.link(temporary, args.output)
    finally:
        if temporary is not None:
            os.unlink(temporary)
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    print(json.dumps({'output': str(args.output), 'source_sha256': hashlib.sha256(raw).hexdigest(),
                      'sha256': hashlib.sha256(payload).hexdigest(), 'bytes': len(payload),
                      'assets_inlined': counts, 'omitted_absent_upstream_assets': omitted,
                      'presentation_adaptation': 'scrollable native charts and narrow-screen layout',
                      'plot_payloads_unchanged': len(original_plot_scripts)}))


if __name__ == '__main__':
    main()
