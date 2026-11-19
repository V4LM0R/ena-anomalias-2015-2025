# =============================================================================
# funciones.R · Detección de anomalías en la ENA 2015-2025 (versión en R)
# Mismas etapas que ena_anomalias.py: variables, modelos y validación.
# Se carga desde 00_configuracion.R
# =============================================================================

# ---- Nombres de variables ---------------------------------------------------
NUMERICAS <- c("z_rend", "z_precio", "z_area", "z_sembrada", "z_cosechado", "z_venta",
               "z_hogar", "z_animales", "z_semilla", "z_cosechas", "z_precio_hogar", "z_meses")
CONTINUAS <- c("z_rend", "z_precio", "z_area", "z_sembrada", "z_precio_hogar")   # entran al z-score
CATEGORICAS <- c("tipo_cultivo", "regimen_tenencia", "fuente_agua", "region_natural")
VARS_3  <- c("z_rend", "z_precio", "z_area")
VARS_16 <- c(NUMERICAS, CATEGORICAS)

NOMBRES <- c(z_rend = "Rendimiento (kg/ha)", z_precio = "Precio de venta por kg",
             z_area = "Superficie cosechada", z_sembrada = "Superficie sembrada",
             z_cosechado = "% de lo sembrado que se cosechó", z_venta = "% de la producción vendida",
             z_hogar = "% para consumo del hogar", z_animales = "% para alimento de animales",
             z_semilla = "% guardado como semilla", z_cosechas = "Número de cosechas",
             z_precio_hogar = "Precio por kg del autoconsumo", z_meses = "Meses entre siembra y cosecha")

METODOS <- c(flag_z = "Z-score robusto", flag_if = "Isolation Forest", flag_km = "k-Means",
             flag_db = "DBSCAN", anomalia = "Votación (≥2)")
SCORES  <- c(flag_z = "score_z", flag_if = "score_if", flag_km = "score_km",
             flag_db = "score_db", anomalia = "score_voto")

# ---- Auxiliares --------------------------------------------------------------
pos  <- function(x) data.table::fifelse(!is.na(x) & x > 0, x, NA_real_)   # 0 o negativo -> NA
cero <- function(x) data.table::fifelse(is.na(x), 0, x)                   # NA -> 0

por_grupo <- function(x, g, f) {          # aplica f dentro de cada grupo y devuelve un vector alineado
  data.table::data.table(x = x, g = g)[, r := f(x), by = g]$r
}

# z robusto del log: (log x - mediana) / (1,4826 * MAD) dentro del grupo.
# Si el grupo tiene menos de 30 valores válidos se usa el grupo amplio (cultivo × año).
# La MAD tiene un piso de 0,05 (escala log) para que grupos casi constantes no den z enormes.
# Faltante -> 0 (neutral)
z_robusto <- function(x, g, g_amplio = g, min_n = 30, piso = 0.05) {
  lx  <- log(pos(x))
  est <- function(gr) data.table::data.table(v = lx, g = gr)[, `:=`(
    n = sum(!is.na(v)), med = stats::median(v, na.rm = TRUE), s = stats::mad(v, na.rm = TRUE)), by = g]
  a <- est(g); b <- est(g_amplio)
  usar_b <- a$n < min_n
  med <- data.table::fifelse(usar_b, b$med, a$med)
  s   <- pmax(data.table::fifelse(usar_b, b$s, a$s), piso)
  z   <- (lx - med) / s
  z[!is.finite(z)] <- 0
  z
}

# desvío: (x - mediana del grupo) / desviación estándar global. Faltante -> 0
desvio_grupo <- function(x, g) {
  med <- por_grupo(x, g, function(v) stats::median(v, na.rm = TRUE))
  z   <- (x - med) / stats::sd(x, na.rm = TRUE)
  z[!is.finite(z)] <- 0
  z
}

