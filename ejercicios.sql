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

/* EJ15 REHACER */

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

/* EJ16 */
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


/* EJ17 */
select str(year(f1.fact_fecha), 4) + str(month(f1.fact_fecha), 2) periodo,
	prod_codigo,
	sum(item_cantidad) cantidad_vendida,
	isnull((
		select sum(i2.item_cantidad)
		from Item_Factura i2
		join Factura f2 on i2.item_tipo+i2.item_sucursal+i2.item_numero=f2.fact_tipo+f2.fact_sucursal+f2.fact_numero
		where i2.item_producto = prod_codigo and year(f2.fact_fecha) =  year(f1.fact_fecha) - 1 and month(f2.fact_fecha) = month(f1.fact_fecha)
	), 0) periodo_anterior,
	count(fact_numero) cantidad_facturas
from producto
join Item_Factura on item_producto = prod_codigo
join Factura f1 on item_tipo+item_sucursal+item_numero=f1.fact_tipo+f1.fact_sucursal+f1.fact_numero
group by year(f1.fact_fecha), month(f1.fact_fecha), prod_codigo

/*
18. Escriba una consulta que retorne una estadística de ventas para todos los rubros.
La consulta debe retornar:
DETALLE_RUBRO: Detalle del rubro
VENTAS: Suma de las ventas en pesos de productos vendidos de dicho rubro
PROD1: Código del producto más vendido de dicho rubro
PROD2: Código del segundo producto más vendido de dicho rubro
CLIENTE: Código del cliente que compro más productos del rubro en los últimos 30
días
La consulta no puede mostrar NULL en ninguna de sus col
*/
select rubr_id, 
    sum(item_cantidad * item_precio),
    (
        select top 1 item_producto from Item_Factura
        join Producto p1 on item_producto = p1.prod_codigo
        where p1.prod_rubro = rubr_id
        group by item_producto
        order by sum(item_cantidad) desc
    ) primero_mas_vendido,
    (
        select top 1 item_producto from Item_Factura
        where item_producto in 
            (select top 2 item_producto from Item_Factura
            join Producto p2 on item_producto = p2.prod_codigo
            where p2.prod_rubro = rubr_id  
            group by item_producto
            order by sum(item_cantidad) desc)
        group by item_producto
        order by sum(item_cantidad) asc
    ) segundo_mas_vendido,
    (
        select top 1 clie_codigo
        from Cliente
        join Factura on fact_cliente = clie_codigo
        join Item_Factura on fact_sucursal+fact_numero+fact_tipo=item_sucursal+item_numero+item_tipo
        join Producto on item_producto = prod_codigo
        where prod_rubro = rubr_id
        group by clie_codigo
        order by sum(item_cantidad)
    ) cliente_mas_compro
from Rubro
join Producto on prod_rubro = rubr_id
join Item_Factura on item_producto = prod_codigo
group by rubr_id
go

/* 1 */
/* sum(fact_total) <> sum(item_cantidad * item_precio), cuando un join tiene facturas repetidas */


/* 2 */
create trigger calculoInflacion on Item_factura for insert
as 
begin
	if exists(
		select * from inserted i1
		join factura f1 on f1.fact_sucursal+f1.fact_numero+f1.fact_tipo=i1.item_sucursal+i1.item_numero+i1.item_tipo
		join item_factura i2 on i1.item_producto = i2.item_producto
		join factura f2 on f2.fact_sucursal+f2.fact_numero+f2.fact_tipo=i2.item_sucursal+i2.item_numero+i2.item_tipo
		where (DATEDIFF(month, f1.fact_fecha, f2.fact_fecha) = 1 and i1.item_precio > i2.item_precio * 1.05) or
			  (DATEDIFF(month, f1.fact_fecha, f2.fact_fecha) = 12 and i1.item_precio > i2.item_precio * 1.5)
	)
	rollback
end
go


select empl_apellido, empl_nombre, 'Mejor facturacion' from empleado
where empl_codigo = (select top 1 fact_vendedor 
					from factura 
					where year(fact_fecha) = (select top 1 year(fact_fecha) from factura order by 1) 
					group by fact_vendedor 
					order by sum(fact_total) desc)
