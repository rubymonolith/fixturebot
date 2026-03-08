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
        pk_column_name = @connection.primary_key(name) || "id"
        pk_column = @connection.columns(name).find { |c| c.name == pk_column_name }
        key = pk_column && pk_column.type == :uuid ? Key::Uuid : Key::Integer

        columns = @connection.columns(name)
          .reject { |c| c.name == pk_column_name || timestamp_column?(c.name) }
          .map { |c| c.name.to_sym }

        fk_associations = @connection.foreign_keys(name).map do |fk|
          Schema::BelongsTo.new(
            name: association_name(fk.column),
            table: fk.to_table.to_sym,
            foreign_key: fk.column.to_sym
          )
        end

        polymorphic_associations = detect_polymorphic_associations(name, columns, fk_associations)

        associations = fk_associations + polymorphic_associations

        Schema::Table.new(
          name: name.to_sym,
          singular_name: singularize(name),
          columns: columns,
          associations: associations,
          key: key,
          primary_key: pk_column_name.to_sym
        )
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

      def timestamp_column?(name)
        %w[created_at updated_at].include?(name)
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

      def detect_polymorphic_associations(table_name, columns, fk_associations)
        fk_column_names = fk_associations.map { |a| a.foreign_key }
        id_columns = columns.select { |c| c.to_s.end_with?("_id") }

        id_columns.filter_map do |id_col|
          next if fk_column_names.include?(id_col)

          name = id_col.to_s.sub(/_id$/, "").to_sym
          type_col = Schema::PolymorphicBelongsTo.foreign_type(name)
          next unless columns.include?(type_col)

          Schema::PolymorphicBelongsTo.new(
            name: name,
            foreign_key: id_col,
            foreign_type: type_col
          )
        end
      end
    end
  end
end
