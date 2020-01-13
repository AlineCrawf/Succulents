--
-- PostgreSQL database dump
--

-- Dumped from database version 11.4
-- Dumped by pg_dump version 11.4

-- Started on 2019-12-17 08:32:09

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 673 (class 1247 OID 59086)
-- Name: adress; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.adress AS (
	code character varying(15),
	city character varying(30),
	street character varying(30),
	phone_number character varying(20)
);


ALTER TYPE public.adress OWNER TO postgres;

--
-- TOC entry 748 (class 1247 OID 59366)
-- Name: email; Type: DOMAIN; Schema: public; Owner: postgres
--

CREATE DOMAIN public.email AS text
	CONSTRAINT email_check CHECK ((VALUE ~ '^[a-zA-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'::text));


ALTER DOMAIN public.email OWNER TO postgres;

--
-- TOC entry 707 (class 1247 OID 59204)
-- Name: purchase_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.purchase_status AS ENUM (
    'not processed',
    'formation',
    'received'
);


ALTER TYPE public.purchase_status OWNER TO postgres;

--
-- TOC entry 685 (class 1247 OID 59112)
-- Name: sale_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.sale_status AS ENUM (
    'not processed',
    'formation',
    'ready to send',
    'sent'
);


ALTER TYPE public.sale_status OWNER TO postgres;

--
-- TOC entry 266 (class 1255 OID 74657)
-- Name: check_flower_amount(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_flower_amount() RETURNS trigger
    LANGUAGE plpgsql
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
$$;


ALTER FUNCTION public.check_flower_amount() OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 74656)
-- Name: check_flower_amount(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_flower_amount(sale_number integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
	BEGIN
	END;
$$;


ALTER FUNCTION public.check_flower_amount(sale_number integer) OWNER TO postgres;

--
-- TOC entry 265 (class 1255 OID 74655)
-- Name: cost(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cost(id_sale integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	DECLARE result numeric;
	BEGIN
		SELECT SUM(fw.cost::numeric*sf.amount) INTO result
		FROM Sale s 
		INNER JOIN Sale_detail sd ON sd.id_sale = s.id
		INNER JOIN Sale_flower sf ON sf.id_sale_detail = sd.id
		INNER JOIN Flower_warehouse fw ON fw.id = sf.id_flower_warehouse
		WHERE s.id = Cost.id_sale;
		RETURN result;
	END;
$$;


ALTER FUNCTION public.cost(id_sale integer) OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 73992)
-- Name: full_name(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.full_name() RETURNS void
    LANGUAGE plpgsql
    AS $$
        BEGIN
                WITH RECURSIVE full_name (id, id_parent, name, fullname) AS (
													SELECT id, id_parent, name, (''::text) as fullname
													FROM Flower
													WHERE id_parent IS NULL
	UNION 
	SELECT f.id, f.id_parent, f.name, fullname||' '||f.name
	FROM Flower f
	INNER JOIN full_name fn ON fn.id = f.id_parent
)
	SELECT *
		FROM full_name;
        END;
$$;


ALTER FUNCTION public.full_name() OWNER TO postgres;

--
-- TOC entry 267 (class 1255 OID 90318)
-- Name: full_name(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.full_name(id_flower integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.full_name(id_flower integer) OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 73991)
-- Name: increment(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.increment(i integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
        BEGIN
                RETURN i + 1;
        END;
$$;


ALTER FUNCTION public.increment(i integer) OWNER TO postgres;

--
-- TOC entry 263 (class 1255 OID 73934)
-- Name: sale_cost(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sale_cost(sale_number integer)
    LANGUAGE plpgsql
    AS $$
	DECLARE cost INT;
	BEGIN
		SELECT SUM(fw.cost::numeric)  
		FROM Sale s 
		INNER JOIN Sale_detail sd ON sd.id_sale = s.id
		INNER JOIN Sale_flower sf ON sf.id_sale_detail = sd.id
		INNER JOIN Flower_warehouse fw ON fw.id = sf.id_flower_warehouse
		WHERE s.id = sale_number;
	END;
$$;


ALTER PROCEDURE public.sale_cost(sale_number integer) OWNER TO postgres;

--
-- TOC entry 268 (class 1255 OID 74667)
-- Name: sale_info(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sale_info(sale_number integer) RETURNS TABLE("Статус заказа" public.sale_status, "ФИО клиента" character varying, "Адресс доставки" public.adress, "Цветок" character varying, "Количество" integer)
    LANGUAGE plpgsql
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
$$;


ALTER FUNCTION public.sale_info(sale_number integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 208 (class 1259 OID 59089)
-- Name: User; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."User" (
    id integer NOT NULL,
    name character varying(20) NOT NULL,
    surname character varying(30) NOT NULL,
    e_mail public.email NOT NULL,
    adress public.adress
);


ALTER TABLE public."User" OWNER TO postgres;

--
-- TOC entry 207 (class 1259 OID 59087)
-- Name: User_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."User_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."User_id_seq" OWNER TO postgres;

--
-- TOC entry 3225 (class 0 OID 0)
-- Dependencies: 207
-- Name: User_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."User_id_seq" OWNED BY public."User".id;


--
-- TOC entry 210 (class 1259 OID 59102)
-- Name: adress_sale; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.adress_sale (
    id integer NOT NULL,
    adress public.adress NOT NULL
);


ALTER TABLE public.adress_sale OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 59100)
-- Name: adress_sale_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.adress_sale_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.adress_sale_id_seq OWNER TO postgres;

--
-- TOC entry 3226 (class 0 OID 0)
-- Dependencies: 209
-- Name: adress_sale_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.adress_sale_id_seq OWNED BY public.adress_sale.id;


--
-- TOC entry 205 (class 1259 OID 59068)
-- Name: dead_flowers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dead_flowers (
    id integer NOT NULL,
    id_flower_warehouse integer NOT NULL,
    date date DEFAULT CURRENT_DATE NOT NULL,
    count integer NOT NULL,
    notes text,
    CONSTRAINT dead_flowers_count_check CHECK ((count > 0)),
    CONSTRAINT dead_flowers_id_flower_warehouse_check CHECK ((id_flower_warehouse > 0))
);


ALTER TABLE public.dead_flowers OWNER TO postgres;

--
-- TOC entry 204 (class 1259 OID 59066)
-- Name: dead_flowers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dead_flowers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dead_flowers_id_seq OWNER TO postgres;

--
-- TOC entry 3227 (class 0 OID 0)
-- Dependencies: 204
-- Name: dead_flowers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dead_flowers_id_seq OWNED BY public.dead_flowers.id;


--
-- TOC entry 199 (class 1259 OID 59014)
-- Name: disease; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.disease (
    id integer NOT NULL,
    name character varying(30) NOT NULL,
    description text,
    foto bytea
);


ALTER TABLE public.disease OWNER TO postgres;

--
-- TOC entry 201 (class 1259 OID 59027)
-- Name: disease_flower; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.disease_flower (
    id integer NOT NULL,
    id_flower integer NOT NULL,
    id_disease integer NOT NULL,
    date date DEFAULT CURRENT_DATE NOT NULL,
    foto bytea NOT NULL,
    notes text,
    CONSTRAINT disease_flower_check CHECK (((id_flower > 0) AND (id_disease > 0)))
);


ALTER TABLE public.disease_flower OWNER TO postgres;

--
-- TOC entry 200 (class 1259 OID 59025)
-- Name: disease_flower_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.disease_flower_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.disease_flower_id_seq OWNER TO postgres;

--
-- TOC entry 3228 (class 0 OID 0)
-- Dependencies: 200
-- Name: disease_flower_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.disease_flower_id_seq OWNED BY public.disease_flower.id;


--
-- TOC entry 198 (class 1259 OID 59012)
-- Name: disease_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.disease_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.disease_id_seq OWNER TO postgres;

--
-- TOC entry 3229 (class 0 OID 0)
-- Dependencies: 198
-- Name: disease_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.disease_id_seq OWNED BY public.disease.id;


--
-- TOC entry 197 (class 1259 OID 58998)
-- Name: flower; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.flower (
    id integer NOT NULL,
    id_parent integer,
    name character varying(20) NOT NULL,
    CONSTRAINT flower_id_parent_check CHECK ((id_parent > 0))
);


ALTER TABLE public.flower OWNER TO postgres;

--
-- TOC entry 196 (class 1259 OID 58996)
-- Name: flower_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.flower_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flower_id_seq OWNER TO postgres;

--
-- TOC entry 3230 (class 0 OID 0)
-- Dependencies: 196
-- Name: flower_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.flower_id_seq OWNED BY public.flower.id;


--
-- TOC entry 212 (class 1259 OID 59123)
-- Name: sale; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale (
    id integer NOT NULL,
    id_user integer NOT NULL,
    id_adress integer,
    buy_date timestamp without time zone DEFAULT CURRENT_DATE NOT NULL,
    status public.sale_status DEFAULT 'not processed'::public.sale_status NOT NULL,
    CONSTRAINT sale_check CHECK (((id_user > 0) AND (id_adress > 0)))
);


ALTER TABLE public.sale OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 59142)
-- Name: sale_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_detail (
    id integer NOT NULL,
    id_sale integer NOT NULL,
    id_flower integer NOT NULL,
    amount integer DEFAULT 1 NOT NULL,
    CONSTRAINT sale_detail_amount_check CHECK ((amount > 0)),
    CONSTRAINT sale_detail_check CHECK (((id_sale > 0) AND (id_flower > 0)))
);


ALTER TABLE public.sale_detail OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 59160)
-- Name: sale_flower; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_flower (
    id_sale_detail integer NOT NULL,
    id_flower_warehouse integer NOT NULL,
    amount integer NOT NULL,
    CONSTRAINT sale_flower_amount_check CHECK ((amount > 0)),
    CONSTRAINT sale_flower_check CHECK (((id_sale_detail > 0) AND (id_flower_warehouse > 0)))
);


ALTER TABLE public.sale_flower OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 90308)
-- Name: flower_sum; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.flower_sum AS
 SELECT f.id AS flower,
    sum(sd.amount) AS sum_amount
   FROM (((public.flower f
     JOIN public.sale_detail sd ON ((sd.id_flower = f.id)))
     JOIN public.sale s ON ((s.id = sd.id_sale)))
     JOIN public.sale_flower sf ON ((sf.id_sale_detail = sd.id)))
  WHERE ((s.buy_date >= (CURRENT_DATE - '1 year'::interval)) AND (s.buy_date <= CURRENT_DATE))
  GROUP BY f.id
  ORDER BY f.id;


ALTER TABLE public.flower_sum OWNER TO postgres;

--
-- TOC entry 203 (class 1259 OID 59049)
-- Name: flower_warehouse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.flower_warehouse (
    id integer NOT NULL,
    id_flower integer NOT NULL,
    ready_to_sale boolean NOT NULL,
    date date DEFAULT CURRENT_DATE NOT NULL,
    amount integer NOT NULL,
    cost money NOT NULL,
    notes text,
    id_greenhouse integer DEFAULT 1,
    CONSTRAINT flower_warehouse_amount_check CHECK ((amount > 0)),
    CONSTRAINT flower_warehouse_cost_check CHECK ((cost > (0)::money)),
    CONSTRAINT flower_warehouse_id_flower_check CHECK ((id_flower > 0))
);


ALTER TABLE public.flower_warehouse OWNER TO postgres;

--
-- TOC entry 202 (class 1259 OID 59047)
-- Name: flower_warehouse_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.flower_warehouse_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flower_warehouse_id_seq OWNER TO postgres;

--
-- TOC entry 3231 (class 0 OID 0)
-- Dependencies: 202
-- Name: flower_warehouse_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.flower_warehouse_id_seq OWNED BY public.flower_warehouse.id;


--
-- TOC entry 242 (class 1259 OID 73938)
-- Name: greenhouse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.greenhouse (
    id integer NOT NULL,
    id_staff integer DEFAULT 1 NOT NULL,
    CONSTRAINT greenhouse_id_staff_check CHECK ((id_staff > 0))
);


ALTER TABLE public.greenhouse OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 73936)
-- Name: greenhouse_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.greenhouse_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.greenhouse_id_seq OWNER TO postgres;

--
-- TOC entry 3232 (class 0 OID 0)
-- Dependencies: 241
-- Name: greenhouse_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.greenhouse_id_seq OWNED BY public.greenhouse.id;


--
-- TOC entry 238 (class 1259 OID 59392)
-- Name: pest; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pest (
    id integer NOT NULL,
    name character varying(30) NOT NULL
);


ALTER TABLE public.pest OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 59402)
-- Name: pest_flower; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pest_flower (
    id integer NOT NULL,
    id_flower integer NOT NULL,
    id_pest integer NOT NULL,
    date date DEFAULT CURRENT_DATE NOT NULL,
    foto bytea,
    notes text,
    CONSTRAINT pest_flower_date_check CHECK ((date <= CURRENT_DATE)),
    CONSTRAINT pest_flower_id_flower_check CHECK ((id_flower > 0)),
    CONSTRAINT pest_flower_id_pest_check CHECK ((id_pest > 0))
);


ALTER TABLE public.pest_flower OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 59400)
-- Name: pest_flower_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pest_flower_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pest_flower_id_seq OWNER TO postgres;

--
-- TOC entry 3233 (class 0 OID 0)
-- Dependencies: 239
-- Name: pest_flower_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pest_flower_id_seq OWNED BY public.pest_flower.id;


--
-- TOC entry 237 (class 1259 OID 59390)
-- Name: pest_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pest_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pest_id_seq OWNER TO postgres;

--
-- TOC entry 3234 (class 0 OID 0)
-- Dependencies: 237
-- Name: pest_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pest_id_seq OWNED BY public.pest.id;


--
-- TOC entry 217 (class 1259 OID 59179)
-- Name: position_rate; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.position_rate (
    id integer NOT NULL,
    "position" character varying(30) NOT NULL,
    rate money NOT NULL,
    CONSTRAINT position_rate_rate_check CHECK ((rate > (0)::money))
);


ALTER TABLE public.position_rate OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 59177)
-- Name: position_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.position_rate_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.position_rate_id_seq OWNER TO postgres;

--
-- TOC entry 3235 (class 0 OID 0)
-- Dependencies: 216
-- Name: position_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.position_rate_id_seq OWNED BY public.position_rate.id;


--
-- TOC entry 226 (class 1259 OID 59259)
-- Name: preparation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.preparation (
    id integer NOT NULL,
    id_type integer NOT NULL,
    name character varying(30) NOT NULL,
    CONSTRAINT preparation_id_type_check CHECK ((id_type > 0))
);


ALTER TABLE public.preparation OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 59257)
-- Name: preparation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.preparation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.preparation_id_seq OWNER TO postgres;

--
-- TOC entry 3236 (class 0 OID 0)
-- Dependencies: 225
-- Name: preparation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.preparation_id_seq OWNED BY public.preparation.id;


--
-- TOC entry 224 (class 1259 OID 59249)
-- Name: preparation_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.preparation_type (
    id integer NOT NULL,
    name character varying(30) NOT NULL
);


ALTER TABLE public.preparation_type OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 59247)
-- Name: preparation_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.preparation_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.preparation_type_id_seq OWNER TO postgres;

