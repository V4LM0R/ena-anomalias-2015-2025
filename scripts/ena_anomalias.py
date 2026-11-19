"""
ena_anomalias.py · Detección de anomalías en la Encuesta Nacional Agropecuaria (ENA) 2014-2025

Funciones por etapa que usa el notebook Deteccion_Anomalias_ENA_2015_2025.ipynb:

  1. Carga e integración   leer_sav, agregar_factor_parcela, leer_2025, integrar  (+ listar_columnas)
  2. Limpieza              limpiar                                               (+ cargar_base)
  3. Variables             crear_variables, z_robusto, desvio_grupo
  4. Modelos               detectar_z, ajustar_dbscan, detectar_dbscan, elegir_k, detectar_kmeans,
                           detectar_iforest, detectar_todo, importancia_variables
  5. Validación            validar_silueta, validar_reglas, validar_inyeccion, validar_temporal

Atajo sin microdatos: limpio = cargar_base('../data/processed/ena_2014_2025_productor.csv.gz')
deja la base consolidada (ya integrada y limpia) lista para las etapas 3 a 5.

Las etapas 3-5 son equivalentes a scripts/R/funciones.R.
"""
from __future__ import annotations

import glob
import io
import os
import re
import zipfile

import numpy as np
import pandas as pd

SEMILLA = 2026
CONTAMINACION = 0.01

# =============================================================================
# Nombres de variables
# =============================================================================
NUMERICAS = ['z_rend', 'z_precio', 'z_area', 'z_sembrada', 'z_cosechado', 'z_venta',
             'z_hogar', 'z_animales', 'z_semilla', 'z_cosechas', 'z_precio_hogar', 'z_meses']
CONTINUAS = ['z_rend', 'z_precio', 'z_area', 'z_sembrada', 'z_precio_hogar']   # entran al z-score
CATEGORICAS = ['tipo_cultivo', 'regimen_tenencia', 'fuente_agua', 'region']
NIVELES = {'tipo_cultivo': [1, 2, 3], 'regimen_tenencia': [1, 2, 3, 4],
           'fuente_agua': [1, 2, 3, 4, 5, 6, 7], 'region': ['Costa', 'Selva', 'Sierra']}
DUMMIES = [f'{c}_{l}' for c in CATEGORICAS for l in NIVELES[c]]

VARS_3 = ['z_rend', 'z_precio', 'z_area']          # modelo base
VARS_16 = NUMERICAS + DUMMIES                       # 12 numéricas + 4 categóricas = 29 columnas

NOMBRES = {
    'z_rend': 'Rendimiento (kg/ha)', 'z_precio': 'Precio de venta por kg', 'z_area': 'Superficie cosechada',
    'z_sembrada': 'Superficie sembrada', 'z_cosechado': '% de lo sembrado que se cosechó',
    'z_venta': '% de la producción vendida', 'z_hogar': '% para consumo del hogar',
    'z_animales': '% para alimento de animales', 'z_semilla': '% guardado como semilla',
    'z_cosechas': 'Número de cosechas', 'z_precio_hogar': 'Precio por kg del autoconsumo',
    'z_meses': 'Meses entre siembra y cosecha',
    'tipo_cultivo': 'Tipo de cultivo', 'regimen_tenencia': 'Conducción (solo o asociado)',
    'fuente_agua': 'Fuente de agua (riego o secano)', 'region': 'Región natural',
}
FLAGS = {'Z-score robusto': 'flag_z', 'Isolation Forest': 'flag_if', 'k-Means': 'flag_km',
         'DBSCAN': 'flag_db', 'Votación (≥2)': 'anomalia'}
SCORES = {'flag_z': 'score_z', 'flag_if': 'score_if', 'flag_km': 'score_km',
          'flag_db': 'score_db', 'anomalia': 'score_voto'}

DEPARTAMENTOS = {
    '01': 'Amazonas', '02': 'Áncash', '03': 'Apurímac', '04': 'Arequipa', '05': 'Ayacucho',
    '06': 'Cajamarca', '07': 'Callao', '08': 'Cusco', '09': 'Huancavelica', '10': 'Huánuco',
    '11': 'Ica', '12': 'Junín', '13': 'La Libertad', '14': 'Lambayeque', '15': 'Lima',
    '16': 'Loreto', '17': 'Madre de Dios', '18': 'Moquegua', '19': 'Pasco', '20': 'Piura',
    '21': 'Puno', '22': 'San Martín', '23': 'Tacna', '24': 'Tumbes', '25': 'Ucayali',
}

