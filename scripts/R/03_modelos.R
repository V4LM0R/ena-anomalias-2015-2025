# =============================================================================
# 03_modelos.R · Etapa 4: cuatro detectores + votación
#  Z-score robusto (|z| > 3,5) · DBSCAN (ruido; muestra de 40 000, minPts 20,
#  eps = percentil 98 k-distancia) · k-Means (1 % más lejano del centroide) ·
#  Isolation Forest (200 árboles, 1 %) · Votación: anomalía si >= 2 métodos.
# =============================================================================
if (!exists("dv")) source("scripts/R/02_variables.R", encoding = "UTF-8")

sil_k <- elegir_k(dv, VARS_16)
print(round(sil_k, 3))
cat("k con mayor silueta =", names(which.max(sil_k)), "\n")
K <- K_INFORME   # el informe usa k = 3; cambiar a as.integer(names(which.max(sil_k))) para usar la mejor silueta
cat("k usado =", K, "\n")
guardar_tab(data.table(k = names(sil_k), silueta = round(sil_k, 3)), "silueta_por_k")

t0 <- Sys.time()
r3  <- detectar_todo(dv, VARS_3, k = 3)
r16 <- detectar_todo(dv, VARS_16, k = K)
cat("Detección (3 y 16 variables):", round(difftime(Sys.time(), t0, units = "secs")), "s\n")

comp <- data.table(Metodo = unname(METODOS),
                   `3 variables (%)`  = sapply(names(METODOS), function(f) round(100 * mean(r3[[f]]), 2)),
                   `16 variables (%)` = sapply(names(METODOS), function(f) round(100 * mean(r16[[f]]), 2)))
print(comp)
guardar_tab(comp, "marcados_3_vs_16")
cat("Anomalías en ambos modelos:", sum(r3$anomalia == 1 & r16$anomalia == 1), "\n")
print(table(votos = r16$votos))

# Dispersión rendimiento vs precio
set.seed(1)
i <- sample(nrow(dv), 60000)
s <- data.table(z_rend = dv$z_rend[i], z_precio = dv$z_precio[i], anomalia = r16$anomalia[i])
p <- ggplot() +
  geom_point(data = s[anomalia == 0], aes(pmin(pmax(z_rend, -25), 25), pmin(pmax(z_precio, -15), 15)),
             colour = "grey75", size = .4) +
  geom_point(data = s[anomalia == 1], aes(pmin(pmax(z_rend, -25), 25), pmin(pmax(z_precio, -15), 15)),
             shape = 4, size = 1.2) +
  labs(x = "z robusto del rendimiento", y = "z robusto del precio por kg",
       title = "Registros normales (gris) y anómalos (x), muestra de 60 000") + tema_ena()
guardar_fig(p, "f2_dispersion", 6.5, 4.5)