--
-- TOC entry 3237 (class 0 OID 0)
-- Dependencies: 223
-- Name: preparation_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.preparation_type_id_seq OWNED BY public.preparation_type.id;


--
-- TOC entry 228 (class 1259 OID 59273)
-- Name: prevention; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prevention (
    id integer NOT NULL,
    id_staff integer NOT NULL,
    date date DEFAULT CURRENT_DATE NOT NULL,
    cause text,
    note text,
    id_greenhouse integer DEFAULT 1 NOT NULL,
    CONSTRAINT prevention_id_greenhouse_check CHECK ((id_greenhouse > 0)),
    CONSTRAINT prevention_id_staff_check CHECK ((id_staff > 0))
);


ALTER TABLE public.prevention OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 59288)
-- Name: prevention_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prevention_detail (
    id_preparation integer NOT NULL,
    id_prevention integer NOT NULL,
    CONSTRAINT prevention_detail_check CHECK (((id_preparation > 0) AND (id_prevention > 0)))
);


ALTER TABLE public.prevention_detail OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 59271)
-- Name: prevention_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.prevention_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.prevention_id_seq OWNER TO postgres;

--
-- TOC entry 3238 (class 0 OID 0)
-- Dependencies: 227
-- Name: prevention_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.prevention_id_seq OWNED BY public.prevention.id;


--
-- TOC entry 221 (class 1259 OID 59213)
-- Name: purchase; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.purchase (
    id integer NOT NULL,
    id_staff integer NOT NULL,
    date timestamp without time zone DEFAULT CURRENT_DATE NOT NULL,
    status public.purchase_status DEFAULT 'not processed'::public.purchase_status NOT NULL,
    notes text,
    CONSTRAINT purchase_id_staff_check CHECK ((id_staff > 0))
);


