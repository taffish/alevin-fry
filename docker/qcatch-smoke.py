#!/opt/qcatch/bin/python3
"""Synthetic engineering regression of native AF -> QCatch -> offline HTML."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
import tempfile


def run(root, full):
    root.mkdir(parents=True, exist_ok=False)
    root = root.resolve()
    source = root / 'input with spaces'
    source.mkdir()
    mapping = root / 'mapped'
    mapping.mkdir()
    rng = random.Random(190014)
    nt = 'ACGT'

    def dna(value, length):
        return ''.join(nt[(value >> (2 * i)) & 3] for i in range(length))

    genes = ['gene%03d' % i for i in range(64)]
    barcodes = [dna(i, 16) for i in range(40)]
    sam = source / 'reads.sam'
    with sam.open('w') as stream:
        stream.write('@HD\tVN:1.6\tSO:queryname\n')
        for gene in genes:
            stream.write('@SQ\tSN:%s\tLN:100\n' % gene)
        record = 0
        for cell, barcode in enumerate(barcodes):
            for j, gene in enumerate(genes):
                for umi in range(rng.randint(1, 7) + (4 if j % 4 == cell % 4 else 0)):
                    record += 1
                    stream.write(f'r{record}\t0\t{gene}\t1\t60\t20M\t*\t0\t0\tACGTACGTACGTACGTACGT\tIIIIIIIIIIIIIIIIIIII\tCR:Z:{barcode}\tUR:Z:{dna(j * 32 + umi, 12)}\n')
    (source / 't2g.tsv').write_text(''.join(f'{g}\t{g}\n' for g in genes))
    (source / 'genes.tsv').write_text(''.join(f'{g}\t' + ('MT-' if i < 4 else '') + f'Synthetic{i:03d}\n' for i, g in enumerate(genes)))
    (source / 'cells.tsv').write_text('\n'.join(barcodes[:32]) + '\n')
    hashes = {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in source.iterdir()}

    def call(label, command):
        with (root / (label + '.log')).open('w') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                    env=dict(os.environ, OMP_NUM_THREADS='2', OPENBLAS_NUM_THREADS='2', NUMBA_NUM_THREADS='2'), timeout=160)
        if result.returncode:
            raise RuntimeError(label + ': ' + (root / (label + '.log')).read_text()[-8000:])

    call('convert', ['alevin-fry', 'convert', '-b', str(sam), '-o', str(mapping / 'map.rad'), '-t', '2'])
    permit = root / 'permit'
    quant = root / 'native quant'
    call('permit', ['alevin-fry', 'generate-permit-list', '-i', str(mapping), '-d', 'fw', '-o', str(permit), '-f', str(len(barcodes)), '-t', '2'])
    call('collate', ['alevin-fry', 'collate', '-i', str(permit), '-r', str(mapping), '-t', '2', '--compress'])
    call('quant', ['alevin-fry', 'quant', '-i', str(permit), '-m', str(source / 't2g.tsv'), '-o', str(quant), '-r', 'cr-like-em', '-t', '2', '--use-mtx', '--small-thresh', '0'])
    from scipy.io import mmread
    matrix = mmread(quant / 'alevin/quants_mat.mtx')
    assert matrix.shape == (len(barcodes), len(genes)), matrix.shape
    assert len((quant / 'alevin/quants_mat_rows.txt').read_text().splitlines()) == len(barcodes)
    before = {str(f.relative_to(quant)): hashlib.sha256(f.read_bytes()).hexdigest() for f in quant.rglob('*') if f.is_file()}
    resources = root / 'resources'
    resources.mkdir(mode=0o700)
    notice = root / 'LICENSE'
    notice.write_text('Synthetic engineering fixture only. CC0-1.0.\n')
    prepare = ['qcatch-gene-map', 'prepare', '--resource-root', str(resources), '--id', 'synthetic-v1',
               '--file', str(source / 'genes.tsv'), '--sha256', hashes['genes.tsv'], '--license-file', str(notice),
               '--source', 'urn:taffish:synthetic-gene-map-v1', '--rights-reviewed']
    call('prepare-map', prepare)
    ready_sha = hashlib.sha256((resources / 'synthetic-v1/READY').read_bytes()).hexdigest()
    call('idempotent-map', prepare)
    assert ready_sha == hashlib.sha256((resources / 'synthetic-v1/READY').read_bytes()).hexdigest()
    call('verify-map', ['qcatch-gene-map', 'verify', '--resource-root', str(resources), '--id', 'synthetic-v1'])
    report = root / 'native report'
    command = ['qcatch', '--input', str(quant), '--output', str(report), '--gene_id2name_file', str(resources / 'synthetic-v1/gene-map.tsv'),
               '--valid_cell_list', str(source / 'cells.tsv'), '--export_summary_table', '--save_filtered_h5ad']
    if not full:
        command.append('--skip_umap_tsne')
    call('qcatch', command)
    import anndata
    retained = anndata.read_h5ad(report / 'filtered_quants.h5ad')
    assert retained.shape == (32, len(genes)), retained.shape
    native = report / 'QCatch_report.html'
    assert native.is_file() and native.stat().st_size > 10000
    offline = root / 'QCatch offline.html'
    call('offline', ['qcatch-offline', '--input', str(native), '--output', str(offline)])
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(offline.read_text(), 'html.parser')
    assert not soup.find('script', src=True) and not soup.find('link', rel='stylesheet')
    scripts = [s.string for s in soup.find_all('script') if s.string and 'Plotly.newPlot(' in s.string]
    assert len(scripts) >= (8 if full else 6), len(scripts)
    assert before == {str(f.relative_to(quant)): hashlib.sha256(f.read_bytes()).hexdigest() for f in quant.rglob('*') if f.is_file()}
    assert hashes == {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in source.iterdir()}
    assert not list(Path(tempfile.gettempdir()).glob('taffish-qcatch-*'))
    (root / 'receipt.json').write_text(json.dumps({'synthetic_only': True, 'full_embeddings': full,
        'native_sha256': hashlib.sha256(native.read_bytes()).hexdigest(),
        'offline_sha256': hashlib.sha256(offline.read_bytes()).hexdigest(), 'plot_scripts': len(scripts),
        'input_unchanged': True}, indent=2))
    print('QCATCH_SMOKE_PASS', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--full', action='store_true')
    args = parser.parse_args()
    if args.out:
        run(args.out, args.full)
    else:
        with tempfile.TemporaryDirectory(prefix='qcatch-smoke-') as scratch:
            run(Path(scratch) / 'run', args.full)
