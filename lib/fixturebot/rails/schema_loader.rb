# frozen_string_literal: true

require "active_record"

module FixtureBot
  module Rails
    class SchemaLoader

      def self.load(connection = ActiveRecord::Base.connection)
        new(connection).load
      end

      def initialize(connection)
        @connection = connection
      end

      def load
        build_schema
      end

      private

      def build_schema
        schema = Schema.new
        table_names = user_table_names

        join_table_names = detect_join_tables(table_names)

        (table_names - join_table_names).each do |name|
          schema.add_table(build_table(name))
        end

        join_table_names.each do |name|
          schema.add_join_table(build_join_table(name))
        end

        schema
      end

      def build_table(name)
        columns = @connection.columns(name)
          .reject { |c| framework_column?(c.name) }
          .map { |c| c.name.to_sym }

        column_names = columns.map(&:to_s)
        polymorphic_pairs = detect_polymorphic_columns(column_names)

        associations = @connection.foreign_keys(name).map do |fk|
          next if polymorphic_pairs.key?(fk.column.to_s)

          Schema::BelongsTo.new(
            name: association_name(fk.column),
            table: fk.to_table.to_sym,
            foreign_key: fk.column.to_sym
          )
        end.compact

        polymorphic_associations = polymorphic_pairs.map do |id_col, type_col|
          Schema::PolymorphicBelongsTo.new(
            name: association_name(id_col),
            foreign_key: id_col.to_sym,
            type_column: type_col.to_sym
          )
        end

        Schema::Table.new(
          name: name.to_sym,
          singular_name: singularize(name),
          columns: columns,
          belongs_to_associations: associations,
          polymorphic_belongs_to_associations: polymorphic_associations
        )
      end

      def detect_polymorphic_columns(column_names)
        pairs = {}
        id_columns = column_names.select { |c| c.end_with?("_id") }
        id_columns.each do |id_col|
          type_col = id_col.sub(/_id$/, "_type")
          pairs[id_col] = type_col if column_names.include?(type_col)
        end
        pairs
      end

      def build_join_table(name)
        fk_columns = foreign_key_columns(name)

        Schema::JoinTable.new(
          name: name.to_sym,
          left_table: table_name_for_foreign_key(fk_columns[0]),
          right_table: table_name_for_foreign_key(fk_columns[1]),
          left_foreign_key: fk_columns[0].to_sym,
          right_foreign_key: fk_columns[1].to_sym
        )
      end

      def user_table_names
        @connection.tables - %w[ar_internal_metadata schema_migrations]
      end

      def framework_column?(name)
        %w[id created_at updated_at].include?(name)
      end

      def foreign_key_column?(column)
        column.name.end_with?("_id")
      end

      def foreign_key_columns(table_name)
        @connection.columns(table_name)
          .select { |c| foreign_key_column?(c) }
          .map { |c| c.name }
      end

      def association_name(column_name)
        column_name.sub(/_id$/, "").to_sym
      end

      def table_name_for_foreign_key(column_name)
        pluralize(column_name.sub(/_id$/, ""))
      end

      def singularize(word)
        ActiveSupport::Inflector.singularize(word).to_sym
      end

      def pluralize(word)
        ActiveSupport::Inflector.pluralize(word).to_sym
      end

      def detect_join_tables(table_names)
        table_names.select do |name|
          next false if @connection.primary_key(name)
          foreign_key_columns(name).size == 2
        end
      end
    end
  end
end
