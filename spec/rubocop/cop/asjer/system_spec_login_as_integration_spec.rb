# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Asjer::SystemSpecLoginAs, :isolated_environment do
  include_context 'mock console output'

  let(:paths) do
    %w[
      spec/system/authentication_spec.rb
      spec/system/admin/authentication_spec.rb
      spec/requests/authentication_spec.rb
      spec/support/authentication.rb
      test/system/authentication_test.rb
    ]
  end
  let(:cop_settings) { { 'Enabled' => true } }
  let(:report) { JSON.parse($stdout.string) }
  let(:offense_counts) do
    report.fetch('files').to_h { |file| [file.fetch('path'), file.fetch('offenses').size] }
  end
  let(:expected_counts) do
    {
      'spec/system/authentication_spec.rb' => 1,
      'spec/system/admin/authentication_spec.rb' => 1,
      'spec/requests/authentication_spec.rb' => 0,
      'spec/support/authentication.rb' => 0,
      'test/system/authentication_test.rb' => 0
    }
  end

  before do
    File.write('.rubocop.yml', {
      'plugins' => ['rubocop-asjer'],
      'AllCops' => { 'NewCops' => 'enable' },
      'Asjer/SystemSpecLoginAs' => cop_settings
    }.to_yaml)
    paths.each do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "login_as(user)\n")
    end
  end

  it 'only reports offenses in the default Include paths', :aggregate_failures do
    expect(RuboCop::CLI.new.run(%w[--only Asjer/SystemSpecLoginAs --format json --cache false spec test])).to eq(1)
    expect(offense_counts).to eq(expected_counts)
  end

  context 'with a custom Include' do
    let(:cop_settings) { { 'Enabled' => true, 'Include' => ['spec/requests/**/*.rb'] } }
    let(:expected_counts) do
      {
        'spec/system/authentication_spec.rb' => 0,
        'spec/system/admin/authentication_spec.rb' => 0,
        'spec/requests/authentication_spec.rb' => 1,
        'spec/support/authentication.rb' => 0,
        'test/system/authentication_test.rb' => 0
      }
    end

    it 'uses the configured file scope instead of the default system spec paths', :aggregate_failures do
      expect(RuboCop::CLI.new.run(%w[--only Asjer/SystemSpecLoginAs --format json --cache false spec test])).to eq(1)
      expect(offense_counts).to eq(expected_counts)
    end
  end
end