# =============================================================================
# Etapas 1-2 · Columnas de los microdatos del INEI
# Las marcadas con "verificar" deben confirmarse con el diccionario de la ENA:
#     listar_columnas('ruta/ENA_2014_2024.sav')   muestra nombre y etiqueta de cada variable.
# Clave: nombre interno -> nombre en el SPSS / CSV del INEI
# =============================================================================
COLUMNAS = {
    'ANIO': 'ANIO',
    'RESFIN': 'RESFIN',                    # resultado final de la encuesta (1 = completa)
    'CCDD': 'CCDD',                        # código de departamento
    'region': 'REGION',                    # región natural (1 costa, 2 sierra, 3 selva)   verificar
    'n_cultivo': 'P203',                   # N° de orden del cultivo (sección 200A)
    'cultivo': 'P204_NOM',                 # nombre del cultivo
    'cod_cultivo': 'P204_COD',             # código del cultivo                            verificar
    'n_cosechas': 'P205',                  # número de cosechas en el año
    'sup_ent': 'P217_SUP_1', 'sup_dec': 'P217_SUP_2', 'sup_ha': 'P217_SUP_ha',
    'cant_ent': 'P219_CANT_1', 'cant_dec': 'P219_CANT_2', 'equiv_kg': 'P219_EQUIV_KG',
    'unidad_medida': 'P219_UM',            # unidad de la cosecha                          verificar
    'sembrada_ha': 'P209_SUP_ha',          # superficie sembrada en ha                     verificar
    'vend_ent': 'P220_1_CANT_1', 'vend_dec': 'P220_1_CANT_2',          # cantidad vendida  verificar
    'precio_unidad': 'P220_1_PRE',         # precio por unidad                             verificar
    'valor_venta': 'P220_1_VAL',           # valor de la venta                             verificar
    'hogar_ent': 'P220_2_CANT_1', 'hogar_dec': 'P220_2_CANT_2',        # autoconsumo       verificar
    'valor_hogar': 'P220_2_VAL',           #                                               verificar
    'semilla_ent': 'P220_3_CANT_1', 'semilla_dec': 'P220_3_CANT_2',    #                   verificar
    'animales_ent': 'P220_4_CANT_1', 'animales_dec': 'P220_4_CANT_2',  #                   verificar
    'siembra_mes': 'P206_MES', 'siembra_anio': 'P206_ANIO',            #                   verificar
    'cosecha_mes': 'P207_MES', 'cosecha_anio': 'P207_ANIO',            #                   verificar
    'tipo_cultivo': 'P212',                #                                               verificar
    'regimen_tenencia': 'P213',            #                                               verificar
    'fuente_agua': 'P214',                 #                                               verificar
    # parcela (para reconstruir hectáreas en 2015 y 2018)
    'parcela_ent': 'P104_SUP_1', 'parcela_dec': 'P104_SUP_2', 'parcela_ha': 'P104_SUP_ha',  # verificar
}
CLAVE_PARCELA = ['ANIO', 'CONGLOMERADO', 'NSELUA', 'UA', 'P101']   # identificador de la parcela   verificar
REGION_COD = {1: 'Costa', 2: 'Sierra', 3: 'Selva'}                 # verificar


def listar_columnas(ruta_sav, patron=r'^(P1|P2)'):
    """Nombre y etiqueta de las variables del SPSS (sin leer los datos)."""
    import pyreadstat
    _, meta = pyreadstat.read_sav(ruta_sav, metadataonly=True, encoding='latin1')
    t = pd.DataFrame({'variable': meta.column_names, 'etiqueta': meta.column_labels})
    return t[t.variable.str.contains(patron, regex=True)].reset_index(drop=True)


def _num(x):
    return pd.to_numeric(x, errors='coerce')


def _entero_decimal(ent, dec):
    """Une entero y decimales escritos como texto: ('0', '069') -> 0,069."""
    e = _num(ent)
    d = pd.Series(dec, copy=False).astype('string').str.strip()
    d = d.where(d.str.fullmatch(r'\d+', na=False))
    frac = _num(d) / np.power(10.0, d.str.len().astype('float'))
    return e + frac.fillna(0)


def _usecols(disponibles):
    pedidas = set(COLUMNAS.values()) | set(CLAVE_PARCELA) | {'FACTOR', 'FACTOR_PRODUCTOR'}
    return [c for c in disponibles if c in pedidas]


