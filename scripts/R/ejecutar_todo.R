# =============================================================================
# ejecutar_todo.R · Corre el análisis completo en R (etapas 3-5)
# En RStudio: abrir ena-anomalias-2015-2025.Rproj y pulsar "Source" en este archivo.
# Salidas: figuras/R/*.png y resultados/R/*.csv
# =============================================================================
t_inicio <- Sys.time()
for (s in c("00_configuracion.R", "01_cargar_datos.R", "02_variables.R",
            "03_modelos.R", "04_resultados.R", "05_validacion.R")) {
  message("\n==== ", s, " ====")
  source(file.path("scripts/R", s), encoding = "UTF-8", echo = FALSE)
}
message("\nListo en ", round(difftime(Sys.time(), t_inicio, units = "mins"), 1), " min")
writeLines(capture.output(sessionInfo()), file.path(DIR_RES, "sessionInfo.txt"))
