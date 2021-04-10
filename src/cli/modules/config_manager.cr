# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.
require "yaml"

module ::Axentro::Interface
  class ConfigManager
    alias Configurable = String | Int32 | Int64 | Bool | Nil

    @@manager = nil

    def self.get_instance : ConfigManager
      @@manager ||= ConfigManager.new
      @@manager.not_nil!
    end

    @config_map : Hash(String, Configurable)
    @config : Config?
    @override : Bool = true

    def initialize
      @config_map = Hash(String, Configurable).new
    end

    def set(name : String, value : Configurable)
      return if value.nil?
      @config_map[name] = value
    end

    def get_config(override_name : String | Nil = nil) : ConfigItem?
      return nil unless File.exists?(config_path)
      @config = Config.from_yaml(File.read(config_path))
      if config = @config
        current_config = (@override && !override_name.nil?) ? config.configs[override_name] : config.configs[config.current_config]
        ConfigItem.new(config.current_config, config.config_status, current_config)
      end
    end

    def get_configs : Hash(String, Hash(String, ConfigManager::Configurable))
      raise "no configuration file found at: #{config_path} - to create, exec `axe config save [your_options]" unless File.exists?(config_path)
      config = Config.from_yaml(File.rea