# =============================================================================
# Etapa 1 · Carga e integración
# =============================================================================
def leer_sav(ruta, chunksize=250_000):
    """Lee del SPSS 2014-2024 solo las columnas del capítulo 200 y de la parcela, por bloques.
    El archivo declara UTF-8 pero trae bytes inválidos: se lee en latin1."""
    import pyreadstat
    _, meta = pyreadstat.read_sav(ruta, metadataonly=True, encoding='latin1')
    cols = _usecols(meta.column_names)
    partes = []
    for df, _ in pyreadstat.read_file_in_chunks(pyreadstat.read_sav, ruta, chunksize=chunksize,
                                                usecols=cols, encoding='latin1',
                                                apply_value_formats=False):
        nom = COLUMNAS['cultivo']
        par = COLUMNAS['parcela_ent']
        m = df[nom].notna() & (df[nom].astype(str).str.strip() != '') if nom in df else False
        if par in df:
            m = m | df[par].notna()
        partes.append(df[m])
    d = pd.concat(partes, ignore_index=True)
    return agregar_factor_parcela(d)


def agregar_factor_parcela(d):
    """Factor de conversión a hectáreas de cada parcela = ha de la parcela / superficie en su unidad.
    Se pasa a todos los cultivos de la misma parcela (sirve para 2015 y 2018)."""
    clave = [c for c in CLAVE_PARCELA if c in d.columns]
    pe, pd_, ph = (COLUMNAS[k] for k in ('parcela_ent', 'parcela_dec', 'parcela_ha'))
    if not clave or pe not in d.columns or ph not in d.columns:
        d['fac_parcela'] = np.nan
        return d
    sup = _entero_decimal(d[pe], d[pd_]) if pd_ in d.columns else _num(d[pe])
    fac = (_num(d[ph]) / sup).where(sup > 0)
    tabla = d.assign(fac_parcela=fac).dropna(subset=['fac_parcela']).groupby(clave)['fac_parcela'].median()
    return d.drop(columns='fac_parcela', errors='ignore').merge(tabla.rename('fac_parcela').reset_index(),
                                                                on=clave, how='left')


def leer_2025(carpeta, archivo='03_CAP200AB.csv'):
    """ENA 2025: busca el CSV del capítulo 200 dentro de los zip (módulo 1895) y lo lee."""
    for z in sorted(glob.glob(os.path.join(carpeta, '*.zip'))):
        with zipfile.ZipFile(z) as zf:
            nombres = [n for n in zf.namelist() if n.upper().endswith(archivo.upper())]
            if nombres:
                with zf.open(nombres[0]) as f:
                    crudo = f.read()
                for enc in ('utf-8', 'latin1'):
                    try:
                        d = pd.read_csv(io.BytesIO(crudo), encoding=enc, dtype=str, sep=None, engine='python')
                        break
                    except UnicodeDecodeError:
                        continue
                d.columns = [c.strip() for c in d.columns]
                d = d[[c for c in d.columns if c in set(COLUMNAS.values()) | set(CLAVE_PARCELA)]]
                d['ANIO'] = 2025
                d['RESFIN'] = d.get('RESFIN', 1)
                d['fac_parcela'] = np.nan
                return d
    raise FileNotFoundError(f'No se encontró {archivo} en los zip de {carpeta}')


def integrar(d_14_24, d_25):
    """Une las dos fuentes por nombre de columna (las variables se llaman igual)."""
    comunes = [c for c in d_14_24.columns if c in d_25.columns or c == 'fac_parcela']
    return pd.concat([d_14_24, d_25.reindex(columns=comunes)], ignore_index=True)


# =============================================================================
# Etapa 2 · Limpieza
# =============================================================================
RELLENO = 99_999_000


