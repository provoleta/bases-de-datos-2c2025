/*
Realizar una consulta SQL que devuelva para los 5 productos mas vendidos y los 10 productos menos vendidos

Código y detalle del producto en una sola columna separado por el carácter “–” (ej: 0001 – DETALLE PRODUCTO)
Nombre del vendedor que más veces vendió el producto.
Cantidad de depósitos donde hay stock de ese producto.
Cliente que más veces compró ese producto.
Monto total facturado al cliente que más compró ese producto.

El resultado deberá mostrarse ordenado de mayor a menor cantidad de ventas de los productos.

NOTA: No se permite el uso de sub-selects en el FROM ni funciones definidas por el usuario para este punto.
*/
select 
	prod_codigo+' - '+prod_detalle,
	(select top 1 fact_vendedor from factura 
		join item_factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
		where item_producto = prod_codigo
		group by fact_tipo+fact_sucursal+fact_numero, fact_vendedor
		order by count(*)) as Mayor_Vendedor,
	(select count(*) from deposito join stock on stoc_deposito = depo_codigo
		where stoc_producto = prod_codigo) as Cantidad_Depositos,
	(select top 1 fact_cliente from factura 
		join item_factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
		where item_producto = prod_codigo
		group by fact_tipo+fact_sucursal+fact_numero, fact_cliente
		order by count(*)) as Mayor_Comprador,
	(select sum(fact_total) from Factura 
	 where fact_cliente in (
		select top 1 fact_cliente from factura 
			join item_factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
			where item_producto = prod_codigo
			group by fact_tipo+fact_sucursal+fact_numero, fact_cliente
			order by count(*))) as Mayor_Vendedor
from Producto
join item_factura on prod_codigo = item_producto
where prod_codigo in (
	select top 5 item_producto from item_factura
	group by item_producto
	order by sum(item_cantidad) desc
	) or prod_codigo in (
	select top 10 item_producto from item_factura
	group by item_producto
	order by sum(item_cantidad) asc
	)
group by prod_codigo, prod_detalle
order by sum(item_cantidad) desc

/*Armar una consulta que muestre para todos los productos:
Producto
Detalle del producto
Detalle composiciOn (si no es compuesto un string SIN COMPOSICION,, si es compuesto un string CON COMPOSICION
Cantidad de Componentes (si no es compuesto, tiene que mostrar 0)
Cantidad de veces que fue comprado por distintos clientes

Nota: No se permiten sub select en el FROM.*/
select 
	prod_codigo as Producto,
	prod_detalle as Detalle,
	case 
		when (select COUNT(*) from Composicion where comp_producto = prod_codigo) > 0
            then 'COMPOSICION'
            else 'SIN COMPOSICION' 
			end AS dato,
	isnull((select count(*) from Composicion where comp_producto = prod_codigo), 0),
	count(distinct fact_cliente)
from producto
join Item_Factura on item_producto = prod_codigo
join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
group by prod_codigo, prod_detalle
go
/*
Implementar el/los objetos necesarios para implementar la siguiente restriccion en linea:
Cuando se inserta en una venta un COMBO, nunca se debera guardar el producto COMBO, sino, 
la descomposicion de sus componentes.
Nota: Se sabe que actualmente todos los articulos guardados de ventas estan descompuestos en sus componentes.
 */
drop trigger descomponerComposicion on Item_factura instead of insert
as
begin
	declare @prodCompuesto char(8), @tipo char(1), @sucursal char(4), @numero char(8), @precio decimal(12, 2), @cantidadProducto decimal(12,2), @componente char(8), @cantidadComponente decimal(12,2)
	declare c1 cursor for 
		select 
			item_producto, 
			item_numero,
			item_sucursal,
			item_tipo,
			item_precio,
			item_cantidad,
			comp_componente, 
			comp_cantidad
		from inserted left join Composicion on item_producto = comp_producto
	open c1
	fetch next from c1 into @prodCompuesto, @numero, @sucursal, @tipo, @precio, @cantidadProducto, @componente, @cantidadComponente
	while @@FETCH_STATUS = 0
	begin
		if @componente is null
		begin
			insert into Item_Factura (item_producto, item_numero, item_sucursal, item_tipo, item_precio, item_cantidad)
			values (@prodCompuesto, @numero, @sucursal, @tipo, @precio, @cantidadProducto)
		end
		else 
		begin
			insert into Item_Factura (item_producto, item_numero, item_sucursal, item_tipo, item_precio, item_cantidad)
			values (@componente, @numero, @sucursal, @tipo, @precio, (@cantidadProducto * @cantidadComponente))
		end
		fetch next from c1 into @prodCompuesto, @numero, @sucursal, @tipo, @precio, @cantidadProducto, @componente, @cantidadComponente
	end
	close c1
	deallocate c1
