"""Convierte el Excel por año (ENA_2014_2025_cultivos.xlsx, una hoja por año)
en la base consolidada data/processed/ena_2014_2025_productor.csv.gz.

Uso:  python scripts/exportar_base.py ruta/ENA_2014_2025_cultivos.xlsx
"""
import sys, hashlib
import pandas as pd
from python_calamine import CalamineWorkbook

NOMBRES = {
    'Año': 'anio', 'Código departamento': 'ccdd', 'Departamento': 'departamento',
    'Región natural': 'region_natural', 'Cultivo': 'cultivo', 'Código cultivo': 'cod_cultivo',
    'Unidad de medida': 'unidad_medida', 'Superficie cosechada (ha)': 'sup_cosechada_ha',
    'Superficie reconstruida (sí/no)': 'sup_reconstruida', 'Superficie sembrada (ha)': 'sup_sembrada_ha',
    'Cantidad cosechada (en su unidad)': 'cant_cosechada', 'Equivalencia de la unidad en kg': 'equiv_kg',
    'Producción (kg)': 'prod_kg', 'Rendimiento (kg/ha)': 'rend_kg_ha',
    'Cantidad vendida (en su unidad)': 'cant_vendida', 'Precio por unidad (S/)': 'precio_unidad',
    'Valor de la venta (S/)': 'valor_venta', 'Precio por kg (S/)': 'precio_kg',
    'Consumo del hogar (en su unidad)': 'cant_hogar', 'Valor del consumo del hogar (S/)': 'valor_hogar',
    'Guardado como semilla (en su unidad)': 'cant_semilla', 'Alimento para animales (en su unidad)': 'cant_animales',
    'Número de cosechas': 'n_cosechas', 'Meses de siembra a cosecha': 'meses_siembra_cosecha',
    'Tipo de cultivo (código INEI)': 'tipo_cultivo', 'Régimen de tenencia (código INEI)': 'regimen_tenencia',
    'Fuente de agua (código INEI)': 'fuente_agua', 'Marca Z-score': 'flag_z',
    'Marca Isolation Forest': 'flag_if', 'Marca k-Means': 'flag_km', 'Marca DBSCAN': 'flag_db',
    'Votos (0 a 4)': 'votos', 'Anomalía (1 = sí)': 'anomalia',
}
ENTEROS = ['anio', 'cod_cultivo', 'n_cosechas', 'meses_siembra_cosecha', 'tipo_cultivo',
           'regimen_tenencia', 'fuente_agua', 'flag_z', 'flag_if', 'flag_km', 'flag_db', 'votos', 'anomalia']


def exportar(xlsx, salida='data/processed/ena_2014_2025_productor.csv.gz'):
    wb = CalamineWorkbook.from_path(xlsx)
    partes = []
    for hoja in wb.sheet_names:
        if not hoja.isdigit():          # se saltan 'Léeme' y 'Resumen'
            continue
        filas = wb.get_sheet_by_name(hoja).to_python()
        partes.append(pd.DataFrame(filas[1:], columns=filas[0]).replace('', pd.NA).rename(columns=NOMBRES))
        print(f'{hoja}: {len(filas) - 1:,} registros')
    d = pd.concat(partes, ignore_index=True)[list(NOMBRES.values())]
    for c in ENTEROS:
        d[c] = pd.to_numeric(d[c]).astype('Int64')
    d['ccdd'] = d['ccdd'].astype('string').str.zfill(2)
    d.to_csv(salida, index=False, encoding='utf-8', compression={'method': 'gzip', 'mtime': 0})
    sha = hashlib.sha256(open(salida, 'rb').read()).hexdigest()
    print(f'{salida}: {len(d):,} filas × {d.shape[1]} columnas · SHA-256 {sha}')


if __name__ == '__main__':
    exportar(sys.argv[1])