# ---- Etapa 3 · Variables ---------------------------------------------------
crear_variables <- function(base) {
  d <- data.table::copy(base)
  # se quitan las marcas de Python que trae la base (el modelo las vuelve a calcular)
  marcas <- intersect(c("flag_z", "flag_if", "flag_km", "flag_db", "votos", "anomalia"), names(d))
  if (length(marcas)) d[, (marcas) := NULL]
  # cifras derivadas (se recalculan para que los errores inyectados se propaguen)
  d[, prod_kg := cant_cosechada * equiv_kg]
  d[, rend_kg_ha := prod_kg / sup_cosechada_ha]
  d[, precio_kg := valor_venta / (cant_vendida * equiv_kg)]
  d[, precio_hogar_kg := valor_hogar / (cant_hogar * equiv_kg)]
  # grupo de comparación: cultivo × año × región natural (cultivo × año si hay < 30 registros)
  d[, n_grupo := .N, by = .(anio, cultivo, region_natural)]
  d[, grupo_amplio := paste(anio, cultivo)]
  d[, grupo := data.table::fifelse(n_grupo >= 30, paste(anio, cultivo, region_natural), grupo_amplio)]
  d[, `:=`(
    z_rend         = z_robusto(rend_kg_ha, grupo, grupo_amplio),
    z_precio       = z_robusto(precio_kg, grupo, grupo_amplio),
    z_area         = z_robusto(sup_cosechada_ha, grupo, grupo_amplio),
    z_sembrada     = z_robusto(sup_sembrada_ha, grupo, grupo_amplio),
    z_cosechado    = desvio_grupo(sup_cosechada_ha / pos(sup_sembrada_ha), grupo),
    z_venta        = desvio_grupo(cero(cant_vendida)  / cant_cosechada, grupo),
    z_hogar        = desvio_grupo(cero(cant_hogar)    / cant_cosechada, grupo),
    z_animales     = desvio_grupo(cero(cant_animales) / cant_cosechada, grupo),
    z_semilla      = desvio_grupo(cero(cant_semilla)  / cant_cosechada, grupo),
    z_cosechas     = desvio_grupo(log(n_cosechas), grupo),
    z_precio_hogar = z_robusto(precio_hogar_kg, grupo, grupo_amplio),
    z_meses        = desvio_grupo(as.numeric(meses_siembra_cosecha), grupo)
  )]
  # se conservan solo las columnas que usa el análisis (ahorra memoria)
  quedan <- c("anio", "departamento", "cultivo", "region_natural", "tipo_cultivo", "regimen_tenencia",
              "fuente_agua", "sup_cosechada_ha", "sup_sembrada_ha", "prod_kg", "rend_kg_ha", "precio_kg",
              "n_cosechas", NUMERICAS)
  d[, setdiff(names(d), quedan) := NULL]
  d[]
}

# niveles fijos de las categóricas (los mismos en entrenamiento y prueba)
niveles_categoricas <- function(base) {
  lapply(stats::setNames(CATEGORICAS, CATEGORICAS), function(c) sort(unique(stats::na.omit(base[[c]]))))
}

# matriz numérica del modelo: z numéricos + categóricas en 0/1
matriz <- function(d, V, niveles = NIVELES) {
  num <- intersect(V, NUMERICAS)
  cat_cols <- unlist(lapply(intersect(V, CATEGORICAS), function(c) paste0(c, "_", niveles[[c]])))
  X <- matrix(0, nrow(d), length(num) + length(cat_cols), dimnames = list(NULL, c(num, cat_cols)))
  for (v in num) X[, v] <- d[[v]]
  for (c in intersect(V, CATEGORICAS)) for (l in niveles[[c]])
    X[, paste0(c, "_", l)] <- as.numeric(!is.na(d[[c]]) & d[[c]] == l)
  X
}

