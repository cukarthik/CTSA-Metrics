-- Query Informatics Metrics CTSA EDW
-- Data Model: OMOP 5.X
-- Database MS SQL
-- Updated 01/05/2018

DECLARE @UPPER_BOUND AS VARCHAR(10);
DECLARE @LOWER_BOUND AS VARCHAR(10);

SET @LOWER_BOUND = '01/01/2020';
SET @UPPER_BOUND = '01/01/2021';

-- With Statement used to calculate Unique Patients, used as the denominator for subsequent measures
with metric_patients as
(
		SELECT distinct OP.Person_ID
		FROM Person OP (nolock)
        JOIN visit_occurrence VO (nolock) ON OP.person_id=VO.person_id
        WHERE VO.visit_start_date between @LOWER_BOUND and @UPPER_BOUND

)
,DEN ([Unique Total Patients]) as
(
		SELECT CAST(Count(Distinct OP.Person_ID)as Float) as 'Unique Total Patients' 
		FROM metric_patients OP
)

--Domain Demographics Unique Patients
	SELECT 'Demo Unique Patients' AS 'Domain', '' as 'Patients with Standards', 
	DEN.[Unique Total Patients] as 'Unique Total Patients' ,'' as  '% Standards', 'Not Applicable' as 'Values Present'		
	FROM DEN	

Union
-- Domain Gender: % of unique patient with gender populated
	Select NUM.*, DEN.*, (100.0 * (NUM.[Patients with Standards]/ DEN.[Unique Total Patients])) as '% Standards','Not Applicable' as 'Values Present'	
	From 
		(
		SELECT 'Demo Gender' AS Domain, 
		CAST(COUNT(DISTINCT D.person_id) as Float) AS 'Patients with Standards'
		FROM metric_patients MP
		JOIN Person D (nolock) on MP.Person_ID=D.Person_ID
		INNER JOIN Concept C (nolock) ON D.Gender_concept_id = C.concept_id AND C.vocabulary_id = 'Gender'
		) Num, DEN

Union
-- Domain Age/DOBL: % of unique patient with DOB populated
	Select NUM.*, DEN.*, (100.0 * (NUM.[Patients with Standards]/ Den.[Unique Total Patients])) as '% Standards','Not Applicable' as 'Values Present'	
	From 
		(
		SELECT 'Demo Age/DOB' AS Domain, 
		CAST(COUNT(DISTINCT D.person_id) as Float) AS 'Patients with Standards'
		FROM metric_patients MP
		JOIN Person D (nolock) on MP.Person_ID=D.Person_ID
		-- We may want to alter this to be only Year of birth present at this time Year, Month and Day are required in order to count
		        --Where D.birth_datetime  is NOT NULL 
		Where D.Year_of_Birth  is NOT NULL 
			--and  D.month_of_Birth is NOT NULL 
			--and  D.Day_of_Birth  is NOT NULL
		) Num, DEN

Union
-- Domain Labs: % of unique patient with LOINC as lab valued
	Select NUM.*, DEN.*, (100.0 * (NUM.[Patients with Standards]/ Den.[Unique Total Patients])) as '% Standards' , 'Not Applicable' as 'Values Present'	
	From 
		(
		SELECT 'Labs as LOINC' AS Domain, 
		CAST(COUNT(DISTINCT D.person_id) as Float) AS 'Patients with Standards'
		FROM dbo.measurement D (nolock)
		JOIN metric_patients MP on D.person_id=MP.person_id
		JOIN dbo.Concept C (nolock) ON D.Measurement_concept_id = C.concept_id AND C.vocabulary_id = 'LOINC'
		WHERE D.measurement_date < @UPPER_BOUND
		) Num, DEN

Union
-- Domain Drug: % of unique patient with RxNorm as Medication valued
	Select NUM.*, DEN.*, (100.0 * (NUM.[Patients with Standards]/ Den.[Unique Total Patients])) as '% Standards','Not Applicable' as 'Values Present'	
	From 
		(
		SELECT 'Drugs as RxNORM' AS Domain, 
		CAST(COUNT(DISTINCT D.person_id) as Float) AS 'Patients with Standards'
		FROM dbo.DRUG_EXPOSURE D (nolock)
		JOIN metric_patients MP on D.person_id=MP.person_id
		JOIN dbo.Concept C (nolock) ON D.drug_concept_id = C.concept_id AND C.vocabulary_id = 'RxNorm'
		WHERE D.drug_exposure_start_date < @UPPER_BOUND
		) Num, DEN