def limpiar(datos, min_registros=30):
    """Filtra, reconstruye cifras y deja una fila por cultivo cosechado.
    Devuelve (limpio, embudo) con el número de registros que queda en cada paso."""
    C = COLUMNAS
    pasos = []

    def paso(nombre, df, nota=''):
        pasos.append({'Paso': nombre, 'Registros': len(df), 'Nota': nota})
        return df

    nom = datos[C['cultivo']].astype('string').str.strip()
    d = datos[nom.notna() & (nom != '') & (nom.str.lower() != 'nan')].copy()
    paso('Filas con nombre de cultivo (todas las secciones)', d)
    d = paso('Registros de cultivos cosechados (sección 200A, con N° de cultivo)', d[d[C['n_cultivo']].notna()])
    d = paso('Solo encuestas completas (RESFIN = 1)', d[_num(d[C['RESFIN']]) == 1])
    d = paso('Sin 2014 (INEI no publicó cantidades ni superficies)', d[_num(d[C['ANIO']]) >= 2015])

    col = lambda k: d[C[k]] if C[k] in d.columns else pd.Series(np.nan, index=d.index)
    o = pd.DataFrame({'ANIO': _num(col('ANIO')).astype(int).values}, index=d.index)
    o['ccdd'] = col('CCDD').astype(str).str.zfill(2)
    o['departamento'] = o.ccdd.map(DEPARTAMENTOS)
    o['region'] = _num(col('region')).map(REGION_COD)
    o['cultivo'] = col('cultivo').astype(str).str.strip().str.upper()
    o['cod_cultivo'] = _num(col('cod_cultivo'))
    o['unidad_medida'] = col('unidad_medida')
    # superficie cosechada en ha: oficial; si falta (2015 y 2018), entero+decimal × factor de la parcela
    sup_local = _entero_decimal(col('sup_ent'), col('sup_dec'))
    o['area_ha'] = _num(col('sup_ha')).fillna(sup_local * _num(d['fac_parcela'] if 'fac_parcela' in d else pd.Series(np.nan, index=d.index)))
    o['sup_reconstruida'] = np.where(_num(col('sup_ha')).isna() & o.area_ha.notna(), 'sí', 'no')
    o['sembrada_ha'] = _num(col('sembrada_ha'))
    o['cant_cosechada'] = _entero_decimal(col('cant_ent'), col('cant_dec'))
    o['equiv_kg'] = _num(col('equiv_kg'))
    o['cant_vendida'] = _entero_decimal(col('vend_ent'), col('vend_dec'))
    o['precio_unidad'] = _num(col('precio_unidad'))
    o['valor_venta'] = _num(col('valor_venta'))
    o['cant_hogar'] = _entero_decimal(col('hogar_ent'), col('hogar_dec'))
    o['valor_hogar'] = _num(col('valor_hogar'))
    o['cant_semilla'] = _entero_decimal(col('semilla_ent'), col('semilla_dec'))
    o['cant_animales'] = _entero_decimal(col('animales_ent'), col('animales_dec'))
    o['n_cosechas'] = _num(col('n_cosechas'))
    ms = (_num(col('cosecha_anio')) - _num(col('siembra_anio'))) * 12 + \
         (_num(col('cosecha_mes')) - _num(col('siembra_mes')))
    o['meses_siembra_cosecha'] = ms.where(ms.between(0, 120))
    for c in ('tipo_cultivo', 'regimen_tenencia', 'fuente_agua'):
        o[c] = _num(col(c))
    o['prod_kg'] = o.cant_cosechada * o.equiv_kg

    o = paso('Con superficie, cantidad y equivalencia en kg', o.dropna(subset=['area_ha', 'cant_cosechada', 'equiv_kg']))
    n0 = len(o)
    relleno = (o[['area_ha', 'cant_cosechada', 'equiv_kg', 'cant_vendida', 'valor_venta']] >= RELLENO).any(axis=1)
    o = o[~relleno]
    paso('Sin códigos de relleno (99 999 999 y similares)', o, f'{n0 - len(o)} eliminados')
    o = paso('Superficie y producción mayores que cero', o[(o.area_ha > 0) & (o.prod_kg > 0)])
    o = paso('Sin registros duplicados (mismo productor, parcela, cultivo y valores)', o.drop_duplicates())
    n = o.groupby(['ANIO', 'cultivo']).cultivo.transform('size')
    o = paso('Cultivos con 30 registros o más en el año', o[n >= min_registros])
    o['rend_kg_ha'] = o.prod_kg / o.area_ha
    o['precio_kg'] = o.valor_venta / (o.cant_vendida * o.equiv_kg)
    return o.reset_index(drop=True), pd.DataFrame(pasos)


def cargar_base(ruta='../data/processed/ena_2014_2025_productor.csv.gz', desde=2015):
    """Atajo: carga la base consolidada (ya integrada y limpia) con los nombres internos.
    Quita las marcas de anomalía que trae la base para volver a calcularlas."""
    d = pd.read_csv(ruta, dtype={'ccdd': str}, low_memory=False)
    d = d[d.anio >= desde].rename(columns={'anio': 'ANIO', 'region_natural': 'region',
                                           'sup_cosechada_ha': 'area_ha', 'sup_sembrada_ha': 'sembrada_ha'})
    d = d.drop(columns=['flag_z', 'flag_if', 'flag_km', 'flag_db', 'votos', 'anomalia'], errors='ignore')
    d['departamento'] = d.departamento.fillna('Sin dato')
    return d.reset_index(drop=True)


