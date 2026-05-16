/*
 * function time_subtype_diff необходима для приведения времени к числовому формату
 * type timerange - создание диапазонного типа в формате time, который изначально не существует.
 */
create function time_subtype_diff(x time, y time) returns float8 as
'select extract(epoch from (x - y))' language sql strict immutable;

create type timerange as range (
    subtype = time,
    subtype_diff = time_subtype_diff
);

--Создаете схему со своим именем
create schema khashchanov_food

/*
 * Пример создания типов данных enum
 */
create type staff_status as enum (
	'свободен',
	'занят',
	'все надоело')

create type pay_type as enum (
	'нал',
	'карта',
	'мешки с картошкой')

/*
 * Пример создания таблиц. 
 * Данные таблицы НЕ являются конечным результатом, это пример для демонстрации генерации данных. 
 */
create table staff (
	staff_id uuid primary key,
	fio varchar(120) not null,
	salary_rate int not null check (salary_rate between 1 and 5),
	status staff_status not null,
	hire_date date not null, 
	dismissal_date date,
	work_time timerange not null)
	
create table staff_pay (
	staff_id uuid references staff (staff_id),
	month int not null,
	year int not null,
	total_pay numeric not null,
	primary key(staff_id, month, year))

create table users (
	user_id uuid primary key,
	fio varchar(120) not null,
	phone char(11) not null,
	email varchar(50) not null unique)
	
create table orders (
	order_id uuid primary key, 
	user_id uuid not null references users (user_id),
	description text,
	pay_type pay_type not null,
	delivery_period timerange not null,
	staff_id uuid not null references staff (staff_id),
	delivery_end_timestamp timestamp,
	total_amount numeric not null,
	total_amount_tax numeric not null)
	
/*
 * Пример того, как должны генерироваться данные. 
 * Формируете свою процедуру по этой логике.
 */
create or replace procedure insert_test_data(value int) as $$
declare 
	str text = 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя';--задаем строку для последующей генерации
	total_amount_var numeric(6, 2); --для получения суммы по заказу и возможности добавления комиссии
	i record; --для циклов
begin
	for i in 1..value
	loop
		insert into staff
		values (
			exts.uuid_generate_v4(), --генерируем uuid
			left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 3)::int), 120), --генерируем строку от 1 до 132 символов и урезаем до 120
			ceil(random() * 5), --генерируем целое от 1 до 5
			(enum_range(NULL::staff_status))[ceil(random() * cardinality(enum_range(NULL::staff_status)))], --генерируем случайное значение из типа данных
			current_date - (random() * 180)::int, --генерируем случайную дату за последние 6 месяцев
			null, --предполагаем, что уволенных нет
			timerange((ceil(random() * 10)::text || ':00')::time, ((ceil(random() * 10) + 10)::text || ':00')::time));--генерируем временной диапазон
		insert into users
		values (
			exts.uuid_generate_v4(), 
			left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 3)::int), 120),
			'+' || ceil(random()*999999999 + 7000000000),--генерируем простой номер телефона
			'user' || floor(random() * 100000)::text || '@example.com');--генерируем простую почту	
	end loop;
	for i in 1..value * 5
	loop
		total_amount_var = (random() * 5000)::numeric(6, 2); --генерируем случайное значение суммы из расчета, что стоимость заказа не превышает 5000
		insert into orders
		values(
			exts.uuid_generate_v4(),
			(select user_id from users order by random() limit 1),--вытаскиваем случайный user_id из клиентов
			repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 10)::int), --генерируем строку от 1 до 330 символов
			(enum_range(NULL::pay_type))[ceil(random() * cardinality(enum_range(NULL::pay_type)))], --генерируем случайное значение из типа данных
			timerange((ceil(random() * 10)::text || ':00')::time, ((ceil(random() * 10) + 10)::text || ':00')::time),--генерируем временной диапазон
			(select staff_id from staff order by random() limit 1),--вытаскиваем случайный staff_id из сотрудников
			current_timestamp - (random() * 262800)::int  * interval '1 min', --генерируем случайный timestamp за последние 6 месяцев
			total_amount_var,
			total_amount_var * 1.1); --добавили 10% комиссии
	end loop;
	--Так как в staff_pay составной PK, то генерировать любое кол-во строк НЕЛЬЗЯ. 
	--Генерируем кол-во строк по формуле: кол-во сотрудников * 12 месяцев, если речь идет о данных за один год 
	for i in 
		select staff_id from staff where staff_id not in (select staff_id from staff_pay) --делаем проверку, что сотрудников, которые есть в базе не используем
	loop
		for j in 1..12--12 месяцев
		loop
			insert into staff_pay
			values(
				i.staff_id,
				j,
				2026,--предполагаем, что данные будут только за 2026 год
				(random() * 200000)::numeric(8, 2));--генерируем случайную зарплату от 0 до 200000
		end loop;
	end loop;
end;
$$ language plpgsql

--запускаем процедуру
call insert_test_data(10)
