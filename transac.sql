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