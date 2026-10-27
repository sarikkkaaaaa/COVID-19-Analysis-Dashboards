create database covid;
use covid;
GO

-- ============================================================
-- BASE QUERIES (unchanged except where marked FIX)
-- ============================================================

-- Don't contain null continent data
select * from Covid19
where continent is not null;

-- Exact columns which we need
select location, population, date, total_cases, new_cases, total_deaths, new_deaths
from Covid19
where continent is not null
order by date;

-- Multi-level sorting
select location, population, date, total_cases, new_cases, total_deaths, new_deaths
from Covid19
where continent is not null
order by 1,3;

-- %age of new cases everyday by total cases
select location, population, date, total_cases, new_cases,
       round((cast(new_cases as float)/nullif(total_cases,0))*100,2) as NC_Ratio
from Covid19
where continent is not null;

-- %age of new cases everyday by Population
-- FIX: 4 decimals (daily % of population is tiny, 2 decimals rounded almost everything to 0.00)
select location, population, date, new_cases,
       round((cast(new_cases as float)/nullif(population,0))*100,4) as NC_Ratio_Population
from Covid19
where continent is not null;

-- %age of total cases by Population  (FIX: 4 decimals)
select location, population, date, total_cases,
       round((cast(total_cases as float)/nullif(population,0))*100,4) as TC_Ratio_Population
from Covid19
where continent is not null;

-- %age of total deaths by Population  (FIX: 4 decimals)
select location, population, date, total_deaths,
       round((cast(total_deaths as float)/nullif(population,0))*100,4) as TD_Ratio_Population
from Covid19
where continent is not null;

-- %age of total deaths by Total Cases
select location, date, total_cases, total_deaths,
       round((cast(total_deaths as float)/nullif(total_cases,0))*100,2) as TD_Ratio_TC
from Covid19
where continent is not null;

-- %age of New deaths by Total deaths
select location, date, new_deaths, total_deaths,
       round((cast(new_deaths as float)/nullif(total_deaths,0))*100,2) as ND_Ratio_TD
from Covid19
where continent is not null;

-- %age of New deaths by Total cases
select location, date, new_deaths, total_cases,
       round((cast(new_deaths as float)/nullif(total_cases,0))*100,2) as ND_Ratio_TC
from Covid19
where continent is not null;
GO

-- ============================================================
-- FIX: ONE ROW PER COUNTRY WITH ITS LATEST (MAX) TOTALS
-- total_cases / total_deaths are cumulative, so MAX per country = final total.
-- Every KPI below reads from this view so the numbers stay consistent.
-- (CREATE VIEW must be the first statement in a batch, hence the GO above/below.)
-- ============================================================
CREATE VIEW vw_country_totals AS
SELECT
    continent,
    location,
    MAX(population)   AS population,
    MAX(total_cases)  AS total_cases,
    MAX(total_deaths) AS total_deaths
FROM Covid19
WHERE continent IS NOT NULL
GROUP BY continent, location;
GO

-- ============================================================
-- KPI CARDS
-- FIX: sum of per-country totals, not MAX across all rows
-- Expected: ~3,180,223 deaths | ~151.4M cases | ~2.10% death rate
-- ============================================================
SELECT MAX(total_deaths) AS Total_Deaths
FROM Covid19;

SELECT MAX(total_cases) AS Total_Cases
FROM Covid19;

-- ============================================================
-- TOP 10 COUNTRIES BY DEATHS
-- ============================================================
SELECT TOP 10
    location,
    MAX(total_deaths) AS Total_Deaths
FROM Covid19
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY Total_Deaths DESC;

-- ============================================================
-- DAILY NEW DEATHS (unchanged)
-- ============================================================
SELECT date, SUM(new_deaths) AS New_Deaths
FROM Covid19
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY date;

-- ============================================================
-- DEATHS BY CONTINENT
-- FIX: SUM of country totals (was MAX = only the biggest country)
-- ============================================================
SELECT
    continent,
    SUM(total_deaths) AS Total_Deaths
FROM Covid19
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY Total_Deaths DESC;

-- ============================================================
-- DEATHS BY COUNTRY
-- ============================================================
SELECT TOP 10
    location,
    MAX(total_deaths) AS Total_Deaths
FROM Covid19
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY Total_Deaths DESC;

-- ============================================================
-- DEATHS PER MILLION POPULATION
-- FIX: skip countries with no deaths/population data (they showed as blanks)
-- ============================================================
SELECT
    location,
    population   AS Population,
    total_deaths AS Total_Deaths,
    ROUND(CAST(total_deaths AS FLOAT) / NULLIF(population,0) * 1000000, 2) AS Deaths_Per_Million
FROM vw_country_totals
WHERE total_deaths IS NOT NULL
  AND population IS NOT NULL
ORDER BY Deaths_Per_Million DESC;

-- ============================================================
-- NEW: TOP 5 COUNTRIES BY TOTAL CASES (for the donut chart)
-- Uses the final cumulative total, not an average over time.
-- ============================================================
SELECT TOP 5 location, total_cases AS Total_Cases
FROM vw_country_totals
ORDER BY total_cases DESC;

-- ============================================================
-- NEW: DATA FRESHNESS (for the "Last Updated" label)
-- Expected: 2021-04-30
-- ============================================================
SELECT MAX(date) AS Data_As_Of
FROM Covid19
WHERE continent IS NOT NULL;