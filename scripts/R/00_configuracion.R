# =============================================================================
# 00_configuracion.R · Paquetes, rutas y parámetros
# Abrir el proyecto "ena-anomalias-2015-2025.Rproj" en RStudio: el directorio
# de trabajo queda en la raíz del repositorio y las rutas de abajo funcionan.
# =============================================================================

paquetes <- c("data.table", "ggplot2", "isotree", "dbscan", "cluster", "readxl")
faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) install.packages(faltan)

library(data.table)
library(ggplot2)

# ---- Rutas ----
RUTA_BASE <- "data/processed/ena_2014_2025_productor.csv.gz"
DIR_FIG   <- "figuras/R"
DIR_RES   <- "resultados/R"
dir.create(DIR_FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_RES, recursive = TRUE, showWarnings = FALSE)

# ---- Parámetros ----
SEMILLA <- 2026
K_INFORME <- 3L   # número de grupos de k-Means usado en el informe
NUCLEOS <- max(1L, parallel::detectCores() - 1L)
setDTthreads(NUCLEOS)

source("scripts/R/funciones.R", encoding = "UTF-8")
message("Configuración lista · ", NUCLEOS, " núcleos")
