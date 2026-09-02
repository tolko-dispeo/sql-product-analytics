WITH cancelled_orders AS (
    SELECT order_id
    FROM user_actions
    WHERE action = 'cancel_order'
),

order_products AS (
    SELECT
        orders.order_id,
        orders.creation_time::date AS date,
        unnest(orders.product_ids) AS product_id
    FROM orders
    WHERE orders.order_id NOT IN (
        SELECT order_id
        FROM cancelled_orders
    )
),

daily_revenue AS (
    SELECT
        order_products.date,
        SUM(products.price) AS sum_orders_of_day
    FROM order_products
    LEFT JOIN products USING (product_id)
    GROUP BY order_products.date
),

first_pay_date AS (
    SELECT
        user_actions.user_id,
        MIN(user_actions.time)::date AS date
    FROM user_actions
    WHERE user_actions.order_id NOT IN (
        SELECT order_id
        FROM cancelled_orders
    )
    GROUP BY user_actions.user_id
),

new_pay_users_by_day AS (
    SELECT
        first_pay_date.date,
        COUNT(first_pay_date.user_id) AS new_pay_users
    FROM first_pay_date
    GROUP BY first_pay_date.date
),

first_action_date AS (
    SELECT
        user_actions.user_id,
        MIN(user_actions.time)::date AS date
    FROM user_actions
    GROUP BY user_actions.user_id
),

new_users_by_day AS (
    SELECT
        first_action_date.date,
        COUNT(first_action_date.user_id) AS new_ussualy_users
    FROM first_action_date
    GROUP BY first_action_date.date
),

orders_by_day AS (
    SELECT
        courier_actions.time::date AS date,
        COUNT(courier_actions.order_id) AS count_orders
    FROM courier_actions
    WHERE courier_actions.order_id NOT IN (
        SELECT order_id
        FROM cancelled_orders
    )
      AND courier_actions.action = 'accept_order'
    GROUP BY courier_actions.time::date
),

daily_metrics AS (
    SELECT
        daily_revenue.date,
        daily_revenue.sum_orders_of_day,
        new_pay_users_by_day.new_pay_users,
        new_users_by_day.new_ussualy_users,
        orders_by_day.count_orders
    FROM daily_revenue
    LEFT JOIN new_pay_users_by_day USING (date)
    LEFT JOIN new_users_by_day USING (date)
    LEFT JOIN orders_by_day USING (date)
),

running_metrics AS (
    SELECT
        daily_metrics.date,

        SUM(daily_metrics.new_ussualy_users)
            OVER (ORDER BY daily_metrics.date)::integer
            AS nacop_action_users,

        SUM(daily_metrics.new_pay_users)
            OVER (ORDER BY daily_metrics.date)::integer
            AS nacop_pay_users,

        SUM(daily_metrics.count_orders)
            OVER (ORDER BY daily_metrics.date)::integer
            AS nacop_count_orders,

        SUM(daily_metrics.sum_orders_of_day)
            OVER (ORDER BY daily_metrics.date)::integer
            AS nacop_sum_orders_of_day

    FROM daily_metrics
)

SELECT
    running_metrics.date,

    ROUND(
        running_metrics.nacop_sum_orders_of_day::decimal
        / running_metrics.nacop_action_users,
        2
    ) AS running_arpu,

    ROUND(
        running_metrics.nacop_sum_orders_of_day::decimal
        / running_metrics.nacop_pay_users,
        2
    ) AS running_arppu,

    ROUND(
        running_metrics.nacop_sum_orders_of_day
        / running_metrics.nacop_count_orders::decimal,
        2
    ) AS running_aov

FROM running_metrics
ORDER BY running_metrics.date
