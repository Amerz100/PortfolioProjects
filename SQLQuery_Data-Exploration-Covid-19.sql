Select *
From PortfolioProject..CovidDeaths
order by 3,4

Select *
From PortfolioProject..CovidVaccinations
order by 3,4

--SELECT THE DATA WE'RE GOING TO BE USING

Select location, date, total_cases, new_cases, total_deaths, population
From PortfolioProject..CovidDeaths
Order by 1,2

--LOOKING AT TOTAL CASES VS TOTAL DEATHS

----- Shows the likelihood of dying if you contract covid in your country
----- Note - you have to use Convert and floating functions to convert the data inorder to compute the calculation

Select location, date, total_cases, total_deaths, (CONVERT(float, total_deaths)/NULLIF(CONVERT(float,total_cases),0))*100 as DeathPercentage
From PortfolioProject..CovidDeaths
Where location like '%South Korea%'
order by 1,2

-- LOOKING AT THE TOTAL CASES VS POPULATION

----- Shows what percentage of the population got Covid

Select location, date, population, total_cases, (CONVERT(float, total_cases)/NULLIF(CONVERT(float,Population),0))*100 as PercentPopulationInfected
From PortfolioProject..CovidDeaths
--Where location like '%South Korea%'
order by 1,2

-- LOOKING AT COUNTRIES WITH HIGHEST INFECTION RATES

Select location, population,  MAX(total_cases) as HighestInfectionCount, (CONVERT(float, total_cases)/Max(NULLIF(CONVERT(float,Population),0)))*100 as PercentPopulationInfected
From PortfolioProject..CovidDeaths
--Where location like '%United Kingdom%'
Group by location, population, total_cases
order by 1,2

SELECT
    location,
    population,
    MAX(total_cases) as HighestInfectionCount,
    (CONVERT(float, MAX(total_cases)) / NULLIF(CONVERT(float, population),0)) * 100 as PercentPopulationInfected
FROM
    PortfolioProject..CovidDeaths
-- WHERE location like '%United Kingdom%'
GROUP BY
    location,
    population
ORDER BY
    PercentPopulationInfected desc

-- SHOWING COUNTRIES WITH HIGHEST DEATH COUNT PER POPULATION

SELECT location, MAX(cast(total_deaths as int)) as TotalDeathCount
FROM PortfolioProject..CovidDeaths
--Where continent is not null
GROUP BY location
ORDER BY TotalDeathCount desc

-- LET'S BREAK DOWN BY CONTINENT

SELECT continent, MAX(cast(total_deaths as int)) as TotalDeathCount
FROM PortfolioProject..CovidDeaths
Where continent is not null
GROUP BY continent
ORDER BY TotalDeathCount desc

-- SHOWING THE CONTINENTS WITH HIGHEST DEATH CONT PER POPULATION

SELECT continent,MAX(CAST(total_deaths AS float)) / MAX(CAST(population AS float)) AS DeathCountPerPopulation
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY DeathCountPerPopulation DESC;

-- BREAKING DOWN THE GLOBAL NUMBERS

SELECT 
    --date,
    SUM(new_cases) as total_cases,
    SUM(cast(new_deaths as int)) as total_deaths,
    CASE 
        WHEN SUM(new_cases) = 0 THEN 0  -- Handle division by zero
        ELSE SUM(cast(new_deaths as int))/SUM(new_cases)*100 
    END as DeathPercentage
FROM 
    PortfolioProject..CovidDeaths
--WHERE location LIKE '%South Korea%'  -- You can uncomment this line if you want to filter by a specific location
WHERE 
    continent IS NOT NULL
--GROUP BY date
ORDER BY 
    1, 2;

------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

-- JOINING THE COVID DEATHS AND VACCINATIONS TABLES TOGETHER MAKING SURE THEY MATCH CORRECTLY USING DATE & LOCATION
-- LOOKING AT TOTAL POPULATION VS VACCINATIONS

SELECT 
    dea.continent, 
    dea.location, 
    dea.date,
	dea.population,
    dea.total_vaccinations, -- Assuming 'total_vaccinations' is the correct column name for the total number of vaccinations
    vac.new_vaccinations,
	SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.location Order by dea.location, dea.date) as RollingPeopleVaccinated
FROM 
    PortfolioProject..CovidVaccinations dea
JOIN 
    PortfolioProject..CovidVaccinations vac ON dea.location = vac.location 
                                             AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL
ORDER BY 
    2, 3;
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

-- LOOKING AT TOTAL POPULATION VS VACCINATIONS
-----What are the total # of people in the world that have been vaccinated

-- USE CTE

WITH PopvsVac (Continent, location, date, population, new_vaccinations, RollingPeopleVaccinated)
AS 
(
    SELECT 
        dea.continent, 
        dea.location, 
        dea.date, 
        dea.population, 
        CONVERT(bigint, vac.new_vaccinations),
        SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.date) as RollingPeopleVaccinated
    FROM PortfolioProject..CovidDeaths dea
    JOIN PortfolioProject..CovidVaccinations vac ON dea.location = vac.location AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT 
    Continent, 
    location, 
    date, 
    population, 
    new_vaccinations,
    RollingPeopleVaccinated,
    (RollingPeopleVaccinated / population) * 100 AS PercentageVaccinated
FROM PopvsVac
ORDER BY 2, 3;

-- TEMP TABLE

IF OBJECT_ID('tempdb..#PercentPopulationVaccinated') IS NOT NULL
    DROP TABLE #PercentPopulationVaccinated;

CREATE TABLE #PercentPopulationVaccinated (
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC,
    New_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
)

INSERT INTO #PercentPopulationVaccinated
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    vac.new_vaccinations, 
    SUM(CONVERT(int, vac.new_vaccinations)) OVER (PARTITION BY dea.location, dea.date) as RollingPeopleVaccinated
FROM 
    PortfolioProject..CovidDeaths dea
JOIN 
    PortfolioProject..CovidVaccinations vac ON dea.location = vac.location AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL

SELECT 
    *, 
    (RollingPeopleVaccinated / Population) * 100 AS PercentPopulationVaccinated
FROM 
    #PercentPopulationVaccinated

-- CREATING VIEW TO STORE DATA FOR LATER VISUALISATIONS

IF OBJECT_ID('dbo.PercentPopulationVaccinated') IS NOT NULL
    DROP VIEW dbo.PercentPopulationVaccinated;

GO -- Add this line to terminate the previous batch and start a new one

CREATE VIEW dbo.PercentPopulationVaccinated AS 
    SELECT 
        dea.continent, 
        dea.location, 
        dea.date, 
        dea.population, 
        CONVERT(BIGINT, vac.new_vaccinations) AS new_vaccinations,
        SUM(CONVERT(BIGINT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.date) AS RollingPeopleVaccinated
    FROM 
        PortfolioProject..CovidDeaths dea
    JOIN 
        PortfolioProject..CovidVaccinations vac ON dea.location = vac.location AND dea.date = vac.date
    WHERE 
        dea.continent IS NOT NULL;
