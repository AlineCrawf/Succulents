--Получить список растений, которые в прошлом году (год должен определяться автоматически,в зависимости от момента выполнения
--запроса) были проданы максимальное количество раз (таких растений может быть несколько).
CREATE OR REPLACE VIEW Flower_sum AS(
			SELECT f.id "flower", SUM(sd.amount) sum_amount
			FROM Flower f
			INNER JOIN Sale_detail sd ON sd.id_flower=f.id
			INNER JOIN Sale s ON s.id = sd.id_sale
			INNER JOIN Sale_Flower sf ON sf.id_sale_detail = sd.id
			WHERE s.buy_date BETWEEN CURRENT_DATE - interval '1 year' AND CURRENT_DATE
			GROUP BY 1
			ORDER BY 1);

WITH Top_Flower_Rank AS
(
		SELECT "flower", DENSE_RANK() OVER(ORDER BY sum_amount) "Rank"
		FROM Flower_sum
)

SELECT f.name
FROM Top_Flower_Rank tfr
INNER JOIN Flower f ON tfr."flower" = f.id 
WHERE "Rank" = 1;