union
select empl_apellido, empl_nombre, 'Vendio mas facturas' from empleado
where empl_codigo = (select top 1 fact_vendedor 
					from factura 
					where year(fact_fecha) = (select top 1 year(fact_fecha) from factura order by 1) 
					group by fact_vendedor 
					order by count(*) desc)
go
/*
2.	Realizar un stored procedure que reciba un código de producto y una fecha y devuelva
 la mayor cantidad de días 
consecutivos a partir de esa fecha que el producto tuvo al menos la venta de una unidad en el día,
 el sistema de ventas 
on line está habilitado 24-7 por lo que se deben evaluar todos los días incluyendo domingos
 y feriados
*/

create proc cantidadDiasConsecutivos(@producto char(8), @fechaAPartir smallDateTime, @cantidadDias int output)
as
begin
	declare @fechaVenta smalldatetime
	declare @fechaVentaAnterior smalldatetime
	declare @acumDias int
	set @cantidadDias = 0
	set @acumDias = 0
	declare c1 cursor for select distinct fact_fecha from Item_Factura 
							join factura on fact_sucursal+fact_numero+fact_tipo=item_sucursal+item_numero+item_tipo
							where fact_fecha > @fechaAPartir and item_producto = @producto
							order by fact_fecha
	open c1
	fetch from c1 next into @fechaVenta
	while @@FETCH_STATUS = 0
	begin
		if @fechaVenta = @fechaVentaAnterior + 1
		begin
			set @acumDias += 1
			if @acumDias > @cantidadDias
				set @cantidadDias = @acumDias
			set @fechaVentaAnterior = @fechaVenta
		end
		else
		begin
			set @acumDias = 0
		end
		fetch from c1 next into @fechaVenta
	end
	close c1
	deallocate c1
end
go


/* Sabiendo que si un producto no es vendido en un deposito determinado entonces no posee registros en el 
Se requiere una consulta SQL que para todos los productos que se quedaron sin stock en un deposito (cantidad 0 o nula) y
poseen un stock mayor al punto de resposicion en otro deposito devuelva:

1 - codigo de producto
2 - detalle de producto
3 - domicilio del deposito sin stock
4 - cantidad de depositos con un stock superior al punto de reposicion

la consulta debe ser ordenada por el codigo de producto.
*/
select prod_codigo, prod_detalle, depo_domicilio, count(*)
from Producto
join STOCK s1 on s1.stoc_producto = prod_codigo
join DEPOSITO d1 on d1.depo_codigo = s1.stoc_deposito
join STOCK s2 on s2.stoc_producto = prod_codigo
where (s1.stoc_cantidad = 0 or s1.stoc_cantidad is null) 
		and s2.stoc_cantidad > s2.stoc_punto_reposicion
		and s1.stoc_deposito <> s2.stoc_deposito
group by s1.stoc_producto, prod_codigo, prod_detalle, depo_domicilio
order by 1

/*
25. Realizar una consulta SQL que para cada año y familia muestre :
	a. Año
	b. El código de la familia más vendida en ese año. asumo mas vendida a item cantidad
	c. Cantidad de Rubros que componen esa familia.
	d. Cantidad de productos que componen directamente al producto más vendido de
	esa familia.
	e. La cantidad de facturas en las cuales aparecen productos pertenecientes a esa
	familia.
	f. El código de cliente que más compro productos de esa familia.
	g. El porcentaje que representa la venta de esa familia respecto al total de venta
del año.
El resultado deberá ser ordenado por el total vendido por año y familia en forma
descendente
*/

