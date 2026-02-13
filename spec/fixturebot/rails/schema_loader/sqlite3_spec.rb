# frozen_string_literal: true

require "fixturebot/rails"

RSpec.describe FixtureBot::Rails::SchemaLoader, "SQLite UUID detection" do
  before do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

    ActiveRecord::Schema.define(version: 2024_01_01_000000) do
      create_table "users", force: :cascade do |t|
        t.string "name"
        t.timestamps
      end
    end
  end

  after do
    ActiveRecord::Base.connection_pool.disconnect!
  end

  let(:connection) { ActiveRecord::Base.connection }

  subject(:schema) { described_class.load }

  # SQLite has no native uuid column type. UUIDs are typically stored in
  # varchar(36) columns, which the adapter reports as `column.type` `:string`.
  # Auto-detection cannot distinguish these from regular string columns, so
  # the loader falls back to the :integer strategy.
  before do
    string_column = instance_double(
      ActiveRecord::ConnectionAdapters::Column,
      name: "id",
      type: :string
    )
    allow(connection).to receive(:primary_key).and_call_original
    allow(connection).to receive(:primary_key).with("users").and_return("id")
    allow(connection).to receive(:columns).and_call_original
    allow(connection).to receive(:columns).with("users").and_return([string_column])
  end

  it "returns :integer because column type is :string, not :uuid" do
    expect(schema.tables[:users].primary_key_type).to eq(:integer)
  end

  context "when table has no primary key" do
    before do
      allow(connection).to receive(:primary_key).with("users").and_return(nil)
    end

    it "returns :integer" do
      expect(schema.tables[:users].primary_key_type).to eq(:integer)
    end
  end
end
