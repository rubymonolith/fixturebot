# frozen_string_literal: true

require "fixturebot/rails"

RSpec.describe FixtureBot::Rails::SchemaLoader do
  before do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

    ActiveRecord::Schema.define(version: 2024_01_01_000000) do
      create_table "users", force: :cascade do |t|
        t.string "name"
        t.string "email"
        t.timestamps
      end

      create_table "posts", force: :cascade do |t|
        t.string "title"
        t.text "body"
        t.integer "author_id"
        t.timestamps
      end

      add_foreign_key "posts", "users", column: "author_id"

      create_table "tags", force: :cascade do |t|
        t.string "name"
        t.timestamps
      end

      create_table "posts_tags", id: false, force: :cascade do |t|
        t.integer "post_id", null: false
        t.integer "tag_id", null: false
      end
    end
  end

  after do
    ActiveRecord::Base.connection_pool.disconnect!
  end

  subject(:schema) { described_class.load }

  it "loads regular tables with columns" do
    expect(schema.tables.keys).to contain_exactly(:users, :posts, :tags)
  end

  it "skips id, created_at, updated_at columns" do
    expect(schema.tables[:users].columns).to contain_exactly(:name, :email)
    expect(schema.tables[:posts].columns).to contain_exactly(:title, :body, :author_id)
    expect(schema.tables[:tags].columns).to contain_exactly(:name)
  end

  it "detects belongs_to associations from foreign keys" do
    associations = schema.tables[:posts].belongs_to_associations
    expect(associations.size).to eq(1)
    expect(associations.first.name).to eq(:author)
    expect(associations.first.table).to eq(:users)
    expect(associations.first.foreign_key).to eq(:author_id)
  end

  it "detects join tables" do
    expect(schema.join_tables.keys).to contain_exactly(:posts_tags)
    jt = schema.join_tables[:posts_tags]
    expect(jt.left_table).to eq(:posts)
    expect(jt.right_table).to eq(:tags)
    expect(jt.left_foreign_key).to eq(:post_id)
    expect(jt.right_foreign_key).to eq(:tag_id)
  end

  it "does not include join tables in regular tables" do
    expect(schema.tables).not_to have_key(:posts_tags)
  end

  it "defaults primary_key_type to Key::Integer for standard tables" do
    schema.tables.each_value do |table|
      expect(table.primary_key_type).to be_a(FixtureBot::Key::Integer)
    end
  end

  it "detects primary_key_column as :id for standard tables" do
    schema.tables.each_value do |table|
      expect(table.primary_key_column).to eq(:id)
    end
  end

  context "when a table has a custom primary key column" do
    before do
      ActiveRecord::Base.connection.execute('CREATE TABLE "accounts" ("account_uid" varchar PRIMARY KEY, "name" varchar)')
    end

    it "detects primary_key_column from the database" do
      expect(schema.tables[:accounts].primary_key_column).to eq(:account_uid)
    end

    it "excludes the custom primary key column from columns" do
      expect(schema.tables[:accounts].columns).to eq([:name])
    end
  end
end
