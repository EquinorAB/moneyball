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

module ::Axentro::Core::Controllers
  struct WalletMessage
    include JSON::Serializable
    property address : String
  end

  class WalletInfoController
    @sockets : Array(HTTP::WebSocket) = [] of HTTP::WebSocket
    @socket_address : Hash(String, HTTP::WebSocket) = {} of String => HTTP::WebSocket

    def initialize(@blockchain : Blockchain)
    end

    def wallet_info(socket : HTTP::WebSocket)
      socket.on_close do |_|
        @sockets.delete(socket)
        @socket_address.each do |a, s|
          if s == socket
            @socket_address.delete(a)
            break
          end
        end
        debug "a w