# ---- Etapa 4 · Modelos -----------------------------------------------------
# Se separa "ajustar" (aprender del entrenamiento) de "aplicar" (marcar registros),
# así sirve igual para el modelo completo y para la validación temporal.
ajustar_detectores <- function(X, k = 3, contaminacion = 0.01, n_dbscan = 40000, min_pts = 20,
                               arboles = 200, semilla = SEMILLA, nucleos = NUCLEOS) {
  set.seed(semilla)
  m <- list(k = k, cont = contaminacion)
  # Isolation Forest (200 árboles, submuestras de 256, cortes en un solo eje como scikit-learn)
  m$iforest <- isotree::isolation.forest(X, ntrees = arboles, sample_size = 256, ndim = 1,
                                         missing_action = "fail", nthreads = nucleos, seed = semilla)
  m$umbral_if <- stats::quantile(stats::predict(m$iforest, X, nthreads = nucleos), 1 - contaminacion)
  # k-Means: umbral = percentil 99 de la distancia al centroide
  km <- suppressWarnings(stats::kmeans(X, centers = k, nstart = 3, iter.max = 300, algorithm = "Lloyd"))
  m$centros <- km$centers
  m$umbral_km <- stats::quantile(dist_centro(X, m$centros)$dist, 1 - contaminacion)
  # DBSCAN en una muestra; eps = percentil 98 de la curva k-distancia
  S <- X[sample.int(nrow(X), min(n_dbscan, nrow(X))), , drop = FALSE]
  m$eps <- unname(stats::quantile(dbscan::kNNdist(S, k = min_pts), 0.98))
  # punto núcleo: tiene minPts puntos (incluido él mismo) a distancia <= eps
  nucleo <- dbscan::kNNdist(S, k = min_pts - 1) <= m$eps
  m$nucleos_db <- unique(S[nucleo, , drop = FALSE])
  m
}

# distancia de cada fila al centroide más cercano: ||x||² - 2·x·c + ||c||² (sin copiar la matriz)
dist_centro <- function(X, centros) {
  D2 <- outer(rowSums(X^2), rowSums(centros^2), "+") - 2 * (X %*% t(centros))
  cl <- max.col(-D2, ties.method = "first")
  list(cluster = cl, dist = sqrt(pmax(D2[cbind(seq_along(cl), cl)], 0)))
}

aplicar_detectores <- function(m, X, Zc, nucleos = NUCLEOS) {
  r <- data.table::data.table(score_z = if (ncol(Zc)) apply(abs(Zc), 1, max) else 0)
  r[, flag_z := as.integer(score_z > 3.5)]
  r[, score_if := stats::predict(m$iforest, X, nthreads = nucleos)]
  r[, flag_if := as.integer(score_if > m$umbral_if)]
  dc <- dist_centro(X, m$centros)
  r[, `:=`(cluster_km = dc$cluster, score_km = dc$dist)]
  r[, flag_km := as.integer(score_km > m$umbral_km)]
  r[, score_db := dbscan::kNN(m$nucleos_db, k = 1, query = X)$dist[, 1]]
  r[, flag_db := as.integer(score_db > m$eps)]
  r[, votos := flag_z + flag_if + flag_km + flag_db]
  r[, anomalia := as.integer(votos >= 2)]
  # puntaje continuo de la votación: votos + promedio de rangos de los 4 puntajes (desempate)
  rk <- (data.table::frank(r$score_z) + data.table::frank(r$score_if) +
         data.table::frank(r$score_km) + data.table::frank(r$score_db)) / (4 * (nrow(r) + 1))
  r[, score_voto := votos + rk]
  r[]
}

detectar_todo <- function(d, V, k = 3, ...) {
  X  <- matriz(d, V)
  Zc <- as.matrix(d[, intersect(V, CONTINUAS), with = FALSE])
  m  <- ajustar_detectores(X, k = k, ...)
  aplicar_detectores(m, X, Zc)
}

elegir_k <- function(d, V, ks = 2:8, n = 10000, semilla = SEMILLA) {
  set.seed(semilla)
  X <- matriz(d, V)[sample.int(nrow(d), n), ]
  D <- stats::dist(X)
  sapply(stats::setNames(ks, ks), function(k) {
    cl <- suppressWarnings(stats::kmeans(X, centers = k, nstart = 3, iter.max = 300, algorithm = "Lloyd"))$cluster
    mean(cluster::silhouette(cl, D)[, "sil_width"])
  })
}

importancia_variables <- function(d, r, vars = NUMERICAS) {
  a <- r$anomalia == 1
  data.table::rbindlist(lapply(vars, function(v) {
    z <- abs(d[[v]])
    data.table::data.table(Variable = NOMBRES[[v]], z_anomalos = mean(z[a]), z_normales = mean(z[!a]),
                           pct_anomalos_z35 = 100 * mean(z[a] > 3.5))
  }))[, Razon := z_anomalos / z_normales][order(-Razon)]
}

