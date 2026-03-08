# frozen_string_literal: true

RSpec.describe FixtureBot::Key do
  describe "Key::Integer" do
    subject(:strategy) { FixtureBot::Key::Integer }

    it "generates deterministic IDs" do
      id1 = strategy.generate(:users, :admin)
      id2 = strategy.generate(:users, :admin)
      expect(id1).to eq(id2)
    end

    it "generates positive integers" do
      id = strategy.generate(:users, :admin)
      expect(id).to be_a(::Integer)
      expect(id).to be > 0
    end

    it "generates different IDs for different records" do
      id1 = strategy.generate(:users, :admin)
      id2 = strategy.generate(:users, :reader)
      expect(id1).not_to eq(id2)
    end
  end

  describe "Key::Uuid" do
    subject(:strategy) { FixtureBot::Key::Uuid }

    it "generates deterministic UUIDs" do
      id1 = strategy.generate(:users, :admin)
      id2 = strategy.generate(:users, :admin)
      expect(id1).to eq(id2)
    end

    it "generates valid UUID format" do
      id = strategy.generate(:users, :admin)
      expect(id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    end

    it "generates different UUIDs for different records" do
      id1 = strategy.generate(:users, :admin)
      id2 = strategy.generate(:users, :reader)
      expect(id1).not_to eq(id2)
    end
  end

  describe ".generate (backward compat)" do
    it "delegates to Integer strategy" do
      expect(FixtureBot::Key.generate(:users, :admin)).to eq(FixtureBot::Key::Integer.generate(:users, :admin))
    end
  end
end
