WITH cancelled_orders AS (
    SELECT order_id
    FROM user_actions
    WHERE action = 'cancel_order'
),

order_products AS (
    SELECT
        orders.order_id,
        UNNEST(orders.product_ids) AS product_id,
        orders.creation_time::date AS date
    FROM orders
    WHERE orders.order_id NOT IN (
        SELECT order_id
        FROM cancelled_orders
    )
),

daily_revenue AS (
    SELECT
        order_products.date,
        SUM(products.price) AS revenue
    FROM order_products
    LEFT JOIN products USING (product_id)
    GROUP BY order_products.date
),

first_action_dates AS (
    SELECT
        user_actions.user_id,
        MIN(user_actions.time::date) AS date
    FROM user_actions
    GROUP BY user_actions.user_id
),

user_orders AS (
    SELECT
        user_actions.user_id,
        user_actions.time::date AS date,
        user_actions.order_id
    FROM user_actions
    WHERE user_actions.order_id NOT IN (
        SELECT order_id
        FROM cancelled_orders
    )
),

user_order_products AS (
    SELECT
        user_orders.user_id,
        user_orders.date,
        user_orders.order_id,
        UNNEST(orders.product_ids) AS product_id
    FROM user_orders
    LEFT JOIN orders USING (order_id)
),

user_daily_revenue AS (
    SELECT
        user_order_products.user_id,
        user_order_products.date,
        SUM(products.price) AS sum_price
    FROM user_order_products
    LEFT JOIN products USING (product_id)
    GROUP BY
        user_order_products.user_id,
        user_order_products.date
),

new_users_revenue AS (
    SELECT
        user_daily_revenue.date,
        SUM(user_daily_revenue.sum_price) AS new_users_revenue
    FROM first_action_dates
    LEFT JOIN user_daily_revenue
        ON first_action_dates.user_id = user_daily_revenue.user_id
        AND first_action_dates.date = user_daily_revenue.date
    GROUP BY user_daily_revenue.date
)

SELECT
    daily_revenue.date,
    daily_revenue.revenue,
    new_users_revenue.new_users_revenue,

    ROUND(
        new_users_revenue.new_users_revenue
        / daily_revenue.revenue::decimal * 100,
        2
    ) AS new_users_revenue_share,

    ROUND(
        100 - ROUND(
            new_users_revenue.new_users_revenue
            / daily_revenue.revenue::decimal * 100,
            2
        ),
        2
    ) AS old_users_revenue_share

FROM daily_revenue
LEFT JOIN new_users_revenue USING (date)
ORDER BY daily_revenue.date
