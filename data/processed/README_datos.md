# ENA 2014–2025 · Base consolidada de cultivos cosechados con marcas de anomalía

**Archivo:** `ena_2014_2025_productor.csv.gz` (CSV UTF-8 comprimido con gzip; separador coma; decimal punto; celda vacía = dato faltante)
**Registros:** 1 329 315 · **Columnas:** 33 · **Diccionario:** `diccionario_variables.csv`

- Unidad: un cultivo cosechado por un productor en una parcela y un año (capítulo 200 de la ENA, sección 200A).
- 2015–2025: 1 250 818 registros limpios (encuestas completas, sin códigos de relleno ni duplicados, cultivos con ≥ 30 registros en el año), con las marcas de los cuatro detectores y la votación (modelo de 16 variables).
- 2014: 78 497 registros solo con columnas descriptivas (el INEI no publicó superficie, cantidad ni valor). No existe la ENA 2020.
- Superficie de 2015 y 2018 reconstruida en hectáreas con el factor de la parcela (`sup_reconstruida = "sí"`).
- No contiene identificadores de productor, vivienda ni conglomerado.

**Fuente primaria:** Instituto Nacional de Estadística e Informática (INEI). Encuesta Nacional Agropecuaria 2014–2024 (SPSS) y 2025 (CSV, módulo 1895). https://proyectos.inei.gob.pe/microdatos/

**Licencia:** CC BY 4.0. **Código y método:** https://github.com/miltonfloresf606-ai/ena-anomalias-2015-2025
