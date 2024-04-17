--QUESTION 1
/*
 ASSUMPTION 1:  Counting only the number of times an item appeared on a successful customers' checkout.
                The QUANTITY of the item being checked out would NOT be considered.
 */
with successful_orders as
					(
					select p.id as product_id, p."name" as product_name, count(*) as num_times_in_successful_orders
					from alt_school.events e
					-- casting line_items "order_id" field as a string since the events table "order_id" in the array is in a string format
					join alt_school.line_items l on cast (l.order_id as text) = e.event_data ->> 'order_id'
					join alt_school.products p on p.id = l.item_id 
					-- to get successful orders the customer must have a check-out status displaying 'success'
					where event_data ->> 'status' = 'success'
					group by 1,2)
select *
from successful_orders s
--To avoid overfitting, I used a subquery to return the highest order where if there is a tie it returns the results
where num_times_in_successful_orders = (select max(num_times_in_successful_orders) from successful_orders);


--QUESTION 2
/* 
 * Assumption 1: A customer can not add back a product after it has been removed from cart
 * Assumption 2: A customer can only add a specific product once through out the shopping period. 
*/
with successful_orders as( --Using a cte to get all customers that successfully checked out
							select * from alt_school.events
							where event_data->>'status' = 'success'
                            ),
successful_customers_cart as (
--This cte gets the cart history of all customers who successfully placed an order i.e all items that were added and removed from cart
								select customer_id, e.event_data->>'item_id' as item_id, 
                                e.event_data->>'quantity' as quantity,e.event_data->>'event_type' as event_type,
                                e.event_timestamp
								from alt_school.events e
--Using the customer_id of "successful_orders" cte, a join is used to return only customers who eventually successfully checked out
								join successful_orders using (customer_id)
                                where e.event_data ->> 'event_type' in ('add_to_cart', 'remove_from_cart')
								order by customer_id, event_timestamp
								),
final_products_in_cart as (
/* For this cte, I counted the number of times an action was carried out on an item in the cart.
ASSUMPTION 3: A customer who buys an item should only perform one action(add_to_cart) per item and if 2 actions
              (add_to_cart and removed_from_cart) were performed on the same item then the item was not bought.  */
							select customer_id, item_id 
							from(
								select customer_id ,item_id, count(item_id) as actions
								from successful_customers_cart
								group by 1,2
								) as cart_updates
							where actions = 1
							),
sales_record as (
				select s.customer_id, p."name" as product_name, quantity, 
                        (cast (quantity as int)*price) as amount_spent, "location"
--quantity is gotten from the events table so it is in a string formart and had to be casted as an integer
                from successful_customers_cart s
				join final_products_in_cart f on s.customer_id = f.customer_id and s.item_id = f.item_id
				join alt_school.customers c on s.customer_id = c.customer_id 
				join alt_school.products p on cast (s.item_id as int) = p.id
				)
select customer_id , "location" , sum(amount_spent) as total_spend
from sales_record
group by 1,2
order by 3 desc
limit 5;



-- QUESTION 3
with checked_out_customers as(--Customers who successfully checked out
							select customer_id 
							from alt_school.events e
							where event_data->>'status' = 'success'
							),
top_performing_locations as (
							select "location" as "location", count(*) as checkout_count
							from alt_school.customers c
							join checked_out_customers using (customer_id)
							group by "location"
							)
select * from top_performing_locations
where checkout_count = (select max(checkout_count) from top_performing_locations);


-- QUESTION 4 
/*
 ASSUMPTION 1: Asides from customers who had a failed or cancelled checkout status, 
                people who did not get to the checkout page are also included as customers who abandoned carts
 */
with unsuccessful_orders as(
							select *
							from alt_school.events e
							where customer_id not in(
													select customer_id from alt_school.events where event_data ->> 'status' = 'success'
													)
								and event_data ->> 'event_type' not in ('visit','checkout')
							)
select customer_id, count(*) as num_events 
from unsuccessful_orders
group by customer_id
order by num_events desc; 


--QUESTION 5
/*
ASSUMPTION 1: average_visit is the average number of visits a customer usually have before they make a purchase.
                This is the average of all the total visits made by all customers before a successful order
*/
with successful_orders_visits as(
								select customer_id, count(event_data->> 'event_type') as total_visit 
                                from alt_school.events 
								where event_data ->> 'event_type' = 'visit' 
								and customer_id in(
												select customer_id from alt_school.events where event_data ->> 'status' = 'success')
								group by customer_id 
								)
select round(avg(total_visit), 2) as average_visit from successful_orders_visits;