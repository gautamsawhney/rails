require "active_support/core_ext/module/attribute_accessors"
require "rails/test_unit/reporter"
require "rails/test_unit/test_requirer"

module Minitest
  class SuppressedSummaryReporter < SummaryReporter
    # Disable extra failure output after a run if output is inline.
    def aggregated_results
      super unless options[:output_inline]
    end
  end

  def self.plugin_rails_options(opts, options)
    executable = ::Rails::TestUnitReporter.executable
    opts.separator ""
    opts.separator "Usage: #{executable} [options] [files or directories]"
    opts.separator "You can run a single test by appending a line number to a filename:"
    opts.separator ""
    opts.separator "    #{executable} test/models/user_test.rb:27"
    opts.separator ""
    opts.separator "You can run multiple files and directories at the same time:"
    opts.separator ""
    opts.separator "    #{executable} test/controllers test/integration/login_test.rb"
    opts.separator ""
    opts.separator "By default test failures and errors are reported inline during a run."
    opts.separator ""

    opts.separator "Rails options:"
    opts.on("-e", "--environment ENV",
            "Run tests in the ENV environment") do |env|
      options[:environment] = env.strip
    end

    opts.on("-b", "--backtrace",
            "Show the complete backtrace") do
      options[:full_backtrace] = true
    end

    opts.on("-d", "--defer-output",
            "Output test failures and errors after the test run") do
      options[:output_inline] = false
    end

    opts.on("-f", "--fail-fast",
            "Abort test run on first failure or error") do
      options[:fail_fast] = true
    end

    opts.on("-c", "--[no-]color",
            "Enable color in the output") do |value|
      options[:color] = value
    end

    options[:color] = true
    options[:output_inline] = true
    options[:patterns] = opts.order!
  end

  # Running several Rake tasks in a single command would trip up the runner,
  # as the patterns would also contain the other Rake tasks.
  def self.rake_run(patterns) # :nodoc:
    @rake_patterns = patterns
    passed = run
    exit passed unless passed
    passed
  end

  def self.plugin_rails_init(options)
    self.run_with_rails_extension = true

    ENV["RAILS_ENV"] = options[:environment] || "test"

    unless run_with_autorun
      patterns = defined?(@rake_patterns) ? @rake_patterns : options[:patterns]
      ::Rails::TestRequirer.require_files(patterns)
    end

    unless options[:full_backtrace] || ENV["BACKTRACE"]
      # Plugin can run without Rails loaded, check before filtering.
      Minitest.backtrace_filter = ::Rails.backtrace_cleaner if ::Rails.respond_to?(:backtrace_cleaner)
    end

    # Replace progress reporter for colors.
    self.reporter.reporters.delete_if { |reporter| reporter.kind_of?(SummaryReporter) || reporter.kind_of?(ProgressReporter) }
    self.reporter << SuppressedSummaryReporter.new(options[:io], options)
    self.reporter << ::Rails::TestUnitReporter.new(options[:io], options)
  end

  mattr_accessor(:run_with_autorun)         { false }
  mattr_accessor(:run_with_rails_extension) { false }
end

Minitest.load_plugins
Minitest.extensions << 'rails'
