require 'optparse'
require 'tmpdir'

logger = nil

if Object.const_defined? :Logger
  logger = Logger.new(STDERR)
  logger = Logger.new(STDOUT)
end

ServerConfigDefaults = {
  'port' => 6789,
  'ip' => '0.0.0.0',
  'logger' => logger,
  'max_message_length' => 500,
  'tmp_files' => File.join(Dir::tmpdir, 'jschat'),
  'db_name' => 'jschat',
  'db_host' => 'localhost',
  'db_port' => 27017,
  #'db_user' => '',
  #'db_password' => '',
  # Register your instance of JsChat here: http://twitter.com/apps/create
  # 'twitter' => { 'key' => '', 'secret' => '' }
}

# Command line options will overrides these
def load_options(path)
  path = File.expand_path path
  if File.exists? path
    JSON.parse(File.read path)
  else
    {}
  end
end

def make_tmp_files
  ServerConfig['use_tmp_files'] = false
  if File.exists? ServerConfig['tmp_files']
    ServerConfig['use_tmp_files'] = true
  else
    if Dir.mkdir ServerConfig['tmp_files']
      ServerConfig['use_tmp_files'] = true
    end
  end
end

options = {}
default_config_file = '/etc/jschat/config.json'

ARGV.clone.options do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: #{$0} [options]" 

  opts.separator ""

  opts.on("-c", "--config=PATH", String, "Configuration file location (#{default_config_file}") { |o| options['config'] = o }
  opts.on("-p", "--port=PORT", String, "Port number") { |o| options['port'] = o }
  opts.on("-t", "--tmp_files=PATH", String, "Temporary files location (including pid file)") { |o| options['tmp_files'] = o }
  opts.on("--help", "-H", "This text") { puts opts; exit 0 }

  opts.parse!
end

options = load_options(options['config'] || default_config_file).merge options

ServerConfig = ServerConfigDefaults.merge options
make_tmp_files
