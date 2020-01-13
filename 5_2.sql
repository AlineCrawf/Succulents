--Составить хранимую процедуру для отображения информации о состоянии выполнения определенного заказа на текущий момент 
--(номер заказа передавать как параметр). 
--При этом отобразить данные о статусе заказа, клиенте, адресе доставки, цветкам, входящим в заказ, и их количестве.

CREATE OR REPLACE FUNCTION sale_info (sale_number int) 
RETURNS TABLE ("Статус заказа" sale_status, "ФИО клиента" varchar
			  ,"Адресс доставки" adress, "Цветок" varchar, "Количество" int)
AS $$
BEGIN
	RETURN QUERY SELECT s.status, (u.name||' '||u.surname):: varchar, 
											CASE WHEN  ads.id IS NULL 
												THEN (u).adress 
												ELSE (ads).adress END,
			f.name, sd.amount 
	FROM Sale s
	INNER JOIN "User" u ON u.id = s.id_user
	LEFT OUTER JOIN Adress_sale ads ON ads.id = s.id_adress
	INNER JOIN Sale_detail sd ON sd.id_sale = s.id	
	INNER JOIN Flower f ON f.id = sd.id_flower
	WHERE s.id = sale_number;
	
END
$$ LANGUAGE plpgsql;