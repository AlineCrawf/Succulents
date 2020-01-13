--Получить список растений, которые в текущем месяце 
--(месяц должен определяться автоматически, в зависимости от момента выполнения запроса) не были проданы ни разу.

WITH Sale_for_month AS (
					SELECT sd.id_flower
				  	FROM  Sale s
				  	INNER JOIN Sale_detail sd ON sd.id_sale = s.id
				  	WHERE s.buy_date BETWEEN CURRENT_DATE - interval '1 month' AND CURRENT_DATE
)
SELECT f.name "Цветок"
FROM Flower f
WHERE f.id_parent IS NOT NULL AND
			f.id NOT IN (SELECT * FROM Sale_for_month)