# =============================================================================
# Etapa 3 · Variables
# =============================================================================
def _pos(x):
    x = pd.to_numeric(x, errors='coerce')
    return x.where(x > 0)


def z_robusto(x, g, g_amplio=None, min_n=30, piso=0.05):
    """z robusto del log: (log x - mediana) / (1,4826·MAD) dentro del grupo.
    Si el grupo tiene menos de min_n valores válidos se usa el grupo amplio (cultivo × año).
    La MAD tiene un piso (escala log) para que grupos casi constantes no den z enormes.
    Faltante -> 0 (neutral)."""
    lx = np.log(_pos(x))

    def est(gr):
        gb = lx.groupby(gr)
        med = gb.transform('median')
        mad = (lx - med).abs().groupby(gr).transform('median') * 1.4826
        return gb.transform('count'), med, mad

    n, med, mad = est(g)
    if g_amplio is not None:
        n2, med2, mad2 = est(g_amplio)
        usar = n < min_n
        med, mad = med.where(~usar, med2), mad.where(~usar, mad2)
    z = (lx - med) / np.maximum(mad, piso)
    return z.replace([np.inf, -np.inf], np.nan).fillna(0.0)


def desvio_grupo(x, g):
    """(x - mediana del grupo) / desviación estándar global. Faltante -> 0."""
    x = pd.to_numeric(x, errors='coerce').replace([np.inf, -np.inf], np.nan)
    z = (x - x.groupby(g).transform('median')) / x.std()
    return z.replace([np.inf, -np.inf], np.nan).fillna(0.0)


def crear_variables(limpio):
    """12 variables numéricas comparadas con su cultivo, año y región natural + 4 categóricas en 0/1."""
    d = limpio.copy()
    d['prod_kg'] = d.cant_cosechada * d.equiv_kg
    d['rend_kg_ha'] = d.prod_kg / d.area_ha
    d['precio_kg'] = d.valor_venta / (d.cant_vendida * d.equiv_kg)
    precio_hogar = d.valor_hogar / (d.cant_hogar * d.equiv_kg)
    amplio = d.ANIO.astype(str) + '|' + d.cultivo.astype(str)
    fino = amplio + '|' + d.region.astype(str)
    n = fino.map(fino.value_counts())
    grupo = fino.where(n >= 30, amplio)
    cc = d.cant_cosechada
    q = lambda c: d[c].fillna(0)
    d['z_rend'] = z_robusto(d.rend_kg_ha, grupo, amplio)
    d['z_precio'] = z_robusto(d.precio_kg, grupo, amplio)
    d['z_area'] = z_robusto(d.area_ha, grupo, amplio)
    d['z_sembrada'] = z_robusto(d.sembrada_ha, grupo, amplio)
    d['z_cosechado'] = desvio_grupo(d.area_ha / _pos(d.sembrada_ha), grupo)
    d['z_venta'] = desvio_grupo(q('cant_vendida') / cc, grupo)
    d['z_hogar'] = desvio_grupo(q('cant_hogar') / cc, grupo)
    d['z_animales'] = desvio_grupo(q('cant_animales') / cc, grupo)
    d['z_semilla'] = desvio_grupo(q('cant_semilla') / cc, grupo)
    d['z_cosechas'] = desvio_grupo(np.log(_pos(d.n_cosechas)), grupo)
    d['z_precio_hogar'] = z_robusto(precio_hogar, grupo, amplio)
    d['z_meses'] = desvio_grupo(d.meses_siembra_cosecha, grupo)
    for c in CATEGORICAS:
        for l in NIVELES[c]:
            d[f'{c}_{l}'] = (d[c] == l).astype(float)
    return d


# =============================================================================
# Etapa 4 · Modelos
# =============================================================================
def _matriz(d, V):
    return d[V].to_numpy(dtype=np.float64)


def detectar_z(d, V, umbral=3.5):
    """Anómalo si alguna variable continua del modelo supera |z| = 3,5 (Iglewicz y Hoaglin)."""
    cont = [c for c in V if c in CONTINUAS]
    s = d[cont].abs().max(axis=1).to_numpy() if cont else np.zeros(len(d))
    return (s > umbral).astype(int), s


def detectar_iforest(X, contaminacion=CONTAMINACION, arboles=200, semilla=SEMILLA, X_nuevo=None):
    """Isolation Forest (200 árboles); anómalo si está en el 1 % que se aísla con menos cortes."""
    from sklearn.ensemble import IsolationForest
    m = IsolationForest(n_estimators=arboles, max_samples=256, random_state=semilla, n_jobs=-1).fit(X)
    umbral = np.quantile(-m.score_samples(X), 1 - contaminacion)
    s = -m.score_samples(X if X_nuevo is None else X_nuevo)
    return (s > umbral).astype(int), s, (m, umbral)


