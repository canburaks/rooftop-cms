# Server configuration. For a simple site this is just one entry.
role :app, [
    "deployment@rooftop-qa.vm.errorstudio.com"
]

role :web, [
    "deployment@rooftop-qa.vm.errorstudio.com"
]

role :db, %w{deployment@rooftop-qa.vm.errorstudio.com}

# Git branch
set :branch, 'qa'

#the base domain for this site - is appended to the primary domain for a prelaunch url
set :base_domain, "prelaunch.errorstudio.com"

# the prelaunch domain
set :prelaunch_domain, ->{"#{fetch(:primary_domain)}.#{fetch(:base_domain)}"}

# set the deploy domain to the prelaunch domain
set :deploy_domain, 'qa.rooftopcms.io'

#redirects domains to the primary domain as a 301
set :domain_redirects, %w()

#domains which this site will answer to (i.e. not redirect)
set :site_domains, [fetch(:deploy_domain), "~^.*\.qa\.rooftopcms\.io"]

#rewrites in nginx format - useful for specifying hard-coded urls for redirection after launch
set :url_rewrites, {}

# Wordpress settings
set :db_host, `source public/.env.qa; echo $DB_HOST`.strip
set :db_prefix, `source public/.env.qa; echo $DB_PREFIX`.strip

# Custom env vars for Rooftop
set :custom_env_vars, {
    "REDIS_HOST" => `source public/.env.qa; echo $REDIS_HOST`.strip,
    "REDIS_PORT" => `source public/.env.qa; echo $REDIS_PORT`.strip,
    "REDIS_DB" => `source public/.env.qa; echo $REDIS_DB`.strip,
}

# Custom settings for nginx
http_context = <<-CONTEXT
set_real_ip_from 10.0.0.0/8;
add_header X-Rooftop-Backend $hostname;
CONTEXT
set :nginx_custom_http_context, http_context

set :nginx_custom_server_context, "client_max_body_size 256M;"

namespace :wordpress do
  namespace :db do
    desc "Copy secrets for Wordpress from an encrypted file"
    task :configure_secrets do
      on roles :app do
        unless test("[ -f #{shared_path}/.env ]")
          set :gpg_phrase, ask("GPG passphrase for the encrypted secrets:",nil)
          yaml = `echo #{fetch(:gpg_phrase)} | gpg -d -q --batch --passphrase-fd 0 --no-mdc-warning #{File.join(File.dirname(__FILE__),"wordpress_config","shared_strings.yml.gpg")}`
          strings = YAML.load(yaml)
          strings.each do |k,v|
            set k.to_sym, v
          end
        end
      end
      
    end
  end
end
before 'wordpress:db:create_config', 'wordpress:db:configure_secrets'