SELECT 
	YEAR(f.fact_fecha),
	(SELECT TOP 1 prod_familia
	FROM Factura f1
    JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
    JOIN Producto ON item_producto = prod_codigo
    WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
    GROUP BY prod_familia
    ORDER BY COUNT(fact_numero) DESC),

	(SELECT COUNT(distinct prod_rubro)
    FROM Producto
    WHERE prod_familia = ((SELECT TOP 1 prod_familia
                            FROM Factura f1
                            JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
                        	JOIN Producto ON item_producto = prod_codigo
                            WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
                            GROUP BY prod_familia
                            ORDER BY SUM(item_cantidad) DESC))) as CantRubros ,

	(SELECT COUNT(*) FROM Composicion 
	JOIN Producto ON comp_producto = prod_codigo
	WHERE comp_producto = (SELECT TOP 1 prod_codigo FROM Producto 
							JOIN Item_Factura ON item_producto = prod_codigo
							WHERE prod_familia = (SELECT TOP 1 prod_familia
                            						FROM Factura f1
                           	 						JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
                        							JOIN Producto ON item_producto = prod_codigo
                            						WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
                            						GROUP BY prod_familia
                            						ORDER BY SUM(item_cantidad)  DESC)
							GROUP BY prod_codigo
							ORDER BY SUM(item_cantidad))) AS CantComponentes,
	(SELECT COUNT(distinct fact_tipo+fact_sucursal+fact_numero) 
	FROM Factura f1
	JOIN Item_Factura ON fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
	JOIN Producto ON prod_codigo = item_producto
	WHERE YEAR(f.fact_fecha) = YEAR(f1.fact_fecha) AND prod_familia = (SELECT TOP 1 prod_familia
                            FROM Factura f1
                           	JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
                        	JOIN Producto ON item_producto = prod_codigo
                            WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
                            GROUP BY prod_familia
                            ORDER BY SUM(item_cantidad)  DESC)) AS CantFacturas,
	(SELECT TOP 1 fact_cliente 
	FROM Factura
	JOIN Item_Factura ON fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
	JOIN Producto ON prod_codigo = item_producto
	WHERE YEAR(f.fact_fecha) = YEAR(fact_fecha) AND prod_familia = (SELECT TOP 1 prod_familia
                            FROM Factura f1
                           	JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
                        	JOIN Producto ON item_producto = prod_codigo
                            WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
                            GROUP BY fact_cliente, prod_familia
                            ORDER BY SUM(item_cantidad) DESC)) as ClienteQueMasCompro ,
	(SELECT SUM(item_cantidad*item_precio) 
	FROM Factura
	JOIN Item_Factura ON fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
	JOIN Producto ON prod_codigo = item_producto
	WHERE YEAR(f.fact_fecha) = YEAR(fact_fecha) AND prod_familia = (SELECT TOP 1 prod_familia
                            FROM Factura f1
                           	JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
                        	JOIN Producto ON item_producto = prod_codigo
                            WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)))* 100 / SUM(fact_total) as Porcentaje                          
FROM Factura f 
GROUP BY YEAR(f.fact_fecha)


SELECT 
	YEAR(f.fact_fecha),
	(SELECT TOP 1 prod_familia
	FROM Factura f1
    JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
    JOIN Producto ON item_producto = prod_codigo
    WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
    GROUP BY prod_familia
    ORDER BY COUNT(fact_numero) DESC),

	(SELECT COUNT(distinct prod_rubro)
    FROM Producto
    WHERE prod_familia = ((SELECT TOP 1 prod_familia
                            FROM Factura f1
                            JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
                        	JOIN Producto ON item_producto = prod_codigo
                            WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
                            GROUP BY prod_familia
                            ORDER BY SUM(item_cantidad) DESC))) as CantRubros ,

	(SELECT COUNT(*) FROM Composicion 
	JOIN Producto ON comp_producto = prod_codigo
	WHERE comp_producto = (SELECT TOP 1 prod_codigo FROM Producto 
							JOIN Item_Factura ON item_producto = prod_codigo
							WHERE prod_familia = (SELECT TOP 1 prod_familia
                            						FROM Factura f1
                           	 						JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
                        							JOIN Producto ON item_producto = prod_codigo
                            						WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
                            						GROUP BY prod_familia
                            						ORDER BY SUM(item_cantidad)  DESC)
							GROUP BY prod_codigo
							ORDER BY SUM(item_cantidad))) AS CantComponentes,
	(SELECT COUNT(distinct fact_tipo+fact_sucursal+fact_numero) 
	FROM Factura f1
	JOIN Item_Factura ON fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
	JOIN Producto ON prod_codigo = item_producto
	WHERE YEAR(f.fact_fecha) = YEAR(f1.fact_fecha) AND prod_familia = (SELECT TOP 1 prod_familia
                            FROM Factura f1
                           	JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
                        	JOIN Producto ON item_producto = prod_codigo
                            WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
                            GROUP BY prod_familia
                            ORDER BY SUM(item_cantidad)  DESC)) AS CantFacturas,
	(SELECT TOP 1 fact_cliente 
	FROM Factura
	JOIN Item_Factura ON fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
	JOIN Producto ON prod_codigo = item_producto
	WHERE YEAR(f.fact_fecha) = YEAR(fact_fecha) AND prod_familia = (SELECT TOP 1 prod_familia
                            FROM Factura f1
                           	JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
                        	JOIN Producto ON item_producto = prod_codigo
                            WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
                            GROUP BY fact_cliente, prod_familia
                            ORDER BY SUM(item_cantidad) DESC)) as ClienteQueMasCompro ,
	(SELECT SUM(item_cantidad*item_precio) 
	FROM Factura
	JOIN Item_Factura ON fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
	JOIN Producto ON prod_codigo = item_producto
	WHERE YEAR(f.fact_fecha) = YEAR(fact_fecha) AND prod_familia = (SELECT TOP 1 prod_familia
                            FROM Factura f1
                           	JOIN Item_Factura ON f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=item_tipo+item_sucursal+item_numero
                        	JOIN Producto ON item_producto = prod_codigo
                            WHERE YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)))* 100 / SUM(fact_total) as Porcentaje                          
