-- Составить триггер, который при оформлении заказа будет блокировать ввод количества цветков, превышающего количество доступных экземпляров.
CREATE OR REPLACE FUNCTION check_flower_amount() RETURNS TRIGGER 
AS $$
	DECLARE flower_sum INT;
			sale_sum INT ;
	BEGIN
		SELECT COALESCE (SUM(fw.amount), 0) INTO flower_sum
		FROM Flower_warehouse fw
		WHERE fw.ready_to_sale IS TRUE AND  fw.id_flower = NEW.id_flower ;		
		
		
		SELECT COALESCE(SUM(sd.amount), 0) INTO sale_sum
		FROM Sale s
		INNER JOIN Sale_detail sd ON s.id = sd.id_sale
		WHERE sd.id_flower = NEW.id_flower;
		
		IF (NEW.amount> flower_sum - sale_sum)
			THEN RAISE EXCEPTION 
				'Количество цветов в заказе (%) превышает количество на складе (%)',NEW.amount,flower_sum - sale_sum ;
		END IF;
		RETURN NEW;
	END;
$$ LANGUAGE plpgsql;

-- CREATE TRIGGER New_sale 
-- 		BEFORE INSERT ON Sale_detail
--		FOR EACH ROW
--		EXECUTE PROCEDURE check_flower_amount();
		
