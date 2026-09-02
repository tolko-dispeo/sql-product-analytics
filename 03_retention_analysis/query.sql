WITH user_activity AS (
    SELECT
        user_actions.user_id,
        user_actions.time::date AS date,
        MIN(user_actions.time::date)
            OVER (PARTITION BY user_actions.user_id) AS start_date
    FROM user_actions
),

cohort_activity AS (
    SELECT
        user_activity.date,
        user_activity.start_date,
        COUNT(DISTINCT user_activity.user_id) AS users_count
    FROM user_activity
    GROUP BY
        user_activity.date,
        user_activity.start_date
),

retention_by_day AS (
    SELECT
        cohort_activity.date,
        cohort_activity.start_date,
        cohort_activity.users_count,

        MAX(cohort_activity.users_count)
            OVER (PARTITION BY cohort_activity.start_date) AS cohort_size,

        ROUND(
            cohort_activity.users_count
            / MAX(cohort_activity.users_count)
                OVER (PARTITION BY cohort_activity.start_date)::decimal,
            2
        ) AS retention

    FROM cohort_activity
)

SELECT
    CASE
        WHEN DATE_PART('month', retention_by_day.start_date) = 8
            THEN DATE '2022-08-01'
        WHEN DATE_PART('month', retention_by_day.start_date) = 9
            THEN DATE '2022-09-01'
    END AS start_month,

    retention_by_day.start_date,

    retention_by_day.date
        - retention_by_day.start_date AS day_number,

    retention_by_day.retention

FROM retention_by_day

ORDER BY
    retention_by_day.start_date,
    day_number
