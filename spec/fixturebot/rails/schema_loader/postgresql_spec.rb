# frozen_string_literal: true

require "fixturebot/rails"

RSpec.describe FixtureBot::Rails::SchemaLoader, "PostgreSQL UUID detection" do
  before do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

    ActiveRecord::Schema.define(version: 2024_01_01_000000) do
      create_table "users", force: :cascade do |t|
        t.string "name"
        t.timestamps
      end

      create_table "posts", force: :cascade do |t|
        t.string "title"
        t.timestamps
      end
    end
  end

  after do
    ActiveRecord::Base.connection_pool.disconnect!
  end

  let(:connection) { ActiveRecord::Base.connection }

  subject(:schema) { described_class.load }

  # PostgreSQL has a native uuid column type. When a table is created with
  # `id: :uuid`, the adapter reports `column.type` as `:uuid`.
  before do
    uuid_column = instance_double(
      ActiveRecord::ConnectionAdapters::Column,
      name: "id",
      type: :uuid
    )
    allow(connection).to receive(:primary_key).and_call_original
    allow(connection).to receive(:primary_key).with("users").and_return("id")
    allow(connection).to receive(:columns).and_call_original
    allow(connection).to receive(:columns).with("users").and_return([uuid_column])
  end

  it "detects :uuid when column type is :uuid" do
    expect(schema.tables[:users].primary_key_type).to eq(:uuid)
  end

  it "still detects :integer for other tables" do
    expect(schema.tables[:posts].primary_key_type).to eq(:integer)
  end
end
