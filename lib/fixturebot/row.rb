# frozen_string_literal: true

module FixtureBot
  module Row
    Declaration = Data.define(:table, :name, :literal_values, :association_refs, :tag_refs)

    class Definition
      attr_reader :literal_values, :association_refs, :tag_refs

      def initialize(table, schema)
        @literal_values = {}
        @association_refs = {}
        @tag_refs = {}

        define_primary_key_method(table)
        define_column_methods(table)
        define_association_methods(table)
        define_join_table_methods(table, schema)
      end

      private

      def define_primary_key_method(table)
        pk_col = table.primary_key_column
        define_singleton_method(pk_col) do |value|
          @literal_values[pk_col] = value
        end
      end

      def define_column_methods(table)
        table.columns.each do |col|
          define_singleton_method(col) do |value|
            @literal_values[col] = value
          end
        end
      end

      def define_association_methods(table)
        table.belongs_to_associations.each do |assoc|
          define_singleton_method(assoc.name) do |ref|
            @association_refs[assoc.name] = ref
          end
        end
      end

      def define_join_table_methods(table, schema)
        schema.join_tables.each_value do |jt|
          if jt.left_table == table.name
            define_singleton_method(jt.right_table) do |*refs|
              @tag_refs[jt.name] = { table: jt.right_table, refs: refs }
            end
          elsif jt.right_table == table.name
            define_singleton_method(jt.left_table) do |*refs|
              @tag_refs[jt.name] = { table: jt.left_table, refs: refs }
            end
          end
        end
      end
    end

    class Builder
      def initialize(row:, table:, defaults:, join_tables:, tables: {}, id_map: {})
        @row = row
        @table = table
        @defaults = defaults
        @join_tables = join_tables
        @tables = tables
        @id_map = id_map
      end

      def id
        pk_col = @table.primary_key_column
        @id ||= @row.literal_values.fetch(pk_col) { generate_key_for(@table, @row.table, @row.name) }
      end

      def record
        result = { @table.primary_key_column => id }
        @table.columns.each do |col|
          if @row.literal_values.key?(col)
            result[col] = @row.literal_values[col]
          elsif foreign_key_values.key?(col)
            result[col] = foreign_key_values[col]
          elsif defaulted_values.key?(col)
            result[col] = defaulted_values[col]
          end
        end
        result
      end

      def join_rows
        @row.tag_refs.flat_map do |join_table_name, tag_info|
          jt = @join_tables[join_table_name]
          tag_info[:refs].map do |tag_ref|
            build_join_row(jt, tag_info[:table], tag_ref)
          end
        end
      end

      private

      def generate_key_for(table_schema, table_name, record_name)
        return @id_map[[table_name, record_name]] if @id_map.key?([table_name, record_name])

        key = table_schema&.primary_key_type || Key::Integer.new
        key.generate(table_name, record_name)
      end

      def build_join_row(jt, other_table, tag_ref)
        other_table_schema = @tables[other_table]
        other_id = generate_key_for(other_table_schema, other_table, tag_ref)

        if jt.left_table == @row.table
          {
            key: :"#{@row.name}_#{tag_ref}",
            join_table: jt.name,
            row: { jt.left_foreign_key => id, jt.right_foreign_key => other_id }
          }
        else
          {
            key: :"#{tag_ref}_#{@row.name}",
            join_table: jt.name,
            row: { jt.left_foreign_key => other_id, jt.right_foreign_key => id }
          }
        end
      end

      def foreign_key_values
        @foreign_key_values ||= @row.association_refs.each_with_object({}) do |(assoc_name, ref), hash|
          assoc = @table.belongs_to_associations.find { |a| a.name == assoc_name }
          referenced_table = @tables[assoc.table]
          hash[assoc.foreign_key] = generate_key_for(referenced_table, assoc.table, ref)
        end
      end

      def defaulted_values
        @defaulted_values ||= @defaults.each_with_object({}) do |(col, block), result|
          next if @row.literal_values.key?(col)
          next if foreign_key_values.key?(col)

          fixture = Default::Fixture.new(key: @row.name)
          context = Default::Context.new(literal_values: @row.literal_values)
          result[col] = context.instance_exec(fixture, &block)
        end
      end
    end
  end
end