ALTER TABLE public.purchase OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 59229)
-- Name: purchase_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.purchase_detail (
    id_flower integer NOT NULL,
    id_purchase integer NOT NULL,
    amount integer NOT NULL,
    cost money NOT NULL,
    CONSTRAINT purchase_detail_amount_check CHECK ((amount > 0)),
    CONSTRAINT purchase_detail_check CHECK (((id_flower > 0) AND (id_purchase > 0))),
    CONSTRAINT purchase_detail_cost_check CHECK ((cost > (0)::money))
);


ALTER TABLE public.purchase_detail OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 59211)
-- Name: purchase_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.purchase_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.purchase_id_seq OWNER TO postgres;

--
-- TOC entry 3239 (class 0 OID 0)
-- Dependencies: 220
-- Name: purchase_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.purchase_id_seq OWNED BY public.purchase.id;


--
-- TOC entry 213 (class 1259 OID 59140)
-- Name: sale_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sale_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sale_detail_id_seq OWNER TO postgres;

--
-- TOC entry 3240 (class 0 OID 0)
-- Dependencies: 213
-- Name: sale_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sale_detail_id_seq OWNED BY public.sale_detail.id;


--
-- TOC entry 211 (class 1259 OID 59121)
-- Name: sale_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sale_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sale_id_seq OWNER TO postgres;

--
-- TOC entry 3241 (class 0 OID 0)
-- Dependencies: 211
-- Name: sale_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sale_id_seq OWNED BY public.sale.id;


--
-- TOC entry 248 (class 1259 OID 90499)
-- Name: sale_sum; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_sum (
    sum bigint
);


ALTER TABLE public.sale_sum OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 73966)
-- Name: sheduled_prevention; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sheduled_prevention (
    id integer NOT NULL,
    id_greenhouse integer NOT NULL,
    date date NOT NULL,
    cause text,
    CONSTRAINT sheduled_prevention_id_greenhouse_check CHECK ((id_greenhouse > 0))
);


ALTER TABLE public.sheduled_prevention OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 73964)
-- Name: sheduled_prevention_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sheduled_prevention_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sheduled_prevention_id_seq OWNER TO postgres;

--
-- TOC entry 3242 (class 0 OID 0)
-- Dependencies: 243
-- Name: sheduled_prevention_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sheduled_prevention_id_seq OWNED BY public.sheduled_prevention.id;


--
-- TOC entry 219 (class 1259 OID 59190)
-- Name: staff; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.staff (
    id integer NOT NULL,
    name character varying(20) NOT NULL,
    surname character varying(30) NOT NULL,
    patronymie character varying(30),
    id_position integer NOT NULL,
    salary money DEFAULT 100 NOT NULL,
    allowance numeric DEFAULT 0 NOT NULL,
    CONSTRAINT staff_id_position_check CHECK ((id_position > 0))
);


ALTER TABLE public.staff OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 59188)
-- Name: staff_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.staff_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.staff_id_seq OWNER TO postgres;

--
-- TOC entry 3243 (class 0 OID 0)
-- Dependencies: 218
-- Name: staff_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.staff_id_seq OWNED BY public.staff.id;


--
-- TOC entry 233 (class 1259 OID 59316)
-- Name: stock; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stock (
    id integer NOT NULL,
    id_type integer NOT NULL,
    name character varying(30) NOT NULL,
    amount integer NOT NULL,
    CONSTRAINT stock_amount_check CHECK ((amount > 0)),
    CONSTRAINT stock_id_type_check CHECK ((id_type > 0))
);


ALTER TABLE public.stock OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 59314)
-- Name: stock_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stock_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stock_id_seq OWNER TO postgres;

--
-- TOC entry 3244 (class 0 OID 0)
-- Dependencies: 232
-- Name: stock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stock_id_seq OWNED BY public.stock.id;


--
-- TOC entry 235 (class 1259 OID 59333)
-- Name: stock_purchase; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stock_purchase (
    id integer NOT NULL,
    id_staff integer NOT NULL,
    date date DEFAULT CURRENT_DATE NOT NULL,
    status public.purchase_status DEFAULT 'not processed'::public.purchase_status NOT NULL,
    CONSTRAINT stock_purchase_id_staff_check CHECK ((id_staff > 0))
);


ALTER TABLE public.stock_purchase OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 59346)
-- Name: stock_purchase_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stock_purchase_detail (
    id_stock integer NOT NULL,
    id_stock_purchase integer NOT NULL,
    amount integer,
    cost money,
    CONSTRAINT stock_purchase_detail_amount_check CHECK ((amount > 0)),
    CONSTRAINT stock_purchase_detail_check CHECK (((id_stock > 0) AND (id_stock_purchase > 0))),
    CONSTRAINT stock_purchase_detail_cost_check CHECK ((cost > (0)::money))
);


ALTER TABLE public.stock_purchase_detail OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 59331)
-- Name: stock_purchase_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stock_purchase_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stock_purchase_id_seq OWNER TO postgres;

--
-- TOC entry 3245 (class 0 OID 0)
-- Dependencies: 234
-- Name: stock_purchase_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stock_purchase_id_seq OWNED BY public.stock_purchase.id;


--
-- TOC entry 231 (class 1259 OID 59306)
-- Name: stock_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stock_type (
    id integer NOT NULL,
    name character varying(30) NOT NULL
);


ALTER TABLE public.stock_type OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 59304)
-- Name: stock_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stock_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stock_type_id_seq OWNER TO postgres;

--
-- TOC entry 3246 (class 0 OID 0)
-- Dependencies: 230
-- Name: stock_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stock_type_id_seq OWNED BY public.stock_type.id;


--
-- TOC entry 246 (class 1259 OID 82128)
-- Name: sum_for_month; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.sum_for_month AS
 SELECT date_part('month'::text, s.buy_date) AS month,
    sum((fw.cost * sd.amount)) AS sum
   FROM (((public.sale s
     JOIN public.sale_detail sd ON ((sd.id_sale = s.id)))
     JOIN public.sale_flower sf ON ((sf.id_sale_detail = sd.id)))
     JOIN public.flower_warehouse fw ON ((fw.id = sf.id_flower_warehouse)))
  WHERE ((s.buy_date >= (CURRENT_DATE - '1 year'::interval)) AND (s.buy_date <= CURRENT_DATE))
  GROUP BY (date_part('month'::text, s.buy_date));


ALTER TABLE public.sum_for_month OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 82121)
-- Name: sum_for_year; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.sum_for_year AS
 SELECT sum_month.month,
    sum(sum_month.sum) OVER (ORDER BY sum_month.month) AS sum
   FROM public.sum_for_month sum_month;


ALTER TABLE public.sum_for_year OWNER TO postgres;

--
-- TOC entry 2892 (class 2604 OID 59092)
-- Name: User id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User" ALTER COLUMN id SET DEFAULT nextval('public."User_id_seq"'::regclass);


--
-- TOC entry 2893 (class 2604 OID 59105)
-- Name: adress_sale id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adress_sale ALTER COLUMN id SET DEFAULT nextval('public.adress_sale_id_seq'::regclass);


--
-- TOC entry 2888 (class 2604 OID 59071)
-- Name: dead_flowers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dead_flowers ALTER COLUMN id SET DEFAULT nextval('public.dead_flowers_id_seq'::regclass);


--
-- TOC entry 2878 (class 2604 OID 59017)
-- Name: disease id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disease ALTER COLUMN id SET DEFAULT nextval('public.disease_id_seq'::regclass);


--
-- TOC entry 2879 (class 2604 OID 59030)
-- Name: disease_flower id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disease_flower ALTER COLUMN id SET DEFAULT nextval('public.disease_flower_id_seq'::regclass);


--
-- TOC entry 2876 (class 2604 OID 59001)
-- Name: flower id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flower ALTER COLUMN id SET DEFAULT nextval('public.flower_id_seq'::regclass);


--
-- TOC entry 2882 (class 2604 OID 59052)
-- Name: flower_warehouse id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flower_warehouse ALTER COLUMN id SET DEFAULT nextval('public.flower_warehouse_id_seq'::regclass);


--
-- TOC entry 2943 (class 2604 OID 73941)
-- Name: greenhouse id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.greenhouse ALTER COLUMN id SET DEFAULT nextval('public.greenhouse_id_seq'::regclass);


--
-- TOC entry 2937 (class 2604 OID 59395)
-- Name: pest id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pest ALTER COLUMN id SET DEFAULT nextval('public.pest_id_seq'::regclass);


--
-- TOC entry 2938 (class 2604 OID 59405)
-- Name: pest_flower id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pest_flower ALTER COLUMN id SET DEFAULT nextval('public.pest_flower_id_seq'::regclass);


