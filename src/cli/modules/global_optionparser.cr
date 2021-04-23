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
        pa