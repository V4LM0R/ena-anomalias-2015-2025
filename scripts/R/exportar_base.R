# =============================================================================
# exportar_base.R · Excel por año (ENA_2014_2025_cultivos.xlsx) -> CSV consolidado
# Equivalente en R de scripts/exportar_base.py
# Uso (consola de RStudio): source("scripts/R/exportar_base.R"); exportar_base("ruta/ENA_2014_2025_cultivos.xlsx")
# =============================================================================
library(data.table)

exportar_base <- function(xlsx, salida = "data/processed/ena_2014_2025_productor.csv.gz") {
  nombres <- c(
    "Año" = "anio", "Código departamento" = "ccdd", "Departamento" = "departamento",
    "Región natural" = "region_natural", "Cultivo" = "cultivo", "Código cultivo" = "cod_cultivo",
    "Unidad de medida" = "unidad_medida", "Superficie cosechada (ha)" = "sup_cosechada_ha",
    "Superficie reconstruida (sí/no)" = "sup_reconstruida", "Superficie sembrada (ha)" = "sup_sembrada_ha",
    "Cantidad cosechada (en su unidad)" = "cant_cosechada", "Equivalencia de la unidad en kg" = "equiv_kg",
    "Producción (kg)" = "prod_kg", "Rendimiento (kg/ha)" = "rend_kg_ha",
    "Cantidad vendida (en su unidad)" = "cant_vendida", "Precio por unidad (S/)" = "precio_unidad",
    "Valor de la venta (S/)" = "valor_venta", "Precio por kg (S/)" = "precio_kg",
    "Consumo del hogar (en su unidad)" = "cant_hogar", "Valor del consumo del hogar (S/)" = "valor_hogar",
    "Guardado como semilla (en su unidad)" = "cant_semilla", "Alimento para animales (en su unidad)" = "cant_animales",
    "Número de cosechas" = "n_cosechas", "Meses de siembra a cosecha" = "meses_siembra_cosecha",
    "Tipo de cultivo (código INEI)" = "tipo_cultivo", "Régimen de tenencia (código INEI)" = "regimen_tenencia",
    "Fuente de agua (código INEI)" = "fuente_agua", "Marca Z-score" = "flag_z",
    "Marca Isolation Forest" = "flag_if", "Marca k-Means" = "flag_km", "Marca DBSCAN" = "flag_db",
    "Votos (0 a 4)" = "votos", "Anomalía (1 = sí)" = "anomalia")
  hojas <- grep("^[0-9]{4}$", readxl::excel_sheets(xlsx), value = TRUE)   # se saltan Léeme y Resumen
  d <- rbindlist(lapply(hojas, function(h) {
    x <- as.data.table(readxl::read_excel(xlsx, sheet = h, col_types = "text"))
    setnames(x, names(x), nombres[names(x)])
    message(h, ": ", format(nrow(x), big.mark = " "), " registros")
    x
  }), fill = TRUE)[, unname(nombres), with = FALSE]
  texto <- c("ccdd", "departamento", "region_natural", "cultivo", "unidad_medida", "sup_reconstruida")
  num <- setdiff(names(d), texto)
  d[, (num) := lapply(.SD, as.numeric), .SDcols = num]
  d[, ccdd := sprintf("%02d", as.integer(ccdd))][ccdd == "NA", ccdd := NA]
  fwrite(d, salida, compress = "gzip", na = "")
  message(salida, ": ", format(nrow(d), big.mark = " "), " filas × ", ncol(d), " columnas")
  invisible(d)
}
