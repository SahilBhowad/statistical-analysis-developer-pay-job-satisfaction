-- =========================================================================
-- Statistical Analysis of Developer Pay & Job Satisfaction: SQL
-- =========================================================================
-- Author  : Sahil Bhowad
-- Tool    : SQL Server (SSMS)
-- Table   : dev_survey (18,153 employed respondents, from so_survey_2025_clean.csv)
-- Purpose :
--		1. Validate the Python analysis: recompute the key numbers (sample size,
--		   medians, satisfaction) in SQL and confirm they match the notebook.
--		2. Answer the business questions behind each Power BI visual: KPIs, pay by
--		   work setup, role, country, experience and company size, and satisfaction.
-- =========================================================================

-- Create Database
CREATE DATABASE developer_survey_2025;

USE developer_survey_2025;

-- NOTE: The table dev_survey was created with the SSMS Import Flat File wizard
-- from so_survey_2025_clean.csv. Blank cells are loaded as NULL.

-- View the entire data
SELECT * FROM dev_survey ;

-- Questions :-

-- -------------------------------------------------------------------------
-- Q1. How many respondents are in clean data ?
-- -------------------------------------------------------------------------

SELECT COUNT(*) AS total_respondents FROM dev_survey;

-- Insight: The clean data has 18153 developers (matching sample size as Python/Power BI).

-- -------------------------------------------------------------------------
-- Q2. What are the overall pay and satisfaction numbers (dashboard KPI cards)?
-- -------------------------------------------------------------------------

WITH pay_stats AS(
	SELECT 
		MIN(ConvertedCompYearly) OVER () AS min_pay,
		MAX(ConvertedCompYearly) OVER () AS max_pay,
		AVG(ConvertedCompYearly) OVER () AS avg_pay,
		PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ConvertedCompYearly) OVER() AS median_pay,
		AVG(JobSat) OVER () AS avg_satisfaction
	FROM dev_survey 
),
satisfied_pct AS (
	SELECT
		CAST(100.0 * SUM(CASE WHEN JobSat >= 8 THEN 1 ELSE 0 END) / COUNT(JobSat) AS DECIMAL(5,2))  AS pct_satisfied
	FROM dev_survey
)
SELECT DISTINCT min_pay, max_pay, avg_pay, median_pay, avg_satisfaction, pct_satisfied
FROM pay_stats,satisfied_pct
;

-- Insight: Pay ranges from $1K to $500K (median $81,210, mean $94,784). 49.81% are highly satisfied (8+).

-- -------------------------------------------------------------------------
-- Q3. How many respondents work in each setup, and what is their share?
-- -------------------------------------------------------------------------

WITH remotecounts AS(
	SELECT 
		RemoteWork, 
		COUNT(*) AS total_respondents
	FROM dev_survey
	GROUP BY RemoteWork
	)
SELECT 
	RemoteWork, 
	total_respondents,
	CAST(100.0 * total_respondents / SUM(total_respondents) OVER () AS DECIMAL (5,2)) AS pct_respondents
FROM remotecounts
ORDER BY total_respondents DESC
;

-- Insight: Hybrid leads volume at 39.76% (7,218 respondents), followed by Remote (32.47%)

-- -------------------------------------------------------------------------
-- Q4. What is the median pay by work setup?
-- -------------------------------------------------------------------------

SELECT DISTINCT
	RemoteWork,
	COUNT(*) OVER(PARTITION BY RemoteWork) AS total_respondents,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY ConvertedCompYearly) OVER(PARTITION BY RemoteWork) AS median_pay
FROM dev_survey
ORDER BY median_pay DESC
;

-- Insight: Remote pays best with a $95,132 median, vs. $52,207 for In-person.

-- -------------------------------------------------------------------------
-- Q5. What is the average job satisfaction by work setup?
-- -------------------------------------------------------------------------

SELECT DISTINCT 
	RemoteWork,
	COUNT(*) OVER(PARTITION BY	RemoteWork) AS total_respondents,
	ROUND(AVG(JobSat) OVER(PARTITION BY RemoteWork),1) AS avg_satisfaction
FROM dev_survey
ORDER BY avg_satisfaction DESC
;

-- Insight: Flexible work setups have the highest average satisfaction at 7.4/10.

-- -------------------------------------------------------------------------
-- Q6. What percentage of respondents are highly satisfied (8+), by work setup?
-- -------------------------------------------------------------------------


