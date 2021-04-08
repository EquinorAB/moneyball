
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

require "../cli"
require "../core/developer_fund/*"
require "../core/official_nodes"

module ::Axentro::Interface::Axen
  class Root < CLI
    def sub_actions : Array(AxeAction)
      [] of AxeAction
    end

    def option_parser : OptionParser | Nil
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::IS_TESTNET,
        Options::IS_PRIVATE,
        Options::BIND_HOST,
        Options::BIND_PORT,
        Options::PUBLIC_URL,
        Options::DATABASE_PATH,
        Options::CONFIG_NAME,
        Options::DEVELOPER_FUND,
        Options::FASTNODE,
        Options::SECURITY_LEVEL_PERCENTAGE,
        Options::MAX_MINERS,
        Options::MAX_PRIVATE_NODES,
        Options::OFFICIAL_NODES,
        Options::EXIT_IF_UNOFFICIAL,
        Options::SYNC_CHUNK_SIZE,
        Options::RECORD_NONCES,
        Options::ADDRESS,
        Options::WHITELIST,
        Options::WHITELIST_MESSAGE,
        Options::METRICS_WHITELIST,
      ])
    end

    private def get_connecting_port(use_ssl : Bool)
      if connect_node = G.op.__connect_node
        connect_uri = URI.parse(connect_node)
        if use_ssl
          connect_uri.port || 443
        else
          connect_uri.port || 80
        end
      end
    end

    def run_impl(action_name) : OptionParser?
      unless G.op.__is_private
        puts_help(HELP_PUBLIC_URL) unless public_url = G.op.__public_url

        public_uri = URI.parse(public_url)

        puts_help(HELP_PUBLIC_URL) unless public_host = public_uri.host