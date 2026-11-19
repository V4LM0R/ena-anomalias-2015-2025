-- Inserta el contenido de un archivo en un bloque de código:  ```{.r include="scripts/R/funciones.R"}
function CodeBlock(el)
  local ruta = el.attributes["include"]
  if ruta then
    local f = io.open(ruta, "r")
    if f then
      el.text = f:read("a"):gsub("%s+$", "")
      f:close()
    else
      el.text = "# No se encontró " .. ruta
    end
    el.attributes["include"] = nil
    return el
  end
end