def elegir_k(d, V, ks=range(2, 9), n=10_000, semilla=SEMILLA):
    """Silueta media de k-Means para cada k en una muestra."""
    from sklearn.cluster import KMeans
    from sklearn.metrics import silhouette_score
    X = _matriz(d.sample(min(n, len(d)), random_state=semilla), V)
    return {k: float(silhouette_score(X, KMeans(k, n_init=3, random_state=semilla).fit_predict(X)))
            for k in ks}


def detectar_kmeans(X, k=3, contaminacion=CONTAMINACION, semilla=SEMILLA, X_nuevo=None):
    """k-Means; anómalo si está en el 1 % más lejano del centro de su grupo."""
    from sklearn.cluster import KMeans
    m = KMeans(k, n_init=3, random_state=semilla).fit(X)
    umbral = np.quantile(m.transform(X).min(axis=1), 1 - contaminacion)
    Dn = m.transform(X if X_nuevo is None else X_nuevo)
    s = Dn.min(axis=1)
    return (s > umbral).astype(int), s, Dn.argmin(axis=1), (m, umbral)


def ajustar_dbscan(X, n=40_000, min_pts=20, pct_eps=98, semilla=SEMILLA):
    """DBSCAN en una muestra: eps = percentil 98 de la curva k-distancia; devuelve eps y los puntos núcleo."""
    from sklearn.neighbors import NearestNeighbors
    rng = np.random.default_rng(semilla)
    S = X[rng.choice(len(X), min(n, len(X)), replace=False)]
    dist, _ = NearestNeighbors(n_neighbors=min_pts + 1).fit(S).kneighbors(S)   # columna 0 = el mismo punto
    eps = float(np.percentile(dist[:, min_pts], pct_eps))
    nucleo = dist[:, min_pts - 1] <= eps          # minPts vecinos (incluido él mismo) a distancia <= eps
    return eps, np.unique(S[nucleo], axis=0)


def detectar_dbscan(X, eps, nucleos, lote=200_000):
    """Anómalo (ruido) si su punto núcleo más cercano está a más de eps."""
    from sklearn.neighbors import NearestNeighbors
    nn = NearestNeighbors(n_neighbors=1).fit(nucleos)
    s = np.concatenate([nn.kneighbors(X[i:i + lote])[0][:, 0] for i in range(0, len(X), lote)])
    return (s > eps).astype(int), s


def _votar(r):
    r['votos'] = r.flag_z + r.flag_if + r.flag_km + r.flag_db
    r['anomalia'] = (r.votos >= 2).astype(int)
    rk = sum(pd.Series(r[c]).rank().to_numpy() for c in ('score_z', 'score_if', 'score_km', 'score_db'))
    r['score_voto'] = r.votos + rk / (4 * (len(r) + 1))      # votos + desempate por rangos
    return r


def detectar_todo(d, V, k=3, copiar=True, semilla=SEMILLA):
    """Los cuatro detectores y la votación (anomalía si la marcan 2 o más)."""
    d = d.copy() if copiar else d
    X = _matriz(d, V)
    r = pd.DataFrame(index=d.index)
    r['flag_z'], r['score_z'] = detectar_z(d, V)
    r['flag_if'], r['score_if'], _ = detectar_iforest(X, semilla=semilla)
    r['flag_km'], r['score_km'], r['cluster_km'], _ = detectar_kmeans(X, k, semilla=semilla)
    eps, nuc = ajustar_dbscan(X, semilla=semilla)
    r['flag_db'], r['score_db'] = detectar_dbscan(X, eps, nuc)
    r = _votar(r)
    for c in r.columns:
        d[c] = r[c].to_numpy()
    return d


def importancia_variables(d, V):
    """|z| medio de los anómalos frente a los normales en cada variable numérica."""
    a = d.anomalia == 1
    filas = []
    for v in [c for c in V if c in NUMERICAS]:
        z = d[v].abs()
        filas.append({'Variable': NOMBRES[v], '|z| medio anómalos': z[a].mean(), '|z| medio normales': z[~a].mean(),
                      '% anómalos con |z|>3,5': 100 * (z[a] > 3.5).mean()})
    t = pd.DataFrame(filas)
    t['Razón'] = t['|z| medio anómalos'] / t['|z| medio normales']
    return t.sort_values('Razón', ascending=False)


