# scripts/

| Archivo | Uso |
|---|---|
| `Deteccion_Anomalias_ENA_2015_2025.ipynb` | Análisis completo (5 etapas). Ejecutar desde esta carpeta. |
| `ena_anomalias.py` | Funciones de cada etapa que importa el notebook. **Copiarlo aquí antes del primer commit.** |
| `exportar_base.py` | `python scripts/exportar_base.py ENA_2014_2025_cultivos.xlsx` → `data/processed/ena_2014_2025_productor.csv.gz` |
| `poner_doi.py` | `python scripts/poner_doi.py 10.5281/zenodo.NNNNNNN` → pone el DOI real en todo el proyecto |

## scripts/R/ (RStudio)

| Archivo | Etapa |
|---|---|
| `00_configuracion.R` | Paquetes, rutas (`figuras/R`, `resultados/R`), semilla, k = 3 |
| `funciones.R` | Todas las funciones (mismos nombres que en Python: `crear_variables`, `z_robusto`, `detectar_todo`, `validar_inyeccion`, …) |
| `01_cargar_datos.R` | Carga `ena_2014_2025_productor.csv.gz` y deja 2015-2025 |
| `02_variables.R` | Etapa 3: 16 variables, descriptivos y correlación |
| `03_modelos.R` | Etapa 4: z-score, Isolation Forest, k-Means, DBSCAN y votación (3 y 16 variables) |
| `04_resultados.R` | Por año, departamento, cultivo, Puno, importancia y comparación con Python |
| `05_validacion.R` | Etapa 5: silueta, reglas, errores inyectados y validación temporal |
| `ejecutar_todo.R` | Corre todo en orden |
| `exportar_base.R` | Excel por año → CSV consolidado (equivale a `exportar_base.py`) |

Abrir antes `ena-anomalias-2015-2025.Rproj` para que las rutas funcionen.
