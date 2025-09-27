-- Tabla optimizada 
CREATE OR REPLACE TABLE `MyDataSet.NRegistro`
PARTITION BY RANGE_BUCKET(data_file_month, GENERATE_ARRAY(1,12))
CLUSTER BY pickup_location_id, dropoff_location_id AS
SELECT * FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` 
LIMIT 1000000;


-- Tabla con JOINS con zonas de recogida y entrega
CREATE OR REPLACE TABLE
MyDataSet.joins AS
SELECT
  t.vendor_id,
  t.pickup_datetime,
  t.dropoff_datetime,
  t.passenger_count,
  t.trip_distance,
  t.payment_type,
  t.total_amount,
  p.zone_name AS pickup_zone,
  p.borough AS pickup_borough,
  d.zone_name AS dropoff_zone,
  d.borough AS dropoff_borough
FROM
  `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` t
LEFT JOIN
  `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom` p
  ON CAST(t.pickup_location_id AS INT64) = CAST(p.zone_id AS INT64)
LEFT JOIN
  `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom` d
  ON CAST(t.dropoff_location_id AS INT64) = CAST(d.zone_id AS INT64)
LIMIT 1000000;

-- Tabla con particion y clustering
CREATE OR REPLACE TABLE `MyDataSet.taxi_optimized`
PARTITION BY DATE(pickup_datetime)
CLUSTER BY pickup_location_id, dropoff_location_id
AS
SELECT 
  pickup_datetime,
  dropoff_datetime,
  pickup_location_id,
  dropoff_location_id,
  passenger_count,
  trip_distance,
  fare_amount,
  tip_amount,
  total_amount,
  payment_type,
  
  DATE(pickup_datetime) as pickup_date,
  EXTRACT(MONTH FROM pickup_datetime) as pickup_month,
  EXTRACT(HOUR FROM pickup_datetime) as pickup_hour,
  EXTRACT(DAYOFWEEK FROM pickup_datetime) as pickup_dayofweek

FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE 
  pickup_datetime IS NOT NULL
  AND dropoff_datetime IS NOT NULL
  AND trip_distance > 0
  AND fare_amount > 0
  AND total_amount > 0
LIMIT 1000000;

-- Consultas 

-- Consulta 1: Análisis por barrio de recogida
SELECT 
  pickup_borough as borough,
  COUNT(*) as total_viajes,                                    
  ROUND(AVG(total_amount), 2) as ticket_promedio,             
  ROUND(SUM(total_amount), 0) as ingresos_totales,            
  COUNT(DISTINCT pickup_zone) as zonas_activas,               
  ROUND(AVG(trip_distance), 2) as distancia_promedio,         
  ROUND(AVG(passenger_count), 1) as ocupacion_promedio,       
FROM `MyDataSet.joins`
WHERE pickup_borough IS NOT NULL 
  AND total_amount > 0
  AND trip_distance > 0
GROUP BY pickup_borough;

-- Consulta 2: Análisis por hora del día
SELECT
  pickup_hour,
  COUNT(*) AS viajes,
  SUM(total_amount) AS ingresos,
  AVG(total_amount) AS ticket_prom
FROM `MyDataSet.taxi_optimized`
GROUP BY pickup_hour
ORDER BY pickup_hour;

-- Consulta 3: Identificacion de valores nulos 
SELECT 
  COUNT(*) as total_registros,
  COUNT(pickup_datetime) as pickup_datetime_validos,
  COUNT(dropoff_datetime) as dropoff_datetime_validos,
  COUNT(trip_distance) as trip_distance_validos,
  COUNT(fare_amount) as fare_amount_validos,
  COUNT(total_amount) as total_amount_validos,
  COUNT(passenger_count) as passenger_count_validos,
  COUNT(payment_type) as payment_type_validos,
  COUNT(pickup_location_id) as pickup_location_validos,
  COUNT(dropoff_location_id) as dropoff_location_validos
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- Consulta 4: Análisis por tipo de pago
SELECT 
  payment_type,
  COUNT(*) as cantidad_viajes,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `MyDataSet.NRegistro`), 2) as porcentaje
FROM `MyDataSet.NRegistro`
GROUP BY payment_type
ORDER BY cantidad_viajes DESC;

-- Consulta 5: Metricas por número de pasajeros
SELECT 
  passenger_count,
  COUNT(*) as total_viajes,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as porcentaje,
  ROUND(AVG(trip_distance), 2) as distancia_promedio,
  ROUND(AVG(fare_amount), 2) as tarifa_promedio,
  ROUND(AVG(total_amount), 2) as total_promedio,
  ROUND(AVG(TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, MINUTE)), 1) as duracion_promedio_min
FROM `MyDataSet.NRegistro`
WHERE 
  pickup_datetime IS NOT NULL
  AND dropoff_datetime IS NOT NULL
  AND passenger_count IS NOT NULL
  AND passenger_count > 0
  AND passenger_count <= 6  
  AND trip_distance > 0
  AND fare_amount > 0
GROUP BY passenger_count
ORDER BY passenger_count;

-- Consulta 6: Metricas descriptivas
SELECT 
  -- Estadísticas de distancia
  ROUND(AVG(trip_distance), 2) as distancia_promedio_millas,
  ROUND(MIN(trip_distance), 2) as distancia_minima,
  ROUND(MAX(trip_distance), 2) as distancia_maxima,
  ROUND(STDDEV(trip_distance), 2) as distancia_desv_std,
  
  -- Estadísticas de tarifa
  ROUND(AVG(fare_amount), 2) as tarifa_promedio,
  ROUND(MIN(fare_amount), 2) as tarifa_minima,
  ROUND(MAX(fare_amount), 2) as tarifa_maxima,
  
  -- Estadísticas de total pagado
  ROUND(AVG(total_amount), 2) as total_promedio,
  ROUND(MIN(total_amount), 2) as total_minimo,
  ROUND(MAX(total_amount), 2) as total_maximo,
  
  -- Estadísticas de propina
  ROUND(AVG(tip_amount), 2) as propina_promedio,
  
  -- Estadísticas de pasajeros
  ROUND(AVG(passenger_count), 1) as pasajeros_promedio,
  MIN(passenger_count) as pasajeros_minimo,
  MAX(passenger_count) as pasajeros_maximo
FROM `MyDataSet.NRegistro`
WHERE 
  trip_distance > 0 
  AND fare_amount > 0 
  AND total_amount > 0;

-- Consulta 7: Top 10 zonas de recogida por distancia promedio
SELECT
  pickup_zone AS zona_recogida,
  pickup_borough AS distrito_recogida,
  ROUND(AVG(trip_distance), 2) AS distancia_promedio_millas,
  ROUND(AVG(passenger_count), 1) AS ocupacion_promedio,
  SUM(total_amount) AS ingresos_totales,
  COUNT(*) AS total_viajes
FROM
  MyDataSet.joins
GROUP BY
  pickup_zone, pickup_borough
ORDER BY
  distancia_promedio_millas DESC
LIMIT 10;

-- Consulta 8: Top 15 rutas más rentables por ingresos
SELECT
  pickup_location_id, dropoff_location_id,
  COUNT(*) AS viajes,
  SUM(total_amount) AS ingresos,
  AVG(total_amount) AS ticket_prom,
  SAFE_DIVIDE(SUM(total_amount), SUM(trip_distance)) AS ingreso_por_milla
FROM `MyDataSet.taxi_optimized`
GROUP BY pickup_location_id, dropoff_location_id
ORDER BY ingresos DESC
LIMIT 15;


-- Consulta 9: Top zonas de recogida por número de viajes
SELECT 
  pickup_zone,
  pickup_borough,
  COUNT(*) as total_pickups,
  ROUND(AVG(trip_distance), 2) as distancia_promedio,
  ROUND(AVG(total_amount), 2) as tarifa_promedio
FROM `MyDataSet.joins`
WHERE pickup_zone IS NOT NULL
GROUP BY pickup_zone, pickup_borough
ORDER BY total_pickups DESC
LIMIT 1000;

-- Consulta 10: Top rutas entre zonas de recogida y entrega
SELECT 
  pickup_zone as zona_origen,
  dropoff_zone as zona_destino,
  CONCAT(pickup_borough, ' → ', dropoff_borough) as ruta_borough,
  COUNT(*) as total_viajes,
  ROUND(AVG(trip_distance), 2) as distancia_promedio,
  ROUND(AVG(total_amount), 2) as costo_promedio
FROM `MyDataSet.joins`
WHERE pickup_zone IS NOT NULL 
  AND dropoff_zone IS NOT NULL
  AND pickup_zone != dropoff_zone
GROUP BY pickup_zone, dropoff_zone, pickup_borough, dropoff_borough
ORDER BY total_viajes DESC
LIMIT 1000;

-- Consulta 11: Análisis detallado de las zonas de recogida más importantes
SELECT 
  pickup_zone as zona_top,
  pickup_borough as distrito,
  COUNT(*) as viajes_zona,
  ROUND(SUM(total_amount), 0) as ingresos_zona_usd,
  ROUND(AVG(total_amount), 2) as ticket_promedio_zona,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `MyDataSet.joins` WHERE pickup_zone IS NOT NULL), 2) as market_share_zona,
  ROUND(AVG(trip_distance), 2) as distancia_promedio_millas,
  ROUND(AVG(passenger_count), 1) as ocupacion_promedio_zona,
  ROUND(SUM(total_amount) / SUM(trip_distance), 2) as revenue_por_milla,
  COUNT(CASE WHEN payment_type = '1' THEN 1 END) as pagos_tarjeta,
  ROUND(COUNT(CASE WHEN payment_type = '1' THEN 1 END) * 100.0 / COUNT(*), 1) as porcentaje_pagos_electronicos
FROM `MyDataSet.joins`
WHERE pickup_zone IS NOT NULL 
  AND total_amount > 0
  AND trip_distance > 0
GROUP BY pickup_zone, pickup_borough
ORDER BY viajes_zona DESC
LIMIT 15

-- Consulta 12: Análisis mensual de viajes y tarifas
SELECT 
  pickup_month as mes,
  COUNT(*) as total_viajes,
  ROUND(AVG(fare_amount), 2) as tarifa_promedio,
  ROUND(SUM(total_amount), 0) as ingresos_totales
FROM `MyDataSet.taxi_optimized`
GROUP BY pickup_month
ORDER BY pickup_month;
