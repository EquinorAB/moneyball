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

module ::Axentro::Core::DApps
  ASSET_ACTIONS    = ["create_asset", "update_asset", "send_asset"]
  UTXO_ACTIONS     = ["head", "send", "hra_buy", "hra_sell", "hra_cancel", "create_token", "update_token", "lock_token", "burn_token"]
  INTERNAL_ACTIONS = UTXO_ACTIONS + ASSET_ACTIONS

  abstract class DApp
    extend Common::Denomination

    abstract def setup
    abstract def transaction_actions : Array(String)
    abstract def transaction_related?(action : String) : Bool
    abstract def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransact