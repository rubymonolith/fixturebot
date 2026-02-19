# frozen_string_literal: true

RSpec.describe FixtureBot::Key::UUID do
  subject(:key) { described_class.new }

  it "generates deterministic UUIDs" do
    uuid1 = key.generate(:users, :admin)
    uuid2 = key.generate(:users, :admin)
    expect(uuid1).to eq(uuid2)
  end

  it "generates valid UUID v5 format" do
    uuid = key.generate(:users, :admin)
    expect(uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
  end

  it "generates different UUIDs for different records" do
    uuid1 = key.generate(:users, :admin)
    uuid2 = key.generate(:users, :reader)
    expect(uuid1).not_to eq(uuid2)
  end

  it "generates different UUIDs for same name in different tables" do
    uuid1 = key.generate(:users, :admin)
    uuid2 = key.generate(:posts, :admin)
    expect(uuid1).not_to eq(uuid2)
  end
end
