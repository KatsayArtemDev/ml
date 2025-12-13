/* Проект «Разработка витрины и решение ad-hoc задач»
 * Цель проекта: подготовка витрины данных маркетплейса «ВсёТут»
 * и решение четырех ad hoc задач на её основе
 *
 * Автор: Кацай Артём
 * Дата: 20.08.2025
*/

/* Часть 1. Разработка витрины данных
 * Напишите ниже запрос для создания витрины данных
*/

create table product_user_features as
	with
		filtered_orders as (
			select *
			from orders
			where order_status in ('Доставлено', 'Отменено')
		),
		top_regions as (
			select region
			from users u
			join filtered_orders fo on fo.buyer_id = u.buyer_id
			group by region
			order by count(order_id) desc
			limit 3
		),
		user_orders as (
			select u.user_id
				 , u.region
				 , min(fo.order_purchase_ts) first_order_ts
				 , max(fo.order_purchase_ts) last_order_ts
				 , count(fo.order_id) total_orders
				 , sum(coalesce(orr.has_review_score, 0)) total_orders_rating
				 , count(orr.order_id) num_orders_with_rating
				 , count(case when fo.order_status = 'Отменено' then 1 end) num_canceled_orders
				 , sum(coalesce(case when order_status != 'Отменено' then oi.total_cost end, 0)) total_order_costs
				 , avg(coalesce(case when order_status != 'Отменено' then oi.total_cost end, 0))::numeric(8, 2) avg_order_cost
				 , sum(op.has_installments) num_installment_orders
				 , sum(op.has_promo) num_orders_with_promo
				 , max(op.money_transfer_first) used_money_transfer
				 , max(op.has_installments) used_installments
				 , max(case when fo.order_status = 'Отменено' then 1 else 0 end) used_cancel
			from filtered_orders fo
			join users u on u.buyer_id = fo.buyer_id
			left join (
				select
					order_id,
					avg(case
						when review_score > 5
							then review_score / 10
						else review_score
					end) has_review_score
				from order_reviews
				group by order_id
			) orr using(order_id)
			left join (
				select order_id
					 , max(case when payment_installments > 1 then 1 else 0 end) has_installments
					 , max(case when payment_type = 'промокод' then 1 else 0 end) has_promo
					 , max(case when payment_type = 'денежный перевод' and payment_sequential = 1 then 1 else 0 end) money_transfer_first
				from order_payments
				group by order_id
			) op using(order_id)
			left join (
				select order_id
				     , max(order_item_id) installment_orders
					 , sum(price+delivery_cost) total_cost
				from order_items
				group by order_id
			) oi using(order_id)
			where u.region in (
				select tr.region
				from top_regions tr
			)
			group by u.user_id, u.region
		)
	select user_id
 		 , region
 		 , first_order_ts
 		 , last_order_ts
 		 , (last_order_ts - first_order_ts) lifetime
 		 , total_orders
 		 , coalesce(total_orders_rating / nullif(num_orders_with_rating, 0)::float, 0)::numeric(3, 2) avg_order_rating
 		 , num_orders_with_rating
 		 , num_canceled_orders
 		 , (num_canceled_orders/total_orders::float)::numeric(5, 4) canceled_orders_ratio
 		 , total_order_costs
 		 , avg_order_cost
 		 , num_installment_orders
 		 , num_orders_with_promo
 		 , used_money_transfer
 		 , used_installments
 		 , used_cancel
	from user_orders
	order by total_orders desc
	
	

/* Часть 2. Решение ad hoc задач
 * Для каждой задачи напишите отдельный запрос.
 * После каждой задачи оставьте краткий комментарий с выводами по полученным результатам.
*/


/*❗❗❗ Bag Report
 * Нашёл критические ошибки в предоставленной для анализа витрине:
 * - Из-за JOIN теряется 79 пользователей.
 * - Из-за LEFT JOIN user_features появляются дубли (см. таблицу ниже).
 * 
 * Всего витрина должна вернуть 62.487 строк. Это подтверждается запросом ниже, который учитывает все ключевые условия.
 * При анализе дополнительных показателей (max, min...) это число строк строго не должно изменяться. 
 * Для упрощения вынес регионы - они входят в топ-3. Статусы заказов учитываются.
*/
	with
		user_orders as (
			select u.user_id
				 , u.region
			from users u 
			join orders fo on u.buyer_id = fo.buyer_id
			where u.region in ('Москва', 'Новосибирская область', 'Санкт-Петербург') and order_status in ('Доставлено', 'Отменено')
			group by u.user_id, u.region
		)
	select count(user_id)
	from user_orders
