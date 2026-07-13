/*
================================================================================
Script Name : Export_Raw_Data_Query.sql
Purpose     : Extract hourly support-contact volume and service metrics from
              SQL Server ERP/support tables for WFM forecasting, Erlang staffing,
              and Power BI reporting.

Production Notes:
  - This script is intended to be scheduled or executed by Export_Raw_Data_CSV.bat.
  - Output column order intentionally mirrors raw data.csv and the Erlang model.
  - Date filter is half-open: >= start date and < next day/month.
  - Service level logic assumes 80/20 style reporting:
        Resolved contact answered within 20 seconds / all offered contacts.
  - Update table and column names if the ERP schema changes.

Source Table Assumption:
  dbo.SupportChatRequests r

Expected Source Fields:
  r.RequestedDateTime  -- Date/time the chat entered the queue
  r.Status             -- Resolved, Abandoned, Expired, Declined, etc.
  r.WaitSeconds        -- Customer wait time before answer/abandon/expiry
  r.HandleSeconds      -- Agent handle time for resolved contacts

Change / Sign-Off History:
  2021-06-15 | Initial production extract created for hourly support volume.
              Owner: Andre DaCosta

  2021-06-30 | Added abandoned, expired, and declined counts to separate
              offered demand from handled demand.
              Owner: Andre DaCosta

  2021-11-18 | Aligned output headers with Erlang forecasting workbook import.
              Owner: WFM Personel - Tommie Her

  2022-03-22 | Added AHT, AWT, total handle time, and service-level metrics.
              Owner: WFM - Tommie Her

  2022-08-09 | Standardized SLA threshold to WaitSeconds <= 20 for 80/20 view.
              Owner: Andre DaCosta



  2023-12-15 | Final documentation cleanup for recruiter-facing case study.
              Owner: Andre DaCosta - Candidate for Sr. Woforce Planner
================================================================================
*/

/* =========================================================
   1. Pull raw interval-level support data from ERP tables

   Production intent:
     Aggregate transaction-level support records into the hourly interval grain
     needed for workforce planning. This is the layer that turns ERP event data
     into a forecast-ready WFM dataset.
   ========================================================= */

SELECT
    /* Calendar fields used for weekday seasonality and dashboard slicing. */
    DATENAME(WEEKDAY, r.RequestedDateTime) AS [Week],
    CAST(r.RequestedDateTime AS date) AS [Date],
    CAST(r.RequestedDateTime AS date) AS [Requested],

    /* Interval fields used by the Erlang model and intraday heatmaps. */
    FORMAT(r.RequestedDateTime, 'h:mm') AS [Interval],
    FORMAT(r.RequestedDateTime, 'tt') AS [AM/PM],

    /* Average wait time shown in time format for business-readable reporting. */
    CONVERT(varchar(8), DATEADD(SECOND, AVG(r.WaitSeconds), 0), 108) AS [Average Wait Time],

    /* Queue outcome counts. These help separate true demand from handled demand. */
    SUM(CASE WHEN r.Status IN ('Expired', 'Declined') THEN 1 ELSE 0 END) AS [Expired/Declined],
    SUM(CASE WHEN r.Status = 'Abandoned' THEN 1 ELSE 0 END) AS [Abandoned],
    SUM(CASE WHEN r.Status = 'Resolved' THEN 1 ELSE 0 END) AS [Resolved],

    /* Offered contacts for the interval. Used as the primary demand volume. */
    COUNT(*) AS [Total Chat Requests],

    /* Placeholder column preserved to match the original raw data.csv layout. */
    NULL AS [Leave Blank],

    /* Repeated calendar/interval fields preserved for workbook compatibility. */
    DATENAME(WEEKDAY, r.RequestedDateTime) AS [Week],
    CAST(r.RequestedDateTime AS date) AS [Chat],
    FORMAT(r.RequestedDateTime, 'h:mm') AS [Requested],
    FORMAT(r.RequestedDateTime, 'tt') AS [Hour],

    /*
      Average handled time:
        Only resolved contacts should contribute to handle-time calculations.
        Abandoned, expired, and declined records are excluded because no agent
        completed a handle event.
    */
    CONVERT(
        varchar(8),
        DATEADD(
            SECOND,
            AVG(CASE WHEN r.Status = 'Resolved' THEN r.HandleSeconds END),
            0
        ),
        108
    ) AS [Average Handled Time],

    /* Duplicate AWT field preserved for the model/report import shape. */
    CONVERT(varchar(8), DATEADD(SECOND, AVG(r.WaitSeconds), 0), 108) AS [Average Wait Time],

    /*
      Service level:
        Numerator   = resolved contacts answered within 20 seconds.
        Denominator = all offered contacts in the interval.
        NULLIF prevents divide-by-zero during empty or test intervals.
    */
    FORMAT(
        1.0 * SUM(CASE WHEN r.WaitSeconds <= 20 AND r.Status = 'Resolved' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        'P2'
    ) AS [Service level],

    /* Resolved contacts repeated for workbook compatibility. */
    SUM(CASE WHEN r.Status = 'Resolved' THEN 1 ELSE 0 END) AS [No of Resolved Requests],

    /* Placeholder column preserved to match the original raw data.csv layout. */
    NULL AS [Leave Blank],

    /* Total handle seconds used to calculate weighted AHT downstream. */
    SUM(CASE WHEN r.Status = 'Resolved' THEN r.HandleSeconds ELSE 0 END) AS [Total Handle Time],

    /* Numeric AHT in seconds for modeling. */
    AVG(CASE WHEN r.Status = 'Resolved' THEN r.HandleSeconds END) AS [AHT],

    /* Numeric AWT in seconds for modeling and KPI weighting. */
    AVG(r.WaitSeconds) AS [AWT],

    /* Rounded service-level label used by the original CSV/workbook. */
    FORMAT(
        1.0 * SUM(CASE WHEN r.WaitSeconds <= 20 AND r.Status = 'Resolved' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        'P0'
    ) AS [SL]

FROM dbo.SupportChatRequests r
WHERE
    /*
      Reporting window:
        Use a half-open range instead of BETWEEN to avoid accidentally including
        midnight records from the next reporting period.
    */
    r.RequestedDateTime >= '2022-12-01'
    AND r.RequestedDateTime < '2022-12-31'
GROUP BY
    /*
      Hourly interval grain:
        Date + hour grouping supports intraday forecasting and Erlang staffing.
    */
    CAST(r.RequestedDateTime AS date),
    DATEPART(HOUR, r.RequestedDateTime),
    FORMAT(r.RequestedDateTime, 'h:mm'),
    FORMAT(r.RequestedDateTime, 'tt'),
    DATENAME(WEEKDAY, r.RequestedDateTime)
ORDER BY
    /*
      Stable output order for CSV comparison, audit checks, and Power BI refresh.
    */
    CAST(r.RequestedDateTime AS date),
    DATEPART(HOUR, r.RequestedDateTime);
