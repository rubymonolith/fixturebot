# frozen_string_literal: true

module FixtureBot
  module Row
    TableReference = Data.define(:table_name, :record_name)
    TagRef = Data.define(:other_table, :refs)
    JoinRow = Data.define(:key, :join_table, :row)
    Declaration = Data.define(:table_name, :name, :literal_values, :association_refs, :tag_refs)

    class Definition
      attr_reader :literal_values, :association_refs, :tag_refs

      def initialize(table, schema)
        @literal_values = {}
        @association_refs = {}
        @tag_refs = {}

        define_column_methods(table)
        define_primary_key_method(table)
        define_association_methods(table)
        define_join_table_methods(table, schema)
        define_table_reference_methods(schema, table)
      end

      private

      def define_column_methods(table)
        table.columns.each do |col|
          define_singleton_method(col) do |value|
            @literal_values[col] = value
          end
        end
      end

      def define_primary_key_method(table)
        pk_col = table.primary_key
        define_singleton_method(pk_col) do |value|
          @literal_values[pk_col] = value
        end unless respond_to?(pk_col)
      end

      def define_association_methods(table)
        table.associations.each do |assoc|
          define_singleton_method(assoc.name) do |ref|
            @association_refs[assoc.name] = ref
          end
        end
      end

      def define_join_table_methods(table, schema)
        schema.join_tables.each_value do |jt|
          if jt.left_table == table.name
            define_singleton_method(jt.right_table) do |*refs|
              @tag_refs[jt.name] = TagRef.new(other_table: jt.right_table, refs: refs)
            end
          elsif jt.right_table == table.name
            define_singleton_method(jt.left_table) do |*refs|
              @tag_refs[jt.name] = TagRef.new(other_table: jt.left_table, refs: refs)
            end
          end
        end
      end

      def define_table_reference_methods(schema, table)
        schema.tables.each_value do |t|
          method_name = t.singular_name
          next if respond_to?(method_name)
          define_singleton_method(method_name) do |record_name|
            TableReference.new(table_name: t.name, record_name: record_name)
          end
        end
      end
    end

    class Builder
      def initialize(row:, table:, defaults:, join_tables:, keys:)
        @row = row
        @table = table
        @defaults = defaults
        @join_tables = join_tables
        @keys = keys
      end

      def primary_key_value
        @primary_key_value ||= @keys.resolve(@row.table_name, @row.name)
      end

      def record
        values = {}
          .merge!(defaulted_values)
          .merge!(association_values)
          .merge!(@row.literal_values)

        result = { @table.primary_key => primary_key_value }
        @table.columns.each do |col|
          result[col] = values[col] if values.key?(col)
        end
        result
      end

      def join_rows
        @row.tag_refs.flat_map do |join_table_name, tag_ref|
          jt = @join_tables[join_table_name]
          tag_ref.refs.map do |ref|
            build_join_row(jt, tag_ref.other_table, ref)
          end
        end
      end

      private

      def build_join_row(jt, other_table, tag_ref)
        other_id = @keys.resolve(other_table, tag_ref)

        if jt.left_table == @row.table_name
          JoinRow.new(
            key: :"#{@row.name}_#{tag_ref}",
            join_table: jt.name,
            row: { jt.left_foreign_key => primary_key_value, jt.right_foreign_key => other_id }
          )
        else
          JoinRow.new(
            key: :"#{tag_ref}_#{@row.name}",
            join_table: jt.name,
            row: { jt.left_foreign_key => other_id, jt.right_foreign_key => primary_key_value }
          )
        end
      end

      def association_values
        @association_values ||= @row.association_refs.each_with_object({}) do |(assoc_name, ref), hash|
          assoc = @table.associations.find { |a| a.name == assoc_name }
          hash.merge!(assoc.resolve(ref, @keys))
        end
      end

      def defaulted_values
        @defaulted_values ||= @defaults.each_with_object({}) do |(col, generator), result|
          next if @row.literal_values.key?(col)
          next if association_values.key?(col)

          result[col] = generator.generate(@row.name, @row.literal_values)
        end
      end
    end
  end
end
