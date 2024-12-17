require 'sshkit'
require 'sshkit/dsl'
require 'securerandom'

module Deployless
  class Dokku
    include SSHKit::DSL

    def initialize(config)
      @config = config
    end

    def configure
      SSHKit::Backend::Netssh.configure do |ssh|
        ssh.connection_timeout = 30
        ssh.ssh_options = {
          user: @config.fetch(:production_server_username),
          keys: %w(@config.fetch(:ssh_key_path)),
          forward_agent: false,
          auth_methods: %w(publickey)
        }
      end
    end

    def install
      on [@config.fetch(:production_server_ip)] do |host|
        execute :wget, '-NP', '.', 'https://dokku.com/bootstrap.sh'
        execute :sudo, 'DOKKU_TAG=v0.35.12', 'bash', 'bootstrap.sh'
      end
    end

    def add_ssh_key
      public_key = File.read(File.expand_path(@config.fetch(:ssh_key_path) + '.pub'))

      on [@config.fetch(:production_server_ip)] do |host|
        execute "echo '#{public_key}' | sudo dokku ssh-keys:add admin"
      end
    end

    def create_app
      app_name = @config.fetch(:app_name)

      on [@config.fetch(:production_server_ip)] do |host|
        execute :dokku, 'apps:create', app_name
      end
    end

    def set_initial_environment_variables
      app_name = @config.fetch(:app_name)
      secret_key_base = SecureRandom.hex(64)

      environment_variables = {
        'SECRET_KEY_BASE' => secret_key_base,
        'RAILS_ENV' => 'production',
        'RAKE_ENV' => 'production',
        'RAILS_LOG_TO_STDOUT' => 'enabled',
        'RAILS_SERVE_STATIC_FILES' => 'enabled'
      }

      on [@config.fetch(:production_server_ip)] do |host|
        execute :dokku, 'config:set', app_name, environment_variables.map { |key, value| "#{key}=#{value}" }.join(' ')
      end
    end

    def install_postgres
      app_name = @config.fetch(:app_name)

      on [@config.fetch(:production_server_ip)] do |host|
        execute :sudo, 'dokku', 'plugin:install', 'https://github.com/dokku/dokku-postgres.git'
        execute :dokku, 'postgres:create', "#{app_name}-db"
        execute :dokku, 'postgres:link', "#{app_name}-db", app_name
      end
    end

    def configure_domain
      domain = @config.fetch(:domain)
      app_name = @config.fetch(:app_name)

      on [@config.fetch(:production_server_ip)] do |host|
        execute :dokku, 'domains:clear-global'
        execute :dokku, 'domains:clear', app_name
        execute :dokku, 'domains:add', app_name, domain
      end
    end

    def configure_ssl
      email = @config.fetch(:email)
      app_name = @config.fetch(:app_name)

      on [@config.fetch(:production_server_ip)] do |host|
        execute :sudo, 'dokku', 'plugin:install', 'https://github.com/dokku/dokku-letsencrypt.git'
        execute :dokku, 'letsencrypt:set', app_name, 'email', email
        execute :dokku, 'letsencrypt:enable', app_name
      end
    end

    def print_instructions
      puts "Configure deployment by adding git remote:"
      puts "git remote add dokku dokku@#{@config.fetch(:production_server_ip)}:#{@config.fetch(:app_name)}"
      puts "Then you can deploy by running:"
      puts "git push dokku main"
    end

    def run_console
      app_name = @config.fetch(:app_name)
      server_ip = @config.fetch(:production_server_ip)

      puts "Connecting to production rails console..."
      system("ssh -t dokku@#{server_ip} enter #{app_name} web rails c")
    end
  end
end
