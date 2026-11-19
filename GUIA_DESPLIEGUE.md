# Guía de despliegue: GitHub Pages + DOI en Zenodo

Requisitos: [Git](https://git-scm.com/), [Quarto](https://quarto.org/docs/get-started/) ≥ 1.4, cuenta de GitHub y cuenta de Zenodo (se entra con GitHub). Los comandos funcionan en PowerShell o Git Bash.

> El sitio ya viene compilado en `docs/`. Solo hay que volver a ejecutar `quarto render` si se cambia un `.qmd` o el DOI.

## 0. Antes del primer commit

1. Copiar `ena_anomalias.py` a `scripts/`.
2. Si el repositorio va en otra cuenta de GitHub, reemplazar `miltonfloresf606-ai` en `_quarto.yml`, `_variables.yml`, `README.md`, `CITATION.cff`, `.zenodo.json` y `data/processed/README_datos.md`.
3. (Opcional) Correr el análisis en R: abrir `ena-anomalias-2015-2025.Rproj` en RStudio y ejecutar `scripts/R/ejecutar_todo.R`. Desde RStudio también se puede compilar el sitio con la pestaña **Build → Render Website** o en la Terminal con los comandos de abajo.
4. Compilar y revisar:

```bash
quarto render
quarto preview
```

## 1. Subir a GitHub

```bash
git init
git add .
git commit -m "Proyecto ENA anomalías 2015-2025: informe, presentación, datos y código"
git branch -M main
git remote add origin https://github.com/miltonfloresf606-ai/ena-anomalias-2015-2025.git
git push -u origin main
```

(Crear antes el repositorio vacío y **público** en GitHub con el nombre `ena-anomalias-2015-2025`, sin README.)

`.gitignore` deja fuera los microdatos del INEI (`data/raw/`, `*.sav`, `*.zip`, `*.xlsx`) y el CSV sin comprimir; solo sube `ena_2014_2025_productor.csv.gz` (22,8 MB, bajo el límite de 100 MB de GitHub).

## 2. Activar GitHub Pages

GitHub → repositorio → **Settings → Pages** → *Source*: **Deploy from a branch** → *Branch*: `main` / carpeta **`/docs`** → Save.

En 1–2 minutos queda en: `https://miltonfloresf606-ai.github.io/ena-anomalias-2015-2025/`
(presentación: `.../presentacion.html`).

## 3. DOI con Zenodo (vinculado a GitHub)

1. Entrar a https://zenodo.org con **Log in → GitHub**.
2. Menú del usuario → **GitHub** → *Sync now* → activar el interruptor de `ena-anomalias-2015-2025`.
3. En GitHub: **Releases → Draft a new release** → tag `v1.0.0` → título `v1.0.0` → **Publish release**.
4. Zenodo archiva el release y crea el registro con los metadatos de `.zenodo.json` (tipo *dataset*, autores, licencia CC BY 4.0).
5. En el registro de Zenodo copiar el **DOI de concepto** ("Cite all versions"), que siempre apunta a la última versión.

## 4. Poner el DOI real y volver a publicar

```bash
python scripts/poner_doi.py 10.5281/zenodo.NNNNNNN
quarto render
git add .
git commit -m "Agrega DOI de Zenodo"
git push
```

El script cambia el DOI en `_variables.yml`, `README.md`, `CITATION.cff`, `references.bib`, `.zenodo.json` y los `.qmd`; con eso aparecen la insignia en el README y en la sección **Disponibilidad de datos** del informe, en *Datos y código* y en la diapositiva final.

Opcional: crear el release `v1.0.1` para que la versión archivada en Zenodo ya contenga el DOI.

## 5. (Opcional) Depósito del dataset en Mendeley Data o Dataverse

Útil si se quiere el dataset en un repositorio de datos separado del código.

- Subir solo: `ena_2014_2025_productor.csv.gz`, `diccionario_variables.csv`, `README_datos.md` y `SHA256SUMS.txt` (carpeta `data/processed/`).
- **Mendeley Data** (https://data.mendeley.com): *New dataset* → completar título, descripción (copiar de `README_datos.md`), autores, licencia CC BY 4.0 → *Reserve DOI* → subir archivos → *Publish*.
- **Dataverse** (Harvard Dataverse o el de la institución): *Add Data → New Dataset* → metadatos → subir archivos → *Publish Dataset*.
- Agregar ese segundo DOI al registro de Zenodo como identificador relacionado (*is supplemented by*) y, si se desea, a la sección **Disponibilidad de datos** de `index.qmd`.

## Alternativa: GitHub Actions

`extras/publish.yml` compila el sitio en la nube y lo publica en la rama `gh-pages`. Para usarlo hay que moverlo a `.github/workflows/`, quitar `output-dir: docs` de `_quarto.yml` y elegir la rama `gh-pages` en Settings → Pages.