end
go


/*
13-11-2024
1. Realizar una consulta que muestre, para los clientes que compraron 
únicamente en años pares, la siguiente información: 
    - El numero de fila
    - el codigo de cliente
    - el nombre del producto más comprado por el cliente
    - la cantidad total comprada por el cliente en el último año

El resultado debe estar ordenado en función de la cantidad máxima comprada por cliente
de mayor a menor    
*/ 
select
	clie_codigo,
	(select top 1 prod_detalle from Producto 
		join Item_Factura on item_producto = prod_codigo
		join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
		where fact_cliente = clie_codigo
		group by prod_detalle, prod_codigo
		order by sum(item_cantidad)),
	(select sum(item_cantidad) 
		from Item_Factura 
		join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
		where fact_cliente = clie_codigo and year(fact_fecha) = (select max(year(fact_fecha)) from Factura))
from Cliente
join Factura on fact_cliente = clie_codigo
join Item_Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
where year(fact_fecha) % 2 = 0
group by clie_codigo
order by sum(item_cantidad)

/*
Implementar un sistema de auditoria para registrar cada operacion realizada en la tabla 
cliente. El sistema debera almacenar, como minimo, los valores(campos afectados), el tipo 
de operacion a realizar, y la fecha y hora de ejecucion. SOlo se permitiran operaciones individuales
(no masivas) sobre los registros, pero el intento de realizar operaciones masivas deberá ser registrado
en el sistema de auditoria
*/
CREATE TABLE AUDITORIA(
    audi_operacion char(100),
	audi_fecha_operacion smalldatetime,
    audi_codigo char(6),
    audi_razon_social char(10),
    audi_telefono char(100),
    audi_domicilio char(100),
    audi_limite_credito decimal(12, 2),
    audi_vendedor numeric(6)
)
go
alter trigger t_auditoria on Cliente for insert, delete, update
as
begin
	if (select count(*) from inserted) > 1 or (select count(*) from deleted) > 1
	begin
		rollback
		insert into AUDITORIA (audi_operacion, audi_fecha_operacion)
		values ('Insercion Masiva', GETDATE())
		
	end
	else
	begin
	if ((select count(*) from inserted) > 0 and (select count(*) from deleted) = 0)
	begin
		insert into AUDITORIA (audi_operacion, audi_fecha_operacion, audi_codigo, audi_razon_social, audi_telefono, audi_domicilio, audi_limite_credito, audi_vendedor)
		select 'Insercion', GETDATE(),* from inserted
	end
	if ((select count(*) from inserted) = 0 and (select count(*) from deleted) > 0)
	begin
		insert into AUDITORIA (audi_operacion, audi_fecha_operacion, audi_codigo, audi_razon_social, audi_telefono, audi_domicilio, audi_limite_credito, audi_vendedor)
		select 'Eliminacion', GETDATE(),* from deleted
	end
	if ((select count(*) from inserted) > 0 and (select count(*) from deleted) > 0)
	begin
		insert into AUDITORIA (audi_operacion, audi_fecha_operacion, audi_codigo, audi_razon_social, audi_telefono, audi_domicilio, audi_limite_credito, audi_vendedor)
		select 'Actualizacion', GETDATE(),* from inserted
	end
	end
end
go

/* 20-11-2024
1. Consulta SQL para analizar clientes con patrones de cmpra especificos

Se debe identificar clientes que realizarion una compra inicial y luego volvieron a 
comprar despues de 5 meses o más 

La consulta debe mostrar 
    - El numero de fila: identificador secuencial del resultado
    - el codigo del cliente id unico del cliente
    - el nombre del cliente: nombre asociado al cliente 
    - cantidad total comprada: total de productos distintos adquiridos por el cliente
    - total facturado: importe total factura al cliente 
El resultado debe estsr ordenado de forma descendente por la cantidad de productos 
adquiridos por cada cliente
*/ 
select 
	c1.clie_codigo, 
	c1.clie_razon_social,
	count(distinct item_producto),
	sum(item_precio * item_cantidad)
