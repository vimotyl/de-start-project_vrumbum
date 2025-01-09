/* ПРОЕКТ АВТОСАЛОН «ВРУМ-БУМ» */




/* ШАГ 1
 * Создали схему raw_data и таблицу sales
 * для загрузки сырых данных из файла */

CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales(
	id smallint,
	auto text,
	gasoline_consumption real,
	price NUMERIC(22, 15),
	date date,
	person_name text,
	phone text,
	discount_percent smallint,
	brand_origin text
);




/* ШАГ 2
 * Загрузили данные в sales через терминал */
--\copy raw_data.sales FROM '/Users/cars.csv' CSV HEADER NULL 'null';

/* Проверили визуально, что загрузилось */
--SELECT * FROM raw_data.sales LIMIT 10;
--SELECT COUNT(*) FROM raw_data.sales;

/* Проверили наличие дублирующихся строк 
SELECT
	auto, 
	date,
	person_name,
	COUNT(*)
FROM raw_data.sales
GROUP BY auto, date, person_name
HAVING COUNT(*) > 1;
*/




/* ШАГ 3
 * Создали схему car_shop и нормализованные таблицы:
 * clients - информация о клиентах;
 * orders - информация о заказах;
 * cars - информация об автомобилях;
 * models - информация о моделях автомобилей;
 * colors - информация о цветах моделей автомобилей;
 * brands - информация о брендах автомобилей.
 */

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.clients(
	id SERIAL PRIMARY KEY,             /* целое число с автоинкрементом */
	service_person_name TEXT,          /* служебное текстовое поле, позже будем делить его на части */
	appeal VARCHAR(10) DEFAULT '',     /* обращение к клиенту, например, Mrs., 10 символов достаточно */
	first_name VARCHAR(50) NOT NULL,   /* имя клиента, 50 символов достаточно, обязательно заполнять */
	last_name VARCHAR(50) NOT NULL,    /* фамилия клиента, 50 символов достаточно, обязательно заполнять */
	status VARCHAR(10) DEFAULT '',     /* степень клиента, например, MD, 10 символов достаточно */
	phone VARCHAR(30)                  /* телефон клиента, могут быть и цифры, и символы, поэтому VARCHAR, 30 символов достаточно */
);

CREATE TABLE car_shop.origin(
	country VARCHAR(50) PRIMARY KEY    /* наименование страны, 50 символов достаточно */
);

CREATE TABLE car_shop.brands(
	name VARCHAR(50) PRIMARY KEY,      /* наименование бренда, 50 символов достаточно */
	
	brand_origin VARCHAR(50)           /* наименование страны, 50 символов достаточно */
		REFERENCES car_shop.origin(country) ON DELETE SET NULL   /* внешний ключ, при удалении страны из родительской
																    таблицы заполняем значением NULL, так как это доп.информация */
);


CREATE TABLE car_shop.models(
	id SERIAL PRIMARY KEY,                 /* целое число с автоинкрементом */
	
	name VARCHAR(50) NOT NULL UNIQUE,      /* название модели авто, 50 символов достаточно, обязательно заполнять, должно быть уникальным */
	
	brand_name VARCHAR(50)                 /* наименование бренда, 50 символов достаточно */
		REFERENCES car_shop.brands(name) ON DELETE RESTRICT,   /* внешний ключ, запрет на удаление бренда из родительской таблицы, 
																  так как модель авто без бренда не может существовать */   
		
	is_electric_car BOOL DEFAULT FALSE,    /* является ли электромобилем, по умолчанию FALSE, так как обычных авто больше, чем электро */
	
	gasoline_consumption REAL              /* среднее потребление бензина, может быть вещественным числом,
											  может быть не заполнено у электромобилей */
);

CREATE TABLE car_shop.colors(
	name VARCHAR(50) PRIMARY KEY           /* название цвета, 50 символов достаточно */
);


CREATE TABLE car_shop.cars(
	id SERIAL PRIMARY KEY,                 /* целое число с автоинкрементом */
	
	model_id INT                           /* id модели, целое число */
		REFERENCES car_shop.models(id) ON DELETE RESTRICT,    /* внешний ключ, запрет на удаление модели из родительской таблицы,
																 так как авто без указания модели не может существовать */ 
		
	color_name VARCHAR(50)                                    /* название цвета, 50 символов достаточно */
		REFERENCES car_shop.colors(name) ON DELETE RESTRICT   /* внешний ключ, запрет на удаление цвета из родительской таблицы,
																 так как авто без указания цвета не может существовать */
);


