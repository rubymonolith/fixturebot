# frozen_string_literal: true

module FixtureBot
  class KeyRegistry
    def initialize(rows, schema_tables)
      @values = {}

      rows.each do |row|
        table = schema_tables[row.table_name]
        pk_col = table.primary_key
        @values[[row.table_name, row.name]] = if row.literal_values.key?(pk_col)
          row.literal_values[pk_col]
        else
          table.key.generate(row.table_name, row.name)
        end
      end
    end

    def resolve(table_name, record_name)
      @values.fetch([table_name, record_name])
    end
  end
end