/* 
 * Ваша витрина возвращает 62.442 строки - на 45 пользователей меньше, чем должно быть.
 * На самом деле из-за ошибок в join-ах потеряно 79 пользователей, выявленных путем сравнения с запросом выше (user_id not in (...)).
 * Разница в 45 объясняется дублированием данных.
 * Если поправить запрос витрины и в конце сделать:
 * final_result.user_id,
    final_result.region,
    count(*)
 * 
 *  То выяснится, что одни и те же пользователи с регионами дублируются по 2-3 раза:
 * 
 *  d44ccec15f5f86d14d6a2cfa67da1975	Москва	                3
	f7b62c75467e8ce080b201667cbbc274	Санкт-Петербург	        2
	fe3e52de024b82706717c38c8e183084	Новосибирская область	2
	d5f79f616536f08c3946ee6ac810a43a	Москва	             	2
	e836a4279bd9127752d8949d46f7a5a5	Москва	 			    2
	...
 * 
 * Исправление для вашей витрины может быть следующее:
 * - Перенести в CTE final_result то, что находится в user_features, это основное место появления дубликатов.
 * - Выполнить все три объединения через LEFT JOIN в orders_info, чтобы не потерять часть пользователей.
 * 
 * По порядку:
 * В CTE final_result убрать LEFT JOIN user_features USING (user_id) - это приводит к дубликатам, пример которых выше.
 * Стоит перенести код user_features ниже внутрь запроса final_result:

    ), orders_info AS (
	   SELECT users_info.user_id,
	   ...,
	   users_info.num_orders_with_promo,
	   users_info.used_money_transfer,
	   CASE
	        WHEN users_info.num_installment_orders >= 1 THEN 1
	        ELSE 0
	    END AS used_installments,
	    CASE
	        WHEN users_info.num_canceled_orders >= 1 THEN 1
	        ELSE 0
	    END AS used_cancel
	   FROM users_info

 * Тем самым дубликаты будут убраны.
 * Но при этом часть пользователей всё также утеряна при join-ах выше.
 * В CTE orders_info нужно делать все 3 объединения не через join, а через left join.
 * FROM ds_ecom.orders
     LEFT JOIN orders_payment_stat USING (order_id)
     LEFT JOIN first_payment_type_per_order USING (order_id)
     LEFT JOIN order_rating USING (order_id)
 *
 * После этого при подсчёте пользователей результат будет 62.487, как и ожидалось.
 * ❗❗❗ 
 */
	
/* Задача 1. Сегментация пользователей
 * Разделите пользователей на группы по количеству совершённых ими заказов.
 * Подсчитайте для каждой группы общее количество пользователей,
 * среднее количество заказов, среднюю стоимость заказа.
 *
 * Выделите такие сегменты:
 * - 1 заказ — сегмент 1 заказ
 * - от 2 до 5 заказов — сегмент 2-5 заказов
 * - от 6 до 10 заказов — сегмент 6-10 заказов
 * - 11 и более заказов — сегмент 11 и более заказов
*/

select case
		when total_orders = 1
			then '1 заказ'
		when total_orders between 2 and 5
			then '2—5 заказов'
		when total_orders between 6 and 10
			then '6–10 заказов'
		when total_orders >= 11
			then '11 и более заказов'
	   end segment
	 , count(*) total_segment_orders
	 , avg(total_orders)::numeric(5, 2) avg_segment_orders
	 , (sum(total_order_costs) / sum(total_orders))::numeric(8, 2) avg_order_cost
from product_user_features
group by segment
order by total_segment_orders desc

/* Напишите краткий комментарий с выводами по результатам задачи 1.
 * 
 * Большинство пользователей совершили 1 заказ (58.807 раз) со средним чеком в 3.299,25.
 * От 2 до 5 заказов сделали 3.615 пользователей, заказав в среднем чуть больше 2 заказов, со средним чеком в 3.131,13.
 * От 6 до 10 заказов сделали 73 пользователя, заказав в среднем 7 заказов, со средним чеком в 3.294,10.
 * 25 пользователей вошли в последний сегмент, заказав в среднем чуть больше 15 товаров. При этом средний чек - 3.369,26.
*/



/* Задача 2. Ранжирование пользователей
 * Отсортируйте пользователей, сделавших 3 заказа и более, по убыванию среднего чека покупки.
 * Выведите 15 пользователей с самым большим средним чеком среди указанной группы.
*/