--
-- TOC entry 2904 (class 2604 OID 59182)
-- Name: position_rate id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.position_rate ALTER COLUMN id SET DEFAULT nextval('public.position_rate_id_seq'::regclass);


--
-- TOC entry 2918 (class 2604 OID 59262)
-- Name: preparation id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preparation ALTER COLUMN id SET DEFAULT nextval('public.preparation_id_seq'::regclass);


--
-- TOC entry 2917 (class 2604 OID 59252)
-- Name: preparation_type id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preparation_type ALTER COLUMN id SET DEFAULT nextval('public.preparation_type_id_seq'::regclass);


--
-- TOC entry 2920 (class 2604 OID 59276)
-- Name: prevention id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prevention ALTER COLUMN id SET DEFAULT nextval('public.prevention_id_seq'::regclass);


--
-- TOC entry 2910 (class 2604 OID 59216)
-- Name: purchase id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase ALTER COLUMN id SET DEFAULT nextval('public.purchase_id_seq'::regclass);


--
-- TOC entry 2894 (class 2604 OID 59126)
-- Name: sale id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale ALTER COLUMN id SET DEFAULT nextval('public.sale_id_seq'::regclass);


--
-- TOC entry 2898 (class 2604 OID 59145)
-- Name: sale_detail id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_detail ALTER COLUMN id SET DEFAULT nextval('public.sale_detail_id_seq'::regclass);


--
-- TOC entry 2946 (class 2604 OID 73969)
-- Name: sheduled_prevention id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sheduled_prevention ALTER COLUMN id SET DEFAULT nextval('public.sheduled_prevention_id_seq'::regclass);


--
-- TOC entry 2906 (class 2604 OID 59193)
-- Name: staff id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff ALTER COLUMN id SET DEFAULT nextval('public.staff_id_seq'::regclass);


--
-- TOC entry 2927 (class 2604 OID 59319)
-- Name: stock id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock ALTER COLUMN id SET DEFAULT nextval('public.stock_id_seq'::regclass);


--
-- TOC entry 2930 (class 2604 OID 59336)
-- Name: stock_purchase id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_purchase ALTER COLUMN id SET DEFAULT nextval('public.stock_purchase_id_seq'::regclass);


--
-- TOC entry 2926 (class 2604 OID 59309)
-- Name: stock_type id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_type ALTER COLUMN id SET DEFAULT nextval('public.stock_type_id_seq'::regclass);


--
-- TOC entry 3182 (class 0 OID 59089)
-- Dependencies: 208
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public."User" (id, name, surname, e_mail, adress) VALUES (3, 'Aline', 'Tkachenko', 'dhhfhh@jhk', '(,Odessa,"sth st",)');
INSERT INTO public."User" (id, name, surname, e_mail, adress) VALUES (4, 'София', 'Мельник', 'sophiya@gmail.com', '(60005,Odessa,"Адмиральский проспект, 20",380634578922)');
INSERT INTO public."User" (id, name, surname, e_mail, adress) VALUES (5, 'Мария', 'Шевченко', 'maria@gmail.com', '(60005,Odessa,"Контр-Адмирала Лунина, 4",380635756462)');
INSERT INTO public."User" (id, name, surname, e_mail, adress) VALUES (7, 'Иван', 'Коваленко', 'ivan@gmail.com', '(60005,Odessa,"Гвардейская, 2а",380935789910)');
INSERT INTO public."User" (id, name, surname, e_mail, adress) VALUES (8, 'Марк', 'Бондаренко', 'mark@gmail.com', '(60005,Odessa,"Леваневского тупик, 2/1а",380634569445)');
INSERT INTO public."User" (id, name, surname, e_mail, adress) VALUES (9, 'Дмитрий', 'Ткаченко', 'dima@gmail.com', '(60005,Odessa,"Литературная, 1а",380634587006)');
INSERT INTO public."User" (id, name, surname, e_mail, adress) VALUES (10, 'Александр', 'Ковальчук', 'alexander@gmail.com', '(60005,Odessa,"Клубничный переулок, 2",380638776602)');
INSERT INTO public."User" (id, name, surname, e_mail, adress) VALUES (11, 'Владислав', 'Кравченко', 'vlad@gmail.com', '(60005,Odessa,"Морской переулок, 14",380638774544)');
INSERT INTO public."User" (id, name, surname, e_mail, adress) VALUES (12, 'Матвей', 'Олейник', 'matvey@gmail.com', '(60005,Odessa,"Генуэзская, 5",380638776698)');
INSERT INTO public."User" (id, name, surname, e_mail, adress) VALUES (13, 'Елизавета', 'Шевчук', 'liza@gmail.com', '(60005,Odessa,"Французский бульвар, 52 к1",380638674468)');


--
-- TOC entry 3184 (class 0 OID 59102)
-- Dependencies: 210
-- Data for Name: adress_sale; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.adress_sale (id, adress) VALUES (1, '(60005,Odessa,"НП 6",380638744487)');
INSERT INTO public.adress_sale (id, adress) VALUES (2, '(60005,Odessa,"НП 6",380635514400)');
INSERT INTO public.adress_sale (id, adress) VALUES (3, '(60005,Odessa,"НП 6",380938426930)');
INSERT INTO public.adress_sale (id, adress) VALUES (4, '(60005,Odessa,"НП 6",380739854578)');
INSERT INTO public.adress_sale (id, adress) VALUES (5, '(60005,Odessa,"НП 6",380738483332)');


