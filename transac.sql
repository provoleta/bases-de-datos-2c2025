/* EJ1 */



/* EJ2 */
create function EJ2(@articulo char(8), @fecha smalldatetime)
returns numeric(12,2)
begin
	return (select sum(stoc_cantidad) from STOCK where stoc_producto = @articulo) 
			+ 
			(select sum(item_cantidad) from Item_Factura 
			join Factura on item_tipo+item_sucursal+item_numero=fact_tipo+fact_sucursal+fact_numero
			where fact_fecha >= @fecha)
end
go

/*
Cree el/los objetos de base de datos necesarios para corregir la tabla empleado
en caso que sea necesario. Se sabe que debería existir un único gerente general
(debería ser el único empleado sin jefe). Si detecta que hay más de un empleado
sin jefe deberá elegir entre ellos el gerente general, el cual será seleccionado por
mayor salario. Si hay más de uno se seleccionara el de mayor antigüedad en la
empresa. Al finalizar la ejecución del objeto la tabla deberá cumplir con la regla
de un único empleado sin jefe (el gerente general) y deberá retornar la cantidad
de empleados que había sin jefe antes de la ejecución
*/


create proc seleccionarGerente(@cantEmpleados numeric(12,2) OUTPUT)
as 
	select @cantEmpleados = count(*) from Empleado where empl_jefe is null
	if(@cantEmpleados > 1)
	begin
		declare @idNuevoGerente numeric(6)
		select top 1 @idNuevoGerente = empl_codigo 
			from Empleado 
			where empl_jefe is null 
			order by empl_salario desc, empl_ingreso asc
		update Empleado set empl_jefe = @idNuevoGerente
			where empl_jefe is null and empl_codigo <> @idNuevoGerente
	end
go

/* como lo pruebo? */
begin
declare @cantidad_emp int
exec dbo.seleccionarGerente @cantidad_emp output 
select @cantidad_emp
end
go

/* EJ9 */
/* Crear el/los objetos de base de datos que ante alguna modificación de un ítem de
factura de un artículo con composición realice el movimiento de sus
correspondientes componentes. */
create trigger modificarComposicion on Item_Factura for update
as
begin
	declare @componente char(8), @cantidad decimal(12,2)
	/* VER RESOLUCION DE MANRIQUE */
end
go
/* EJ4 */
/*
Cree el/los objetos de base de datos necesarios para actualizar la columna de
empleado empl_comision con la sumatoria del total de lo vendido por ese
empleado a lo largo del último año. Se deberá retornar el código del vendedor
que más vendió (en monto) a lo largo del último año.
*/
/* MALISIMA SOLUCION */
create proc actualizarComision(@mayorVendedor numeric(6) output)
as
	declare @codEmpleado numeric(6)
	declare @totalVenta decimal(12,2)
	declare empleadosConVenta cursor for select empl_codigo, isnull(sum(fact_total) * empl_comision,0) from Empleado 
								left join Factura on fact_vendedor = empl_codigo
								where year(fact_fecha) = (select max(year(fact_fecha)) from Factura)
								group by empl_codigo
	open empleadosConVenta
	fetch from empleadosConVenta into @codEmpleado, @totalVenta
	while (@@FETCH_STATUS <> -1)
	begin
		update Empleado set empl_comision = @totalVenta where empl_codigo = @codEmpleado
		fetch from empleadosConVenta into @codEmpleado, @totalVenta
	end
	close empleadosConVenta
	deallocate empleadosConVenta
	select top 1 @mayorVendedor = sum(fact_total) from Empleado 
								join Factura on fact_vendedor = empl_codigo
								where year(fact_fecha) = (select max(fact_fecha) from Factura)
								group by empl_codigo
								order by sum(fact_total) desc
go
/* SOLUCION DE REINOSA */
create proc actualizarComision2(@mayorVendedor numeric(6) output)
as
	update Empleado set empl_salario = empl_salario + ((select sum(fact_total) from Factura 
								where fact_vendedor = empl_codigo 
								and year(fact_fecha) = (select max(fact_fecha) from Factura))
							* empl_comision)

	select top 1 @mayorVendedor = sum(fact_total) from Empleado 
								join Factura on fact_vendedor = empl_codigo
								where year(fact_fecha) = (select max(fact_fecha) from Factura)
								group by empl_codigo
								order by sum(fact_total) desc
go

/* EJ10 */
/*
Crear el/los objetos de base de datos que ante el intento de borrar un artículo
verifique que no exista stock y si es así lo borre en caso contrario que emita un
mensaje de error.
*/
create trigger verificarEliminacion on Producto instead of delete
as
begin
	if((select count(*) from STOCK join deleted on stoc_producto = prod_codigo and stoc_cantidad > 0) <> 0)
	begin
		raiserror('ERROR sos un mogolico', 1, 1)
	end
	delete from stock where stoc_producto in (select prod_codigo from deleted)
end
go

/* EJ 6 */
/*Realizar un procedimiento que si en alguna factura se facturaron componentes
que conforman un combo determinado (o sea que juntos componen otro
producto de mayor nivel), en cuyo caso deberá reemplazar las filas
correspondientes a dichos productos por una sola fila con el producto que
componen con la cantidad de dicho producto que corresponda*/
/* BLA BLA BLE MAXIMUS */
/* perdi muchos ejercicios */

/* EJ16 */
create trigger ej16 on Item_Factura after insert
as 
begin
	declare @producto char(8), @cantidad int
	declare c1 cursor for select item_producto, item_cantidad from inserted
	open c1
	fetch c1 into @producto, @cantidad
	while @@FETCH_STATUS = 0
	begin
		exec restarStock @producto, @cantidad
		fetch c1 into @producto, @cantidad
	end
	close c1
	deallocate c1
