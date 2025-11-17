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


/*
Realizar un stored procedure que reciba un código de producto y una
	fecha y devuelva la mayor cantidad de días consecutivos a partir de esa
	fecha que el producto tuvo al menos la venta de una unidad en el día, el
	sistema de ventas on line está habilitado 24-7 por lo que se deben evaluar
	todos los días incluyendo domingos y feriados.
*/

create procedure diasSeguidos (@producto char(8), @fechaInicio smalldatetime, @dias int output)
as 
begin
	set @dias = 0
	declare @seguidos int
	set @seguidos = 0
	declare @unaFecha smalldatetime, @fechaAnterior smalldatetime
	declare c1 cursor for select fact_fecha from Item_Factura 
							join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
							where item_producto = @producto and fact_fecha > @fechaInicio
							group by item_producto, fact_fecha
							order by fact_fecha
	open c1
	fetch c1 into @unaFecha -- 1, 2, 5, 6, 7
	while @@FETCH_STATUS = 0
	begin
		if @fechaAnterior is null or datediff(day, @unaFecha, @fechaAnterior) = 1
		begin
			set @seguidos = @seguidos + 1
			set @fechaAnterior = @unaFecha
			if @dias < @seguidos
				set @dias = @seguidos
		end
		else
		begin
			set @seguidos = 1
		end
		fetch c1 into @unaFecha
	end
	close c1
	deallocate c1
end
go

/*2. Actualmente el campo fact_vendedor representa al empleado que vendió
la factura. Implementar el/los objetos necesarios para respetar
integridad referenciales de dicho campo suponiendo que no existe una
foreign key entre ambos.

NOTA: No se puede usar una foreign key para el ejercicio, deberá buscar
otro método */
create trigger integridadVendedor on Factura for insert 
as
begin
	if exists( select fact_vendedor from inserted
		left join Empleado on fact_vendedor = empl_codigo
		where empl_nombre is null
	)
	begin
		print('No pueden insertarse facturas para vendedores no registrados')
		rollback
	end
end
go

create trigger integridadVendedor on Empleado for delete 
as
begin
	if exists( select fact_vendedor from deleted
		join Factura on fact_vendedor = empl_codigo
	)
	begin
		print('El empleado tiene facturas asignadas')
		rollback
	end
end
go

/* 2. Cree el o los objetos necesarios para que controlar que un producto no pueda tener asignado 
un rubro que tenga mas de 20 productos asignados, 
si esto ocurre, 
hay que asignarle el rubro que menos productos tenga asignado e informar a que producto y que rubro se le asigno.
En la actualidad la regla se cumple y no se sabe la forma en que se accede a la Base de Datos.*/
create trigger rubroCorrecto on Producto for insert, update
as
begin
	declare @producto char(8), @detalle char(50), @precio decimal(12,2), @familia char(3), @rubro char(4), @envase numeric(6)
	declare c1 cursor for select * from inserted
	open c1
	while @@FETCH_STATUS = 0
	begin
		if (select count(*) from Producto where prod_rubro = @rubro) + 1 > 20
		begin
			declare @nuevoRubro char(4)
			set @nuevoRubro = (select top 1 rubr_id 
							from Rubro 
							left join Producto on prod_rubro = rubr_id
							group by rubr_id order by count(*))
			insert into Producto (prod_codigo, prod_detalle, prod_precio, prod_familia, prod_rubro, prod_envase)
			values (@producto, @detalle, @precio, @familia, @nuevoRubro, @envase)
			print('Se asigno el rubro '+ @nuevoRubro + ' al producto '+ @producto)
		end
		else
		begin
			insert into Producto (prod_codigo, prod_detalle, prod_precio, prod_familia, prod_rubro, prod_envase)
			values (@producto, @detalle, @precio, @familia, @rubro, @envase)
		end
	end
	close c1
	deallocate c1
end
go

select * from Producto
go

/*
Implementar una regla de negocio en línea que al realizar una venta (SOLO INSERCION)
permita componer los productos descompuestos,
es decir, si se guardan en la factura 2 hamb, 2 papas 2 gaseosas se deberá guardar en la factura 2 (DOS) combo1, 
Si 1 combo1 equivale a: 1 hamb. 1 papa y 1 gaseosa.

Nota: Considerar que cada vez que se guardan los items, se mandan todos los productos de ese item a la vez, 
y no de manera parcial.
*/
create trigger componerVenta on Item_Factura for insert
as
begin
	declare @productoCompuesto char(8), @cantidadCombo int
	declare c1 cursor for select comp_producto, max(item_cantidad / comp_cantidad) from inserted 
						join Composicion co1 on item_producto = co1.comp_componente
						group by comp_producto
						having (select count(*) from Composicion co2 
								where co1.comp_producto = co2.comp_producto) 
							= count(*)
	open c1
	fetch c1 into @productoCompuesto, @cantidadCombo
	while @@FETCH_STATUS = 0
	begin
		declare @componente char(8), @cantidadComponente int
		declare c2 cursor for select comp_componente, comp_cantidad from inserted 
						join Composicion on item_producto = comp_componente
						where comp_producto = @productoCompuesto
		open c2
		fetch c2 into @componente, @cantidadComponente
		while @@FETCH_STATUS = 0
		begin
			update Item_Factura set item_cantidad = item_cantidad - @cantidadComponente * @cantidadCombo
			where @componente = item_producto
			fetch c2 into @componente, @cantidadComponente
		end
		close c2
		deallocate c2

		insert into Item_Factura /* info combo */
		fetch c1 into @productoCompuesto, @cantidadCombo
	end
	close c1
	deallocate c1
