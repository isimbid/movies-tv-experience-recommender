-- Find experiences that show up more often among the best-received titles.
-- Adjusted ratings account for both rating quality and vote volume.

WITH media_baselines AS (

    SELECT
        media_type,
        AVG(vote_average) AS media_avg_rating,
        MEDIAN(vote_count) AS media_median_votes

    FROM titles

    WHERE
        vote_count >= 10
        AND vote_average > 0

    GROUP BY media_type
),

adjusted_titles AS (

    SELECT
        t.title_key,
        t.media_type,
        t.vote_average,
        t.vote_count,

        -- Pull low-vote titles toward the format average.
        (
            (t.vote_count / (t.vote_count + b.media_median_votes))
            * t.vote_average
        )
        +
        (
            (b.media_median_votes / (t.vote_count + b.media_median_votes))
            * b.media_avg_rating
        ) AS adjusted_rating

    FROM titles AS t

    INNER JOIN media_baselines AS b
        ON t.media_type = b.media_type

    WHERE
        t.vote_count >= 10
        AND t.vote_average > 0
),

ranked_titles AS (

    SELECT
        *,
        PERCENT_RANK() OVER (
            PARTITION BY media_type
            ORDER BY adjusted_rating
        ) AS reception_percentile

    FROM adjusted_titles
),

experience_thresholds AS (

    SELECT
        media_type,
        experience,
        QUANTILE_CONT(score, 0.75) AS strong_threshold

    FROM analysis_dataset

    GROUP BY
        media_type,
        experience
),

classified_experiences AS (

    SELECT
        r.title_key,
        r.media_type,
        r.reception_percentile,
        e.experience,
        e.category,

        CASE
            WHEN e.score >= t.strong_threshold THEN 1
            ELSE 0
        END AS strong_experience

    FROM ranked_titles AS r

    INNER JOIN experience_scores AS e
        ON r.title_key = e.title_key
        AND r.media_type = e.media_type

    INNER JOIN experience_thresholds AS t
        ON r.media_type = t.media_type
        AND e.experience = t.experience
),

experience_patterns AS (

    SELECT
        media_type,
        experience,
        category,

        -- Compare the top 20% of titles with all eligible titles.
        AVG(
            CASE
                WHEN reception_percentile >= 0.80
                THEN strong_experience
            END
        ) AS top_title_share,

        AVG(strong_experience) AS overall_share

    FROM classified_experiences

    GROUP BY
        media_type,
        experience,
        category
)

SELECT
    media_type,
    experience,
    category,
    ROUND(top_title_share * 100, 1) AS top_title_pct,
    ROUND(overall_share * 100, 1) AS overall_pct,
    ROUND(
        (top_title_share - overall_share) * 100,
        1
    ) AS overrepresentation_pp

FROM experience_patterns

ORDER BY
    media_type,
    overrepresentation_pp DESC;