from cliente c1
join Factura f1 on c1.clie_codigo = f1.fact_cliente
join Item_Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
where clie_codigo in (
	select top 1 clie_codigo from cliente c2
	join Factura f2 on c2.clie_codigo = f2.fact_cliente
	where DATEDIFF(month, f2.fact_fecha, f1.fact_fecha) >= 5 and f2.fact_numero <> f1.fact_numero and f1.fact_cliente = f2.fact_cliente 
	order by f2.fact_fecha asc
	)
group by clie_codigo, clie_razon_social
order by 3 desc
go

/* 
2. Se detectó un error en el proceso de registro de ventas, donde se almacenaron productos compuestos
en lugar de sus componentes individuales. Para solucionar este problema, se debe:

    1. Diseñar e implmenetar los objetos necesarios para reoganizar las ventas tal como están registradas actualmente 
    2. Desagregar los productos compuestos vendidos en sus componenetes individuales, asegurando
    que cada venta refleje correctamente los elementos que la compronen
    3. Garantizar que la base de datos quede consistente y alineada con las especificaciones requeridas para el manejo de poductos
*/
alter proc reorganizarComponentes 
as
begin
	declare @producto char(8), @tipo char(1), @sucursal char(4), @numero char(8), @precio decimal(12, 2), @cantidadProducto decimal(12,2)
	declare @componente char(8), @cantidadComponente numeric(12,2), @precioComponente decimal(12,2)
	declare c1 cursor for select item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio from Item_Factura where item_producto in (select comp_producto from  Composicion )
	open c1
	fetch next from c1 into @tipo, @sucursal, @numero,  @producto, @cantidadProducto, @precio
	while @@FETCH_STATUS = 0
	begin
		declare c2 cursor for select comp_componente, comp_cantidad, prod_precio 
			from Composicion 
			join Producto on prod_codigo = comp_componente
			where comp_producto = @producto
		open c2
		fetch next from c2 into @componente, @cantidadComponente, @preciocomponente
		while @@FETCH_STATUS = 0
		begin
			insert into Item_Factura 
			values (@tipo, @sucursal, @numero,  @componente, @cantidadProducto * @cantidadComponente, @preciocomponente)
			fetch next from c2 into @componente, @cantidadComponente, @preciocomponente
		end
		close c2
		deallocate c2
		delete from Item_Factura where item_tipo+item_sucursal+item_numero+item_producto=@tipo+@sucursal+@numero+@producto
		fetch next from c1 into @tipo, @sucursal, @numero,  @producto, @cantidadProducto, @precio
	end
	close c1
	deallocate c1
end 
go

alter trigger reorganizacionAutomatica on Item_factura for Insert
as 
begin
	if exists(select item_producto from inserted where item_producto in (select comp_producto from Composicion))
	begin
		declare @producto char(8), @tipo char(1), @sucursal char(4), @numero char(8), @precio decimal(12, 2), @cantidadProducto decimal(12,2)
		declare @componente char(8), @cantidadComponente numeric(12,2), @precioComponente decimal(12,2)
		declare c1 cursor for select item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio from inserted where item_producto in (select comp_producto from  Composicion )
		open c1
		fetch next from c1 into @tipo, @sucursal, @numero,  @producto, @cantidadProducto, @precio
		while @@FETCH_STATUS = 0
		begin
			declare c2 cursor for select comp_componente, comp_cantidad, prod_precio 
				from Composicion 
				join Producto on prod_codigo = comp_componente
				where comp_producto = @producto
			open c2
			fetch next from c2 into @componente, @cantidadComponente, @preciocomponente
			while @@FETCH_STATUS = 0
			begin
				insert into Item_Factura 
				values (@tipo, @sucursal, @numero,  @componente, @cantidadProducto * @cantidadComponente, @preciocomponente)
				fetch next from c2 into @componente, @cantidadComponente, @preciocomponente
			end
			close c2
			deallocate c2
			delete from Item_Factura where item_tipo+item_sucursal+item_numero+item_producto=@tipo+@sucursal+@numero+@producto
			fetch next from c1 into @tipo, @sucursal, @numero,  @producto, @cantidadProducto, @precio
		end
		close c1
		deallocate c1
	end