end
go

/* 2. Implementar los objetos necesarios para registrar, en tiempo real, los 10 productos
mas vendidos por anio en una tabla especifica. Esta tabla debe contener exclusivamente la info requerida
sin incluir filas adicionales. 

Los mas vendidos se define como aquellos productos con el mayor numero de unidades vendidas.
*/
create table mas_vendidos (
	prod_codigo char(8),
	cantidad numeric(12,2),
	anio int
)
go

CREATE PROCEDURE registrar_mas_vendidos(@anio datetime2)
AS
BEGIN
    INSERT INTO mas_vendidos(
        prod_codigo,
        cantidad,
        anio
    ) SELECT TOP 10 prod_codigo, SUM(item_cantidad), @anio
    FROM Producto
    JOIN Item_Factura ON item_producto = prod_codigo
    JOIN Factura ON item_tipo+item_numero+item_sucursal = fact_tipo+fact_numero+fact_sucursal
    WHERE year(fact_fecha) = @anio
    GROUP BY prod_codigo
    ORDER BY SUM(item_cantidad) desc
END
go
/* 2. Se detectó un error en el proceso de registro de ventas, donde se almacenaron productos compuestos
en lugar de sus componentes individuales. Para solucionar este problema, se debe:

    1. Diseñar e implmenetar los objetos necesarios para reoganizar las ventas tal como están registradas actualmente 
    2. Desagregar los productos compuestos vendidos en sus componenetes individuales, asegurando
		que cada venta refleje correctamente los elementos que la compronen
    3. Garantizar que la base de datos quede consistente y alineada con las 
		especificaciones requeridas para el manejo de poductos
*/
create procedure corregirComposiciones
as
begin
	declare @tipo char(1), @sucursal char(4), @numero char(8), @prodcompuesto char(8), @cantidad decimal(12,2)
	declare c1 cursor for select 
							item_tipo,
							item_sucursal,
							item_numero,
							item_producto,
							item_cantidad
							from Item_Factura where item_producto in (select comp_producto from Composicion)
	open c1
	fetch c1 into @tipo, @sucursal, @numero, @prodcompuesto, @cantidad
	while @@FETCH_STATUS = 0
	begin
		declare @componente char(8), @cantidadComponente decimal(12,2), @precioComponente decimal(12,2)
		declare c2 cursor for select comp_componente, comp_cantidad from Composicion 
							join Producto on comp_componente = prod_codigo
							where comp_producto = @prodcompuesto
								
		open c2

		while @@FETCH_STATUS = 0
		begin
			insert into Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
			values (@tipo, @sucursal, @numero, @componente, @cantidad * @cantidadComponente, @precioComponente)
		end
		close c2
		deallocate c2
		delete from Item_Factura where item_tipo+item_sucursal+item_numero=@tipo+@sucursal+@numero and item_producto = @prodcompuesto
	end
	close c1
	deallocate c1
end
go

/*
Implementar una regla de negocio en linea donde se valide que nunc?
un producto compuesto pueda estar compuesto por componentes de rubros distintos a el.
*/

create trigger composicionDistintoRubro on Composicion for insert, update
as
begin
	if exists(
		select * from inserted 
		join Producto p1 on comp_producto = p1.prod_codigo
		join Producto p2 on comp_componente = p2.prod_codigo
		where p1.prod_rubro <> p2.prod_rubro
	)
	rollback
end
go

/*
Se pide crear el/los objetos necesarios para que se imprima un cupon
con la leyenda "Recuerde solicitar su regalo sorpresa en su próxima compra" a
los clientes que, entre los productos comprados, hayan adquirido algún producto
de los siguientes rubros: PILAS y PASTILLAS y tengan un limite crediticio menor
a $ 15000
*/
create trigger notificarCliente on Item_factura for insert
as
begin
	declare @cliente char(6)
	declare c1 cursor for select fact_cliente from inserted 
						join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
						join Producto on item_producto = prod_codigo
						join Rubro on prod_rubro = rubr_id
						where (rubr_detalle = 'PILAS' or rubr_detalle = 'PASTILLAS')
						group by fact_cliente
	open c1
	fetch c1 into @cliente
	while @@FETCH_STATUS = 0
	begin 
		if @cliente in (select clie_codigo from Cliente where clie_limite_credito < 15000)
			print('Recuerde solicitar su regalo sorpresa en su próxima compra')
	end
	close c1
	deallocate c1
end
go

/* 2. Se requiere diseñar e implemetar los objetos necesarios para crear una regla que detecte inconsistencias en
las ventas en linea. 
En caso de detectar una incosistencia, debera registrarse el detalle correspondiente en una estructura
adicional. POr el contrario, si no se encuentra ninguna incosistencia, se debera registrar que la factura ha sido validada

Inconsistencias a considerar:
    1. Que el valor de fact_total no coincida con la suma de los precios multiplicados por la cantidades que los articulos
    2. Que se genere una factura con una fecha anterior al día actual
    3. Que se intente eliminar algun registro de una venta
*/
create table verficacionFactura (
	veri_tipo char(1),
	veri_sucursal char(4),
	veri_numero char(8),
	veri_detalle char(50)
);
go

create trigger verificarTotal on Item_factura for insert
as
begin
		
end
go