# =============================================================================
# Etapa 5 · Validación
# =============================================================================
def validar_silueta(d, V, k=3, n=20_000, semilla=SEMILLA):
    """Silueta de los grupos de k-Means y de cada partición normal / anómalo (muestra de n registros)."""
    from sklearn.metrics import silhouette_score
    m = d.sample(min(n, len(d)), random_state=semilla)
    X = _matriz(m, V)
    s = lambda lab: float(silhouette_score(X, lab)) if len(set(lab)) > 1 else np.nan
    out = {f'k-Means (k={k})': s(m.cluster_km.to_numpy())}
    out.update({f'Normal vs anómalo: {nom}': s(m[f].to_numpy()) for nom, f in FLAGS.items()})
    return out


def validar_reglas(d, tolerancia=0.10):
    """R1 vendió más de lo que cosechó · R2 cosechó más superficie de la que sembró ·
    R3 valor de venta distinto de cantidad × precio unitario (más de 10 %).
    Devuelve (tabla por método, reglas como columnas booleanas)."""
    reglas = pd.DataFrame({
        'R1 vendió > cosechó': d.cant_vendida.fillna(0) > d.cant_cosechada,
        'R2 cosechó > sembró': d.area_ha > _pos(d.sembrada_ha),
        'R3 valor ≠ cantidad × precio': (d.valor_venta - d.cant_vendida * d.precio_unidad).abs()
                                        > tolerancia * d.valor_venta,
    }).fillna(False)
    filas = []
    for regla in reglas:
        caso = reglas[regla].to_numpy()
        if caso.sum() == 0:
            continue
        for nom, f in FLAGS.items():
            det, resto = 100 * d[f].to_numpy()[caso].mean(), 100 * d[f].to_numpy()[~caso].mean()
            filas.append({'Regla': regla, 'Casos': int(caso.sum()), 'Método': nom, 'Detectadas (%)': det,
                          'Marcadas en el resto (%)': resto, 'Lift': det / resto})
    return pd.DataFrame(filas), reglas


ETIQUETAS_ERROR = {'A': 'A) producción × 10', 'B': 'B) kg ↔ t', 'C': 'C) valor × 10',
                   'D': 'D) sembrada × 10', 'E': 'E) cosechas × 10'}


def inyectar(limpio, candidatos, frac=0.01, semilla=SEMILLA):
    """Errores típicos de digitación en el 1 % de los registros normales, repartidos por igual entre
    5 tipos. C solo en quienes venden y D solo donde la superficie sembrada es mayor que 0."""
    rng = np.random.default_rng(semilla)
    b = limpio.copy()
    candidatos = np.asarray(candidatos)
    n_tipo = int(np.ceil(frac * len(candidatos) / 5))
    elegibles = {'A': candidatos, 'B': candidatos, 'E': candidatos,
                 'C': candidatos[b.valor_venta.fillna(0).to_numpy()[candidatos] > 0],
                 'D': candidatos[b.sembrada_ha.fillna(0).to_numpy()[candidatos] > 0]}
    usados, idx, tipo = set(), [], []
    for t in ['C', 'D', 'A', 'B', 'E']:
        pool = np.array([i for i in elegibles[t] if i not in usados])
        sel = rng.choice(pool, min(n_tipo, len(pool)), replace=False)
        usados.update(sel.tolist()); idx += sel.tolist(); tipo += [t] * len(sel)
    idx, tipo = np.array(idx), np.array(tipo)
    col = b.columns.get_loc
    b.iloc[idx[tipo == 'A'], col('cant_cosechada')] *= 10
    iB = idx[tipo == 'B']
    b.iloc[iB, col('equiv_kg')] *= rng.choice([1000, 1 / 1000], len(iB))
    b.iloc[idx[tipo == 'C'], col('valor_venta')] *= 10
    b.iloc[idx[tipo == 'D'], col('sembrada_ha')] *= 10
    b.iloc[idx[tipo == 'E'], col('n_cosechas')] *= 10
    return b, idx, tipo


def _auc(y, s):
    from sklearn.metrics import roc_auc_score
    return roc_auc_score(y, s) if 0 < y.sum() < len(y) else np.nan


def _metricas(y, f, s):
    y, f = y.astype(bool), f.astype(bool)
    tp, fp, fn = (f & y).sum(), (f & ~y).sum(), (~f & y).sum()
    p = tp / (tp + fp) if tp + fp else 0.0
    r = tp / (tp + fn) if tp + fn else 0.0
    return {'Precisión': p, 'Recall': r, 'F1': 2 * p * r / (p + r) if p + r else 0.0, 'AUC': _auc(y, s)}