Union
-- Domain Condition: % of unique patient with standard value set for condition
	Select NUM.*, DEN.*, (100.0 * (NUM.[Patients with Standards]/ Den.[Unique Total Patients])) as '% Standards', 'Not Applicable' as 'Values Present'	
	From 
		(
		SELECT 'Diagnosis as ICD/SNOMED' AS Domain, 
		CAST(COUNT(DISTINCT P.person_id) as Float) AS 'Patients with Standards' 
		FROM dbo.Condition_Occurrence P (nolock)
		JOIN metric_patients MP on MP.person_id=P.person_id
		LEFT JOIN Concept c (nolock) ON p.condition_source_concept_id = c.concept_id AND c.vocabulary_id IN ('SNOMED','ICD9CM','ICD10CM')
		LEFT JOIN Concept c2 (nolock) ON p.condition_concept_id = c2.concept_id AND c2.vocabulary_id IN ('SNOMED','ICD9CM','ICD10CM')
		WHERE (c.concept_id IS NOT NULL OR c2.concept_id IS NOT NULL)
		    AND P.condition_start_date < @UPPER_BOUND
		) Num, DEN

Union
-- Domain Procedure: % of unique patient with standard value set for procedure
	Select NUM.*, DEN.*, (100.0 * (NUM.[Patients with Standards]/ Den.[Unique Total Patients])) as '% Standards', 'Not Applicable' as 'Values Present'		
	From 
		(
		SELECT 'Procedures as ICD/SNOMED/CPT4' AS Domain, 
		CAST(COUNT(DISTINCT P.person_id) as Float) AS 'Patients with Standards'
		FROM dbo.procedure_occurrence P (nolock)
		JOIN metric_patients MP on MP.person_id=P.person_id
		LEFT JOIN Concept c (nolock) ON p.procedure_source_concept_id= c.concept_id AND c.vocabulary_id IN ('SNOMED','ICD9Proc','ICD10PCS','CPT4')
		LEFT JOIN Concept c2 (nolock) ON p.procedure_concept_id = c2.concept_id   AND c2.vocabulary_id IN ('SNOMED','ICD9Proc','ICD10PCS','CPT4')
		WHERE (c.concept_id IS NOT NULL OR c2.concept_id IS NOT NULL)
		    AND P.procedure_date < @UPPER_BOUND
		) Num, DEN

Union
-- Domain Observations:  Checks for the presents of recorded observations
	Select 'Observations Present' AS 'Domain',  '' as 'Patients with Standards', '' as 'Unique Total Patients', '' as  '% Standards', 
		Case 
			When Count(*) = 0 then 'No Observation' else 'Observations Present' end as 'Values Present'		
	from dbo.observation O (nolock)
	JOIN metric_patients MP on MP.person_id=O.person_id
    WHERE O.observation_date < @UPPER_BOUND

Union
-- Domain Note Text: % of unique patient with note text populated
	Select NUM.*, DEN.*, (100.0 * (NUM.[Patients with Standards]/ Den.[Unique Total Patients])) as '% Standards','Not Applicable' as 'Values Present'	
	From 
		(
		SELECT 'Note Text' AS Domain, 
		CAST(COUNT(DISTINCT D.person_id) as Float) AS 'Patients with Standards'
		FROM dbo.Note D (nolock)
		JOIN metric_patients MP on MP.person_id=D.person_id
        WHERE D.note_date < @UPPER_BOUND
		) Num, DEN

----Union
---- Future Measures 
-- Domain NLP present does not measure % of unique patients
--	--Select 'Note NLP Present' AS 'Domain',  '' as 'Patients with Standards', '' as 'Unique Total Patients', '' as  '% Standards', 
--	--Case 
--	--		When Count(*) = 0 then 'No Observation' else 'Observations Present' end as 'Values Present'		
--	--from Note_NLP

Order by Domain
