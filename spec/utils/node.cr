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

module ::Units::Utils::NodeHelper
  include Axentro::Core

  class MockRequest < HTTP::Request
    def initialize(method : String, url : String = "/rpc", body : IO = IO::Memory.new, headers : HTTP::Headers = HTTP::Headers.new)
      super(method, url, headers, body, "HTTP/1.1", internal: nil)
    end
  end

  class MockResponse < HTTP::Server::Response
    @content : IO::Memory = IO::Memory.new

    def initialize
      super(@content)
    end

    def content
      @content.rewind.gets_to_end
    end
  end

  class MockContext < HTTP::Server::Context
    def initialize(method : String = "POST", url : String = "/rpc", body : IO = IO::Memory.new)
      @request = MockRequest.new(method, url, body).unsafe_as(HTTP::Request)
      @request.path = url
      @response = MockResponse.new.unsafe_as(HTTP::Server::Response)
    end
  end

  def exec_res