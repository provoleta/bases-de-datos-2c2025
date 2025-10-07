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
