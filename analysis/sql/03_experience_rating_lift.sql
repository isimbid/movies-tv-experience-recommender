-- Compare ratings for titles that strongly deliver each experience
-- with other titles of the same media type.
-- Strong experience titles are the top 25% within each format.

WITH experience_thresholds AS (

    SELECT
        media_type,
        experience,
        QUANTILE_CONT(score, 0.75) AS strong_threshold

    FROM analysis_dataset

    GROUP BY
        media_type,
        experience
),

classified_titles AS (

    SELECT
        a.media_type,
        a.experience,
        a.category,
        a.title_key,
        a.vote_average,
        a.vote_count,

        CASE
            WHEN a.score >= t.strong_threshold THEN 1
            ELSE 0
        END AS strong_experience

    FROM analysis_dataset AS a

    INNER JOIN experience_thresholds AS t
        ON a.media_type = t.media_type
        AND a.experience = t.experience

    WHERE
        a.vote_count >= 10
        AND a.vote_average > 0
),

rating_summary AS (

    SELECT
        media_type,
        experience,
        category,

        SUM(strong_experience) AS strong_title_count,
        SUM(CASE WHEN strong_experience = 0 THEN 1 ELSE 0 END) AS other_title_count,

        -- Give every title equal weight.
        ROUND(
            AVG(CASE WHEN strong_experience = 1 THEN vote_average END),
            2
        ) AS strong_avg_rating,

        ROUND(
            AVG(CASE WHEN strong_experience = 0 THEN vote_average END),
            2
        ) AS other_avg_rating,

        -- Give titles with more audience votes more weight.
        ROUND(
            SUM(
                CASE
                    WHEN strong_experience = 1
                    THEN vote_average * vote_count
                END
            )
            /
            NULLIF(
                SUM(CASE WHEN strong_experience = 1 THEN vote_count END),
                0
            ),
            2
        ) AS strong_weighted_rating,

        ROUND(
            SUM(
                CASE
                    WHEN strong_experience = 0
                    THEN vote_average * vote_count
                END
            )
            /
            NULLIF(
                SUM(CASE WHEN strong_experience = 0 THEN vote_count END),
                0
            ),
            2
        ) AS other_weighted_rating

    FROM classified_titles

    GROUP BY
        media_type,
        experience,
        category
)

SELECT
    *,
    ROUND(strong_avg_rating - other_avg_rating, 2) AS title_rating_lift,
    ROUND(
        strong_weighted_rating - other_weighted_rating,
        2
    ) AS weighted_rating_lift

FROM rating_summary

ORDER BY
    media_type,
    weighted_rating_lift DESC;