--
-- TOC entry 3180 (class 0 OID 59068)
-- Dependencies: 205
-- Data for Name: dead_flowers; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (1, 8, '2019-10-12', 1, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (2, 8, '2019-09-12', 1, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (3, 8, '2019-10-12', 1, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (4, 8, '2019-08-12', 1, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (5, 8, '2019-04-12', 1, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (6, 10, '2019-04-12', 1, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (7, 10, '2019-04-12', 1, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (8, 10, '2019-04-11', 1, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (9, 10, '2019-10-12', 1, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (10, 10, '2019-11-12', 1, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (12, 3, '2019-11-27', 7, NULL);
INSERT INTO public.dead_flowers (id, id_flower_warehouse, date, count, notes) VALUES (13, 3, '2019-11-27', 4, NULL);


--
-- TOC entry 3174 (class 0 OID 59014)
-- Dependencies: 199
-- Data for Name: disease; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.disease (id, name, description, foto) VALUES (1, 'Фузариоз', 'Грибок поражает корни и распространяется по проводящим жилкам вверх суккулента. На разрезе виден ржавый окрас пораженных тканей. Внешние признаки остановка роста, снижение тургора листьев и ствола, бледная окраска.', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (2, 'Название', 'Описание', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (3, 'имя1', 'грибками', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (4, 'имя2', 'грибков', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (5, 'имя3', 'грибкамй', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (6, 'имя4', 'грибков', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (7, 'имя5', 'грибок', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (8, 'имя6', 'грибками ', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (9, 'имя7', 'грибков ', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (10, 'имя8', 'грибкамй ', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (11, 'имя9', 'грибков ', NULL);
INSERT INTO public.disease (id, name, description, foto) VALUES (12, 'имя10', 'грибок ', NULL);


--
-- TOC entry 3176 (class 0 OID 59027)
-- Dependencies: 201
-- Data for Name: disease_flower; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.disease_flower (id, id_flower, id_disease, date, foto, notes) VALUES (2, 8, 1, '2019-11-25', '\x0030', NULL);
INSERT INTO public.disease_flower (id, id_flower, id_disease, date, foto, notes) VALUES (3, 12, 1, '2019-11-25', '\x0030', NULL);
INSERT INTO public.disease_flower (id, id_flower, id_disease, date, foto, notes) VALUES (4, 11, 1, '2019-11-25', '\x0030', NULL);
INSERT INTO public.disease_flower (id, id_flower, id_disease, date, foto, notes) VALUES (5, 10, 1, '2019-11-25', '\x0030', NULL);
INSERT INTO public.disease_flower (id, id_flower, id_disease, date, foto, notes) VALUES (6, 9, 1, '2019-11-25', '\x0030', NULL);
INSERT INTO public.disease_flower (id, id_flower, id_disease, date, foto, notes) VALUES (7, 13, 2, '2019-11-25', '\x0030', NULL);
INSERT INTO public.disease_flower (id, id_flower, id_disease, date, foto, notes) VALUES (8, 12, 2, '2019-11-25', '\x0030', NULL);
INSERT INTO public.disease_flower (id, id_flower, id_disease, date, foto, notes) VALUES (9, 22, 2, '2019-11-25', '\x0030', NULL);


--
-- TOC entry 3172 (class 0 OID 58998)
-- Dependencies: 197
-- Data for Name: flower; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.flower (id, id_parent, name) VALUES (1, NULL, 'Asclepiadaceae');
INSERT INTO public.flower (id, id_parent, name) VALUES (2, NULL, 'Asphodelaceae');
INSERT INTO public.flower (id, id_parent, name) VALUES (3, NULL, 'Crassulaceae');
INSERT INTO public.flower (id, id_parent, name) VALUES (4, NULL, 'Aizoaceae');
INSERT INTO public.flower (id, id_parent, name) VALUES (5, NULL, 'Cactaceae');
INSERT INTO public.flower (id, id_parent, name) VALUES (6, 3, 'Echeveria');
INSERT INTO public.flower (id, id_parent, name) VALUES (7, 6, 'elegans');
INSERT INTO public.flower (id, id_parent, name) VALUES (8, 6, 'derenbergii');
INSERT INTO public.flower (id, id_parent, name) VALUES (9, 6, 'gibbiflora');
INSERT INTO public.flower (id, id_parent, name) VALUES (10, 6, 'Black Prince');
INSERT INTO public.flower (id, id_parent, name) VALUES (11, 3, 'Aeonium');
INSERT INTO public.flower (id, id_parent, name) VALUES (12, 11, 'arboreum');
INSERT INTO public.flower (id, id_parent, name) VALUES (13, 11, 'Kiwi');
INSERT INTO public.flower (id, id_parent, name) VALUES (14, 11, 'tabulaeforme');
INSERT INTO public.flower (id, id_parent, name) VALUES (15, 11, 'undulatum');
INSERT INTO public.flower (id, id_parent, name) VALUES (16, 3, 'Sedum');
INSERT INTO public.flower (id, id_parent, name) VALUES (17, 16, 'morganianum');
INSERT INTO public.flower (id, id_parent, name) VALUES (18, 16, 'pahyphyllum');
INSERT INTO public.flower (id, id_parent, name) VALUES (19, 3, 'Kalanchoe');
INSERT INTO public.flower (id, id_parent, name) VALUES (20, 19, 'daigremontiana');
INSERT INTO public.flower (id, id_parent, name) VALUES (21, 19, 'blossfeldiana');
INSERT INTO public.flower (id, id_parent, name) VALUES (22, 2, 'Aloe');
INSERT INTO public.flower (id, id_parent, name) VALUES (23, 22, 'vera');
INSERT INTO public.flower (id, id_parent, name) VALUES (24, 22, 'ferox');
INSERT INTO public.flower (id, id_parent, name) VALUES (25, 22, 'mitriformis');


--
-- TOC entry 3178 (class 0 OID 59049)
-- Dependencies: 203
-- Data for Name: flower_warehouse; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (5, 11, true, '2019-11-24', 1, '400,00 ?', NULL, 1);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (15, 11, true, '2019-11-18', 1, '400,00 ?', NULL, 1);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (1, 7, true, '2019-11-24', 5, '50,00 ?', NULL, 2);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (2, 8, true, '2019-11-24', 10, '150,00 ?', NULL, 2);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (3, 9, true, '2019-11-24', 7, '75,00 ?', NULL, 2);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (4, 10, true, '2019-11-24', 12, '60,00 ?', NULL, 2);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (10, 10, true, '2019-10-12', 2, '60,00 ?', NULL, 2);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (6, 13, true, '2019-11-24', 10, '40,00 ?', NULL, 3);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (7, 14, true, '2019-11-24', 3, '50,00 ?', NULL, 3);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (8, 15, true, '2019-11-24', 4, '50,00 ?', NULL, 3);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (11, 14, true, '2019-08-14', 5, '50,00 ?', NULL, 3);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (13, 14, true, '2019-10-26', 9, '50,00 ?', NULL, 3);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (14, 13, true, '2019-11-14', 7, '40,00 ?', NULL, 3);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (16, 12, true, '2019-12-02', 4, '300,00 ?', NULL, 3);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (17, 17, true, '2019-12-02', 3, '250,00 ?', NULL, 4);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (9, 24, true, '2019-11-24', 13, '100,00 ?', NULL, 5);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (12, 24, true, '2019-03-16', 7, '100,00 ?', NULL, 5);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (19, 25, true, '2019-12-04', 20, '100,00 ?', NULL, 1);
INSERT INTO public.flower_warehouse (id, id_flower, ready_to_sale, date, amount, cost, notes, id_greenhouse) VALUES (21, 20, false, '2019-12-04', 10, '20,00 ?', NULL, 1);


--
-- TOC entry 3216 (class 0 OID 73938)
-- Dependencies: 242
-- Data for Name: greenhouse; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.greenhouse (id, id_staff) VALUES (1, 5);
INSERT INTO public.greenhouse (id, id_staff) VALUES (2, 6);
INSERT INTO public.greenhouse (id, id_staff) VALUES (3, 7);
INSERT INTO public.greenhouse (id, id_staff) VALUES (4, 7);
INSERT INTO public.greenhouse (id, id_staff) VALUES (5, 5);


--
-- TOC entry 3212 (class 0 OID 59392)
-- Dependencies: 238
-- Data for Name: pest; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 3214 (class 0 OID 59402)
-- Dependencies: 240
-- Data for Name: pest_flower; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 3191 (class 0 OID 59179)
-- Dependencies: 217
-- Data for Name: position_rate; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.position_rate (id, "position", rate) VALUES (1, 'Директор', '5 000,00 ?');
INSERT INTO public.position_rate (id, "position", rate) VALUES (2, 'Бухгалтер', '1 000,00 ?');
INSERT INTO public.position_rate (id, "position", rate) VALUES (3, 'Садовник', '600,00 ?');
INSERT INTO public.position_rate (id, "position", rate) VALUES (4, 'Сотрудник склада', '400,00 ?');


--
-- TOC entry 3200 (class 0 OID 59259)
-- Dependencies: 226
-- Data for Name: preparation; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.preparation (id, id_type, name) VALUES (1, 1, 'Актара');


--
-- TOC entry 3198 (class 0 OID 59249)
-- Dependencies: 224
-- Data for Name: preparation_type; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.preparation_type (id, name) VALUES (1, 'Инсектицид');


--
-- TOC entry 3202 (class 0 OID 59273)
-- Dependencies: 228
-- Data for Name: prevention; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.prevention (id, id_staff, date, cause, note, id_greenhouse) VALUES (4, 5, '2019-11-25', NULL, NULL, 1);
INSERT INTO public.prevention (id, id_staff, date, cause, note, id_greenhouse) VALUES (5, 5, '2019-11-25', NULL, NULL, 1);
INSERT INTO public.prevention (id, id_staff, date, cause, note, id_greenhouse) VALUES (1, 6, '2019-11-25', NULL, NULL, 2);
INSERT INTO public.prevention (id, id_staff, date, cause, note, id_greenhouse) VALUES (2, 6, '2019-11-25', NULL, NULL, 2);
INSERT INTO public.prevention (id, id_staff, date, cause, note, id_greenhouse) VALUES (3, 6, '2019-11-25', NULL, NULL, 2);
INSERT INTO public.prevention (id, id_staff, date, cause, note, id_greenhouse) VALUES (6, 6, '2019-11-25', NULL, NULL, 2);
INSERT INTO public.prevention (id, id_staff, date, cause, note, id_greenhouse) VALUES (7, 6, '2019-08-12', NULL, NULL, 2);


--
-- TOC entry 3203 (class 0 OID 59288)
-- Dependencies: 229
-- Data for Name: prevention_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 3195 (class 0 OID 59213)
-- Dependencies: 221
-- Data for Name: purchase; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.purchase (id, id_staff, date, status, notes) VALUES (7, 5, '2019-11-25 00:00:00', 'not processed', NULL);
INSERT INTO public.purchase (id, id_staff, date, status, notes) VALUES (8, 5, '2019-11-25 00:00:00', 'not processed', NULL);
INSERT INTO public.purchase (id, id_staff, date, status, notes) VALUES (9, 5, '2019-11-25 00:00:00', 'not processed', NULL);
INSERT INTO public.purchase (id, id_staff, date, status, notes) VALUES (10, 5, '2019-08-12 00:00:00', 'not processed', NULL);
INSERT INTO public.purchase (id, id_staff, date, status, notes) VALUES (11, 6, '2019-11-25 00:00:00', 'not processed', NULL);
INSERT INTO public.purchase (id, id_staff, date, status, notes) VALUES (12, 6, '2019-11-25 00:00:00', 'not processed', NULL);
INSERT INTO public.purchase (id, id_staff, date, status, notes) VALUES (13, 6, '2019-11-11 00:00:00', 'not processed', NULL);
INSERT INTO public.purchase (id, id_staff, date, status, notes) VALUES (14, 6, '2019-11-13 00:00:00', 'not processed', NULL);


--
-- TOC entry 3196 (class 0 OID 59229)
-- Dependencies: 222
-- Data for Name: purchase_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (7, 7, 1, '50,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (24, 7, 1, '100,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (24, 8, 1, '100,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (10, 8, 1, '60,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (15, 8, 1, '50,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (9, 8, 1, '75,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (24, 9, 1, '100,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (13, 9, 1, '40,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (9, 10, 1, '75,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (15, 11, 1, '50,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (15, 12, 1, '50,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (13, 13, 1, '40,00 ?');
INSERT INTO public.purchase_detail (id_flower, id_purchase, amount, cost) VALUES (9, 14, 1, '75,00 ?');


--
-- TOC entry 3186 (class 0 OID 59123)
-- Dependencies: 212
-- Data for Name: sale; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (3, 12, NULL, '2018-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (4, 4, 3, '2019-11-04 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (5, 12, 2, '2018-10-05 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (6, 3, 1, '2019-03-12 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (7, 7, 4, '2019-08-15 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (10, 4, NULL, '2019-07-18 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (11, 5, NULL, '2019-07-18 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (12, 9, NULL, '2019-11-20 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (13, 13, NULL, '2019-03-21 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (15, 7, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (16, 7, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (17, 5, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (18, 7, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (19, 11, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (20, 11, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (21, 11, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (22, 11, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (23, 12, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (24, 10, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (25, 10, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (26, 9, NULL, '2019-11-24 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (28, 7, NULL, '2010-11-12 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (29, 7, NULL, '2009-11-12 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (30, 7, NULL, '2014-11-12 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (31, 7, NULL, '2014-11-27 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (32, 7, NULL, '2010-11-25 00:00:00', 'not processed');
INSERT INTO public.sale (id, id_user, id_adress, buy_date, status) VALUES (33, 4, NULL, '2019-12-02 00:00:00', 'not processed');


--
-- TOC entry 3188 (class 0 OID 59142)
-- Dependencies: 214
-- Data for Name: sale_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (1, 3, 12, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (2, 3, 15, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (3, 5, 12, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (4, 10, 7, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (5, 11, 12, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (6, 11, 17, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (7, 11, 10, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (8, 33, 10, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (9, 4, 10, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (10, 4, 12, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (11, 7, 7, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (12, 16, 15, 1);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (15, 10, 14, 16);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (16, 4, 25, 10);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (18, 4, 25, 10);
INSERT INTO public.sale_detail (id, id_sale, id_flower, amount) VALUES (24, 4, 13, 10);


--
-- TOC entry 3189 (class 0 OID 59160)
-- Dependencies: 215
-- Data for Name: sale_flower; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (1, 16, 1);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (2, 8, 2);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (3, 16, 2);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (4, 1, 3);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (5, 16, 1);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (6, 17, 3);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (7, 10, 1);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (8, 10, 2);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (9, 10, 1);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (10, 16, 1);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (11, 1, 1);
INSERT INTO public.sale_flower (id_sale_detail, id_flower_warehouse, amount) VALUES (12, 8, 1);


--
-- TOC entry 3219 (class 0 OID 90499)
-- Dependencies: 248
-- Data for Name: sale_sum; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.sale_sum (sum) VALUES (NULL);


--
-- TOC entry 3218 (class 0 OID 73966)
-- Dependencies: 244
-- Data for Name: sheduled_prevention; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 3193 (class 0 OID 59190)
-- Dependencies: 219
-- Data for Name: staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.staff (id, name, surname, patronymie, id_position, salary, allowance) VALUES (2, 'Вероника', 'Ткаченко', NULL, 1, '5 000,00 ?', 0);
INSERT INTO public.staff (id, name, surname, patronymie, id_position, salary, allowance) VALUES (3, 'Александра', 'Кушнир', NULL, 2, '1 000,00 ?', 0);
INSERT INTO public.staff (id, name, surname, patronymie, id_position, salary, allowance) VALUES (4, 'Фёдор', 'Чернов', NULL, 4, '400,00 ?', 0);
INSERT INTO public.staff (id, name, surname, patronymie, id_position, salary, allowance) VALUES (5, 'Ксения', 'Попова', NULL, 3, '600,00 ?', 0);
INSERT INTO public.staff (id, name, surname, patronymie, id_position, salary, allowance) VALUES (6, 'Таисия', 'Осипова', NULL, 3, '600,00 ?', 0);
INSERT INTO public.staff (id, name, surname, patronymie, id_position, salary, allowance) VALUES (7, 'Олеся', 'Кузьмина', NULL, 3, '600,00 ?', 0);
INSERT INTO public.staff (id, name, surname, patronymie, id_position, salary, allowance) VALUES (8, 'Алексей', 'Иванов', NULL, 4, '100,00 ?', 0);


--
-- TOC entry 3207 (class 0 OID 59316)
-- Dependencies: 233
-- Data for Name: stock; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.stock (id, id_type, name, amount) VALUES (2, 1, 'Черный горшок', 2);
INSERT INTO public.stock (id, id_type, name, amount) VALUES (3, 1, 'Белый горшок', 3);
INSERT INTO public.stock (id, id_type, name, amount) VALUES (4, 1, 'Серый горшок', 5);


--
-- TOC entry 3209 (class 0 OID 59333)
-- Dependencies: 235
-- Data for Name: stock_purchase; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.stock_purchase (id, id_staff, date, status) VALUES (1, 4, '2019-11-27', 'not processed');
INSERT INTO public.stock_purchase (id, id_staff, date, status) VALUES (2, 4, '2019-11-27', 'not processed');
INSERT INTO public.stock_purchase (id, id_staff, date, status) VALUES (3, 4, '2019-11-27', 'not processed');
INSERT INTO public.stock_purchase (id, id_staff, date, status) VALUES (4, 8, '2019-11-27', 'not processed');
INSERT INTO public.stock_purchase (id, id_staff, date, status) VALUES (5, 8, '2019-11-27', 'not processed');
INSERT INTO public.stock_purchase (id, id_staff, date, status) VALUES (6, 8, '2019-11-27', 'not processed');


--
-- TOC entry 3210 (class 0 OID 59346)
-- Dependencies: 236
-- Data for Name: stock_purchase_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.stock_purchase_detail (id_stock, id_stock_purchase, amount, cost) VALUES (2, 1, 1, '30,00 ?');
INSERT INTO public.stock_purchase_detail (id_stock, id_stock_purchase, amount, cost) VALUES (3, 2, 1, '30,00 ?');
INSERT INTO public.stock_purchase_detail (id_stock, id_stock_purchase, amount, cost) VALUES (4, 3, 2, '30,00 ?');
INSERT INTO public.stock_purchase_detail (id_stock, id_stock_purchase, amount, cost) VALUES (2, 4, 2, '30,00 ?');
INSERT INTO public.stock_purchase_detail (id_stock, id_stock_purchase, amount, cost) VALUES (3, 5, 3, '30,00 ?');
INSERT INTO public.stock_purchase_detail (id_stock, id_stock_purchase, amount, cost) VALUES (4, 6, 1, '30,00 ?');
INSERT INTO public.stock_purchase_detail (id_stock, id_stock_purchase, amount, cost) VALUES (2, 2, 3, '40,00 ?');
INSERT INTO public.stock_purchase_detail (id_stock, id_stock_purchase, amount, cost) VALUES (2, 3, 4, '40,00 ?');


--
-- TOC entry 3205 (class 0 OID 59306)
-- Dependencies: 231
-- Data for Name: stock_type; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.stock_type (id, name) VALUES (1, 'Горшок');


--
-- TOC entry 3247 (class 0 OID 0)
-- Dependencies: 207
-- Name: User_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."User_id_seq"', 13, true);


--
-- TOC entry 3248 (class 0 OID 0)
-- Dependencies: 209
-- Name: adress_sale_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.adress_sale_id_seq', 5, true);


--
-- TOC entry 3249 (class 0 OID 0)
-- Dependencies: 204
-- Name: dead_flowers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dead_flowers_id_seq', 13, true);


--
-- TOC entry 3250 (class 0 OID 0)
-- Dependencies: 200
-- Name: disease_flower_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.disease_flower_id_seq', 9, true);


--
-- TOC entry 3251 (class 0 OID 0)
-- Dependencies: 198
-- Name: disease_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.disease_id_seq', 12, true);


--
-- TOC entry 3252 (class 0 OID 0)
-- Dependencies: 196
-- Name: flower_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.flower_id_seq', 25, true);


--
-- TOC entry 3253 (class 0 OID 0)
-- Dependencies: 202
-- Name: flower_warehouse_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.flower_warehouse_id_seq', 21, true);


--
-- TOC entry 3254 (class 0 OID 0)
-- Dependencies: 241
-- Name: greenhouse_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.greenhouse_id_seq', 5, true);


--
-- TOC entry 3255 (class 0 OID 0)
-- Dependencies: 239
-- Name: pest_flower_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pest_flower_id_seq', 1, false);


--
-- TOC entry 3256 (class 0 OID 0)
-- Dependencies: 237
-- Name: pest_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pest_id_seq', 1, false);


--
-- TOC entry 3257 (class 0 OID 0)
-- Dependencies: 216
-- Name: position_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.position_rate_id_seq', 4, true);


--
-- TOC entry 3258 (class 0 OID 0)
-- Dependencies: 225
-- Name: preparation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.preparation_id_seq', 1, true);


--
-- TOC entry 3259 (class 0 OID 0)
-- Dependencies: 223
-- Name: preparation_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.preparation_type_id_seq', 1, true);


--
-- TOC entry 3260 (class 0 OID 0)
-- Dependencies: 227
-- Name: prevention_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.prevention_id_seq', 10, true);


--
-- TOC entry 3261 (class 0 OID 0)
-- Dependencies: 220
-- Name: purchase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.purchase_id_seq', 14, true);


--
-- TOC entry 3262 (class 0 OID 0)
-- Dependencies: 213
-- Name: sale_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sale_detail_id_seq', 56, true);


--
-- TOC entry 3263 (class 0 OID 0)
-- Dependencies: 211
-- Name: sale_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sale_id_seq', 33, true);


--
-- TOC entry 3264 (class 0 OID 0)
-- Dependencies: 243
-- Name: sheduled_prevention_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sheduled_prevention_id_seq', 1, false);


--
-- TOC entry 3265 (class 0 OID 0)
-- Dependencies: 218
-- Name: staff_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.staff_id_seq', 8, true);


--
-- TOC entry 3266 (class 0 OID 0)
-- Dependencies: 232
-- Name: stock_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stock_id_seq', 4, true);


--
-- TOC entry 3267 (class 0 OID 0)
-- Dependencies: 234
-- Name: stock_purchase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stock_purchase_id_seq', 6, true);


--
-- TOC entry 3268 (class 0 OID 0)
-- Dependencies: 230
-- Name: stock_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stock_type_id_seq', 1, true);


--
-- TOC entry 2963 (class 2606 OID 59369)
-- Name: User User_e_mail_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_e_mail_key" UNIQUE (e_mail);


--
-- TOC entry 2965 (class 2606 OID 59097)
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- TOC entry 2967 (class 2606 OID 59110)
-- Name: adress_sale adress_sale_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adress_sale
    ADD CONSTRAINT adress_sale_pkey PRIMARY KEY (id);


--
-- TOC entry 2961 (class 2606 OID 59078)
-- Name: dead_flowers dead_flowers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dead_flowers
    ADD CONSTRAINT dead_flowers_pkey PRIMARY KEY (id);


--
-- TOC entry 2957 (class 2606 OID 59036)
-- Name: disease_flower disease_flower_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disease_flower
    ADD CONSTRAINT disease_flower_pkey PRIMARY KEY (id);


--
-- TOC entry 2953 (class 2606 OID 59024)
-- Name: disease disease_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disease
    ADD CONSTRAINT disease_name_key UNIQUE (name);


--
-- TOC entry 2955 (class 2606 OID 59022)
-- Name: disease disease_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disease
    ADD CONSTRAINT disease_pkey PRIMARY KEY (id);


--
-- TOC entry 2949 (class 2606 OID 59006)
-- Name: flower flower_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flower
    ADD CONSTRAINT flower_name_key UNIQUE (name);


--
-- TOC entry 2951 (class 2606 OID 59004)
-- Name: flower flower_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flower
    ADD CONSTRAINT flower_pkey PRIMARY KEY (id);


--
-- TOC entry 2959 (class 2606 OID 59060)
-- Name: flower_warehouse flower_warehouse_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flower_warehouse
    ADD CONSTRAINT flower_warehouse_pkey PRIMARY KEY (id);


--
-- TOC entry 3013 (class 2606 OID 73945)
-- Name: greenhouse greenhouse_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.greenhouse
    ADD CONSTRAINT greenhouse_pkey PRIMARY KEY (id);


--
-- TOC entry 3011 (class 2606 OID 59414)
-- Name: pest_flower pest_flower_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pest_flower
    ADD CONSTRAINT pest_flower_pkey PRIMARY KEY (id);


--
-- TOC entry 3007 (class 2606 OID 59399)
-- Name: pest pest_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pest
    ADD CONSTRAINT pest_name_key UNIQUE (name);


--
-- TOC entry 3009 (class 2606 OID 59397)
-- Name: pest pest_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pest
    ADD CONSTRAINT pest_pkey PRIMARY KEY (id);


--
-- TOC entry 2975 (class 2606 OID 59185)
-- Name: position_rate position_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.position_rate
    ADD CONSTRAINT position_rate_pkey PRIMARY KEY (id);


--
-- TOC entry 2977 (class 2606 OID 59187)
-- Name: position_rate position_rate_position_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.position_rate
    ADD CONSTRAINT position_rate_position_key UNIQUE ("position");


--
-- TOC entry 2989 (class 2606 OID 59265)
-- Name: preparation preparation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preparation
    ADD CONSTRAINT preparation_pkey PRIMARY KEY (id);


--
-- TOC entry 2985 (class 2606 OID 59256)
-- Name: preparation_type preparation_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preparation_type
    ADD CONSTRAINT preparation_type_name_key UNIQUE (name);


--
-- TOC entry 2987 (class 2606 OID 59254)
-- Name: preparation_type preparation_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preparation_type
    ADD CONSTRAINT preparation_type_pkey PRIMARY KEY (id);


--
-- TOC entry 2993 (class 2606 OID 59293)
-- Name: prevention_detail prevention_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prevention_detail
    ADD CONSTRAINT prevention_detail_pkey PRIMARY KEY (id_preparation, id_prevention);


--
-- TOC entry 2991 (class 2606 OID 59282)
-- Name: prevention prevention_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prevention
    ADD CONSTRAINT prevention_pkey PRIMARY KEY (id);


--
-- TOC entry 2983 (class 2606 OID 59236)
-- Name: purchase_detail purchase_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_detail
    ADD CONSTRAINT purchase_detail_pkey PRIMARY KEY (id_flower, id_purchase);


--
-- TOC entry 2981 (class 2606 OID 59223)
-- Name: purchase purchase_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase
    ADD CONSTRAINT purchase_pkey PRIMARY KEY (id);


--
-- TOC entry 2971 (class 2606 OID 59149)
-- Name: sale_detail sale_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_detail
    ADD CONSTRAINT sale_detail_pkey PRIMARY KEY (id);


--
-- TOC entry 2973 (class 2606 OID 59166)
-- Name: sale_flower sale_flower_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_flower
    ADD CONSTRAINT sale_flower_pkey PRIMARY KEY (id_sale_detail, id_flower_warehouse);


--
-- TOC entry 2969 (class 2606 OID 59129)
-- Name: sale sale_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale
    ADD CONSTRAINT sale_pkey PRIMARY KEY (id);


--
-- TOC entry 3015 (class 2606 OID 73975)
-- Name: sheduled_prevention sheduled_prevention_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sheduled_prevention
    ADD CONSTRAINT sheduled_prevention_pkey PRIMARY KEY (id);


--
-- TOC entry 2979 (class 2606 OID 59197)
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (id);


--
-- TOC entry 2999 (class 2606 OID 59325)
-- Name: stock stock_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock
    ADD CONSTRAINT stock_name_key UNIQUE (name);


--
-- TOC entry 3001 (class 2606 OID 59323)
-- Name: stock stock_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock
    ADD CONSTRAINT stock_pkey PRIMARY KEY (id);


--
-- TOC entry 3005 (class 2606 OID 59353)
-- Name: stock_purchase_detail stock_purchase_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_purchase_detail
    ADD CONSTRAINT stock_purchase_detail_pkey PRIMARY KEY (id_stock, id_stock_purchase);


--
-- TOC entry 3003 (class 2606 OID 59340)
-- Name: stock_purchase stock_purchase_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_purchase
    ADD CONSTRAINT stock_purchase_pkey PRIMARY KEY (id);


--
-- TOC entry 2995 (class 2606 OID 59313)
-- Name: stock_type stock_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_type
    ADD CONSTRAINT stock_type_name_key UNIQUE (name);


--
-- TOC entry 2997 (class 2606 OID 59311)
-- Name: stock_type stock_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_type
    ADD CONSTRAINT stock_type_pkey PRIMARY KEY (id);


--
-- TOC entry 3045 (class 2620 OID 74658)
-- Name: sale_detail new_sale; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_sale BEFORE INSERT ON public.sale_detail FOR EACH ROW EXECUTE PROCEDURE public.check_flower_amount();


--
-- TOC entry 3046 (class 2620 OID 74659)
-- Name: sale_flower new_sale; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_sale BEFORE INSERT ON public.sale_flower FOR EACH ROW EXECUTE PROCEDURE public.check_flower_amount();


--
-- TOC entry 3021 (class 2606 OID 59079)
-- Name: dead_flowers dead_flowers_id_flower_warehouse_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dead_flowers
    ADD CONSTRAINT dead_flowers_id_flower_warehouse_fkey FOREIGN KEY (id_flower_warehouse) REFERENCES public.flower_warehouse(id);


--
-- TOC entry 3018 (class 2606 OID 59042)
-- Name: disease_flower disease_flower_id_disease_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disease_flower
    ADD CONSTRAINT disease_flower_id_disease_fkey FOREIGN KEY (id_disease) REFERENCES public.disease(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3017 (class 2606 OID 59037)
-- Name: disease_flower disease_flower_id_flower_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disease_flower
    ADD CONSTRAINT disease_flower_id_flower_fkey FOREIGN KEY (id_flower) REFERENCES public.flower(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3016 (class 2606 OID 59007)
-- Name: flower flower_id_parent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flower
    ADD CONSTRAINT flower_id_parent_fkey FOREIGN KEY (id_parent) REFERENCES public.flower(id) ON UPDATE CASCADE;


--
-- TOC entry 3019 (class 2606 OID 59061)
-- Name: flower_warehouse flower_warehouse_id_flower_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flower_warehouse
    ADD CONSTRAINT flower_warehouse_id_flower_fkey FOREIGN KEY (id_flower) REFERENCES public.flower(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3020 (class 2606 OID 73952)
-- Name: flower_warehouse flower_warehouse_id_greenhouse_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flower_warehouse
    ADD CONSTRAINT flower_warehouse_id_greenhouse_fkey FOREIGN KEY (id_greenhouse) REFERENCES public.greenhouse(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3043 (class 2606 OID 73946)
-- Name: greenhouse greenhouse_id_staff_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.greenhouse
    ADD CONSTRAINT greenhouse_id_staff_fkey FOREIGN KEY (id_staff) REFERENCES public.staff(id) ON UPDATE CASCADE;


--
-- TOC entry 3041 (class 2606 OID 59415)
-- Name: pest_flower pest_flower_id_flower_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pest_flower
    ADD CONSTRAINT pest_flower_id_flower_fkey FOREIGN KEY (id_flower) REFERENCES public.flower(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3042 (class 2606 OID 59420)
-- Name: pest_flower pest_flower_id_pest_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pest_flower
    ADD CONSTRAINT pest_flower_id_pest_fkey FOREIGN KEY (id_pest) REFERENCES public.pest(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3032 (class 2606 OID 59266)
-- Name: preparation preparation_id_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preparation
    ADD CONSTRAINT preparation_id_type_fkey FOREIGN KEY (id_type) REFERENCES public.preparation_type(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3035 (class 2606 OID 59294)
-- Name: prevention_detail prevention_detail_id_preparation_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prevention_detail
    ADD CONSTRAINT prevention_detail_id_preparation_fkey FOREIGN KEY (id_preparation) REFERENCES public.preparation(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3036 (class 2606 OID 59299)
-- Name: prevention_detail prevention_detail_id_prevention_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prevention_detail
    ADD CONSTRAINT prevention_detail_id_prevention_fkey FOREIGN KEY (id_prevention) REFERENCES public.prevention(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3034 (class 2606 OID 73959)
-- Name: prevention prevention_id_greenhouse_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prevention
    ADD CONSTRAINT prevention_id_greenhouse_fkey FOREIGN KEY (id_greenhouse) REFERENCES public.greenhouse(id) ON UPDATE CASCADE;


--
-- TOC entry 3033 (class 2606 OID 59283)
-- Name: prevention prevention_id_staff_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prevention
    ADD CONSTRAINT prevention_id_staff_fkey FOREIGN KEY (id_staff) REFERENCES public.staff(id) ON UPDATE CASCADE;


--
-- TOC entry 3030 (class 2606 OID 59237)
-- Name: purchase_detail purchase_detail_id_flower_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_detail
    ADD CONSTRAINT purchase_detail_id_flower_fkey FOREIGN KEY (id_flower) REFERENCES public.flower(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3031 (class 2606 OID 59242)
-- Name: purchase_detail purchase_detail_id_purchase_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_detail
    ADD CONSTRAINT purchase_detail_id_purchase_fkey FOREIGN KEY (id_purchase) REFERENCES public.purchase(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3029 (class 2606 OID 59224)
-- Name: purchase purchase_id_staff_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase
    ADD CONSTRAINT purchase_id_staff_fkey FOREIGN KEY (id_staff) REFERENCES public.staff(id) ON UPDATE CASCADE;


--
-- TOC entry 3025 (class 2606 OID 59155)
-- Name: sale_detail sale_detail_id_flower_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_detail
    ADD CONSTRAINT sale_detail_id_flower_fkey FOREIGN KEY (id_flower) REFERENCES public.flower(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3024 (class 2606 OID 59150)
-- Name: sale_detail sale_detail_id_sale_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_detail
    ADD CONSTRAINT sale_detail_id_sale_fkey FOREIGN KEY (id_sale) REFERENCES public.sale(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3027 (class 2606 OID 73924)
-- Name: sale_flower sale_flower_id_flower_warehouse_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_flower
    ADD CONSTRAINT sale_flower_id_flower_warehouse_fkey FOREIGN KEY (id_flower_warehouse) REFERENCES public.flower_warehouse(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3026 (class 2606 OID 59167)
-- Name: sale_flower sale_flower_id_sale_detail_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_flower
    ADD CONSTRAINT sale_flower_id_sale_detail_fkey FOREIGN KEY (id_sale_detail) REFERENCES public.sale_detail(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3023 (class 2606 OID 59135)
-- Name: sale sale_id_adress_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale
    ADD CONSTRAINT sale_id_adress_fkey FOREIGN KEY (id_adress) REFERENCES public.adress_sale(id) ON UPDATE CASCADE;


--
-- TOC entry 3022 (class 2606 OID 59130)
-- Name: sale sale_id_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale
    ADD CONSTRAINT sale_id_user_fkey FOREIGN KEY (id_user) REFERENCES public."User"(id) ON UPDATE CASCADE;


--
-- TOC entry 3044 (class 2606 OID 73976)
-- Name: sheduled_prevention sheduled_prevention_id_greenhouse_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sheduled_prevention
    ADD CONSTRAINT sheduled_prevention_id_greenhouse_fkey FOREIGN KEY (id_greenhouse) REFERENCES public.greenhouse(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3028 (class 2606 OID 59198)
-- Name: staff staff_id_position_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_id_position_fkey FOREIGN KEY (id_position) REFERENCES public.position_rate(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3037 (class 2606 OID 59326)
-- Name: stock stock_id_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock
    ADD CONSTRAINT stock_id_type_fkey FOREIGN KEY (id_type) REFERENCES public.stock_type(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3039 (class 2606 OID 59354)
-- Name: stock_purchase_detail stock_purchase_detail_id_stock_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_purchase_detail
    ADD CONSTRAINT stock_purchase_detail_id_stock_fkey FOREIGN KEY (id_stock) REFERENCES public.stock(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3040 (class 2606 OID 59359)
-- Name: stock_purchase_detail stock_purchase_detail_id_stock_purchase_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_purchase_detail
    ADD CONSTRAINT stock_purchase_detail_id_stock_purchase_fkey FOREIGN KEY (id_stock_purchase) REFERENCES public.stock_purchase(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3038 (class 2606 OID 59341)
-- Name: stock_purchase stock_purchase_id_staff_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_purchase
    ADD CONSTRAINT stock_purchase_id_staff_fkey FOREIGN KEY (id_staff) REFERENCES public.staff(id) ON UPDATE CASCADE;


-- Completed on 2019-12-17 08:32:12

--
-- PostgreSQL database dump complete
--

