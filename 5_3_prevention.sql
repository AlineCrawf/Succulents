WITH No_prevention AS
(
	SELECT g.id, COUNT(prev.id)
	FROM Greenhouse g 
	LEFT OUTER JOIN Prevention prev ON prev.id_greenhouse = g.id
	WHERE prev.date BETWEEN CURRENT_DATE - interval '1 month' AND CURRENT_DATE
	GROUP BY g.id
)

SELECT fw.id "Номер на складе", f.name "Название"
FROM Flower_warehouse fw
INNER JOIN Flower f ON f.id = fw.id_flower
WHERE fw.id_greenhouse NOT IN (SELECT id FROM No_prevention)
ORDER BY 1