select user_id
	 , coalesce(total_order_costs / total_orders, 0)::numeric(8,2) avg_cost
from product_user_features
where total_orders >= 3
order by avg_cost desc
limit 15

/* Напишите краткий комментарий с выводами по результатам задачи 2.
 * 
 * Максимальний средний чек покупки среди пользователей, совершивших 3 и более заказа - 29.475.
 * Минимальный из топ-15 пользователей был средний чек в 11.970.
*/



/* Задача 3. Статистика по регионам.
 * Для каждого региона подсчитайте:
 * - общее число клиентов и заказов;
 * - среднюю стоимость одного заказа;
 * - долю заказов, которые были куплены в рассрочку;
 * - долю заказов, которые были куплены с использованием промокодов;
 * - долю пользователей, совершивших отмену заказа хотя бы один раз.
*/

with 
region_statistics as (
	select region
		 , count(user_id) total_users
		 , sum(total_orders) total_orders
		 , avg(avg_order_cost)::numeric(8,2) avg_order_cost
		 , sum(num_installment_orders) total_installment_orders
		 , sum(num_orders_with_promo) total_orders_with_promo
		 , sum(num_canceled_orders) total_canceled_orders
	from product_user_features
	group by region
)
select region
	 , total_users
	 , total_orders
	 , avg_order_cost
	 , (total_installment_orders / total_orders::float)::numeric(3,2) installment_ratio
	 , (total_orders_with_promo / total_orders::float)::numeric(3,2) promo_ratio
	 , (total_canceled_orders / total_users::float)::numeric(4,3) canceled_ratio
from region_statistics

/* Напишите краткий комментарий с выводами по результатам задачи 3.
 *
 * Самое большое число пользователей зафиксировано в Москве - 39.455 (является лидером по количеству заказов - 42.686). 
 * При этом меньше всего пользователей из Новосибирская области - 11.064 (является аутсайдером по количеству заказов - 11.881).
 * Максимальный средний чек в Санкт-Петербурге - 3.618,47, минимальный в Москве - 3.164,58.
 * Рассрочкой больше всего пользовались в Санкт-Петербурге и в Новосибирской области по 53%, меньше всего в Москве - 47%.
 * Доля промокодов при оплате от общего числа заказов у всех регионов от 7% до 9%.
 * У всех регионов доля отменённых заказов от числа всех пользователей <1%.
*/



/* Задача 4. Активность пользователей по первому месяцу заказа в 2023 году
 * Разбейте пользователей на группы в зависимости от того, в какой месяц 2023 года они совершили первый заказ.
 * Для каждой группы посчитайте:
 * - общее количество клиентов, число заказов и среднюю стоимость одного заказа;
 * - средний рейтинг заказа;
 * - долю пользователей, использующих денежные переводы при оплате;
 * - среднюю продолжительность активности пользователя.
*/

with 
users_activity as (
    select extract(month from first_order_ts) month_date
         , count(distinct user_id) total_users
         , sum(total_orders) total_orders
         , avg(avg_order_cost)::numeric(8,2) avg_order_cost
         , avg(avg_order_rating)::numeric(3,2) avg_review_score
         , sum(used_money_transfer) total_money_transaction
         , avg(lifetime) avg_lifetime
    from product_user_features
	where first_order_ts >= '2023-01-01' and first_order_ts < '2024-01-01' 
    group by month_date
    order by month_date
)
select month_date
     , total_users
     , total_orders
     , avg_order_cost
     , avg_review_score
     , (total_money_transaction / total_users::float)::numeric(3,2) as money_transaction_share
     , avg_lifetime
from users_activity

/* Напишите краткий комментарий с выводами по результатам задачи 4.
 * 
 * Данные за 2023 год:
 * Самый пиковый месяц по пользователям, которые совершили заказ - ноябрь (4.707 пользователей и 5.125 заказов (лидер по числу заказов)). 
 * Меньше всего пришлось на январь (465 пользователей и 541 заказ (аутсайдер по числу заказов)).
 * Самая большая средняя цена покупки была в сентябре - 3.309,36, наименьшая пришлась на февраль - 2.581,28.
 * Самые лучшие средние оценки товарам ставили в августе - 4,31 из 5, худшие средние оценки пользователи ставили в ноябре 4 из 5.
 * Денежные переводы во всех масяцах варьируются от 19% до 22%.
 * Продолжительность активности пользователя варьируется от 2 дней и 5 часов в декабре до 12 дней и 19 часов в январе.
 */

