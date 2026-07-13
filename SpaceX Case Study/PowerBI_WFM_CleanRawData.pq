// Power Query M script for cleaning the attached raw data.csv.
// Paste into Power BI Desktop: Get Data > Blank Query > Advanced Editor.
// Update SourcePath if the file is moved.

let
    SourcePath = "C:\Users\dacos\OneDrive\Documents\SpaceX Case Study\raw data.csv",
    Source = Csv.Document(
        File.Contents(SourcePath),
        [Delimiter = ",", Columns = 24, Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),

    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
            {"Week", type text},
            {"Date", type text},
            {"Interval", type text},
            {"AM/PM", type text},
            {"Expired/Declined", type number},
            {"Abandoned", type number},
            {"Resolved", type number},
            {"Total Chat Requests", type number},
            {"Total Handle Time", type number},
            {"AHT", type number},
            {"AWT", type number},
            {"SL", type text}
        }
    ),

    FilteredValidIntervals = Table.SelectRows(
        ChangedTypes,
        each [Total Chat Requests] <> null and [Total Chat Requests] > 0 and [Date] <> null
    ),

    AddedParsedDate = Table.AddColumn(
        FilteredValidIntervals,
        "ParsedDate",
        each try Date.FromText([Date]) otherwise null,
        type date
    ),

    AddedParsedTime = Table.AddColumn(
        AddedParsedDate,
        "ParsedTime",
        each try Time.FromText([Interval] & " " & [#"AM/PM"]) otherwise null,
        type time
    ),

    AddedHour24 = Table.AddColumn(
        AddedParsedTime,
        "Hour24",
        each if [ParsedTime] = null then null else Time.Hour([ParsedTime]),
        Int64.Type
    ),

    AddedIntervalLabel = Table.AddColumn(
        AddedHour24,
        "IntervalLabel",
        each if [ParsedTime] = null then null else Time.ToText([ParsedTime], "HH:mm"),
        type text
    ),

    AddedWeekStart = Table.AddColumn(
        AddedIntervalLabel,
        "WeekStart",
        each if [ParsedDate] = null then null else Date.StartOfWeek([ParsedDate], Day.Monday),
        type date
    ),

    AddedDayName = Table.AddColumn(
        AddedWeekStart,
        "DayName",
        each if [ParsedDate] = null then null else Date.DayOfWeekName([ParsedDate]),
        type text
    ),

    AddedDayOfWeekNumber = Table.AddColumn(
        AddedDayName,
        "DayOfWeekNumber",
        each if [ParsedDate] = null then null else Date.DayOfWeek([ParsedDate], Day.Monday) + 1,
        Int64.Type
    ),

    AddedSLPercent = Table.AddColumn(
        AddedDayOfWeekNumber,
        "SLPercent",
        each try Number.FromText(Text.Replace([SL], "%", "")) / 100 otherwise null,
        type number
    ),

    AddedDateHourKey = Table.AddColumn(
        AddedSLPercent,
        "DateHourKey",
        each Date.ToText([ParsedDate], "yyyy-MM-dd") & " " & [IntervalLabel],
        type text
    ),

    RenamedColumns = Table.RenameColumns(
        AddedDateHourKey,
        {
            {"ParsedDate", "DateClean"},
            {"Expired/Declined", "ExpiredDeclined"},
            {"Total Chat Requests", "Requests"},
            {"Total Handle Time", "TotalHandleSeconds"},
            {"AHT", "AHTSeconds"},
            {"AWT", "AWTSeconds"}
        }
    ),

    SelectedColumns = Table.SelectColumns(
        RenamedColumns,
        {
            "DateClean",
            "WeekStart",
            "DayName",
            "DayOfWeekNumber",
            "Hour24",
            "IntervalLabel",
            "DateHourKey",
            "Requests",
            "Resolved",
            "Abandoned",
            "ExpiredDeclined",
            "TotalHandleSeconds",
            "AHTSeconds",
            "AWTSeconds",
            "SLPercent"
        }
    ),

    RenamedForModel = Table.RenameColumns(
        SelectedColumns,
        {{"DateClean", "Date"}}
    ),

    SortedRows = Table.Sort(
        RenamedForModel,
        {{"Date", Order.Ascending}, {"Hour24", Order.Ascending}}
    )
in
    SortedRows
