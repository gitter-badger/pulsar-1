module Pulsar
  module Helpers
    module Clamp
      include Pulsar::Helpers::Shell
      include Pulsar::Helpers::Path

      def self.included(base)
        base.extend(InstanceAndClassMethods)
        base.send(:include, InstanceMethods)
      end

      module InstanceAndClassMethods
        def from_application_path?
          File.exist?("#{Dir.pwd}/config.ru")
        end
      end

      module InstanceMethods
        include InstanceAndClassMethods

        def application_path
          Dir.pwd if from_application_path?
        end

        def build_capfile(app, stage)
          # Variables
          set_log_level
          include_base_conf
          include_app(app, stage) if app

          # Recipes
          include_app_recipes(app, stage) if app
        end

        def bundle_install
          cd(config_path, verbose: verbose?) do
            run_cmd("bundle install --quiet --path=#{bundle_path.shellescape}", verbose: verbose?)
          end
        end

        def create_capfile
          touch(capfile_path, verbose: verbose?)
        end

        def create_tmp_dir
          run_cmd("mkdir -p #{tmp_path.shellescape}", verbose: verbose?)
        end

        def each_app
          Dir["#{config_apps_path}/*"].each do |path|
            yield(File.basename(path)) if File.directory?(path)
          end
        end

        def expand_applications
          if from_application_path?
            [ENV['PULSAR_APP_NAME'] || File.basename(application_path)]
          else
            #
            # Given following applications:
            # pulsar_repo/
            #   apps/
            #     app1
            #     app2
            #     app3-web
            #     app3-worker
            #     app4
            # it turns app1,app2,app3* into
            #
            # [ app1, app2, app3-web, app3-worker ]
            #
            applications.split(',').flat_map { |glob| find_apps_from_pattern(glob) }.uniq
          end
        end

        def fetch_repo
          if File.directory?(conf_repo)
            fetch_directory_repo(conf_repo)
          else
            if conf_repo =~ /\A[a-zA-Z-]+\/[a-zA-Z-]+\Z/
              fetch_git_repo("git@github.com:#{conf_repo}.git")
            else
              fetch_git_repo(conf_repo)
            end
          end
        end

        def fetch_directory_repo(repo)
          run_cmd("cp -rp #{repo} #{config_path}", verbose: verbose?)
        end

        def fetch_git_repo(repo, local = false)
          git_options = "--quiet --branch #{conf_branch}"
          git_options = "#{git_options} --depth=1" unless local

          run_cmd("git clone #{git_options} #{repo} #{config_path}", verbose: verbose?)
        end

        def find_apps_from_pattern(glob)
          found_apps = []

          Dir.glob(config_app_path("#{glob}/")).each do |path|
            found_apps << File.basename(path)
          end

          found_apps << glob if found_apps.empty?
          found_apps
        end

        def include_app(app, stage)
          app_file = config_app_defaults_path(app)
          stage_file = config_stage_path(app, stage)

          if File.exist?(app_file)
            run_cmd("cat #{app_file} >> #{capfile_path}", verbose: verbose?)
          end

          if File.exist?(stage_file)
            run_cmd("cat #{stage_file} >> #{capfile_path}", verbose: verbose?)
          end
        end

        def include_app_recipes(app, stage)
          recipes_dir = config_app_recipes_path(app)
          stage_recipes_dir = config_app_stage_recipes_path(app, stage)

          Dir["#{recipes_dir}/*.rb", "#{stage_recipes_dir}/*.rb"].each do |recipe|
            run_cmd("cat #{recipe} >> #{capfile_path}", verbose: verbose?)
          end
        end

        def include_base_conf
          run_cmd("cat #{config_base_path} >> #{capfile_path}", verbose: verbose?)
        end

        def list_apps
          each_app do |name|
            puts "#{name.cyan}: #{stages_for(name).map(&:magenta).join(', ')}"
          end
        end

        def load_configuration
          return if pulsar_configuration.nil?

          File.readlines(pulsar_configuration).each do |line|
            conf, value = line.split('=')

            ENV[conf] = value.chomp.gsub('"', '') if !conf.nil? && !value.nil?
          end
        end

        def pulsar_configuration
          path_list = []
          path_list << File.join(application_path, '.pulsar')  unless application_path.nil?
          path_list << File.join(home_path, 'config')

          path_list.find { |path| File.file?(path) }
        end

        def remove_capfile
          rm_rf(capfile_path, verbose: verbose?)
        end

        def remove_repo
          rm_rf(config_path, verbose: verbose?)
        end

        def run_capistrano(args)
          cmd = 'bundle exec cap'
          env = "CONFIG_PATH=#{config_path}"
          opts = "--file #{capfile_path}"

          env += " APP_PATH=#{application_path}" unless application_path.nil?

          cd(config_path, verbose: verbose?) do
            run_cmd("#{cmd} #{env} #{opts} #{args}", verbose: verbose?)
          end
        end

        def set_log_level
          level = log_level.upcase
          levels = %w(IMPORTANT INFO DEBUG TRACE)

          level = levels.first unless levels.include?(level)

          cmd = "echo 'logger.level = logger.level = Capistrano::Logger::#{level}' >> #{capfile_path}"

          run_cmd(cmd, verbose: verbose?)
        end

        def supported_env_vars
          %w(PULSAR_APP_NAME PULSAR_CONF_REPO PULSAR_DEFAULT_TASK)
        end

        def stages_for(app)
          exclude = %w(defaults recipes)

          Dir["#{config_app_path(app)}/*"].sort.map do |env|
            env_name = File.basename(env, '.rb')

            env_name unless exclude.include?(env_name)
          end.compact
        end

        def validate(app, stage)
          app_path = config_app_path(app)
          stage_path = config_stage_path(app, stage)
          valid_paths = File.exist?(app_path) && File.exist?(stage_path)
          fail(ArgumentError, "no pulsar config available for app=#{app}, stage=#{stage}") unless valid_paths
        end

        def with_clean_env_and_supported_vars
          vars_from_original_env = ENV.select { |var| supported_env_vars.include?(var) }

          Bundler.with_clean_env do
            vars_from_original_env.each { |var, val| ENV[var] = val }
            yield
          end
        end
      end
    end
  end
end