FROM Factura f 
GROUP BY YEAR(f.fact_fecha)

/*
29. Se solicita que realice una estadística de venta por producto para el año 2011, solo para
los productos que pertenezcan a las familias que tengan más de 20 productos asignados
a ellas, la cual deberá devolver las siguientes columnas:
	a. Código de producto
	b. Descripción del producto
	c. Cantidad vendida
	d. Cantidad de facturas en la que esta ese producto
	e. Monto total facturado de ese producto
Solo se deberá mostrar un producto por fila en función a los considerandos establecidos
antes. El resultado deberá ser ordenado por el la cantidad vendida de mayor a menor.
*/
select prod_codigo, 
	prod_detalle, 
	sum(item_cantidad),
	count(distinct fact_numero),
	sum(item_cantidad * item_precio)
from Producto
join Item_Factura on item_producto = prod_codigo
join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
where year(fact_fecha) = 2011 and prod_familia in (select fami_id from Familia
												join Producto on prod_familia = fami_id
												group by fami_id
												having count(*) >= 20
												)
group by prod_codigo, prod_detalle

/*
34. Escriba una consulta sql que retorne para todos los rubros la cantidad de facturas mal
facturadas por cada mes del año 2011 Se considera que una factura es incorrecta cuando
en la misma factura se factutan productos de dos rubros diferentes. Si no hay facturas
mal hechas se debe retornar 0. Las columnas que se deben mostrar son:
	1- Codigo de Rubro
	2- Mes
	3- Cantidad de facturas mal realizadas.
*/
select  
	r1.rubr_id,
	MONTH(fact_fecha),
	isnull(count(distinct fact_numero), 0)
from Factura f1
join Item_Factura i1 on i1.item_tipo+i1.item_sucursal+i1.item_numero=f1.fact_tipo+f1.fact_sucursal+f1.fact_numero
join Producto p1 on i1.item_producto = p1.prod_codigo
join Rubro r1 on r1.rubr_id = p1.prod_rubro
where year(f1.fact_fecha) = 2011 and 
	fact_numero in (
		select fact_numero from Factura f2
		join Item_Factura i2 on i2.item_tipo+i2.item_sucursal+i2.item_numero=f2.fact_tipo+f2.fact_sucursal+f2.fact_numero
		join Producto p2 on i2.item_producto = p2.prod_codigo
		join Rubro r2 on r2.rubr_id = p2.prod_rubro
		where f1.fact_tipo+f1.fact_sucursal+f1.fact_numero=f2.fact_tipo+f2.fact_sucursal+f2.fact_numero 
			and r1.rubr_id <> r2.rubr_id
		)
group by MONTH(f1.fact_fecha), r1.rubr_id

/*
35. Se requiere realizar una estadística de ventas por año y producto, para ello se solicita
que escriba una consulta sql que retorne las siguientes columnas:
? Año
? Codigo de producto
? Detalle del producto
? Cantidad de facturas emitidas a ese producto ese año
? Cantidad de vendedores diferentes que compraron ese producto ese año.
? Cantidad de productos a los cuales compone ese producto, si no compone a ninguno
se debera retornar 0.
? Porcentaje de la venta de ese producto respecto a la venta total de ese año.
Los datos deberan ser ordenados por año y por producto con mayor cantidad vendida.
*/