def validar_inyeccion(limpio, V, k=3, frac=0.01, semilla=SEMILLA, previo=None):
    """Inyecta errores conocidos y mide precisión, recall, F1 y AUC de cada método.
    Los registros que ya eran anómalos en los datos reales no cuentan como falsos positivos.
    Devuelve (métricas por método, recall % por tipo de error)."""
    limpio = limpio.reset_index(drop=True)
    if previo is None:
        previo = detectar_todo(crear_variables(limpio), V, k).anomalia.to_numpy()
    b, idx, tipo = inyectar(limpio, np.flatnonzero(np.asarray(previo) == 0), frac, semilla)
    r = detectar_todo(crear_variables(b), V, k)
    y = np.zeros(len(b), bool); y[idx] = True
    ok = y | (np.asarray(previo) == 0)
    met = pd.DataFrame({nom: _metricas(y[ok], r[f].to_numpy()[ok], r[SCORES[f]].to_numpy()[ok])
                        for nom, f in FLAGS.items()}).T
    met.index.name = 'Método'
    rec = pd.DataFrame({nom: {t: 100 * r[f].to_numpy()[idx[tipo == t]].mean() for t in 'ABCDE'}
                        for nom, f in FLAGS.items()})
    return met, rec


def validar_temporal(limpio, V, k=3, frac=0.01, semilla=SEMILLA):
    """Entrena con los años anteriores y prueba en el siguiente (2016, 2017, …, 2025),
    con los cinco tipos de error inyectados en el año de prueba."""
    from sklearn.cluster import KMeans
    from sklearn.ensemble import IsolationForest
    limpio = limpio.reset_index(drop=True)
    d = crear_variables(limpio)
    anios = sorted(d.ANIO.unique())
    filas = []
    for t in anios[1:]:
        tr = d[d.ANIO < t]
        Xtr = _matriz(tr, V)
        iso = IsolationForest(n_estimators=200, max_samples=256, random_state=semilla, n_jobs=-1).fit(Xtr)
        u_if = np.quantile(-iso.score_samples(Xtr), 1 - CONTAMINACION)
        km = KMeans(k, n_init=3, random_state=semilla).fit(Xtr)
        u_km = np.quantile(km.transform(Xtr).min(axis=1), 1 - CONTAMINACION)
        eps, nuc = ajustar_dbscan(Xtr, semilla=semilla)

        def aplicar(dd):
            X = _matriz(dd, V)
            r = pd.DataFrame(index=dd.index)
            r['flag_z'], r['score_z'] = detectar_z(dd, V)
            r['score_if'] = -iso.score_samples(X); r['flag_if'] = (r.score_if > u_if).astype(int)
            r['score_km'] = km.transform(X).min(axis=1); r['flag_km'] = (r.score_km > u_km).astype(int)
            r['flag_db'], r['score_db'] = detectar_dbscan(X, eps, nuc)
            return _votar(r)

        r0 = aplicar(d[d.ANIO == t])
        bt = limpio[limpio.ANIO == t].reset_index(drop=True)
        b, idx, tipo = inyectar(bt, np.flatnonzero(r0.anomalia.to_numpy() == 0), frac, semilla + int(t))
        r1 = aplicar(crear_variables(b))
        y = np.zeros(len(bt), bool); y[idx] = True
        ok = y | (r0.anomalia.to_numpy() == 0)
        mi = _metricas(y[ok], r1.flag_if.to_numpy()[ok], r1.score_if.to_numpy()[ok])
        mv = _metricas(y[ok], r1.anomalia.to_numpy()[ok], r1.score_voto.to_numpy()[ok])
        filas.append({'Año de prueba': int(t),
                      'Entrenado con': str(anios[0]) if t == anios[1] else f'{anios[0]}-{max(a for a in anios if a < t)}',
                      'Registros': len(bt), 'Marcados (%)': 100 * r1.anomalia.mean(),
                      'Precisión IF': mi['Precisión'], 'Recall IF': mi['Recall'], 'F1 IF': mi['F1'], 'AUC IF': mi['AUC'],
                      'Precisión Votación': mv['Precisión'], 'Recall Votación': mv['Recall'],
                      'F1 Votación': mv['F1'], 'AUC Votación': mv['AUC']})
        print(f"  {t}: F1 votación = {mv['F1']:.3f} · AUC = {mv['AUC']:.3f}", flush=True)
    return pd.DataFrame(filas)
