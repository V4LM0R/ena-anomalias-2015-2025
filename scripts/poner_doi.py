"""Reemplaza el DOI provisional (10.5281/zenodo.XXXXXXX) por el DOI real en todo el proyecto.

Uso:  python scripts/poner_doi.py 10.5281/zenodo.1234567
Luego: quarto render  ->  git commit  ->  git push
"""
import pathlib, re, sys

PROVISIONAL = '10.5281/zenodo.XXXXXXX'
ARCHIVOS = ['_variables.yml', 'README.md', 'CITATION.cff', 'references.bib', '.zenodo.json',
            'index.qmd', 'datos.qmd', 'presentacion.qmd']

doi = sys.argv[1].strip().removeprefix('https://doi.org/')
if not re.fullmatch(r'10\.\d{4,9}/\S+', doi):
    sys.exit(f'DOI no válido: {doi}')
raiz = pathlib.Path(__file__).resolve().parent.parent
actual = re.search(r'doi:\s*"([^"]+)"', (raiz / '_variables.yml').read_text(encoding='utf-8')).group(1)
for nombre in ARCHIVOS:
    f = raiz / nombre
    if f.exists():
        t = f.read_text(encoding='utf-8')
        n = t.count(actual)
        if n:
            f.write_text(t.replace(actual, doi), encoding='utf-8')
            print(f'{nombre}: {n} reemplazo(s)')
print(f'DOI {actual} -> {doi}. Ahora ejecute: quarto render')