end
go

/* 22-11-2022
Realizar una consulta SQL que muestre aquellos productos que tengan
3 componentes a nivel producto y cuyos componentes tengan 2 rubros
distintos.
De estos productos mostrar:
    i) El código de producto.
    ii) El nombre del producto.
    iii) La cantidad de veces que fueron vendidos sus componentes en el 2012.
    iv) Monto total vendido del producto.

El resultado deberá ser ordenado por cantidad de facturas del 2012 en
las cuales se vendieron los componentes.
Nota: No se permiten select en el from, es decir, select... from (select ...) as T....
*/
select
	prod_codigo,
	prod_detalle,
	isnull((select sum(item_precio * item_cantidad) from composicion 
		left join Item_Factura on item_producto = comp_componente
		join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero 
		where comp_producto = prod_codigo and YEAR(fact_fecha) = 2012),0),
	isnull((select sum(item_precio * item_cantidad) from Item_Factura where item_producto = prod_codigo),0)
from Producto
join Composicion on prod_codigo = comp_producto

where prod_codigo in (
	select comp_producto from Composicion
	join Producto on comp_componente = prod_codigo
	group by comp_producto
	having count(distinct prod_rubro) >= 2 
	)
group by prod_codigo, prod_detalle
order by 3
go
/*
1. Implementar una regla de negocio en linea donde se valide que nunc?
un producto compuesto pueda estar compuesto por componentes de rubros distintos a el.
*/
create trigger reglaComposicion on Composicion for insert, update
as
begin
	if exists(
		select * from inserted 
		join producto p1 on p1.prod_codigo = comp_componente
		join Producto p2 on p2.prod_codigo = comp_producto
		where p1.prod_rubro <> p2.prod_rubro
	)
	rollback
end
go


/* 25-06-2024
Dada la crisis que atraviesa la empresa, el directorio solicia un informe especial para poder analizar y definir
la nueva estrategia a adoptar
Este informe consta de un listado de aquellos productos cuyas ventas de lo que va del año 2012 fueron superiores
al 15% del promedio de ventas de los productos vendidos entre los años 2010 y 2011
En base a lo solicitado, armar una consulta SQL que retorne la siguiente informacion:
    1) Detalle producto 
    2) Mostrar la leyenda "Popular" si dicho producto figura en más de 100 facturas realizadas en el 2012. Caso 
        contrario, mostrar la leyenda "SIN INTERES"
    3) Cantidad de facturas en las que aparece el producto en el año 2012
    4) Codigo del cliente que más compro dicho producto en el año 2012 (en caso de existi más de un cliente
     mostrar solamente el de menor codigo)
*/
select
	prod_detalle,
	case 
		when count(distinct fact_numero) > 100
		then 'Popular'
		else 'Sin interes'
		end,
	count(distinct fact_numero),
	(select top 1 clie_codigo from cliente join Factura on fact_cliente = clie_codigo
		join Item_Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
		where YEAR(fact_fecha) = 2012 and item_producto = prod_codigo
		group by clie_codigo
		order by sum(item_cantidad), clie_codigo)
from Producto
join Item_Factura on item_producto = prod_codigo
join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
where YEAR(fact_fecha) = 2012
group by prod_codigo, prod_detalle
having sum(item_cantidad * item_precio) > 
	1.15 * 
	(select sum(item_cantidad * item_precio) from Item_Factura 
				join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
				where item_producto = prod_codigo and YEAR(fact_fecha) = 2011) 
		+(select sum(item_cantidad * item_precio) from Item_Factura 
				join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
				where item_producto = prod_codigo and YEAR(fact_fecha) = 2010)
go
/*
Realizar el o los objetos de base de datos necesarios para que dado un codigo de producto y una fecha devuelva
la mayor cantidad de dias consecutivos a partir de esa fecha que el producto tuvo al menos la venta de una unidad en el dia, 
el sistema de ventas on line esta habilitado 24-7 por lo que se deben evaluar tidos los dias incluyendo domingos y feriados
*/
create function diasSeguidos (@producto char(8), @fechaInicio smalldatetime)
returns int
as 
begin
	
end
go