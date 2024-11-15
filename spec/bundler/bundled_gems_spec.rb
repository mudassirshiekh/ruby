require "bundled_gems"

RSpec.describe "bundled_gems.rb" do
  ENV["TEST_BUNDLED_GEMS"] = "true"

  def script(code, options = {})
    options[:artifice] ||= "compact_index"
    ruby("require 'bundler/inline'\n\n" + code, options)
  end

  it "Show warning require and LoadError" do
    script <<-RUBY
      gemfile do
        source "https://rubygems.org"
      end

      begin
        require "csv"
      rescue LoadError
      end
      require "ostruct"
    RUBY

    expect(err).to include(/csv was loaded from (.*) from Ruby 3.4.0/)
    expect(err).to include(/ostruct was loaded from (.*) from Ruby 3.5.0/)
  end

  it "Show warning when bundled gems called as dependency" do
    build_lib "activesupport", "7.0.7.2" do |s|
      s.write "lib/active_support/all.rb", "require 'ostruct'"
    end

    script <<-RUBY, env: { "BUNDLER_SPEC_GEM_REPO" => gem_repo1.to_s }
      gemfile do
        source "https://gem.repo1"
        path "#{lib_path}" do
          gem "activesupport", "7.0.7.2"
        end
      end

      require "active_support/all"
    RUBY

    expect(err).to include(/ostruct was loaded from (.*) from Ruby 3.5.0/)
    # TODO: We should assert caller location like below:
    # $GEM_HOME/gems/activesupport-7.0.7.2/lib/active_support/core_ext/big_decimal.rb:3: warning: bigdecimal ...
  end

  it "Show warning dash gem like net/smtp" do
    script <<-RUBY
      gemfile do
        source "https://rubygems.org"
      end

      begin
        require "net/smtp"
      rescue LoadError
      end
    RUBY

    expect(err).to include(/net\/smtp was loaded from (.*) from Ruby 3.1.0/)
    expect(err).to include("You can add net-smtp")
  end

  it "Show warning when bundle exec with ruby and script" do
    code = <<-RUBY
      require "ostruct"
    RUBY
    create_file("script.rb", code)
    create_file("Gemfile", "source 'https://rubygems.org'")

    bundle "exec ruby script.rb"

    expect(err).to include(/ostruct was loaded from (.*) from Ruby 3.5.0/)
  end

  it "Show warning when bundle exec with shebang's script" do
    code = <<-RUBY
      #!/usr/bin/env ruby
      require "ostruct"
    RUBY
    create_file("script.rb", code)
    FileUtils.chmod(0o777, bundled_app("script.rb"))
    create_file("Gemfile", "source 'https://rubygems.org'")

    bundle "exec ./script.rb"

    expect(err).to include(/ostruct was loaded from (.*) from Ruby 3.5.0/)
  end

  it "Show warning when bundle exec with -r option" do
    create_file("Gemfile", "source 'https://rubygems.org'")
    bundle "exec ruby -rostruct -e ''"

    expect(err).to include(/ostruct was loaded from (.*) from Ruby 3.5.0/)
  end

  it "Show warning when warn is not the standard one in the current scope" do
    script <<-RUBY
      module My
        def warn(msg)
        end

        def my
          gemfile do
            source "https://rubygems.org"
          end

          require "ostruct"
        end

        extend self
      end

      My.my
    RUBY

    expect(err).to include(/ostruct was loaded from (.*) from Ruby 3.5.0/)
  end

  it "Show warning when bundled gems called as dependency" do
    build_lib "activesupport", "7.0.7.2" do |s|
      s.write "lib/active_support/all.rb", "require 'ostruct'"
    end
    build_lib "ostruct", "1.0.0" do |s|
      s.write "lib/ostruct.rb", "puts 'ostruct'"
    end

    script <<-RUBY, env: { "BUNDLER_SPEC_GEM_REPO" => gem_repo1.to_s }
      gemfile do
        source "https://gem.repo1"
        path "#{lib_path}" do
          gem "activesupport", "7.0.7.2"
          gem "ostruct"
        end
      end

      require "active_support/all"
    RUBY

    expect(err).to be_empty
  end

  it "Don't show warning with net/smtp when net-smtp on Gemfile" do
    build_lib "net-smtp", "1.0.0" do |s|
      s.write "lib/net/smtp.rb", "puts 'net-smtp'"
    end

    script <<-RUBY, env: { "BUNDLER_SPEC_GEM_REPO" => gem_repo1.to_s }
      gemfile do
        source "https://gem.repo1"
        path "#{lib_path}" do
          gem "net-smtp"
        end
      end

      require "net/smtp"
    RUBY

    expect(err).to be_empty
  end

  it "Don't show warning for reline when using irb from standard library" do
    create_file("Gemfile", "source 'https://rubygems.org'")
    bundle "exec ruby -rirb -e ''"

    expect(err).to include(/irb was loaded from (.*) from Ruby 3.5.0/)
    expect(err).to_not include(/reline was loaded from (.*) from Ruby 3.5.0/)
  end
end
