# frozen_string_literal: true

module FixtureBot
  class Definition
    attr_reader :defaults, :rows

    def initialize(schema)
      @schema = schema
      @defaults = {}
      @rows = []

      schema.tables.each_value do |table|
        @defaults[table.name] = {}
        define_table_method(table)
      end
    end

    private

    def define_table_method(table)
      define_singleton_method(table.singular_name) do |record_name = nil, &block|
        if record_name.nil? && block.nil?
          Default::Definition.new(table, @defaults[table.name])
        elsif record_name && block
          add_row(table, record_name, block)
        elsif record_name
          add_row(table, record_name, nil)
        else
          raise ArgumentError, "#{table.singular_name} requires a record name or no arguments"
        end
      end
    end

    def add_row(table, record_name, block)
      row_def = Row::Definition.new(table, @schema)
      row_def.instance_eval(&block) if block
      @rows << Row::Declaration.new(
        table: table.name,
        name: record_name,
        literal_values: row_def.literal_values,
        association_refs: row_def.association_refs,
        tag_refs: row_def.tag_refs,
        polymorphic_refs: row_def.polymorphic_refs
      )
    end
  end
end
