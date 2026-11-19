# =============================================================================
# 05_validacion.R · Etapa 5: silueta, reglas lógicas, errores inyectados y
# validación temporal (entrenar con años anteriores, probar en el siguiente).
# Siempre se compara el modelo de 3 con el de 16 variables.
# Tiempo aproximado: 25 min (validación temporal: 18 ajustes de los 4 detectores).
# =============================================================================
if (!exists("r16")) source("scripts/R/03_modelos.R", encoding = "UTF-8")
for (obj in c("d", "top", "puno", "py")) if (exists(obj)) rm(list = obj)
invisible(gc())

# 5.1 Silueta (muestra de 10 000 registros)
sil <- validar_silueta(dv, r16, VARS_16)
print(round(sil, 3)); guardar_tab(data.table(Particion = names(sil), Silueta = round(sil, 3)), "silueta")

# 5.2 Reglas lógicas (R1 vendió > cosechó · R2 cosechó > sembró · R3 valor ≠ cantidad × precio)
vr16 <- validar_reglas(base, r16); vr3 <- validar_reglas(base, r3)
print(vr16$casos)
vr <- rbind(vr3$tabla[, Modelo := "3 variables"], vr16$tabla[, Modelo := "16 variables"])
print(vr[Casos > 10, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)]); guardar_tab(vr, "validacion_reglas")

# Desde aquí solo se usa "base" (los errores se inyectan en las cifras originales):
# se libera dv para que la validación entre en memoria
rm(dv); invisible(gc())

# 5.3 Errores inyectados (1 % de los registros normales)
t0 <- Sys.time()
vi <- list(`3 variables`  = validar_inyeccion(base, VARS_3, k = 3, previo = r3$anomalia),
           `16 variables` = validar_inyeccion(base, VARS_16, k = K, previo = r16$anomalia))
cat("Inyección:", round(difftime(Sys.time(), t0, units = "mins"), 1), "min\n")
met <- rbindlist(lapply(names(vi), function(m) vi[[m]]$metricas[, Modelo := m]))
rec <- rbindlist(lapply(names(vi), function(m) vi[[m]]$recall_tipo[, Modelo := m]))
print(met); print(rec)
guardar_tab(met, "validacion_inyeccion"); guardar_tab(rec, "recall_por_tipo_error")

f1 <- met[, .(Metodo = factor(Metodo, levels = unname(METODOS)), F1 = as.numeric(F1),
              Modelo = factor(Modelo, levels = c("3 variables", "16 variables")))]
p <- ggplot(f1, aes(Metodo, F1, fill = Modelo)) + geom_col(position = position_dodge(.8), width = .75) +
  scale_fill_manual(values = c("grey75", "grey15"), name = NULL) + ylim(0, 1.05) +
  labs(x = NULL, title = "Errores inyectados: F1 con 3 y con 16 variables") + tema_ena() + theme(legend.position = "top")
guardar_fig(p, "f5_inyeccion", 7, 3.4)

# 5.4 Validación temporal 2016-2025
t0 <- Sys.time()
vt <- rbind(validar_temporal(base, VARS_3, k = 3)[, Modelo := "3 variables"],
            validar_temporal(base, VARS_16, k = K)[, Modelo := "16 variables"])
cat("Temporal:", round(difftime(Sys.time(), t0, units = "mins"), 1), "min\n")
print(vt); guardar_tab(vt, "validacion_temporal")
p <- ggplot(vt, aes(factor(Anio_prueba), F1_votacion, group = Modelo, linetype = Modelo, shape = Modelo, colour = Modelo)) +
  geom_line(linewidth = .9) + geom_point(size = 2.2) +
  scale_colour_manual(values = c("16 variables" = "black", "3 variables" = "grey55"), name = NULL) +
  scale_linetype_manual(values = c("16 variables" = "solid", "3 variables" = "dashed"), name = NULL) +
  scale_shape_manual(values = c("16 variables" = 16, "3 variables" = 15), name = NULL) +
  coord_cartesian(ylim = c(min(.5, min(vt$F1_votacion) - .05), 1)) + labs(x = "Año de prueba", y = "F1", title = "Validación temporal 2016-2025") +
  tema_ena() + theme(legend.position = "bottom")
guardar_fig(p, "f6_temporal", 7, 3.4)
print(vt[, .(F1_medio = mean(F1_votacion), AUC_medio = mean(AUC_votacion)), by = Modelo])
