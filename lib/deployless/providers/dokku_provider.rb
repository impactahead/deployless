require 'sshkit'
require 'sshkit/dsl'
require 'securerandom'

module Deployless
  module Providers
    class DokkuProvider
      include SSHKit::DSL

      AppAlreadyExists = Class.new(StandardError)

      VERSION = '0.35.12'

      def initialize(config:, environment:)
        @config = config
        @environment = environment
      end

      def run_console
        server_ip = env_config.fetch(:server_ip)
  
        puts "Connecting to #{@environment} rails console..."
        system("ssh -t dokku@#{server_ip} enter #{app_name} web rails c")
      end

      def configure_environment
        configure
        install
        add_ssh_key
        create_app
        set_initial_environment_variables
        install_postgres
        install_redis if @config.fetch(:background_job_processor) == 'Sidekiq'

        result = "No"
        prompt = TTY::Prompt.new

        while result == "No"
          result = prompt.enum_select("Add DNS record for the domain #{env_config.fetch(:domain)} - type: A, value: #{env_config.fetch(:server_ip)}. Is it done?", ["Yes", "No"], required: true)
          if result == "No"
            puts "Please add DNS record for the domain #{env_config.fetch(:domain)} - type: A, value: #{env_config.fetch(:server_ip)} and confirm when done."
          end
        end

        configure_domain
        configure_ssl
        print_instructions
      end

      private

      def configure
        SSHKit::Backend::Netssh.configure do |ssh|
          ssh.connection_timeout = 30
          ssh.ssh_options = {
            user: env_config.fetch(:server_username),
            keys: %w(env_config.fetch(:ssh_key_path)),
            forward_agent: false,
            auth_methods: %w(publickey)
          }
        end
      end
  
      def install
        on [env_config.fetch(:server_ip)] do |host|
          unless test "dokku"
            execute :wget, '-NP', '.', 'https://dokku.com/bootstrap.sh'
            execute :sudo, "DOKKU_TAG=#{VERSION}", 'bash', 'bootstrap.sh'
          end
        end
      end
  
      def add_ssh_key
        public_key = File.read(File.expand_path(env_config.fetch(:ssh_key_path) + '.pub'))
  
        on [env_config.fetch(:server_ip)] do |host|
          unless test :dokku, 'ssh-keys:list', 'admin'
            execute "echo '#{public_key}' | sudo dokku ssh-keys:add admin"
          end
        end
      end
  
      def create_app
        app = app_name
        on [env_config.fetch(:server_ip)] do |host|
          if test :dokku, 'apps:exists', app
            raise AppAlreadyExists, "App #{app} is already created"
          else
            execute :dokku, 'apps:create', app
          end
        end
      end
  
      def set_initial_environment_variables
        secret_key_base = SecureRandom.hex(64)
  
        environment_variables = {
          'SECRET_KEY_BASE' => secret_key_base,
          'RAILS_ENV' => @environment,
          'RAKE_ENV' => @environment,
          'RAILS_LOG_TO_STDOUT' => 'enabled',
          'RAILS_SERVE_STATIC_FILES' => 'enabled'
        }
  
        app = app_name
        on [env_config.fetch(:server_ip)] do |host|
          execute :dokku, 'config:set', app, environment_variables.map { |key, value| "#{key}=#{value}" }.join(' ')
        end
      end
  
      def install_postgres
        app = app_name
        on [env_config.fetch(:server_ip)] do |host|
          unless test :dokku, 'postgres'
            execute :sudo, 'dokku', 'plugin:install', 'https://github.com/dokku/dokku-postgres.git'
          end
  
          unless test :dokku, 'postgres:exists', "#{app}-db"
            execute :dokku, 'postgres:create', "#{app}-db"
          end
  
          unless test :dokku, 'postgres:linked', "#{app}-db", app
            execute :dokku, 'postgres:link', "#{app}-db", app
          end
        end
      end

      def install_redis
        app = app_name
        on [env_config.fetch(:server_ip)] do |host|
          unless test :dokku, 'redis'
            execute :sudo, 'dokku', 'plugin:install', 'https://github.com/dokku/dokku-redis.git'
          end
  
          unless test :dokku, 'redis:exists', "#{app}-redis"
            execute :dokku, 'redis:create', "#{app}-redis"
          end
  
          unless test :dokku, 'redis:linked', "#{app}-redis", app
            execute :dokku, 'redis:link', "#{app}-redis", app
          end
        end
      end
  
      def configure_domain
        domain = env_config.fetch(:domain)
        app = app_name
  
        on [env_config.fetch(:server_ip)] do |host|
          unless test("dokku domains:report #{app} | grep #{domain}")
            execute :dokku, 'domains:clear-global'
            execute :dokku, 'domains:clear', app
            execute :dokku, 'domains:add', app, domain
          end
        end
      end
  
      def configure_ssl
        email = env_config.fetch(:email)
        app = app_name
  
        on [env_config.fetch(:server_ip)] do |host|
          unless test :dokku, 'letsencrypt'
            execute :sudo, 'dokku', 'plugin:install', 'https://github.com/dokku/dokku-letsencrypt.git'
          end
  
          unless test("dokku letsencrypt:list | grep #{app}")
            execute :dokku, 'letsencrypt:set', app, 'email', email
            execute :dokku, 'letsencrypt:enable', app
          end
        end
      end
  
      def print_instructions
        puts "Configure deployment by adding git remote:"
        puts "git remote add dokku dokku@#{env_config.fetch(:server_ip)}:#{app_name}"
        puts "Then you can deploy by running:"
        puts "git push dokku main"
      end

      def env_config
        @config.fetch(@environment.to_sym)
      end

      def app_name
        if @environment == 'production'
          @config.fetch(:app_name)
        else
          "#{@config.fetch(:app_name)}-#{@environment}"
        end
      end
    end
  end
end