CREATE TABLE car_shop.orders(
	id SERIAL PRIMARY KEY,                                 /* целое число с автоинкрементом */
	
	order_date date NOT NULL DEFAULT CURRENT_DATE,         /* дата совершения покупки, время не важно, не может быть пустым, 
															  по умолчанию ставим текущую дату, т.к. чаще заказ вносят день в день */
	
	client_id INT                                             /* id клиента, целое число */
		REFERENCES car_shop.clients(id) ON DELETE RESTRICT,   /* внешний ключ, запрет на удаление клиента из родительской таблицы,
																 так как заказ без указания клиента не может существовать */
	
	car_id INT                                              /* id автомобиля, целое число */
		REFERENCES car_shop.cars(id) ON DELETE RESTRICT,    /* внешний ключ, запрет на удаление автомобиля из родительской таблицы,
															   так как заказ без указания авто не может существовать */
		
	price numeric(9, 2) NOT NULL,               /* полная стомость заказа, достаточно округления до 2 знаков после запятой,
												   максимальная стоимость по условию 9 999 999,99 */
	
	discount_percent SMALLINT DEFAULT 0         /* целое число, процент скидки в диапазоне от 0 до 100, по умолчанию 0 */
);





/* ШАГ 4
 * Создали и заполнили вспомогательные столбцы
 * в таблице sales с сырыми данными */

ALTER TABLE raw_data.sales
	ADD COLUMN brand TEXT,                /* бренд авто */
	ADD COLUMN model TEXT,                /* модель авто */
	ADD COLUMN color TEXT,                /* цвет авто */
	ADD COLUMN full_price NUMERIC(9, 2);  /* стомость заказа без учета скидки */

-- выделяем бренд авто из поля auto
UPDATE raw_data.sales
SET brand = trim(split_part(auto, ' ', 1));

-- выделяем цвет авто из поля auto
UPDATE raw_data.sales
SET color = trim(split_part(auto, ',', -1));

-- выделяем модель авто из поля auto
UPDATE raw_data.sales
SET model = trim(substr(auto, strpos(auto, ' '), strpos(auto, ',') - strpos(auto, ' ')));

-- пересчитываем полную стомость заказа (без учета скидки)
UPDATE raw_data.sales
SET full_price = 
	CASE 
		WHEN discount_percent IN (0, NULL) THEN ROUND(price, 2)
		ELSE ROUND((price * 100 / (100 - discount_percent)), 2)
	END;





/* ШАГ 5
 * Заполняем номализованные таблицы */

-- colors
INSERT INTO car_shop.colors (name)
	(SELECT DISTINCT color
	FROM raw_data.sales
	WHERE color IS NOT NULL);


-- origin
INSERT INTO car_shop.origin (country)
	(SELECT DISTINCT brand_origin
	FROM raw_data.sales
	WHERE brand_origin IS NOT NULL);


-- brands
INSERT INTO car_shop.brands (name, brand_origin) 
	(SELECT DISTINCT brand, brand_origin 
	FROM raw_data.sales);


-- models
INSERT INTO car_shop.models (name, brand_name, is_electric_car, gasoline_consumption)
	(SELECT
		DISTINCT model, 
		brand,
		CASE
			WHEN (gasoline_consumption IS NULL) OR (gasoline_consumption = 0)
			THEN TRUE
			ELSE FALSE
		END electric,
		gasoline_consumption
	FROM raw_data.sales
	ORDER BY model);


-- cars
INSERT INTO car_shop.cars (model_id, color_name)
	(SELECT
		DISTINCT m.id,
		c.name
	FROM raw_data.sales AS s
	JOIN car_shop.models AS m ON s.model = m.name
	JOIN car_shop.colors AS c ON s.color = c.name
	ORDER BY 1);


-- clients
INSERT INTO car_shop.clients (service_person_name, phone, first_name, last_name)
	(SELECT
		DISTINCT person_name,
		phone,
		'' AS first_name,
		'' AS last_name
	FROM raw_data.sales);


-- orders
INSERT INTO car_shop.orders (order_date, client_id, car_id, price, discount_percent)
	(SELECT
		s.date,
		cl.id AS client,
		cr.id AS car,
		s.full_price,
		s.discount_percent
	FROM raw_data.sales AS s
	JOIN car_shop.clients AS cl ON s.person_name = cl.service_person_name
	JOIN car_shop.models AS m ON s.model = m.name
	JOIN car_shop.colors AS col ON s.color = col.name
	JOIN car_shop.cars AS cr ON cr.model_id = m.id AND cr.color_name = col.name
);






