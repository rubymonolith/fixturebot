# frozen_string_literal: true

RSpec.describe FixtureBot::Key, ".resolve" do
  it "resolves :integer to Key::Integer" do
    expect(FixtureBot::Key.resolve(:integer)).to be_a(FixtureBot::Key::Integer)
  end

  it "resolves :uuid to Key::UUID" do
    expect(FixtureBot::Key.resolve(:uuid)).to be_a(FixtureBot::Key::UUID)
  end

  it "passes through objects responding to #generate" do
    custom = Object.new
    def custom.generate(table_name, record_name) = 1
    expect(FixtureBot::Key.resolve(custom)).to be(custom)
  end

  it "raises ArgumentError for unsupported symbols" do
    expect { FixtureBot::Key.resolve(:bigint) }.to raise_error(ArgumentError, /unsupported primary key type/)
  end

  it "raises ArgumentError for objects not responding to #generate" do
    expect { FixtureBot::Key.resolve("not a key") }.to raise_error(ArgumentError, /respond to #generate/)
  end
end
