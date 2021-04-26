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

module ::Axentro::Interface
  class GlobalOptionParser
    @@instance : GlobalOptionParser? = nil

    def self.op : GlobalOptionParser
      @@instance ||= GlobalOptionParser.new
      @@instance.not_nil!
    end

    @connect_node : String?
    @wallet_path : String?
    @wallet_password : String?

    @is_testnet : Bool = false
    @is_testnet_changed = false
    @is_private : Bool = false
    @is_private_changed = false
    @json : Bool = false

    @bind_host : String = "0.0.0.0"
    @bind_port : Int32 = 3000
    @public_url : String?
    @database_path : String?
    @max_miners : Int32 = 512
    @max_nodes : Int32 = 512

    @address : String?
    @amount : String?
    @action : String?
    @message : String = ""
    @block_index : Int32?
    @transaction_id : String?
    @fee : String?

    @header : Bool = false

    @processes : Int32 = 1

    @encrypted : Bool = false
    @seed : String?
    @derivation : String?

    @price : String?
    @domain : String?

    @token : String?

    @config_name : String?

    @node_id : String?

    @developer_fund_path : String?
    @fastnode : Bool = false
    @official_nodes_path : String?
    @exit_if_unofficial : Bool = false

    @security_level_percentage = 20_i64
    @sync_chunk_size = 100

    @is_fast_transaction : Bool = false
    @record_nonces : Bool = false

    @whitelist : Array(String) = [] of String
    @whitelist_message : String = ""
    @metrics_whitelist : Array(String) = [] of String

    @asset_id : String?
    @asset_name : String?
    @asset_description : String?
    @asset_media_location : String?
    @asset_locked : Bool = false

    enum Options
      # common options
      CONNECT_NODE
      WALLET_PATH
      WALLET_PASSWORD
      # flags
      IS_TESTNET
      IS_PRIVATE
      JSON
      # for node setting up
      BIND_HOST
      BIND_PORT
      PUBLIC_URL
      DATABASE_PATH
      # for transaction
      ADDRESS
      AMOUNT
      ACTION
      MESSAGE
      BLOCK_INDEX
      TRANSACTION_ID
      FEE
      IS_FAST_TRANSACTION
      # for blockchain
      HEADER
      # for miners
      PROCESSES
      # for wallet
      ENCRYPTED
      SEED
      DERIVATION
      # for hra
      PRICE
      DOMAIN
      # for tokens
      TOKEN
      # for config
      CONFIG_NAME
      # for node
      NODE_ID
      DEVELOPER_FUND
      FASTNODE
      OFFICIAL_NODES
      SECURITY_LEVEL_PERCENTAGE
      SYNC_CHUNK_SIZE
      MAX_MINERS
      MAX_PRIVATE_NODES
      EXIT_IF_UNOFFICIAL
      RECORD_NONCES
      WHITELIST
      WHITELIST_MESSAGE
      # for assets
      ASSET_ID
      ASSET_NAME
      ASSET_DESCRIPTION
      ASSET_MEDIA_LOCATION
      ASSET_LOCKED
      METRICS_WHITELIST
    end

    def create_option_parser(actives : Array(Options)) : OptionParser
      OptionParser.new do |parser|
        parse_version(parser)
        parse_node(parser, actives)
        parse_wallet_path(parser, actives)
        parse_password(parser, actives)
        parse_mainnet(parser, actives)
        parse_testnet(parser, actives)
        parse_public(parser, actives)
        parse_private(parser, actives)
        parse_json(parser, actives)
        parse_bind_host(parser, actives)
        parse_bind_port(parser, actives)
        parse_public_url(parser, actives)
        parse_database(parser, actives)
        parse_address(parser, actives)
        parse_amount(parser, actives)
        parse_action(parser, actives)
        parse_message(parser, actives)
        parse_block_index(parser, actives)
        parse_transaction_id(parser, actives)
        parse_fee(parser, actives)
        parse_header(parser, actives)
        parse_processes(parser, actives)
        parse_encrypted(parser, actives)
        parse_price(parser, actives)
        parse_domain(parser, actives)
        parse_token(parser, actives)
        parse_config_name(parser, actives)
        parse_node_id(parser, actives)
        parse_developer_fund(parser, actives)
        parse_fast_node(parser, actives)
        parse_official_nodes(parser, actives)
        parse_if_unofficial_nodes(parser, actives)
        parse_security_level_percentage(parser, actives)
        parse_sync_chunk_size(parser, actives)
        parse_slow_transaction(parser, actives)
        parse_fast_transaction(parser, actives)
        parse_max_miners(parser, actives)
        parse_max_private_nodes(parser, actives)
        parse_seed(parser, actives)
        parse_derivation(parser, actives)
        parse_record_nonces(parser, actives)
        parse_whitelist(parser, actives)
        parse_whitelist_message(parser, actives)
        parse_asset_id(parser, actives)
        parse_asset_name(parser, actives)
        parse_asset_description(parser, actives)
        parse_asset_media_location(parser, actives)
        parse_asset_locked(parser, actives)
        parse_metrics_whitelist(parser, actives)
      end
    end

    private def parse_version(parser : OptionParser)
      parser.on("-v", "--version", "version") {
        puts {{ read_file("#{__DIR__}/../../../version.txt") }}
        exit 0
      }
    end

    private def parse_node(parser : OptionParser, actives : Array(Options))
      parser.on("-n NODE", "--node=NODE", I18n.translate("cli.options.node.url")) { |connect_node|
        @connect_node = connect_node
      } if is_active?(actives, Options::CONNECT_NODE)
    end

    private def parse_wallet_path(parser : OptionParser, actives : Array(Options))
      parser.on(
        "-w WALLET_PATH",
        "--wallet_path=WALLET_PATH",
        I18n.translate("cli.options.wallet")
      ) { |wallet_path| @wallet_path = wallet_path } if is_active?(actives, Options::WALLET_PATH)
    end

    private def parse_password(parser : OptionParser, actives : Array(Options))
      parser.on("--password=PASSWORD", I18n.translate("cli.options.password")) { |password|
        @wallet_password = password
      } if is_active?(actives, Options::WALLET_PASSWORD)
    end

    private def parse_mainnet(parser : OptionParser, actives : Array(Options))
      parser.on("--mainnet", I18n.translate("cli.options.mainnet")) {
        @is_testnet = false
        @is_testnet_changed = true
      } if is_active?(actives, Options::IS_TESTNET)
    end

    private def parse_testnet(parser : OptionParser, actives : Array(Options))
      parser.on("--testnet", I18n.translate("cli.options.testnet")) {
        @is_testnet = true
        @is_testnet_changed = true
      } if is_active?(actives, Options::IS_TESTNET)
    end

    private def parse_if_unofficial_nodes(parser : OptionParser, actives : Array(Options))
      parser.on("--exit-if-unofficial", I18n.translate("cli.options.unofficial")) {
        @exit_if_unofficial = true
      } if is_active?(actives, Options::EXIT_IF_UNOFFICIAL)
    end

    private def parse_public(parser : OptionParser, actives : Array(Options))
      parser.on("--public", I18n.translate("cli.options.public.mode")) {
        @is_private = false
        @is_private_changed = true
      } if is_active?(actives, Options::IS_PRIVATE)
    end

    private def parse_private(parser : OptionParser, actives : Array(Options))
      parser.on("--private", I18n.translate("cli.options.private")) {
        