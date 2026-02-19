# frozen_string_literal: true

module FixtureBot
  class FixtureSet
    attr_reader :tables

    def initialize(schema, definition)
      @tables = {}

      schema.tables.each_key { |name| @tables[name] = {} }
      schema.join_tables.each_key { |name| @tables[name] = {} }

      id_map = collect_hardcoded_ids(definition.rows, schema.tables)

      definition.rows.each do |row|
        builder = Row::Builder.new(
          row: row,
          table: schema.tables[row.table],
          defaults: definition.defaults[row.table],
          join_tables: schema.join_tables,
          tables: schema.tables,
          id_map: id_map
        )

        @tables[row.table][row.name] = builder.record

        builder.join_rows.each do |join_row|
          @tables[join_row[:join_table]][join_row[:key]] = join_row[:row]
        end
      end
    end

    private

    def collect_hardcoded_ids(rows, schema_tables)
      rows.each_with_object({}) do |row, map|
        pk_col = schema_tables[row.table]&.primary_key_column || :id
        map[[row.table, row.name]] = row.literal_values[pk_col] if row.literal_values.key?(pk_col)
      end
    end
  end
end
