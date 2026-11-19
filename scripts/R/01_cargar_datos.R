# =============================================================================
# 01_cargar_datos.R · Etapas 1-2: base consolidada (ya integrada y limpia)
# La integración SPSS 2014-2024 + CSV 2025 y la limpieza se hicieron en el
# notebook de Python; aquí se parte del archivo depositado en Zenodo.
# =============================================================================
if (!exists("SEMILLA")) source("scripts/R/00_configuracion.R", encoding = "UTF-8")

ena <- fread(RUTA_BASE, colClasses = list(character = "ccdd"), encoding = "UTF-8")
cat("Base completa:", format(nrow(ena), big.mark = " "), "registros ×", ncol(ena), "columnas\n")

# 2014 no trae superficie, cantidad ni valor de venta: el modelo usa 2015-2025
base <- ena[anio >= 2015]
NIVELES <- niveles_categoricas(base)

resumen_anios <- ena[, .(registros = .N, anomalias_python = sum(anomalia, na.rm = TRUE)), by = anio][order(anio)]
print(resumen_anios)
rm(ena); invisible(gc())   # libera memoria: el resto del análisis usa "base"

# Embudo de limpieza (cifras del notebook de Python)
embudo <- fread("resultados/embudo_limpieza.csv", encoding = "UTF-8")
embudo[, paso := factor(paso, levels = rev(paso))]
p <- ggplot(embudo, aes(registros / 1e6, paso)) +
  geom_col(fill = "grey55", width = 0.7) +
  geom_text(aes(label = format(registros, big.mark = " ")), hjust = -0.1, size = 2.8) +
  scale_x_continuous(limits = c(0, 2), expand = c(0, 0)) +
  labs(x = "Millones de registros", y = NULL, title = "Embudo de limpieza") + tema_ena()
guardar_fig(p, "f1_embudo", 8, 4.6)
