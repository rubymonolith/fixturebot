# frozen_string_literal: true

module FixtureBot
  class FixtureSet
    attr_reader :tables

    def initialize(schema, definition)
      @tables = {}

      schema.tables.each_key { |name| @tables[name] = {} }
      schema.join_tables.each_key { |name| @tables[name] = {} }

      definition.rows.each do |row|
        builder = Row::Builder.new(
          row: row,
          table: schema.tables[row.table],
          defaults: definition.defaults[row.table],
          join_tables: schema.join_tables,
          tables: schema.tables
        )

        @tables[row.table][row.name] = builder.record

        builder.join_rows.each do |join_row|
          @tables[join_row[:join_table]][join_row[:key]] = join_row[:row]
        end
      end
    end
  end
end