# ---- Etapa 5 · Validación --------------------------------------------------
auc_rangos <- function(score, y) {           # AUC por Mann-Whitney (rápido para millones de filas)
  y <- as.logical(y); n1 <- as.numeric(sum(y)); n0 <- length(y) - n1   # numeric: evita desborde de enteros
  (sum(data.table::frank(score)[y]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

metricas <- function(y, flag, score) {
  y <- as.logical(y); f <- as.logical(flag)
  tp <- sum(f & y); fp <- sum(f & !y); fn <- sum(!f & y)
  p <- tp / (tp + fp); rc <- tp / (tp + fn)
  c(Precision = p, Recall = rc, F1 = 2 * p * rc / (p + rc), AUC = auc_rangos(score, y))
}

validar_silueta <- function(d, r, V, n = 10000, semilla = SEMILLA) {
  set.seed(semilla)
  i <- sample.int(nrow(d), n)
  D <- stats::dist(matriz(d[i], V))
  s <- function(cl) if (length(unique(cl)) < 2) NA_real_ else mean(cluster::silhouette(as.integer(cl), D)[, "sil_width"])
  out <- c(s(r$cluster_km[i]), sapply(names(METODOS), function(f) s(r[[f]][i] + 1)))
  names(out) <- c(sprintf("k-Means (k=%d)", max(r$cluster_km)), paste("Normal vs anómalo:", METODOS))
  out
}

reglas_logicas <- function(base, tolerancia = 0.10) {
  data.table::data.table(
    R1 = cero(base$cant_vendida) > base$cant_cosechada,
    R2 = base$sup_cosechada_ha > pos(base$sup_sembrada_ha),
    R3 = abs(base$valor_venta - base$cant_vendida * base$precio_unidad) > tolerancia * base$valor_venta
  )[, lapply(.SD, function(x) !is.na(x) & x)]
}

validar_reglas <- function(base, r, tolerancia = 0.10) {
  R <- reglas_logicas(base, tolerancia)
  tab <- data.table::rbindlist(lapply(names(R), function(regla) {
    caso <- R[[regla]]
    if (sum(caso) == 0) return(NULL)
    data.table::rbindlist(lapply(names(METODOS), function(f) {
      det <- 100 * mean(r[[f]][caso]); resto <- 100 * mean(r[[f]][!caso])
      data.table::data.table(Regla = regla, Casos = sum(caso), Metodo = METODOS[[f]],
                             Detectadas = det, Marcadas_resto = resto, Lift = det / resto)
    }))
  }))
  list(casos = colSums(R), tabla = tab)
}

# Errores típicos de digitación en el 1 % de registros normales.
# Cada tipo se reparte por igual y solo entre registros donde el error cambia algo:
# C solo en quienes venden (valor de venta > 0) y D solo donde la superficie sembrada > 0.
inyectar <- function(base, candidatos, frac = 0.01, semilla = SEMILLA) {
  set.seed(semilla)
  b <- data.table::copy(base)
  n_tipo <- ceiling(frac * length(candidatos) / 5)
  elegibles <- list(
    A = candidatos, B = candidatos, E = candidatos,
    C = candidatos[cero(b$valor_venta[candidatos]) > 0],
    D = candidatos[cero(b$sup_sembrada_ha[candidatos]) > 0])
  usados <- integer(0); idx <- integer(0); tipo <- character(0)
  for (t in c("C", "D", "A", "B", "E")) {            # primero los tipos con menos elegibles
    pool <- setdiff(elegibles[[t]], usados)
    i <- pool[sample.int(length(pool), min(n_tipo, length(pool)))]
    usados <- c(usados, i); idx <- c(idx, i); tipo <- c(tipo, rep(t, length(i)))
  }
  iA <- idx[tipo == "A"]; iB <- idx[tipo == "B"]; iC <- idx[tipo == "C"]
  iD <- idx[tipo == "D"]; iE <- idx[tipo == "E"]
  b[iA, cant_cosechada := cant_cosechada * 10]                                       # A) producción × 10
  b[iB, equiv_kg := equiv_kg * sample(c(1000, 1/1000), length(iB), replace = TRUE)]  # B) kg <-> t
  b[iC, valor_venta := valor_venta * 10]                                             # C) valor × 10
  b[iD, sup_sembrada_ha := sup_sembrada_ha * 10]                                     # D) sembrada × 10
  b[iE, n_cosechas := n_cosechas * 10L]                                              # E) cosechas × 10
  list(base = b, idx = idx, tipo = tipo)
}

ETIQUETAS_ERROR <- c(A = "A) producción × 10", B = "B) kg ↔ t", C = "C) valor × 10",
                     D = "D) sembrada × 10", E = "E) cosechas × 10")

validar_inyeccion <- function(base, V, k = 3, frac = 0.01, semilla = SEMILLA, previo = NULL) {
  # previo: marca de anomalía (0/1) de los datos reales; si no se da, se calcula
  if (is.null(previo)) previo <- detectar_todo(crear_variables(base), V, k)$anomalia
  inj <- inyectar(base, which(previo == 0), frac, semilla)
  d1  <- crear_variables(inj$base); inj$base <- NULL
  r1  <- detectar_todo(d1, V, k); rm(d1); invisible(gc())
  y <- seq_len(nrow(base)) %in% inj$idx
  ok <- y | previo == 0                                           # previas no cuentan como falso positivo
  met <- data.table::rbindlist(lapply(names(METODOS), function(f)
    data.table::data.table(Metodo = METODOS[[f]],
      t(round(metricas(y[ok], r1[[f]][ok], r1[[SCORES[[f]]]][ok]), 3)))))
  rec <- data.table::rbindlist(lapply(LETTERS[1:5], function(t) {
    i <- inj$idx[inj$tipo == t]
    data.table::as.data.table(c(list(Error = ETIQUETAS_ERROR[[t]]),
      as.list(sapply(names(METODOS), function(f) round(100 * mean(r1[[f]][i]), 1)))))
  }))
  data.table::setnames(rec, names(METODOS), unname(METODOS))
  list(metricas = met, recall_tipo = rec)
}

validar_temporal <- function(base, V, k = 3, frac = 0.01, semilla = SEMILLA) {
  d <- crear_variables(base)
  anios <- sort(unique(base$anio))
  data.table::rbindlist(lapply(anios[-1], function(t) {
    tr <- d[anio < t]
    m  <- ajustar_detectores(matriz(tr, V), k = k)
    zc <- function(x) as.matrix(x[, intersect(V, CONTINUAS), with = FALSE])
    te0 <- d[anio == t]
    r0  <- aplicar_detectores(m, matriz(te0, V), zc(te0))
    bt  <- base[anio == t]
    inj <- inyectar(bt, which(r0$anomalia == 0), frac, semilla + t)
    te1 <- crear_variables(inj$base)
    r1  <- aplicar_detectores(m, matriz(te1, V), zc(te1))
    rm(tr, m); invisible(gc())
    y <- seq_len(nrow(bt)) %in% inj$idx; ok <- y | r0$anomalia == 0
    mv <- metricas(y[ok], r1$anomalia[ok], r1$score_voto[ok])
    mi <- metricas(y[ok], r1$flag_if[ok], r1$score_if[ok])
    message(sprintf("  %d: F1 votación = %.3f · AUC = %.3f", t, mv["F1"], mv["AUC"]))
    data.table::data.table(Anio_prueba = t, Entrenado_con = if (t == anios[2]) as.character(anios[1]) else sprintf("%d-%d", min(anios), max(anios[anios < t])),
      Registros = nrow(bt), Marcados_pct = round(100 * mean(r1$anomalia), 3),
      F1_IF = round(mi["F1"], 3), AUC_IF = round(mi["AUC"], 3),
      Precision_votacion = round(mv["Precision"], 3), Recall_votacion = round(mv["Recall"], 3),
      F1_votacion = round(mv["F1"], 3), AUC_votacion = round(mv["AUC"], 3))
  }))
}

# ---- Gráficos (estilo del informe: grises) ---------------------------------
tema_ena <- function() {
  ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold", hjust = 0),
                   plot.title.position = "plot")
}

guardar_fig <- function(p, nombre, ancho = 7, alto = 3.5) {
  ggplot2::ggsave(file.path(DIR_FIG, paste0(nombre, ".png")), p, width = ancho, height = alto, dpi = 200, bg = "white")
  invisible(p)
}

guardar_tab <- function(x, nombre) {
  data.table::fwrite(data.table::as.data.table(x), file.path(DIR_RES, paste0(nombre, ".csv")))
  invisible(x)
}
