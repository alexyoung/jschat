require 'optparse'

logger = nil

if Object.const_defined? :Logger
  logger = Logger.new(STDERR)
  logger = Logger.new(STDOUT)
end

ServerConfigDefaults = {
  'port' => 6789,
  'ip' => '0.0.0.0',
  'logger' => logger,
  'max_message_length' => 500
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

options = {}
default_config_file = '/etc/jschat/config.json'

ARGV.clone.options do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: #{$0} [options]" 

  opts.separator ""

  opts.on("-c", "--config=PATH", String, "Configuration file location (#{default_config_file}") { |o| options['config'] = o }
  opts.on("-p", "--port=port", String, "Port number") { |o| options['port'] = o }
  opts.on("--help", "-H", "This text") { puts opts; exit 0 }

  opts.parse!
end

options = load_options(options['config'] || default_config_file).merge options

ServerConfig = ServerConfigDefaults.merge options
