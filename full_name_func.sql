--DROP FUNCTION full_name(integer);
DROP FUNCTION full_name(int);
CREATE OR REPLACE FUNCTION Full_name(id_flower int) RETURNS TEXT AS $$
		DECLARE flower_full_name TEXT; 
        BEGIN
                WITH RECURSIVE full_name (id, id_parent, name, fullname) AS (
													SELECT f.id, f.id_parent, f.name, (''::text) as fullname
													FROM Flower f
													WHERE f.id_parent IS NULL
													UNION 
													SELECT f.id, f.id_parent, f.name, fn.fullname||' '||f.name
													FROM Flower f
													INNER JOIN full_name fn ON fn.id = f.id_parent
)
				SELECT fn.fullname INTO flower_full_name
				FROM full_name fn
				WHERE fn.id = $1;
				RETURN flower_full_name;
		END;
$$ LANGUAGE plpgsql;