end
go

create or alter proc restarStock (@producto char(8), @cantidad int)
as
begin
	declare @cantidadStock int, @deposito char(2) , @ultimoDeposito char(2)
	declare c1 cursor for select stoc_cantidad, stoc_deposito from STOCK where stoc_producto = @producto order by stoc_cantidad desc
	open c1
	fetch c1 into @cantidadStock, @deposito
	while @producto > 0 and @@FETCH_STATUS = 0
	begin
		if @cantidadStock > @cantidad
		begin
			update STOCK set stoc_cantidad = stoc_cantidad - @cantidad 
			select * from STOCK where stoc_deposito = @deposito and stoc_producto = @producto
		end
		else
			update STOCK set stoc_cantidad = 0
			select * from STOCK where stoc_deposito = @deposito and stoc_producto = @producto
			select @cantidad = @cantidad - @cantidadStock
		select @ultimoDeposito = @deposito
		fetch c1 into @cantidadStock, @deposito
	end
	if @cantidad > 0
	update STOCK set stoc_cantidad = stoc_cantidad - @cantidad 
			select * from STOCK where stoc_deposito = @ultimoDeposito and stoc_producto = @producto
	close c1
	deallocate c1
end
go

/* EJ17 */ -- tmb se podria con instead of, pero es mucho mas largo (si tuviera que ver 1 por 1, si o si asi)
create trigger ej17 on STOCK after update, insert
as
begin
	if (exists(select * from inserted where stoc_cantidad < stoc_punto_reposicion or stoc_cantidad > stoc_stock_maximo))
		rollback
end
go

/* EJ18 */
create trigger ej18 on factura for insert
as 
begin
	if exists(select * from inserted i
				join Cliente on i.fact_cliente = clie_codigo
				where clie_limite_credito < i.fact_total+(select sum(fact_total) 
														from Factura f 
														where f.fact_cliente = clie_codigo 
															and MONTH(f.fact_fecha) = MONTH(i.fact_fecha)) + 
														(select sum(fact_total) 
														from Inserted f 
														where f.fact_cliente = clie_codigo and f.fact_numero <> i.fact_numero
															and MONTH(f.fact_fecha) = MONTH(i.fact_fecha)))
		print('Alguno no cumple la regla')
		rollback
end
go

/* EJ19 */
create trigger ej19 on Empleado after insert, update, delete
as
begin
	if exists(select * from Empleado 
			where empl_codigo in (select empl_jefe from Empleado) and year(CURRENT_DATE) - year(empl_ingreso) < 5)
		rollback


end
go

create function cantSubordinados(@empleado int)
returns int
as
begin
	declare @cantidad int
	select @cantidad = count(*) from Empleado where empl_jefe = @empleado
	
end
go

create trigger prueba1 on Empleado for insert
as
begin
	declare @cant int
	select @cant = (select count(*) from Empleado)
	print(@cant)

end
go

insert into Empleado (empl_codigo) 
values
(123.0)
go
/*
25. Desarrolle el/los elementos de base de datos necesarios para que no se permita
que la composición de los productos sea recursiva, o sea, que si el producto A
compone al producto B, dicho producto B no pueda ser compuesto por el
producto A, hoy la regla se cumple.
*/
create trigger ej25 on Composicion for insert, update
as
begin
	declare @producto char(8), @componente char(8)
	declare c1 cursor for select comp_producto, comp_componente from inserted
	open c1
	fetch next into @producto
	while @@FETCH_STATUS = 0
	begin
		if exists(
			select * from Composicion
			where comp_componente = @producto and comp_producto = @componente
			)
			rollback
		fetch next into @producto
	end
	close c1
	deallocate c1
end
go

create or alter trigger pruebaCantidad on Rubro For insert
as
begin
	declare @cant int
	select @cant = count(*) from Rubro
	print(@cant)
	rollback
end
go
insert into rubro values (9898, 'PIES') 
select * from Rubro
go
/*
27. Se requiere reasignar los encargados de stock de los diferentes depósitos. Para
ello se solicita que realice el o los objetos de base de datos necesarios para
asignar a cada uno de los depósitos el encargado que le corresponda,
entendiendo que el encargado que le corresponde es cualquier empleado que no
es jefe y que no es vendedor, o sea, que no está asignado a ningun cliente, se
deberán ir asignando tratando de que un empleado solo tenga un deposito
asignado, en caso de no poder se irán aumentando la cantidad de depósitos
progresivamente para cada empleado.
*/
create proc ej27 
as
begin
	declare @deposito char(2)
	declare c1 cursor for select depo_codigo from DEPOSITO
	open c1
	fetch next into @deposito
	while @@FETCH_STATUS = 0
	begin
		exec dbo.reasignarEncargado @deposito
	end
	close c1
	deallocate c1
end
go

create proc reasignarEncargado (@deposito char(2))
as
begin
	declare @nuevoEncargado numeric(6)
	select top 1 @nuevoEncargado = empl_codigo from Empleado
	left join DEPOSITO on depo_encargado = empl_codigo
	where 
		empl_codigo not in (
			select j.empl_codigo from Empleado j
			join Empleado e on e.empl_jefe = j.empl_codigo
		) and 
		empl_codigo not in (
			select empl_codigo from Empleado
			join Cliente on clie_vendedor = empl_codigo
		)
	group by empl_codigo
	order by count(*)

	if @nuevoEncargado is not null
	begin
		update DEPOSITO set depo_encargado = @nuevoEncargado
		where depo_codigo = @deposito
	end

end
go

