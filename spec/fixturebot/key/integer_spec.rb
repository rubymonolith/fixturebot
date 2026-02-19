# frozen_string_literal: true

RSpec.describe FixtureBot::Key::Integer do
  subject(:key) { described_class.new }

  it "generates deterministic IDs" do
    id1 = key.generate(:users, :admin)
    id2 = key.generate(:users, :admin)
    expect(id1).to eq(id2)
  end

  it "generates positive integers" do
    id = key.generate(:users, :admin)
    expect(id).to be > 0
  end

  it "generates different IDs for different records" do
    id1 = key.generate(:users, :admin)
    id2 = key.generate(:users, :reader)
    expect(id1).not_to eq(id2)
  end
end
