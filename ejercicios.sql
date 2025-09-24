/* EJ1 */
SELECT clie_codigo, clie_razon_social FROM Cliente
WHERE clie_limite_credito >= 1000
ORDER BY clie_codigo 

/* EJ2 */
SELECT prod_codigo, prod_detalle, SUM(item_cantidad)
FROM Producto join Item_Factura ON prod_codigo = item_producto join Factura ON fact_tipo+fact_sucursal+fact_numero = 
item_tipo+item_sucursal+item_numero  
WHERE year(fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle

/* EJ3 */
SELECT prod_codigo, prod_detalle, sum(ISNULL(stoc_cantidad,0))
FROM Producto left join STOCK on prod_codigo = stoc_producto
GROUP BY prod_codigo, prod_detalle
ORDER BY prod_detalle

/* EJ4 */
SELECT prod_codigo, prod_detalle, count(comp_componente)
FROM Producto left join Composicion on prod_codigo = comp_producto 
WHERE prod_codigo in (SELECT stoc_producto FROM STOCK 
					GROUP BY stoc_producto
					HAVING SUM(stoc_cantidad) > 100)
GROUP BY prod_codigo, prod_detalle

/* EJ5 */
SELECT prod_codigo, prod_detalle, sum(item_cantidad)
FROM Producto join Item_Factura on prod_codigo = item_producto
join Factura ON fact_tipo+fact_sucursal+fact_numero = 
item_tipo+item_sucursal+item_numero  
WHERE year(fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle
HAVING sum(item_cantidad) > (SELECT sum(item_cantidad)
							FROM Item_Factura 
							join Factura ON fact_tipo+fact_sucursal+fact_numero = 
							item_tipo+item_sucursal+item_numero  
							WHERE year(fact_fecha) = 2011 AND item_producto = prod_codigo)
							
/* EJ6 */
SELECT rubr_id, rubr_detalle, count(rubr_id) cantidad_productos, sum(isnull(stoc_cantidad,0)) stock_total
FROM Rubro left join Producto ON rubr_id = prod_rubro and prod_codigo in (SELECT stoc_producto 
							FROM STOCK 
							GROUP BY stoc_producto
							HAVING sum(stoc_cantidad) > 
							(select stoc_cantidad from STOCK WHERE stoc_deposito = '00' and stoc_producto = '00000000'))
left join STOCK ON prod_codigo = stoc_producto
GROUP BY rubr_id, rubr_detalle

/* EJ13 */
select Producto.prod_detalle, Producto.prod_precio, sum(comp_cantidad * CompProducto.prod_precio) valor_sin_promo
from Producto 
join Composicion on prod_codigo = comp_producto
join Producto as CompProducto on CompProducto.prod_codigo = comp_componente
group by Producto.prod_detalle, Producto.prod_codigo, Producto.prod_precio
/* contemplando que el enunciado se refiere a cantidad de productos y no variedad */
having count(*) >= 2 
order by count(*) desc

/* EJ14 */
select clie_codigo, 
	count(fact_numero) cantidad_compras, 
	isnull(avg(fact_total), 0) promedio_compras,
	count(item_producto),
	max(fact_total)
from Cliente
left join Factura on fact_cliente = clie_codigo and year(fact_fecha) = (select year(max(fact_fecha)) from Factura )
left join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
group by clie_codigo
order by 2

/* Escriba una consulta que retorne los pares de productos que hayan sido vendidos juntos
(en la misma factura) más de 500 veces. El resultado debe mostrar el código y
descripción de cada uno de los productos y la cantidad de veces que fueron vendidos
juntos. El resultado debe estar ordenado por la cantidad de veces que se vendieron
juntos dichos productos. Los distintos pares no deben retornarse más de una vez.
Ejemplo de lo que retornaría la consulta:
PROD1 DETALLE1 PROD2 DETALLE2 VECES
1731 MARLBORO KS 1 7 1 8 P H ILIPS MORRIS KS 5 0 7
1718 PHILIPS MORRIS KS 1 7 0 5 P H I L I P S MORRIS BOX 10 5 6 2 */

select I1.item_producto, 
	(select prod_detalle from Producto where prod_codigo = I1.item_producto), 
	I2.item_producto, 
	(select prod_detalle from Producto where prod_codigo = I2.item_producto), 
	count(*)
from Item_Factura as I1 
join Item_Factura as I2 on I1.item_tipo+I1.item_sucursal+I1.item_numero = I2.item_tipo+I2.item_sucursal+I2.item_numero
where I1.item_producto < I2.item_producto
group by I1.item_producto, I2.item_producto
having count(*) > 500
order by 5

/* SOLUCION DE MATICAO */
select p1.prod_codigo, p1.prod_detalle, p2.prod_codigo, p2.prod_Detalle, count(*)
from producto p1 join item_factura i1 on prod_codigo = item_producto join item_factura i2 
    on i1.item_tipo+i1.item_sucursal+i1.item_numero = i2.item_tipo+i2.item_sucursal+i2.item_numero 
    join producto p2 on p2.prod_codigo = i2.item_producto 
where p1.prod_codigo < p2.prod_codigo
group by p1.prod_codigo, p1.prod_detalle, p2.prod_codigo, p2.prod_Detalle 
having count(*) > 500

/* Con el fin de lanzar una nueva campaña comercial para los clientes que menos compran
en la empresa, se pide una consulta SQL que retorne aquellos clientes cuyas compras
son inferiores a 1/3 del monto de ventas del producto que más se vendió en el 2012.
Además mostrar
1. Nombre del Cliente
2. Cantidad de unidades totales vendidas en el 2012 para ese cliente.
3. Código de producto que mayor venta tuvo en el 2012 (en caso de existir más de 1,
mostrar solamente el de menor código) para ese cliente.
*/
select clie_codigo,
	clie_razon_social,
	sum(item_cantidad),
	(select top 1 item_producto
		from Item_Factura
		join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
		where fact_cliente = clie_codigo and year(fact_fecha) = 2012
		group by item_producto
		order by sum(item_cantidad* item_precio) desc, item_producto)
from Cliente
join Factura on clie_codigo = fact_cliente
left join Item_Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
group by clie_codigo, clie_razon_social
having sum(fact_total) < (
	select top 1 sum(item_cantidad * item_precio) * 1/3
	from Item_Factura
	join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
	where year(fact_fecha) = 2012
	group by item_producto
	order by sum(item_cantidad) desc
)


/*
Escriba una consulta que retorne una estadística de ventas por año y mes para cada
producto.
La consulta debe retornar:
PERIODO: Año y mes de la estadística con el formato YYYYMM
PROD: Código de producto
DETALLE: Detalle del producto
CANTIDAD_VENDIDA= Cantidad vendida del producto en el periodo
VENTAS_AÑO_ANT= Cantidad vendida del producto en el mismo mes del periodo
pero del año anterior
CANT_FACTURAS= Cantidad de facturas en las que se vendió el producto en el
periodo
La consulta no puede mostrar NUL
*/
select str(year(fact_fecha), 4) + str(month(fact_fecha), 2) periodo, 
	prod_codigo,
	sum(item_cantidad),
	(select sum(i2.item_cantidad) from Item_Factura i2
		join Factura f2 on i2.item_tipo+i2.item_sucursal+i2.item_numero=f2.fact_tipo+f2.fact_sucursal+f2.fact_numero
		where i2.item_producto = '00010200' and year(f2.fact_fecha) = 2011 and month(f2.fact_fecha) = month(fact_fecha)
		)
from producto 
left join Item_Factura on item_producto = prod_codigo
left join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
where prod_codigo = '00010200'
group by year(fact_fecha), MONTH(fact_fecha), prod_codigo


select * from factura