use covid;

SELECT
    iso_code,
    continent,
    location,
    MAX(population)                 AS population,
    MAX(population_density)         AS population_density,
    MAX(median_age)                 AS median_age,
    MAX(aged_65_older)              AS aged_65_older,
    MAX(aged_70_older)              AS aged_70_older,
    MAX(gdp_per_capita)             AS gdp_per_capita,
    MAX(extreme_poverty)            AS extreme_poverty,
    MAX(handwashing_facilities)     AS handwashing_facilities,
    MAX(hospital_beds_per_thousand) AS hospital_beds_per_thousand,
    MAX(life_expectancy)            AS life_expectancy,
    MAX(human_development_index)    AS human_development_index
INTO dim_location
FROM Covid19
WHERE continent IS NOT NULL
GROUP BY iso_code, continent, location;

SELECT * FROM dim_location;

SELECT
    iso_code,
    location,
    [date],
    total_vaccinations,        -- cumulative doses given
    people_vaccinated,         -- cumulative people with at least 1 dose
    people_fully_vaccinated,   -- cumulative people fully vaccinated
    new_vaccinations           -- doses given that day
INTO fact_vaccination
FROM Covid19
WHERE continent IS NOT NULL
  AND (total_vaccinations       IS NOT NULL
    OR people_vaccinated        IS NOT NULL
    OR people_fully_vaccinated  IS NOT NULL
    OR new_vaccinations         IS NOT NULL);
 
 SELECT * FROM fact_vaccination;

 SELECT
    iso_code,
    location,
    [date],
    total_cases,
    new_cases,
    stringency_index,
    new_tests,
    total_tests,
    positive_rate
INTO fact_covid_context
FROM Covid19
WHERE continent IS NOT NULL;

 SELECT * FROM fact_covid_context;

 SELECT
    l.iso_code,
    l.continent,
    l.location,
    l.population,
    MAX(v.total_vaccinations)      AS total_doses,
    MAX(v.people_vaccinated)       AS people_vaccinated,
    MAX(v.people_fully_vaccinated) AS people_fully_vaccinated,
    MAX(v.people_vaccinated)       * 100.0 / NULLIF(l.population, 0) AS pct_at_least_one_dose,
    MAX(v.people_fully_vaccinated) * 100.0 / NULLIF(l.population, 0) AS pct_fully_vaccinated,
    MAX(v.total_vaccinations)      * 100.0 / NULLIF(l.population, 0) AS doses_per_100_people,
    MIN(v.[date])                  AS vaccination_start_date,
    MAX(v.[date])                  AS last_update_date
INTO country_vaccination_summary
FROM dim_location l
JOIN fact_vaccination v ON v.iso_code = l.iso_code
GROUP BY l.iso_code, l.continent, l.location, l.population;

SELECT * FROM country_vaccination_summary;

DROP TABLE continent_vaccination_summary;

SELECT
    continent,
    SUM(population) AS population,
    SUM(total_doses) AS total_doses,
    SUM(people_vaccinated) AS people_vaccinated,
    SUM(people_fully_vaccinated) AS people_fully_vaccinated,
    SUM(people_vaccinated) * 100.0 /
        NULLIF(SUM(CASE WHEN people_vaccinated IS NOT NULL THEN population END), 0) AS pct_at_least_one_dose,
    SUM(people_fully_vaccinated) * 100.0 /
        NULLIF(SUM(CASE WHEN people_fully_vaccinated IS NOT NULL THEN population END), 0) AS pct_fully_vaccinated
INTO continent_vaccination_summary
FROM country_vaccination_summary
GROUP BY continent;

SELECT * FROM continent_vaccination_summary;

SELECT
    [date],
    SUM(new_vaccinations) AS doses_given_that_day,
    SUM(SUM(new_vaccinations)) OVER (ORDER BY [date]) AS cumulative_doses
INTO global_daily_vaccination
FROM fact_vaccination
GROUP BY [date];

SELECT * FROM global_daily_vaccination;

SELECT
    l.continent,
    l.location,
    v.[date],
    l.population,
    v.new_vaccinations,
    SUM(v.new_vaccinations) OVER (
        PARTITION BY l.location ORDER BY v.[date]
        ROWS UNBOUNDED PRECEDING
    ) AS rolling_doses_given,
    SUM(v.new_vaccinations) OVER (
        PARTITION BY l.location ORDER BY v.[date]
        ROWS UNBOUNDED PRECEDING
    ) * 100.0 / NULLIF(l.population, 0) AS rolling_doses_per_100_people
INTO country_rolling_vaccination
FROM dim_location l
JOIN fact_vaccination v ON v.iso_code = l.iso_code
WHERE v.new_vaccinations IS NOT NULL;

SELECT * FROM country_rolling_vaccination;

SELECT rank_no, location, continent, population,
       pct_at_least_one_dose, pct_fully_vaccinated
INTO top10_countries_fully_vaccinated
FROM (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY pct_fully_vaccinated DESC) AS rank_no
    FROM country_vaccination_summary
    WHERE pct_fully_vaccinated IS NOT NULL
      AND population > 1000000
) ranked
WHERE rank_no <= 10;

SELECT * FROM top10_countries_fully_vaccinated;

SELECT
    s.location,
    s.continent,
    s.population,
    s.pct_at_least_one_dose,
    s.pct_fully_vaccinated,
    l.gdp_per_capita,
    l.median_age,
    l.aged_65_older,
    l.human_development_index,
    l.hospital_beds_per_thousand,
    l.life_expectancy
INTO vaccination_vs_demographics
FROM country_vaccination_summary s
JOIN dim_location l ON l.iso_code = s.iso_code
WHERE s.pct_at_least_one_dose IS NOT NULL;

SELECT * FROM vaccination_vs_demographics;