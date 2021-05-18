
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
require "json"

module ::Axentro::Core::TransactionModels
  enum TransactionKind
    SLOW
    FAST

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end

  enum TransactionVersion
    V1

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end

  enum BlockVersion
    V1
    V2

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end

  enum HashVersion
    V1
    V2

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end
