#!/usr/bin/env ruby
require 'rubygems'
require 'sprockets'

sprockets_root = File.join(File.dirname(__FILE__), '..')
sprockets_config = YAML.load(IO.read(File.join(sprockets_root, 'config', 'sprockets.yml')))

secretary = Sprockets::Secretary.new(
  :root         => sprockets_root, 
  :load_path    => sprockets_config[:load_path],
  :source_files => sprockets_config[:source_files]
)

secretary.concatenation.save_to(File.join(sprockets_root, sprockets_config[:output_file]))