/* ШАГ 6
 * Делим имя клиента на части.
 * Используя служебное поле service_person_name в таблице clients,
 * заполняем отдельные поля appeal, first_name, last_name, status */

-- clients(appeal)
UPDATE car_shop.clients
SET appeal = 
	CASE
		WHEN split_part(service_person_name, ' ', 1) IN ('Dr.', 'Miss', 'Mr.', 'Mrs.')
		THEN split_part(service_person_name, ' ', 1)
		ELSE null
	END;

-- удаляем обращение (appeal) из служебного поля service_person_name
UPDATE car_shop.clients
SET service_person_name = 
	CASE
		WHEN split_part(service_person_name, ' ', 1) IN ('Dr.', 'Miss', 'Mr.', 'Mrs.')
		THEN TRIM(replace(service_person_name, split_part(service_person_name, ' ', 1), ''))
		ELSE service_person_name
	END;

-- clients(first_name)
UPDATE car_shop.clients
SET first_name = TRIM(SPLIT_PART(service_person_name, ' ', 1));

-- clients(last_name)
UPDATE car_shop.clients
SET last_name = TRIM(SPLIT_PART(service_person_name, ' ', 2));

-- clients(status)
UPDATE car_shop.clients
SET status = 
	CASE
		WHEN SPLIT_PART(service_person_name, ' ', 3) != ''
		THEN TRIM(SPLIT_PART(service_person_name, ' ', 3))
		ELSE null
	END;

-- удаляем вспомогательный столбец service_person_name
ALTER TABLE car_shop.clients
DROP COLUMN service_person_name;






/* ШАГ 7
 * СОЗДАНИЕ ВЫБОРОК */


/* ВЫБОРКА 1 
 * процент моделей машин, у которых нет параметра gasoline_consumption */
SELECT ROUND(COUNT(*) / (SELECT COUNT(*) FROM car_shop.models)::NUMERIC * 100, 2)
			AS nulls_percentage_gasoline_consumption
FROM car_shop.models
WHERE is_electric_car = TRUE;



/* ВЫБОРКА 2
 * название бренда и средняя цена его автомобилей в разбивке по всем годам с учётом скидки */
SELECT
	b.name,
	current_year,
	CASE
		WHEN COUNT(o.id) = 0 THEN 0
		ELSE ROUND(AVG(o.price - o.price / 100 * o.discount_percent), 2)
	END AS price_avg
FROM GENERATE_SERIES(2015, 2023, 1) AS current_year
CROSS JOIN car_shop.brands b 
LEFT JOIN car_shop.models m ON m.brand_name = b.name
LEFT JOIN car_shop.cars c ON m.id = c.model_id
LEFT JOIN car_shop.orders o ON current_year = EXTRACT(YEAR FROM o.order_date) AND c.id = o.car_id
GROUP BY b.name, current_year
ORDER BY b.name, current_year;




/* ВЫБОРКА 3
 * средняя цена всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки */
SELECT
	EXTRACT(MONTH FROM o.order_date) AS month,
	EXTRACT(YEAR FROM o.order_date) AS year,
	ROUND(AVG(o.price - o.price / 100 * o.discount_percent), 2) AS price_avg
FROM car_shop.orders o
WHERE EXTRACT(YEAR FROM o.order_date) = 2022
GROUP BY year, month
ORDER BY month;



/* ВЫБОРКА 4
 * список купленных машин у каждого пользователя */
SELECT
	(c.first_name || ' ' || c.last_name) AS person,
	STRING_AGG(m.brand_name || ' ' || m.name, ', ') AS cars
FROM car_shop.orders o
JOIN car_shop.clients c ON o.client_id = c.id
JOIN car_shop.cars cr ON o.car_id = cr.id
JOIN car_shop.models m ON cr.model_id = m.id
GROUP BY o.client_id, person
ORDER BY person ASC;



/* ВЫБОРКА 5
 * самая большая и самая маленькая цена продажи автомобиля с разбивкой по стране без учёта скидки */
SELECT
	b.brand_origin,
	MAX(price) AS price_max,
	MIN(price) AS price_min
FROM car_shop.orders o
JOIN car_shop.cars cr ON o.car_id = cr.id
JOIN car_shop.models m ON cr.model_id = m.id
JOIN car_shop.brands b ON m.brand_name = b.name
WHERE b.brand_origin IS NOT NULL
GROUP BY b.brand_origin;



/* ВЫБОРКА 6
 * количество всех пользователей из США */
SELECT COUNT(*) AS persons_from_usa_count
FROM car_shop.clients
WHERE phone LIKE '+1%';

