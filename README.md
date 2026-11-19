# Detección de anomalías en la Encuesta Nacional Agropecuaria (ENA) 2014–2025

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24375916.svg)](https://doi.org/10.5281/zenodo.24375916)
[![Sitio web](https://img.shields.io/badge/informe-GitHub%20Pages-14213d)](https://miltonfloresf606-ai.github.io/ena-anomalias-2015-2025/)
[![Código: MIT](https://img.shields.io/badge/código-MIT-blue)](LICENSE)
[![Datos: CC BY 4.0](https://img.shields.io/badge/datos-CC%20BY%204.0-lightgrey)](data/LICENSE-DATOS.md)

Detección no supervisada de registros anómalos de producción agrícola (capítulo 200, cultivos cosechados) en 1 250 818 registros de la ENA del INEI, 2015–2025. Se comparan un modelo de 3 y uno de 16 variables con z-score robusto, DBSCAN, k-Means e Isolation Forest combinados por votación, y se valida con reglas lógicas, errores inyectados y validación temporal año por año.

- **Informe web:** https://miltonfloresf606-ai.github.io/ena-anomalias-2015-2025/
- **Presentación:** https://miltonfloresf606-ai.github.io/ena-anomalias-2015-2025/presentacion.html
- **Datos y código (DOI):** https://doi.org/10.5281/zenodo.24375916

Universidad Nacional del Altiplano – Puno · FINESI · Ciencia de Datos I · Docente: Fred Torres Cruz.

## Estructura

```
.
├── _quarto.yml              # sitio web Quarto (salida en docs/)
├── _variables.yml           # DOI, repo y URL del sitio (un solo lugar)
├── index.qmd                # informe técnico
├── datos.qmd                # diccionario, descarga y cómo citar
├── presentacion.qmd         # diapositivas revealjs
├── references.bib · apa.csl · styles.scss · presentacion.scss
├── data/
│   ├── raw/                 # microdatos INEI (NO se suben a GitHub)
│   └── processed/
│       ├── ena_2014_2025_productor.csv.gz   # base consolidada (22,7 MB)
│       └── diccionario_variables.csv
├── resultados/              # tablas CSV del informe
├── figuras/                 # figuras PNG del informe
├── ena-anomalias-2015-2025.Rproj   # proyecto de RStudio
├── codigo-r.qmd             # página con el código en R
├── scripts/
│   ├── R/                   # análisis completo en R (RStudio)
│   │   ├── 00_configuracion.R · funciones.R
│   │   ├── 01_cargar_datos.R … 05_validacion.R
│   │   ├── ejecutar_todo.R
│   │   └── exportar_base.R
│   ├── Deteccion_Anomalias_ENA_2015_2025.ipynb
│   ├── ena_anomalias.py     # módulo con las funciones por etapa
│   ├── exportar_base.py     # Excel por año -> CSV consolidado
│   └── poner_doi.py         # reemplaza el DOI en todos los archivos
├── docs/                    # sitio compilado (GitHub Pages)
├── CITATION.cff · .zenodo.json · LICENSE
└── GUIA_DESPLIEGUE.md
```

## Datos

| Archivo | Registros | Columnas |
|---|---:|---:|
| `data/processed/ena_2014_2025_productor.csv.gz` | 1 329 315 | 33 |

Un registro = un cultivo cosechado por un productor en una parcela y un año. Sin identificadores de productor. 2014 solo trae columnas descriptivas (el INEI no publicó superficie, cantidad ni valor); no existe 2020. El diccionario está en `data/processed/diccionario_variables.csv`.

Fuente primaria: INEI, Encuesta Nacional Agropecuaria 2014–2024 (SPSS) y 2025 (CSV, módulo 1895), portal de microdatos: https://proyectos.inei.gob.pe/microdatos/

```python
import pandas as pd
ena = pd.read_csv("data/processed/ena_2014_2025_productor.csv.gz", dtype={"ccdd": str}, low_memory=False)
```

```r
ena <- readr::read_csv("data/processed/ena_2014_2025_productor.csv.gz", col_types = readr::cols(ccdd = "c"))
```

## Compilar el sitio

```bash
quarto render        # genera docs/
quarto preview       # vista previa local
```

## Análisis en R (RStudio)

1. Abrir `ena-anomalias-2015-2025.Rproj` en RStudio.
2. Abrir `scripts/R/ejecutar_todo.R` y pulsar **Source** (o correr los scripts `00` a `05` en orden).
3. Las figuras quedan en `figuras/R/` y las tablas en `resultados/R/`.

Paquetes: `data.table`, `ggplot2`, `isotree`, `dbscan`, `cluster`, `readxl` (se instalan solos la primera vez). Usa hasta ~5 GB de RAM (computadora de 8 GB o más); todo el análisis tarda ~30 min.

## Reproducir el análisis en Python

```bash
pip install -r requirements.txt
# copiar los microdatos del INEI en data/raw/ y ajustar las rutas de la primera celda del notebook
jupyter lab scripts/Deteccion_Anomalias_ENA_2015_2025.ipynb
```

## Cómo citar

Flores Flores, M., Pacori Vera, R. A., Mamani Fernandez, R. R., Aquize Jimenez, V. S., & Luque Cornejo, Z. Y. (2026). *Detección de anomalías en la Encuesta Nacional Agropecuaria 2014–2025: base consolidada y código* (Versión 1.0.0) [Conjunto de datos]. Zenodo. https://doi.org/10.5281/zenodo.24375916

## Licencia

Código bajo [MIT](LICENSE). Base procesada, tablas y figuras bajo [CC BY 4.0](data/LICENSE-DATOS.md), citando también al INEI como fuente primaria.
