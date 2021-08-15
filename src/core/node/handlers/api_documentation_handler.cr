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
require "../virtual_file_system/file_storage"

module ::Axentro::Core
  class ApiDocumentationHandler
    include HTTP::Handler

    def initialize(@path : String, @filename : String)
    end

    def call(context)
      if context.request.path.try &.starts_with?(@path)
        context.response.headers["Content-Type"] = "text/html"
        context.response << FileStorage.get(@filename).gets_to_end
      else
        call_next(context)
      end
    end

    def request_