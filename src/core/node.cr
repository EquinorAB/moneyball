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

require "./node/*"

module ::Axentro::Core
  struct NodeConnection
    property host : String
    property port : Int32
    property ssl : Bool

    def initialize(@host, @port, @ssl); end

    def to_s
      "#{host}:#{port}"
    end
  end

  class Node < HandleSocket
    alias Network = NamedTuple(
      prefix: String,
      name: String,
    )

    property phase : SetupPhase

    getter blockchain : Blockchain
    getter network_type : String
    getter chord : Chord
    getter database : Database
    getter miners_manager : MinersManager

    @miners_manager : MinersManager
    @clients_manager : ClientsManager

    @rpc_controller : Controllers::RPCController
    @rest_controller : Controllers::RESTController
    @pubsub_controller : Controllers::PubsubController
    @wallet_info_controller : Controllers::WalletInfoController

    MAX_SYNC_RETRY = 20
    @sync_retry_count : Int32 = 2
    @sync_retry_list : Set(NodeConnection) = Set(NodeConnection).new

    # child node gets this from parent on setup
    @sync_blocks_target_index : Int64 = 0_i64
    @validation_hash : String = ""

    # ameba:disable Metrics/CyclomaticComplexity
    def initialize(
      @is_private : Bool,
      @is_testnet : Bool,
      @bind_host : String,
      @bind_port : Int32,
      @public_host : String?,
      @public_port : Int32?,
      @ssl : Bool?,
      @connect_host : String?,
      @connect_port : Int32?,
      @wallet : Wallet?,
      @wallet_address : String,
      @database_path : String,
      @database : Database,
      @developer_fund : DeveloperFund?,
      @official_nodes : OfficialNodes?,
      @exit_on_unofficial : Bool,
      @security_level_percentage : Int64,
      @sync_chunk_size : Int32,
      @record_nonces : Bool,
      @max_miners : Int32,
      @max_private_nodes : Int32,
      @whitelist : Array(String),
      @whitelist_message : String,
      @metrics_whitelist : Array(String),
      @use_ssl : Bool = false
    )
      welcome

      @phase = SetupPhase::NONE

      @network_type = @is_testnet ? "testnet" : "mainnet"
      @blockchain = Blockchain.new(@network_type, @wallet, @wallet_address, @database_path, @database, @developer_fund, @official_nodes, @security_level_percentage, @sync_chunk_size, @record_nonces, @max_miners, is_standalone?)
      @chord = Chord.new(@database, @connect_host, @connect_port, @public_host, @public_port, @ssl, @network_type, @is_private, @use_ssl, @max_private_nodes, @wallet_address, @blockchain.official_node, @exit_on_unofficial, @whitelist, @whitelist_message)
      @miners_manager = MinersManager.new(@blockchain, @is_private)
      @clients_manager = ClientsManager.new(@blockchain)

      @limiter = RateLimiter(String).new
      @limiter.bucket(:incoming_nonces, 1_u32, 30.seconds)

      # Configure HTTP throttle
      Defense.store = Defense::MemoryStore.new
      Defense.throttle("throttle requests per second for creating transactions via API", limit: 500, period: 1) do |request|
        if @phase == SetupPhase::DONE
          if request.resource == "/api/v1/transaction" && request.method == "POST"
            "request"
          end
        end
      end

      Defense.throttle("throttle requests per second for general API", limit: 10, period: 1) do |request|
        if @phase == SetupPhase::DONE
          remote_connection = NetworkUtil.get_remote_connection(request)
          if request.resource.starts_with?("/api")
            remote_connection.ip
          end
        end
      end

      Defense.blocklist("ban noisy miners") do |request|
        if @phase == SetupPhase::DONE
          remote_connection = NetworkUtil.get_remote_connection(request)
          banned = MinersManager.ban_list(@miners_manager.get_mortalities)
          result = banned.includes?(remote_connection.ip)
          METRICS_MINERS_BANNED_GAUGE[kind: "banned"].set banned.size
          if result
            METRICS_MINERS_COUNTER[kind: "banned"].inc
          end
          result
        else
          false
        end
      end

      Defense.blocklist("block requests to metrics") do |request|
        remote_connection = NetworkUtil.get_remote_connection(request)
        if request.path.starts_with?("/metrics")
          !@metrics_whitelist.includes?(remote_connection.ip)
        else
          false
        end
      end

      info "max private nodes allowed to connect is #{light_green(@max_private_nodes)}"
      info "max miners allowed to connect is #{light_green(@max_miners)}"
      info "your log level is #{light_green(log_level_text)}"
      info "record nonces is set to #{light_green(@record_nonces)}"

      if @whitelist.size > 0
        info "whitelist enabled: #{@whitelist.inspect}"
        info "whitelist message: #{@whitelist_message}"
      end

      debug "is_private: #{light_green(@is_private)}"
      debug "public url: #{light_green(@public_host)}:#{light_green(@public_port)}" unless @is_private
      debug "connecting node is using ssl?: #{light_green(@use_ssl)}"
      debug "network type: #{light_green(@network_type)}"

      @rpc_controller = Controllers::RPCController.new(@blockchain)
      @rest_controller = Controllers::RESTController.new(@blockchain)
      @pubsub_controller = Controllers::PubsubController.new(@blockchain)
      @wallet_info_controller = Controllers::WalletInfoController.new(@blockchain)

      wallet_network = Wallet.address_network_type(@wallet_address)

      unless wallet_network[:name] == @network_type
        error "wallet type mismatch"
        error "node's   network: #{@network_type}"
        error "wallet's network: #{wallet_network[:name]}"
        exit -1
      end

      if chain_network = @blockchain.database.chain_network_kind
        if chain_network != (@network_type == "mainnet" ? MAINNET : TESTNET)
          error "The database is of network type: #{chain_network[:name]} but you tried to start it as network type: #{@network_type}"
          exit -1
        end
      end

      @chord.set_node(self)
      spawn proceed_setup
    end

    private def is_standalone?
      @connect_host.nil?
    end

    def i_am_a_fast_node?
      @blockchain.official_node.i_am_a_fastnode?(@wallet_address)
    end

    def fastnode_is_online?
      return true if ENV.has_key?("AX_SET_DIFFICULTY")
      @blockchain.official_node.a_fastnode_is_online?(@chord.official_nodes_list[:online].map(&.[:address]))
    end

    def get_wallet
      @wallet
    end

    def get_node_id
      @chord.context.id
    end

    def has_no_connections?
      chord.connected_nodes[:successor_list].empty?
    end

    def is_private_node?
      @is_private
    end

    def wallet_info_controller
      @wallet_info_controller
    end

    def run!
      info "Axentro node started on #{light_green(@bind_host)}:#{light_green(@bind_port)}"

      node = HTTP::Server.new(handlers)
      node.bind_tcp(@bind_host, @bind_port)
      node.listen
    end

    private def sync_chain_from_point(index : Int64, socket : HTTP::WebSocket? = nil)
      _sync_chain(index, socket)
    end

    private def sync_chain(socket : HTTP::WebSocket? = nil)
      start_slow = database.highest_index_of_kind(BlockKind::SLOW)
      _sync_chain(start_slow, socket)
    end

    # mostly on the child unless child chain is longer than parent then it happens on parent too
    private def _sync_chain(slow_start : Int64, socket : HTTP::WebSocket? = nil)
      info "start synching chain from slow index: #{slow_start}"

      s = if _socket = socket
            _socket
          elsif predecessor = @chord.find_predecessor?
            predecessor.socket
          elsif successor = @chord.find_successor?
            successor.socket
          end

      if _s = s
        info "requesting to stream slow blocks from index: #{slow_start}"
        send(s, M_TYPE_NODE_REQUEST_STREAM_SLOW_BLOCK, {start_slow: slow_start})
      else
        warning "successor not found. skip synching blockchain"

        if @phase == SetupPhase::BLOCKCHAIN_SYNCING
          @phase = SetupPhase::TRANSACTION_SYNCING
          proceed_setup
        end
      end
    end

    # def get_latest_slow_index : Int64
    #   @blockchain.has_no_blocks? ? 0_i64 : @blockchain.latest_slow_block.index
    # end

    # def get_latest_fast_index : Int64
    #   @blockchain.has_no_blocks? ? 0_i64 : (@blockchain.latest_fast_block || @blockchain.get_genesis_block).index
    # end

    private def sync_transactions(socket : HTTP::WebSocket? = nil)
      info "start synching transactions"

      s = if _socket = socket
            _socket
          elsif predecessor = @chord.find_predecessor?
            predecessor.socket
          elsif successor = @chord.find_successor?
            successor.socket
          end

      if _s = s
        transactions = @blockchain.pending_slow_transactions + @blockchain.pending_fast_transactions

        send(
          _s,
          M_TYPE_NODE_REQUEST_TRANSACTIONS,
          {
            transactions: transactions,
          }
        )
      else
        warning "successor not found. skip synching transactions"

        if @phase == SetupPhase::TRANSACTION_SYNCING
          @phase = SetupPhase::PRE_DONE
          proceed_setup
        end
      end
    end

    private def peer_handler : WebSocketHandler
      WebSocketHandler.new("/peer") { |socket, context|
        peer(socket, context)
      }
    end

    private def v1_api_documentation_handler : ApiDocumentationHandler
      ApiDocumentationHandler.new("/", "/index.html")
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def peer(socket : HTTP::WebSocket, context : HTTP::Server::Context? = nil)
      socket.on_binary do |message|
        transport = Transport.from_msgpack(message)
        message_type = transport.type
        message_content = transport.content

        case message_type
        when M_TYPE_MINER_HANDSHAKE
          METRICS_MINERS_COUNTER[kind: "attempted_join"].inc
          @miners_manager.handshake(socket, context, message_content)
        when M_TYPE_MINER_FOUND_NONCE
          if _context = context
            if miner = @miners_manager.find?(socket)
              if @limiter.rate_limited?(:incoming_nonces, miner.mid)
                METRICS_MINERS_COUNTER[kind: "rate_limit"].inc
                remaining_duration = @limiter.rate_limited?(:incoming_nonces, miner.mid)
                duration = remaining_duration.is_a?(Time::Span) ? remaining_duration.seconds : 0
                warning "rate limiting miner (#{miner.ip}:#{miner.port