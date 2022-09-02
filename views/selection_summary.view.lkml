view: selection_summary {
  derived_table: {
    persist_for: "0 seconds"
    sql:
       SELECT column_stats.column_name
                          , column_stats._nulls as count_nulls
                          , column_stats._non_nulls as count_not_nulls
                          , column_stats.pct_not_null as pct_not_null
                          , column_stats.count_distinct_values
                          , column_stats.pct_unique
                          , column_metadata.data_type
                          , column_metadata.input_data_column_count
                          , column_stats.input_data_row_count
                          , column_stats._min_value
                          , column_stats._max_value
                          , column_stats._avg_value
                     FROM ( SELECT
                                  column_name,
                                  COUNT(0) AS input_data_row_count,
                                  COUNT(DISTINCT column_value) AS count_distinct_values,
                                  safe_divide(COUNT(DISTINCT column_value),COUNT(*)) AS pct_unique,
                                  COUNTIF(column_value IS NULL) AS _nulls,
                                  COUNTIF(column_value IS NOT NULL) AS _non_nulls,
                                  COUNTIF(column_value IS NOT NULL) / COUNT(0) AS pct_not_null,
                                  min(column_value) as _min_value,
                                  max(column_value) as _max_value,
                                  avg(SAFE_CAST(column_value AS numeric)) as _avg_value
                                FROM
                                       (--unpivot input data into column_name, column_value
                                          --  capture all fields in each row as JSON string (e.g., "field_a": valueA, "field_b": valueB)
                                          --  unnest array created by split of row_json by ','
                                          --      "field_a": valueA
                                          --      "field_b": valueB
                                          --  split further on : to get separate columns for name and value
                                          --  format to trim "" from column name and replace any string nulls with true NULLs
                                          SELECT
                                            trim(column_name, '"') AS column_name
                                            ,IF(SAFE_CAST(column_value AS STRING)='null',NULL, column_value) AS column_value
                                          FROM (
                                            SELECT
                                              REGEXP_REPLACE(TO_JSON_STRING(t), r'^{|}$', '') AS row_json
                                            FROM
                                              `@{GCP_PROJECT}.@{BQML_MODEL_DATASET_NAME}.{% parameter selection_summary.input_data_view_name %}` AS t ) table_as_json,
                                            UNNEST(SPLIT(row_json, ',"')) AS cols,
                                            UNNEST([SPLIT(cols, ':')[SAFE_OFFSET(0)]]) AS column_name,
                                            UNNEST([SPLIT(cols, ':')[SAFE_OFFSET(1)]]) AS column_value
                                           ) as col_val
                                WHERE
                                  column_name <> ''
                                  AND column_name NOT LIKE '%-%'
                                  GROUP BY
                                  column_name) as column_stats
                     inner join (SELECT table_catalog
                                        ,  table_schema
                                        ,  table_name
                                        ,  column_name
                                        ,  data_type
                                        ,  count(0) over (partition by 1) as input_data_column_count
                                    FROM
                                      `@{GCP_PROJECT}.@{BQML_MODEL_DATASET_NAME}`.INFORMATION_SCHEMA.COLUMNS
                                      where table_name = '{% parameter selection_summary.input_data_view_name %}'
                                ) column_metadata
                       on column_stats.column_name = column_metadata.column_name
        ;;
  }

  parameter: input_data_view_name {
    # Model Name + "_input_data"
    type: unquoted
    default_value: "bqml_accelerator_input_data"
  }


  dimension: column_name {
    type: string
    sql: ${TABLE}.column_name ;;
  }

  dimension: count_nulls {
    type: number
    sql: ${TABLE}.count_nulls ;;
  }

  dimension: count_not_nulls {
    type: number
    sql: ${TABLE}.count_not_nulls ;;
  }

  dimension: pct_not_null {
    type: number
    hidden: yes
    sql: ${TABLE}.pct_not_null ;;
    value_format_name: percent_2
  }

  dimension: pct_null {
    type: number
    sql: 1 - ${pct_not_null} ;;
    value_format_name: percent_2
  }

  dimension: count_distinct_values {
    label: "Distinct Values"
    type: number
    sql: ${TABLE}.count_distinct_values ;;
  }

  dimension: pct_unique {
    type: number
    sql: ${TABLE}.pct_unique ;;
    value_format_name: percent_2
  }

  dimension: data_type {
    type: string
    sql: ${TABLE}.data_type ;;
  }

  dimension: _min_value {
    type: string
    sql: ${TABLE}._min_value ;;
  }

  dimension: _max_value {
    type: string
    sql: ${TABLE}._max_value ;;
  }

  dimension: _avg_value {
    type: number
    sql: ${TABLE}._avg_value ;;
  }

  dimension: input_data_column_count {
    type: number
    sql: ${TABLE}.input_data_column_count ;;
  }

  dimension: input_data_row_count {
    type: number
    sql: ${TABLE}.input_data_row_count ;;
  }



}
