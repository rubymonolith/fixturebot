# frozen_string_literal: true

module FixtureBot
  module Row
    TableReference = Data.define(:table_name, :record_name)
    Declaration = Data.define(:table, :name, :literal_values, :association_refs, :tag_refs, :polymorphic_refs)

    class Definition
      attr_reader :literal_values, :association_refs, :tag_refs, :polymorphic_refs

      def initialize(table, schema)
        @literal_values = {}
        @association_refs = {}
        @tag_refs = {}
        @polymorphic_refs = {}

        define_column_methods(table)
        define_association_methods(table)
        define_polymorphic_methods(table)
        define_join_table_methods(table, schema)
        define_table_reference_methods(schema, table)
      end

      def define_table_reference_methods(schema, table)
        schema.tables.each_value do |tbl|
          next if table.belongs_to_associations.any? { |a| a.name == tbl.singular_name }
          next if table.polymorphic_belongs_to_associations.any? { |a| a.name == tbl.singular_name }
          define_singleton_method(tbl.singular_name) do |record_name|
            TableReference.new(table_name: tbl.name, record_name: record_name)
          end
        end
      end

      private

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

      def define_polymorphic_methods(table)
        table.polymorphic_belongs_to_associations.each do |assoc|
          define_singleton_method(assoc.name) do |table_ref|
            @polymorphic_refs[assoc.name] = table_ref
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
      def initialize(row:, table:, defaults:, join_tables:)
        @row = row
        @table = table
        @defaults = defaults
        @join_tables = join_tables
      end

      def id
        @id ||= Key.generate(@row.table, @row.name)
      end

      def record
        result = { id: id }
        @table.columns.each do |col|
          if @row.literal_values.key?(col)
            result[col] = @row.literal_values[col]
          elsif foreign_key_values.key?(col)
            result[col] = foreign_key_values[col]
          elsif polymorphic_values.key?(col)
            result[col] = polymorphic_values[col]
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

      def build_join_row(jt, other_table, tag_ref)
        other_id = Key.generate(other_table, tag_ref)

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
          hash[assoc.foreign_key] = Key.generate(assoc.table, ref)
        end
      end

      def polymorphic_values
        @polymorphic_values ||= @row.polymorphic_refs.each_with_object({}) do |(assoc_name, table_ref), hash|
          assoc = @table.polymorphic_belongs_to_associations.find { |a| a.name == assoc_name }
          hash[assoc.foreign_key] = Key.generate(table_ref.table_name, table_ref.record_name)
          hash[assoc.type_column] = classify(table_ref.table_name)
        end
      end

      def classify(table_name)
        if defined?(ActiveSupport::Inflector)
          ActiveSupport::Inflector.classify(table_name.to_s)
        else
          table_name.to_s.sub(/s$/, "").capitalize
        end
      end

      def defaulted_values
        @defaulted_values ||= @defaults.each_with_object({}) do |(col, block), result|
          next if @row.literal_values.key?(col)
          next if foreign_key_values.key?(col)
          next if polymorphic_values.key?(col)

          fixture = Default::Fixture.new(key: @row.name)
          context = Default::Context.new(literal_values: @row.literal_values)
          result[col] = context.instance_exec(fixture, &block)
        end
      end
    end
  end
end
