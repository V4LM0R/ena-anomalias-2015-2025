# =============================================================================
# 04_resultados.R · Resultados descriptivos, caso Puno y comparación con Python
# =============================================================================
if (!exists("r16")) source("scripts/R/03_modelos.R", encoding = "UTF-8")

cols <- c("anio", "departamento", "cultivo", "sup_cosechada_ha", "sup_sembrada_ha", "prod_kg", "rend_kg_ha",
          "precio_kg", "n_cosechas", "z_rend", "z_precio", "z_cosechado", "z_cosechas", "votos")
d <- cbind(dv[, setdiff(cols, "votos"), with = FALSE], r16[, !c("cluster_km")])
d[, departamento := fifelse(is.na(departamento) | departamento == "", "Sin dato", departamento)]

# Por año
por_anio <- d[, .(registros = .N, anomalias = sum(anomalia)), by = anio][order(anio)][, pct := round(100 * anomalias / registros, 2)]
print(por_anio); guardar_tab(por_anio, "anomalias_por_anio")
p <- ggplot(por_anio, aes(factor(anio), pct)) + geom_col(fill = "grey40", width = .6) +
  geom_text(aes(label = format(pct, decimal.mark = ",", nsmall = 1, digits = 1)), vjust = -.4, size = 2.8) +
  labs(x = NULL, y = "% de registros anómalos", title = "Anomalías por año (2020 sin encuesta)") + tema_ena()
guardar_fig(p, "f3_por_anio", 7, 3)

# Por departamento
por_dep <- d[departamento != "Sin dato", .(registros = .N, anomalias = sum(anomalia)), by = departamento][registros > 1000]
por_dep[, pct := round(100 * anomalias / registros, 2)][order(-pct)]
guardar_tab(por_dep[order(-pct)], "anomalias_por_departamento")
p <- ggplot(por_dep, aes(pct, reorder(departamento, pct), fill = departamento == "Puno")) +
  geom_col(show.legend = FALSE) + scale_fill_manual(values = c("grey65", "black")) +
  labs(x = "% de registros anómalos", y = NULL, title = "Anomalías por departamento, 2015-2025 (Puno en negro)") + tema_ena()
guardar_fig(p, "f4_departamentos", 6.5, 5.5)

# Por cultivo (>= 5000 registros)
por_cultivo <- d[, .(registros = .N, anomalias = sum(anomalia)), by = cultivo][registros >= 5000][, pct := round(100 * anomalias / registros, 2)][order(-pct)]
print(head(por_cultivo, 10)); guardar_tab(por_cultivo, "anomalias_por_cultivo")

# Importancia de variables
imp <- importancia_variables(dv, r16)
print(imp[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)]); guardar_tab(imp, "importancia_variables")
p <- ggplot(imp, aes(Razon, reorder(Variable, Razon))) + geom_col(fill = "grey45") + scale_x_log10() +
  labs(x = "|z| medio de los anómalos ÷ |z| medio de los normales (escala log)", y = NULL,
       title = "Peso de cada variable en las anomalías") + tema_ena()
guardar_fig(p, "f7_importancia", 7, 4)

# Top nacional y caso Puno
top <- d[anomalia == 1][order(-votos, -score_if)]
guardar_tab(top[1:15, ..cols], "top_anomalias_nacional")
puno <- d[departamento == "Puno"]
cat(sprintf("Puno: %s registros · %d anómalos (%.2f %%)\n", format(nrow(puno), big.mark = " "),
            sum(puno$anomalia), 100 * mean(puno$anomalia)))
print(puno[anomalia == 1, .N, by = cultivo][order(-N)][1:8])
guardar_tab(puno[anomalia == 1][order(-votos, -score_if)][1:15, ..cols], "top_anomalias_puno")

# Registros marcados por al menos un método
guardar_tab(d[votos >= 1, c(cols, names(METODOS)), with = FALSE], "registros_marcados")

# ---- Comparación con las marcas de Python (columnas flag_* de la base) ----
py <- base[, .(flag_z, flag_if, flag_km, flag_db, anomalia)]
kappa <- function(a, b) { po <- mean(a == b); pe <- mean(a) * mean(b) + (1 - mean(a)) * (1 - mean(b)); (po - pe) / (1 - pe) }
comp_py <- rbindlist(lapply(names(METODOS), function(f) data.table(
  Metodo = METODOS[[f]], Python_pct = round(100 * mean(py[[f]]), 2), R_pct = round(100 * mean(r16[[f]]), 2),
  Acuerdo_pct = round(100 * mean(py[[f]] == r16[[f]]), 2), Kappa = round(kappa(py[[f]], r16[[f]]), 3),
  Coinciden_anomalos = sum(py[[f]] == 1 & r16[[f]] == 1))))
print(comp_py); guardar_tab(comp_py, "comparacion_python_vs_R")

rm(d, top, puno, py); invisible(gc())   # libera memoria antes de la validación