SELECT
	RemoteWork,
	CAST(100.0 * SUM(CASE WHEN JobSat >=8 THEN 1 ELSE 0 END) / COUNT(JobSat)  AS DECIMAL (5,2)) AS pct_satisfied
FROM dev_survey
GROUP BY RemoteWork
ORDER BY pct_satisfied DESC
;

-- Insight: Flexible (54.18%) and Remote (53.07%) developers report the highest share of satisfaction.

-- -------------------------------------------------------------------------
-- Q7. How many managers and individual contributors are there, and what is their median pay?
-- -------------------------------------------------------------------------

SELECT DISTINCT 
	ICorPM,
	COUNT(*) OVER (PARTITION BY ICorPM) AS total_respondents,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY ConvertedCompYearly) OVER(PARTITION BY ICorPM) AS Median_pay
FROM dev_survey
;

-- Insight: Managers earn more ($93,611 median) than Individual Contributers ($78,890 median).

-- -------------------------------------------------------------------------
-- Q8. What is the median pay in the top 10 countries with the most respondents?
-- -------------------------------------------------------------------------

SELECT TOP 10
	Country,
	total_respondents,
	median_pay
FROM (
	SELECT DISTINCT TOP 10
	Country,
	COUNT(*) OVER (PARTITION BY Country) AS total_respondents,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY ConvertedCompYearly) OVER (PARTITION BY Country) AS median_pay
FROM dev_survey
ORDER BY total_respondents DESC) AS Top10ByRespondents
ORDER BY median_pay DESC
;

-- Insight: US leads with 4,215 respondents and a $150,000 median; India is lowest at $19,761.

-- -------------------------------------------------------------------------
-- Q9. How does median pay change with experience?
-- -------------------------------------------------------------------------

WITH experience_data AS(
	SELECT
		ConvertedCompYearly,
		CASE 
			WHEN WorkExp <=2 THEN '1) 0-2 Years'
			WHEN WorkExp <=5 THEN '2) 3-5 Years'
			WHEN WorkExp <=10 THEN '3) 6-10 Years'
			WHEN WorkExp <=20 THEN '4) 11-20 Years'
		ELSE '5) 20+ Years'
		END AS experience_groups
	FROM dev_survey
)
SELECT DISTINCT
	experience_groups,
	COUNT(*) OVER(PARTITION BY experience_groups) AS total_respondents,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY ConvertedCompYearly) OVER(PARTITION BY experience_groups) AS median_pay
FROM experience_data
ORDER BY experience_groups
;

-- Insight: Pay scales increases with more experience:- 0-2 years earn the lowest median ($32,484), while 20+ years earn the most ($114,725.5).

-- -------------------------------------------------------------------------
-- Q10. Do larger companies pay more?
-- -------------------------------------------------------------------------

SELECT
	OrgSize,
	total_respondents,
	median_pay
FROM(
	SELECT DISTINCT
	OrgSize,
	COUNT(*) OVER(PARTITION BY OrgSize) AS total_respondents,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY ConvertedCompYearly) OVER(PARTITION BY OrgSize) AS median_pay,
	CASE OrgSize
		WHEN 'Just me' THEN 1
		WHEN 'Less than 20' THEN 2
		WHEN '20-99' THEN 3
		WHEN '100-499' THEN 4
		WHEN '500-999' THEN 5
		WHEN '1,000-4,999' THEN 6
		WHEN '5,000-9,999' THEN 7
		WHEN '10,000+' THEN 8
	END AS OrgSize_order
	FROM dev_survey
) AS RankOrgSize
ORDER BY OrgSize_order
;

-- Insight: Median pay increases with company size, rising from $34,804 for solo developers up to $104,000 for enterprises with 10,000+ employees.

-- -------------------------------------------------------------------------
-- Q11. What is the median pay by work setup inside the United States?
-- -------------------------------------------------------------------------

WITH us_data AS(
	SELECT
		ConvertedCompYearly,
		RemoteWork
	FROM dev_survey
	WHERE Country = 'United States of America'
)
SELECT DISTINCT
	RemoteWork,
	COUNT(*) OVER(PARTITION BY RemoteWork) AS total_respondents,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY ConvertedCompYearly) OVER(PARTITION BY RemoteWork) AS median_pay
FROM us_data
ORDER BY median_pay DESC
;

-- Insight: In the US, Remote developers earn the highest median ($165,000) compared to In-person ($120,000).