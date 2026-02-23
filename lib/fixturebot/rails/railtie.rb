# frozen_string_literal: true

module FixtureBot
  module Rails
    class Railtie < ::Rails::Railtie
      config.fixturebot = ActiveSupport::OrderedOptions.new

      rake_tasks do
        namespace :fixturebot do
          desc "Compile FixtureBot DSL to YAML fixture files"
          task compile: :environment do
            files = ENV["FILES"]&.split(",")&.map(&:strip)
            output_dir = ENV["OUTPUT_DIR"]

            FixtureBot::Rails.compile(
              fixtures_file: files,
              output_dir: output_dir
            )
          end
        end
      end
    end
  end
end
