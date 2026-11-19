# =============================================================================
# 02_variables.R · Etapa 3: de 3 a 16 variables
# z robusto del log (rendimiento, precios, superficies) y desvío respecto a la
# mediana del grupo (proporciones, cosechas, meses). Grupo = cultivo × año ×
# región natural (cultivo × año si tiene menos de 30 registros).
# =============================================================================
if (!exists("base")) source("scripts/R/01_cargar_datos.R", encoding = "UTF-8")

t0 <- Sys.time()
dv <- crear_variables(base)
cat("Variables creadas en", round(difftime(Sys.time(), t0, units = "secs")), "s\n")
cat("Modelo ampliado:", length(NUMERICAS), "numéricas +", length(CATEGORICAS), "categóricas =",
    ncol(matriz(dv[1:10], VARS_16)), "columnas tras pasar las categóricas a 0/1\n")

desc <- dv[, lapply(.SD, function(z) c(media = mean(z), de = sd(z), p01 = quantile(z, .01),
                                      mediana = median(z), p99 = quantile(z, .99))), .SDcols = NUMERICAS]
desc <- data.table(estadistico = c("media", "de", "p01", "mediana", "p99"), round(desc, 2))
print(desc)
guardar_tab(desc, "descriptivos_variables")

# Correlación entre las 12 numéricas
corr <- cor(dv[, ..NUMERICAS])
dimnames(corr) <- list(substr(NOMBRES[NUMERICAS], 1, 22), substr(NOMBRES[NUMERICAS], 1, 22))
cat("Correlación absoluta máxima fuera de la diagonal:", round(max(abs(corr[upper.tri(corr)])), 2), "\n")
cm <- as.data.table(as.table(corr))
p <- ggplot(cm, aes(V2, V1, fill = N)) + geom_tile() +
  geom_text(aes(label = sprintf("%.1f", N), colour = abs(N) > .5), size = 2.2, show.legend = FALSE) +
  scale_fill_gradient2(low = "grey20", mid = "white", high = "grey20", limits = c(-1, 1), name = NULL) +
  scale_colour_manual(values = c("black", "white")) +
  labs(x = NULL, y = NULL, title = "Correlación entre las 12 variables numéricas") + tema_ena() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = .5))
guardar_fig(p, "f0_correlacion", 7.5, 6)
